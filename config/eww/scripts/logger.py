#!/usr/bin/env python

# Authored By dharmx <dharmx@gmail.com> under:
# GNU GENERAL PUBLIC LICENSE
# Version 3, 29 June 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.
#
# Permissions of this strong copyleft license are conditioned on
# making available complete source code of licensed works and
# modifications, which include larger works using a licensed work,
# under the same license. Copyright and license notices must be
# preserved. Contributors provide an express grant of patent rights.
#
# Read the complete license here:
# <https://github.com/dharmx/vile/blob/main/LICENSE.txt>

import datetime
import os
import dbus
import gi
import typing
import time
import re
import pathlib
import sys

# supress GIO warnings
gi.require_version("Gtk", "3.0")
gi.require_version("GdkPixbuf", "2.0")

from gi.repository import GdkPixbuf, Gio, GLib, Gtk
from dbus.mainloop.glib import DBusGMainLoop
from html.parser import HTMLParser

# image data dir
cache_dir = os.path.expandvars("$XDG_CACHE_HOME/image_data")
os.makedirs(cache_dir, exist_ok=True)

# log file
log_file = os.path.expandvars("$XDG_CONFIG_HOME/eww/scripts/notifications.txt")
if not os.path.exists(log_file):
    open(log_file, "w").close()

def clean_text(text):
    # Remove HTML tags
    class HTMLTagStripper(HTMLParser):
        def __init__(self):
            super().__init__()
            self.reset()
            self.strict = False
            self.convert_charrefs = True
            self.text = []

        def handle_data(self, data):
            self.text.append(data)

        def get_text(self):
            return ''.join(self.text)

    stripper = HTMLTagStripper()
    stripper.feed(text)
    text = stripper.get_text()

    # Replace multiple spaces with a single space
    text = re.sub(r'\s+', ' ', text)
    # Escape double quotes
    text = text.replace('"', '\\"')

    return text

def unwrap(value):
    # Try to trivially translate a dictionary's elements into nice string
    # formatting.
    if isinstance(value, dbus.ByteArray):
        return "".join([str(byte) for byte in value])
    if isinstance(value, (dbus.Array, list, tuple)):
        return [unwrap(item) for item in value]
    if isinstance(value, (dbus.Dictionary, dict)):
        return dict([(unwrap(x), unwrap(y)) for x, y in value.items()])
    if isinstance(value, (dbus.Signature, dbus.String)):
        return str(value)
    if isinstance(value, dbus.Boolean):
        return bool(value)
    if isinstance(
        value,
        (dbus.Int16, dbus.UInt16, dbus.Int32, dbus.UInt32, dbus.Int64, dbus.UInt64),
    ):
        return int(value)
    if isinstance(value, dbus.Byte):
        return bytes([int(value)])
    return value

def save_img_byte(px_args: typing.Iterable, save_path: str):
    GdkPixbuf.Pixbuf.new_from_bytes(
        width=px_args[0],
        height=px_args[1],
        has_alpha=px_args[3],
        data=GLib.Bytes(px_args[6]),
        colorspace=GdkPixbuf.Colorspace.RGB,
        rowstride=px_args[2],
        bits_per_sample=px_args[4],
    ).savev(save_path, "png")

def get_gtk_icon_path(icon_name: str, size: int = 128) -> str:
    if size < 32:
        return os.path.expandvars("$XDG_CONFIG_HOME/eww/assets/bell.png")
    if info := Gtk.IconTheme.get_default().lookup_icon(icon_name, size, 0):
        return info.get_filename()
    return get_gtk_icon_path(icon_name, size - 1)


def get_mime_icon_path(mimetype: str, size: int = 32) -> str:
    icon = Gio.content_type_get_icon(mimetype)
    theme = Gtk.IconTheme.get_default()
    if info := theme.choose_icon(icon.get_names(), size, 0):
        return info.get_filename()

def message_callback(_, message):
    if type(message) != dbus.lowlevel.MethodCallMessage:
        return
    args_list = message.get_args_list()
    args_list = [unwrap(item) for item in args_list]
    details = {
        "appname": args_list[0].strip() or "Unknown",
        "summary": clean_text(args_list[3].strip()) or "Summary Unavailable",
        "body": clean_text(args_list[4].strip()) or "Body Unavailable",
        "id": datetime.datetime.now().strftime("%s"),
    }

    if args_list[2].strip():
        # if the iconpath value is a path i.e. if it has slashes on them
        # then assign that as the iconpath
        if "/" in args_list[2] or "." in args_list[2]:
            details["iconpath"] = args_list[2]
        else:
            # and if the iconpath is just a string that has no extensions or,
            # a pathlike structure like: 'bell' or 'custom-folder-bookmark'
            # it might have a dash (-) sign but not all the time.
            # then fetch that actual path of that icon as that is a part of the
            # icon theme naming convention and the current icon theme should probably have it
            details["iconpath"] = get_gtk_icon_path(args_list[2])
    else:
        # if there are no icon hints then use fallback (generic bell)
        details["iconpath"] = get_gtk_icon_path("custom-notification")

    if "image-data" in args_list[6]:
        # capture the raw image bytes and save them to the cache_dir/x.png path
        details["iconpath"] = f"{cache_dir}/{details['id']}.png"
        save_img_byte(args_list[6]["image-data"], details["iconpath"])
    
    print(details) # debug

    # print notification data into log_file always on first line
    # (notification :app "appname" :summary "summary" :body "body" :image "iconpath" :time "HH:MM" :id "timestamp")
    with open(log_file, "r+") as file:
        content = file.read()
        file.seek(0, 0)
        file.write(
            '(notification :app "{}" :summary "{}" :body "{}" :image "{}" :time "{}" :id "{}")'.format(
                details["appname"],
                details["summary"],
                details["body"],
                details["iconpath"],
                datetime.datetime.now().strftime("%H:%M"),
                details["id"],
            )
            + '\n' + content
        )
    
DBusGMainLoop(set_as_default=True)

rules = {
    "interface": "org.freedesktop.Notifications",
    "member": "Notify",
    "eavesdrop": "true", # https://bugs.freedesktop.org/show_bug.cgi?id=39450
}

bus = dbus.SessionBus()
bus.add_match_string(",".join([f"{key}={value}" for key, value in rules.items()]))
bus.add_message_filter(message_callback)

loop = GLib.MainLoop()
try:
    loop.run()
except KeyboardInterrupt:
    bus.close()
