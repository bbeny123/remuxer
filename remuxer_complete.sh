#!/bin/bash

_remuxer_complete_path() {
  local cur="$1" type_or_formats="$2" dirs=()

  if [ "$type_or_formats" = "-f" ]; then
    mapfile -t COMPREPLY < <(compgen -f -- "$cur")
  elif [ "$type_or_formats" = "-d" ]; then
    mapfile -t COMPREPLY < <(compgen -d -- "$cur")
  else
    mapfile -t COMPREPLY < <(compgen -f -- "$cur" | grep -iE "\.(${type_or_formats// /|})$")
    mapfile -t dirs < <(compgen -d -- "$cur")
    COMPREPLY+=("${dirs[@]}")
  fi

  compopt -o filenames

  return 0
}

_remuxer_complete() {
  local cur prev cmd options values formats="mkv mp4 m2ts ts hevc bin" output_formats="mkv mp4 hevc bin"
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  cmd="${COMP_WORDS[1]}"

  if [ "$COMP_CWORD" -eq 1 ]; then
    mapfile -t COMPREPLY < <(compgen -W "info plot frame-shift sync fix inject remux extract cuts subs png mp3" -- "$cur")
    return
  fi

  case "$cmd" in
  extract) formats="mkv mp4 m2ts ts hevc" && output_formats="hevc bin" ;;
  remux | png | mp3) formats="mkv mp4 m2ts ts" && output_formats="mkv mp4" ;;
  subs) formats="mkv" && output_formats="srt" ;;
  esac

  case "$prev" in
  -[ib] | --input | --base-input)
    _remuxer_complete_path "$cur" "$formats" && return ;;
  -r | --hevc)
    _remuxer_complete_path "$cur" "hevc" && return ;;
  -j | --json)
    _remuxer_complete_path "$cur" "json" && return ;;
  --subs)
    _remuxer_complete_path "$cur" "srt" && return ;;
  -o | --output)
    _remuxer_complete_path "$cur" "-f" && return ;;
  --out-dir | --tmp-dir)
    _remuxer_complete_path "$cur" '-d' && return ;;
  -x | --formats) values="$formats" ;;
  -e | --output-format) values="$output_formats" ;;
  -t | --input-type) values="shows movies" ;;
  -l | --rpu-levels) values="1 2 3 4 5 6 8 9 10 11 254 255" ;;
  -[nm] | --info | --clean-filenames | --find-subs | --auto-title | --auto-tracks | --cuts-first | --cuts-consecutive) values="0 1" ;;
  -p | --plot) values="0 1 2 3" ;;
  -c | --lang-codes) values="pol eng fre ger ita por rus spa chi jpn kor" ;;
  --copy-subs) values="0 1 pol eng fre ger ita por rus spa chi jpn kor" ;;
  --copy-audio) values="1 2 3" ;;
  -[fuk] | --frame-shift | --title | --frames | --time | --l5 | --cuts-clear) return ;;
  esac

  if [[ -n "$values" ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$values" -- "$cur")
    return
  fi

  if [[ "$COMP_CWORD" -gt 1 && -n "$cur" && "$cur" != -* ]]; then
    _remuxer_complete_path "$cur" "$formats" && return
  fi

  case "$cmd" in
  info) options="--formats --input-type --output --frames --sample --plot" ;;
  plot) options="--formats --input-type --output --sample --plot" ;;
  frame-shift) options="--base-input" ;;
  sync) options="--base-input --output --frame-shift --info --plot" ;;
  fix) options="--formats --input-type --output --info --l5 --cuts-clear --cuts-first --cuts-consecutive --json --json-examples" ;;
  inject) options="--base-input --output --output-format --skip-sync --frame-shift --rpu-levels --raw-rpu --info --plot --subs --find-subs --copy-subs --copy-audio --title --auto-title --auto-tracks --clean-filenames --l5 --cuts-clear --cuts-first --cuts-consecutive" ;;
  remux) options="--formats --input-type --output --output-format --subs --find-subs --copy-subs --copy-audio --hevc --title --auto-title --auto-tracks --clean-filenames" ;;
  extract) options="--formats --input-type --output --output-format --sample --info --plot" ;;
  cuts) options="--formats --input-type --output --sample" ;;
  subs) options="--input-type --output --lang-codes --clean-filenames" ;;
  png) options="--formats --input-type --output --time" ;;
  mp3) options="--formats --input-type --output --sample" ;;
  esac

  [[ -n "$options" ]] && mapfile -t COMPREPLY < <(compgen -W "--input $options --out-dir --tmp-dir --help" -- "$cur")
}

complete -F _remuxer_complete remuxer
