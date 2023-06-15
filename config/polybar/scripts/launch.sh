#!/usr/bin/env sh

if ! pgrep -x polybar; then
    polybar -c ~/.config/polybar/config.ini spotify &
    polybar -c ~/.config/polybar/config.ini weather &
    polybar -c ~/.config/polybar/config.ini updates &
    polybar -c ~/.config/polybar/config.ini bspwm &
    polybar -c ~/.config/polybar/config.ini memory &
    polybar -c ~/.config/polybar/config.ini cpu &
    polybar -c ~/.config/polybar/config.ini pulseaudio &
    polybar -c ~/.config/polybar/config.ini date &
else
    pkill -USR1 polybar
fi
