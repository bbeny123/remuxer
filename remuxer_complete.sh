#!/bin/bash

_remuxer_complete_path() {
  local cur="$1" type="${2:-"-f"}"

  mapfile -t COMPREPLY < <(compgen "$type" -- "$cur")
  compopt -o filenames

  return 0
}

_remuxer_complete() {
  local cur prev cmd options values f formats="mkv mp4 hevc bin"
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  cmd="${COMP_WORDS[1]}"

  if [ "$COMP_CWORD" -eq 1 ]; then
    mapfile -t COMPREPLY < <(compgen -W "info plot cuts extract frame-shift sync inject subs remux" -- "$cur")
    return
  fi

  case "$cmd" in
  extract) formats="mkv mp4 hevc" ;;
  remux) formats="mkv mp4" ;;
  subs) formats="mkv" ;;
  esac

  case "$prev" in
  -[ibor] | --input | --base-input | --output | --hevc | --subs)
    _remuxer_complete_path "$cur" && return ;;
  --out-dir | --tmp-dir)
    _remuxer_complete_path "$cur" '-d' && return ;;
  -[ex] | --output-format | --formats) values="$formats" ;;
  -t | --input-type) values="shows movies" ;;
  -l | --rpu-levels) values="1 2 3 4 5 6 8 9 10 11 254 255" ;;
  -[npm] | --info | --plot | --clean-filenames | --find-subs | --auto-title | --auto-tracks) values="0 1" ;;
  -c | --lang-codes) values="pol eng fre ger ita por rus spa chi jpn kor" ;;
  --copy-subs) values="0 1 pol eng fre ger ita por rus spa chi jpn kor" ;;
  --copy-audio) values="1 2 3" ;;
  -f | --frame-shift | --title) return ;;
  esac

  if [[ -n "$values" ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$values" -- "$cur")
    return
  fi

  if [[ "$COMP_CWORD" -gt 1 && -n "$cur" && "$cur" != -* ]]; then
    _remuxer_complete_path "$cur" && return
  fi

  case "$cmd" in
  info) options="--formats --input-type --sample --plot" ;;
  plot) options="--formats --input-type --output --sample" ;;
  cuts) options="--formats --input-type --output --sample" ;;
  extract) options="--formats --input-type --output --info --plot" ;;
  frame-shift) options="--base-input" ;;
  sync) options="--base-input --output --frame-shift --info --plot" ;;
  inject) options="--base-input --output --output-format --skip-sync --frame-shift --rpu-levels --raw-rpu --info --plot --subs --find-subs --copy-subs --copy-audio --title --auto-title --auto-tracks --clean-filenames" ;;
  subs) options="--input-type --output --lang-codes --clean-filenames" ;;
  remux) options="--formats --input-type --output --output-format --subs --find-subs --copy-subs --copy-audio --hevc --title --auto-title --auto-tracks --clean-filenames" ;;
  esac

  [[ -n "$options" ]] && mapfile -t COMPREPLY < <(compgen -W "--input $options --out-dir --tmp-dir --help" -- "$cur")
}

complete -F _remuxer_complete remuxer
