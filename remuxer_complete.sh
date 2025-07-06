#!/usr/bin/env bash

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
  local cur prev cmd options values all_values value formats="mkv mp4 m2ts ts hevc bin" output_formats="mkv mp4 hevc bin"
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  cmd="${COMP_WORDS[1]}"

  if [ "$COMP_CWORD" -eq 1 ]; then
    mapfile -t COMPREPLY < <(compgen -W "info plot shift sync fix generate inject remux extract cuts subs topsubs png mp3 edl" -- "$cur")
    return
  fi

  case "$cmd" in
  extract) formats="mkv mp4 m2ts ts hevc" && output_formats="hevc bin mov" ;;
  generate) formats="mkv mp4 m2ts ts hevc mov" ;;
  remux | png | mp3) formats="mkv mp4 m2ts ts" && output_formats="mkv mp4" ;;
  subs) formats="mkv" && output_formats="srt" ;;
  topsubs) formats="mkv mp4 m2ts ts sup pgs" ;;
  edl) formats="txt edl" ;;
  esac

  case "$prev" in
  -[ib] | --input | --base-input)
    _remuxer_complete_path "$cur" "$formats" && return ;;
  --l6-source)
    _remuxer_complete_path "$cur" "mkv mp4 m2ts ts hevc bin" && return ;;
  --cuts)
    _remuxer_complete_path "$cur" "txt edl" && return ;;
  -r | --hevc)
    _remuxer_complete_path "$cur" "hevc" && return ;;
  -j | --json | --l5v | --l5v-analysis)
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
  -l | --levels) values="1 2 3 4 5 6 8 9 10 11 254 255" ;;
  -[nm] | --info | --clean-filenames | --subs-find | --title-auto | --tracks-auto | --cuts-first | --cuts-consecutive) values="0 1" ;;
  -p | --plot) all_values="0 1 none all L1 L2 L2_100 L2_600 L2_1000 L2_MAX L8T L8T_100 L8T_600 L8T_1000 L8T_MAX L8S L8S_100 L8S_600 L8S_1000 L8S_MAX L8H L8H_100 L8H_600 L8H_1000 L8H_MAX" ;;
  -c | --lang) values="pol eng fre ger ita por rus spa chi jpn kor" ;;
  --subs-copy) values="0 1 pol eng fre ger ita por rus spa chi jpn kor" ;;
  --audio-copy) values="1 2 3" ;;
  --tuning) values="legacy most more balanced less least" ;;
  --mdl) values="P3_1000 BT_1000 P3_2000 BT_2000 P3_4000 BT_4000" && cur=${cur^^} ;;
  --fps) values="23.976 24000/1001 24 25 30 50 48 60" && [ "$cmd" != 'edl' ] && values+=" 29.97 59.94" ;;
  --profile) values="0 1 2 3 4 5" ;;
  -[fuk] | --shift | --title | --frames | --time | --l5 | --l5-analysis | --cuts-clear | --max-y) return ;;
  esac

  if [[ -n "$all_values" ]]; then
    local cur_lower="${cur,,}"
    local last="${cur_lower##*,}" currents=" ${cur_lower//,/ } "
    [[ "$cur" == *,* ]] && previous="${cur%,*},"

    for value in $all_values; do
      [[ -n "$last" && "${value,,}" != "$last"* ]] && continue
      [[ "$currents" == *" ${value,,} "* ]] && continue
      values+="$previous$value "
    done

    mapfile -t COMPREPLY < <(compgen -W "$values")
    return
  fi

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
  shift) options="--base-input" ;;
  sync) options="--base-input --output --shift --info --plot" ;;
  fix) options="--formats --input-type --output --info --l5 --l6 --l6-source --cuts-clear --cuts-first --cuts-consecutive --json --json-example" ;;
  generate) options="--formats --input-type --output --sample --info --plot --profile --cuts --tuning --fps --mdl --l5 --l5-analysis --l5v --l5v-analysis --l6 --l5v-example --cuts-clear --cuts-first --cuts-consecutive" ;;
  inject) options="--base-input --output --output-format --synced --shift --levels --raw-rpu --info --plot --subs --subs-find --subs-copy --audio-copy --title --title-auto --tracks-auto --clean-filenames --l5 --l6 --cuts-clear --cuts-first --cuts-consecutive" ;;
  remux) options="--formats --input-type --output --output-format --subs --subs-find --subs-copy --audio-copy --hevc --title --title-auto --tracks-auto --clean-filenames" ;;
  extract) options="--formats --input-type --output --output-format --sample --profile --info --plot" ;;
  cuts) options="--formats --input-type --output --sample" ;;
  subs) options="--input-type --output --lang --clean-filenames" ;;
  topsubs) options="--formats --input-type --sample --fps --lang --max-y" ;;
  png) options="--formats --input-type --output --time" ;;
  mp3) options="--formats --input-type --output --sample" ;;
  edl) options="--formats --input-type --output --fps" ;;
  esac

  [[ -n "$options" ]] && mapfile -t COMPREPLY < <(compgen -W "--input $options --out-dir --tmp-dir --help" -- "$cur")
}

complete -F _remuxer_complete remuxer
