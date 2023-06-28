#!/usr/bin/env zsh

function _set_vars() {
  typeset -gx DUNST_CACHE_DIR="$HOME/.cache/dunst"
  typeset -gx DUNST_LOG="$DUNST_CACHE_DIR/notifications.txt"
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

  # clean summary
  [ "$DUNST_SUMMARY" = "" ] && summary="No summary ?" || \
  # escape
  summary="$(echo "$DUNST_SUMMARY" | sed 's/"/\\"/g')"

  # clean body
  [ "$DUNST_BODY" = "" ] && body="No body?" || \

  body="$(echo "$DUNST_BODY" | sed -e 's/\n//g' -e 's/&quot;/"/g' -e 's/ \+/ /g' -e 's/<b>//' -e 's/<\/b>/:/' -e 's/"/\\"/g')"
  
  local image_width=50
  local image_height=50
  local screenshot=false

  if [[ $DUNST_APP_NAME == "Spotify" || $DUNST_APP_NAME == "Color Picker" ]]; then
    image_width=90
    image_height=90
  elif [[ $DUNST_APP_NAME == "Screenshot" ]]; then
    image_width=384
    image_height=216
    screenshot=true
  fi

  local SPOTIFY_TITLE=$(echo $DUNST_SUMMARY | sed -e 's/\//-/g' -e "s/'//g")

  if [[ $DUNST_APP_NAME == "Spotify" ]]; then
    icon=$DUNST_CACHE_DIR/cover/$SPOTIFY_TITLE.png

  elif [[ $DUNST_APP_NAME == "Kotatogram Desktop" ]]; then
    icon=$HOME/.config/eww/assets/telegram.png

  elif [[ $DUNST_APP_NAME == "discord" ]]; then
    icon=$HOME/.config/eww/assets/discord.png
  else
    icon=$(echo ${DUNST_ICON_PATH} | sed 's/32x32/48x48/g')
  fi

  # pipe stdout -> pipe cat stdin (cat conCATs multiple files and sends to stdout) -> absorb stdout from cat
  # concat: "one" + "two" + "three" -> notice how the order matters i.e. "one" will be prepended
sleep 0.3 && \
echo '(notification :id "'$DUNST_ID'" :app "'$DUNST_APP_NAME'" :summary "'$summary'" :body "'$body'" :image "'$icon'" :image_width "'$image_width'" :image_height "'$image_height'" :time "'$(date +'%H:%M')'" :screenshot "'$screenshot'" :tt "'$DUNST_TIMESTAMP'")' \
  | cat - "$DUNST_LOG" \
  | sponge "$DUNST_LOG" 
}

function compile_caches() {
  tr -d '\n' < "$DUNST_LOG"
}

function make_literal() {
  local caches="$(compile_caches)"
  [[ "$caches" == "" ]] \
  && echo '(box :class "empty" :height 800 :orientation "v" :space-evenly "false" (image :class "bell" :valign "end" :vexpand "true" :path "assets/bell.png" :image-width 100 :image-height 100) (label :vexpand "true" :valign "start" :class "label" :text "No Notifications"))' \
  || echo "(scroll :height 800 :vscroll true (box :orientation 'v' :class 'scroll' :spacing 10 :space-evenly 'false' $caches))"
}

function clear_logs() {
  dunstctl history-clear
  echo > "$DUNST_LOG"
  rm -rf  $DUNST_CACHE_DIR/cover/*
}

function remove_line() {
  sed -i '/tt "'$1'"/d' "$DUNST_LOG"

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
  "count") cat $DUNST_LOG | wc -l ;;
  "clear") clear_logs ;;
  "subscribe") subscribe ;;
  "rm_id") remove_line $2 ;;
  *) create_cache ;;
esac

sed -i '/^$/d' "$DUNST_LOG"
_unset_vars

# vim:ft=zsh