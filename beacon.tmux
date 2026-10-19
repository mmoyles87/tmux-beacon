#!/usr/bin/env bash
# tmux-beacon: a 256-colour tmux theme with one accent colour per host.
#
# Everything is built from tmux's own formats. The status line runs no shell
# commands, so nothing is forked every status-interval.

# opt NAME DEFAULT. An option set to '' stays empty; only an unset one
# takes the default.
opt() {
  if [ -n "$(tmux show-option -gq "$1")" ]; then
    tmux show-option -gqv "$1"
  else
    printf '%s' "$2"
  fi
}

# Named hues, all from the xterm 256-colour table. A number becomes colourN;
# anything else (#rrggbb, colour123, a tmux colour name) passes through.
colour() {
  case "$1" in
    red) echo colour167 ;;
    orange) echo colour215 ;;
    yellow) echo colour221 ;;
    lime) echo colour149 ;;
    jade) echo colour72 ;;
    blue) echo colour75 ;;
    violet) echo colour141 ;;
    pink) echo colour211 ;;
    '' | *[!0-9]*) echo "$1" ;;
    *) echo "colour$1" ;;
  esac
}

host=$(tmux display-message -p '#{host_short}' 2>/dev/null)
[ -n "$host" ] || host=$(hostname -s 2>/dev/null || hostname)
host=$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')

# Accent: a per-host override, then a global one, then a hue picked from the
# hostname so an unconfigured host still gets a stable colour of its own.
accent=$(opt "@beacon-host-$host" "$(opt @beacon-accent)")
if [ -z "$accent" ]; then
  sum=$(printf '%s' "$host" | cksum | cut -d' ' -f1)
  set -- red orange yellow lime jade blue violet pink
  shift $((sum % 8))
  accent=$1
fi

A=$(colour "$accent")
BG=$(colour "$(opt @beacon-bg 235)")
CHIP=$(colour "$(opt @beacon-chip 237)")
FG=$(colour "$(opt @beacon-fg 252)")
DIM=$(colour "$(opt @beacon-dim 244)")
MUTED=$(colour "$(opt @beacon-muted 241)")
BORDER=$(colour "$(opt @beacon-border 238)")
INK=$(colour "$(opt @beacon-ink 234)")
COPY=$(colour "$(opt @beacon-copy-colour 252)")
SYNC=$(colour "$(opt @beacon-sync-colour 203)")
[ "$(opt @beacon-transparent off)" = on ] && BG=default

# Nerd Font glyphs as UTF-8 bytes, which bash 3.2 (macOS) can print.
L=$(printf '\356\202\266')          # U+E0B6 left half-circle
R=$(printf '\356\202\264')          # U+E0B4 right half-circle
SERVER=$(printf '\363\260\222\213') # U+F048B nf-md-server
ZOOM=$(printf '\363\260\201\214')   # U+F004C nf-md-arrow_expand_all

style=$(opt @beacon-style rounded)
if [ "$style" = flat ]; then
  icon=$(opt @beacon-icon '')
  zoom=' +Z'
else
  icon=$(opt @beacon-icon "$SERVER")
  zoom=" $ZOOM"
fi

# pill BG FG TEXT. Styles are written one attribute per #[] so a pill can sit
# inside a #{?...} conditional, where a bare comma would end the branch.
pill() {
  if [ "$style" = flat ]; then
    printf '#[fg=%s]#[bg=%s]#[bold] %s #[bg=%s]#[nobold]' "$2" "$1" "$3" "$BG"
  else
    printf '#[fg=%s]#[bg=%s]%s#[fg=%s]#[bg=%s]#[bold] %s #[fg=%s]#[bg=%s]#[nobold]%s' \
      "$1" "$BG" "$L" "$2" "$1" "$3" "$1" "$BG" "$R"
  fi
}

# Left: host badge, then session.
label=$(opt "@beacon-label-$host" "$(opt @beacon-label '#{host_short}')")
left="$(pill "$A" "$INK" "${icon:+$icon }$label")"
[ "$style" = flat ] || left="$left "
left="$left$(pill "$CHIP" "$A" '#S') "

# Windows. Inactive ones carry the same padding as the active pill so the row
# doesn't shift when you switch.
flags="#{?window_zoomed_flag,$zoom,}"
if [ "$style" = flat ]; then
  win_on="#[fg=$A,bg=$CHIP,bold] #I #[fg=$FG]#W$flags #[bg=$BG,nobold]"
  win_off="#[fg=$MUTED] #I #[fg=$DIM]#W$flags#{?window_bell_flag, #[fg=$SYNC]!,}#{?window_activity_flag, #[fg=$A]•,} "
else
  win_on="#[fg=$CHIP,bg=$BG]$L#[fg=$A,bg=$CHIP,bold] #I #[fg=$FG]#W$flags #[fg=$CHIP,bg=$BG,nobold]$R"
  win_off="#[fg=$MUTED]  #I #[fg=$DIM]#W$flags#{?window_bell_flag, #[fg=$SYNC]!,}#{?window_activity_flag, #[fg=$A]•,}  "
fi

# Right: path, clock, then a pill only while a mode is on.
right=''
clock=$(opt @beacon-clock '%H:%M')
if [ "$(opt @beacon-show-path on)" = on ]; then
  len=$(opt @beacon-path-length 30)
  min=$(opt @beacon-path-min-width 110)
  # Dropped on narrow clients so the window list keeps its room.
  right="#{?#{e|>=:#{client_width},$min}, #[fg=$DIM]#{=/-$len/…:#{s|^$HOME|~|:pane_current_path}}${clock:+ #[fg=$BORDER]│},} "
fi
if [ -n "$clock" ]; then
  right="$right#[fg=$FG]$clock "
fi
right="$right#{?client_prefix,$(pill "$A" "$INK" PREFIX),}"
right="$right#{?#{==:#{pane_mode},copy-mode},$(pill "$COPY" "$INK" COPY),}"
right="$right#{?pane_synchronized,$(pill "$SYNC" "$INK" SYNC),}"

set() { tmux set-option -gq "$@"; }
setw() { tmux set-window-option -gq "$@"; }

set @beacon-accent-resolved "$A"
set status on
set status-position "$(opt @beacon-position bottom)"
set status-justify left
set status-style "bg=$BG,fg=$DIM"
# Reset the styles a previous theme may have left behind.
set status-left-style default
set status-right-style default
set status-left "$left"
set status-left-length 60
set status-right "$right"
set status-right-length 100
set message-style "bg=$CHIP,fg=$A"
set message-command-style "bg=$CHIP,fg=$A"
set display-panes-active-colour "$A"
set display-panes-colour "$BORDER"

setw window-status-format "$win_off"
setw window-status-current-format "$win_on"
setw window-status-separator ''
setw window-status-style "bg=$BG"
setw window-status-current-style default
setw window-status-last-style default
setw window-status-activity-style none
setw window-status-bell-style none
setw pane-border-style "fg=$BORDER"
setw pane-active-border-style "fg=$A"
setw mode-style "bg=$A,fg=$INK"
setw copy-mode-position-style "bg=$CHIP,fg=$DIM"
setw clock-mode-colour "$A"
# Newer than tmux 3.0; -q skips them on a tmux that doesn't know them.
setw copy-mode-match-style "bg=$CHIP,fg=$A"
setw copy-mode-current-match-style "bg=$A,fg=$INK"
setw popup-border-style "fg=$A"
set menu-selected-style "bg=$A,fg=$INK"
set menu-border-style "fg=$A"
