#!/usr/bin/env zsh

function _set_vars() {
  typeset -gx DUNST_CACHE_DIR="$HOME/.cache/dunst"
  typeset -gx DUNST_LOG="$DUNST_CACHE_DIR/notifications.txt"
  typeset -gx ICON_THEME="Papirus-Dark"
}
_set_vars

function _unset_vars() {
  unset DUNST_CACHE_DIR
  unset DUNST_LOG
}

mkdir "$DUNST_CACHE_DIR" 2>/dev/null
touch "$DUNST_LOG" 2>/dev/null

function create_cache() {

  local summary
  local body
  [ "$DUNST_SUMMARY" = "" ] && summary="Summary unavailable." || summary="$(print "$DUNST_SUMMARY" | tr '"' "'")"
  [ "$DUNST_BODY" = "" ] && body="Body unavailable." || body="$(print "$DUNST_BODY" | tr '\n' ' ' | tr '"' "'")"
  # | recode html)"

  local image_width=50
  local image_height=50

  local screenshot=false
  local show=true

  if [[ $DUNST_APP_NAME == "Spotify" || $DUNST_APP_NAME == "Color Picker" ]]; then
    image_width=90
    image_height=90
  elif [[ $DUNST_APP_NAME == "Screenshot" ]]; then
    image_width=420
    image_height=220
    screenshot=true
    show=false
  fi

  local timestamp=$(cat $DUNST_CACHE_DIR/timestamp/$DUNST_ID)

  if [[ $DUNST_ICON_PATH == "" ]]; then
    ICON_PATH=/usr/share/icons/Papirus-Dark/128x128/apps/$DUNST_APP_NAME.svg
  else
    FIXED_ICON_PATH=$(echo ${DUNST_ICON_PATH} | sed 's/32x32/48x48/g')
    ICON_PATH=$FIXED_ICON_PATH
  fi

  local SPOTIFY_TITLE=$(echo $DUNST_SUMMARY | tr '/' '-')

  if [[ $DUNST_APP_NAME == "Spotify" ]]; then
    ICON_PATH=$DUNST_CACHE_DIR/cover/$SPOTIFY_TITLE.png

  elif [[ $DUNST_APP_NAME == "Kotatogram Desktop" ]]; then
    ICON_PATH=$HOME/.config/eww/assets/telegram.png

  elif [[ $DUNST_APP_NAME == "discord" ]]; then
    ICON_PATH=$HOME/.config/eww/assets/discord.png
  fi

  # pipe stdout -> pipe cat stdin (cat conCATs multiple files and sends to stdout) -> absorb stdout from cat
  # concat: "one" + "two" + "three" -> notice how the order matters i.e. "one" will be prepended
sleep 1 && print '(notification-card :id "'$DUNST_ID'" :pop "dunstctl history-pop '$DUNST_ID'" :body "'$body'" :summary "'$summary'" :image "'$ICON_PATH'" :image_width "'$image_width'" :image_height "'$image_height'" :app "'$DUNST_APP_NAME'" :time "'$timestamp'" :show "'$show'" :screenshot "'$screenshot'")' \
  | cat - "$DUNST_LOG" \
  | sponge "$DUNST_LOG"
}

function compile_caches() {
  tr '\n' ' ' < "$DUNST_LOG"
}

function make_literal() {
  local caches="$(compile_caches)"
  [[ "$caches" == "" ]] \
  && print '(box :class "notifications-empty-box" :height 500 :orientation "v" :space-evenly "false" (image :class "notifications-empty-banner" :valign "end" :vexpand "true" :path "assets/fallback.png" :image-width 100 :image-height 100) (label :vexpand "true" :valign "start" :class "notifications-empty-label" :text "No Notifications :("))' \
  || print "(scroll :height 500 :vscroll true (box :orientation 'v' :class 'notification-scroll-box' :spacing 10 :space-evenly 'false' $caches))"
}

function clear_logs() {
  dunstctl history-clear
  print > "$DUNST_LOG"
  rm -rf  $DUNST_CACHE_DIR/cover/*
  rm -rf  $DUNST_CACHE_DIR/timestamp/*
}

function pop() {
  sed -i '1d' "$DUNST_LOG" 
}

function remove_line() { 
  sed -i '/id "'$1'"/d' "$DUNST_LOG"

  dunstctl history-rm $DUNST_ID

  if [[ -z $(cat $DUNST_LOG) ]]; then
    dunstctl history-clear
  fi
}

function subscribe() {
  make_literal
  local lines=$(cat $DUNST_LOG | wc -l)
  while sleep 0.1; do
    local new=$(cat $DUNST_LOG | wc -l)
    [[ $lines -ne $new ]] && lines=$new && print
  done | while read -r _ do; make_literal done
}

case "$1" in
  "pop") pop;;
  "clear") clear_logs;;
  "subscribe") subscribe;;
  "rm_id") remove_line $2;;
  *) create_cache;;
esac

sed -i '/^$/d' "$DUNST_LOG"
_unset_vars

# vim:ft=zsh