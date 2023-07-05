#!/usr/bin/zsh

LOG="$HOME/.config/eww/scripts/notifications.txt"

[ ! -f "$DUNST_LOG" ] && touch "$LOG"

create_cache() {

  local summary
  local body

  [ "$DUNST_SUMMARY" = "" ] && summary="No summary?" || \
  # escape
  summary=${DUNST_SUMMARY//\"/\\\"}

  [ "$DUNST_BODY" = "" ] && body="No body?" || \
  # clear body
  body="${DUNST_BODY//$'\n'/ }"
  body="${body//&quot;/\"}"
  body="${body//+([[:space:]])/ }"
  body="${body#"${body%%[![:space:]]*}"}"
  body="${body%"${body##*[![:space:]]}"}"
  body="${body//<b>/}"
  body="${body//<\/b>/:}"
  body="${body//\"/\\\"}"

  local image_width=50
  local image_height=50
  local screenshot=false
  local icon=${DUNST_ICON_PATH/32x32/48x48}

  case $DUNST_APP_NAME in
    "Spotify")
      image_width=90
      image_height=90
      icon=$(playerctl -p spotify metadata -f {{mpris:artUrl}})
      ;;
    "Color Picker")
      image_width=90
      image_height=90
      ;;
    "Screenshot")
      image_width=384
      image_height=216
      screenshot=true
      ;;
    "Kotatogram Desktop")
      icon=$HOME/.config/eww/assets/telegram.png
      ;;
    "discord")
      icon=$HOME/.config/eww/assets/discord.png
      ;;
  esac

echo '(notification :id "'$DUNST_ID'" :app "'$DUNST_APP_NAME'" :summary "'$summary'" :body "'$body'" :image "'$icon'" :image_width "'$image_width'" :image_height "'$image_height'" :time "'$(date +'%H:%M')'" :screenshot "'$screenshot'" :tt "'$DUNST_TIMESTAMP'")' \
  | cat - "$LOG" \
  | sponge "$LOG"
}

compile_caches() {
  tr -d '\n' < "$LOG"
}

make_literal() {
  local caches="$(compile_caches)"
  [[ -z "$caches" ]] \
  && echo '(box :class "empty" :height 800 :orientation "v" :space-evenly "false" (image :class "bell" :valign "end" :vexpand "true" :path "assets/bell.png" :image-width 100 :image-height 100) (label :vexpand "true" :valign "start" :class "label" :text "No Notifications"))' \
  || echo "(scroll :height 800 :vscroll true (box :orientation 'v' :class 'scroll' :spacing 10 :space-evenly 'false' $caches))"
}

clear_logs() {
  dunstctl history-clear
  echo > "$LOG"
}

remove_line() {
  sed -i '/tt "'$1'"/d' "$LOG"
  [[ ! -s "$LOG" ]] && dunstctl history-clear
}

subscribe() {
  make_literal
  local lines=$(wc -l < "$LOG")
  while sleep 0.1; do
    local new=$(wc -l < "$LOG")
    [[ $lines -ne $new ]] && lines=$new && print
  done | while read -r _ do; make_literal done
}

case "$1" in
  "count") wc -l < "$LOG" ;;
  "clear") clear_logs ;;
  "subscribe") subscribe ;;
  "rm_id") remove_line $2 ;;
  *) create_cache ;;
esac

sed -i '/^$/d' "$LOG"