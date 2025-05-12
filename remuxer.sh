#!/bin/bash

shopt -s expand_aliases

readonly N=$(tput sgr0) B=$(tput bold) U=$(tput smul)
readonly RED=$(tput setaf 1) YELLOW=$(tput setaf 3)
readonly BU="$B$U"
readonly REMUXER="$B$(basename "$0")$N" VERSION="1.0.3"
readonly START_TIME=$(date +%s%1N)
readonly DEBUG_LOG='0'
readonly TOOLS_DIR="$(dirname -- "${BASH_SOURCE[0]}")/tools"

alias jq="'$TOOLS_DIR/jq-win64.exe'"                                       # v1.7.1: https://jqlang.org/download/
alias mediainfo="'$TOOLS_DIR/MediaInfo.exe'"                               # v25.04: https://mediaarea.net/pl/MediaInfo/Download
alias ffmpeg="'$TOOLS_DIR/ffmpeg.exe' -hide_banner -stats -loglevel error" # v7.1.1: https://ffmpeg.org/download.html
alias mkvmerge="'$TOOLS_DIR/mkvtoolnix/mkvmerge.exe'"                      # v92.0: https://mkvtoolnix.download/downloads.html
alias mkvextract="'$TOOLS_DIR/mkvtoolnix/mkvextract.exe'"                  #
alias dovi_tool="'$TOOLS_DIR/dovi_tool.exe'"                               # v2.2.0: https://github.com/quietvoid/dovi_tool/releases
# Last dovi_tool version (1.5.3) supporting convert_to_cmv4 (non-modified build: https://github.com/quietvoid/dovi_tool/releases/tag/1.5.3
# Additionally, this is a modified build (source: DoVi_Scripts: dovi_tool_2.9_to_4.0.exe) that skips injecting default values for L9 and L11 during CMv4 conversion
alias dovi_tool_cmv4="'$TOOLS_DIR/dovi_tool_cmv4.exe'"

OUT_DIR="$(pwd)"
PLOTS_DIR=""                     # <empty> - same as OUT_DIR
TMP_DIR="$(pwd)/temp$START_TIME" # caution: This dir will be removed only if it is created by the script
RPU_LEVELS="3,8,9,11,254"
INFO_INTERMEDIATE='1'  # 0 - disabled,       1 - enabled
INFO_L1_PLOT='1'       # 0 - disabled,       1 - enabled
CLEAN_FILENAMES='1'    # 0 - disabled,       1 - enabled
SUBS_AUTODETECTION='1' # 0 - disabled,       1 - enabled
TITLE_SHOWS_AUTO='0'   # 0 - disabled,       1 - enabled
TITLE_MOVIES_AUTO='1'  # 0 - disabled,       1 - enabled
TRACK_NAMES_AUTO='1'   # 0 - disabled,       1 - enabled [e.g., audio: DTS 5.1, subs: Polish]
AUDIO_COPY_MODE='3'    # 1 - 1st track only, 2 - 1st + compatibility, 3 - all
SUBS_COPY_MODE='1'     # 0 - none,           1 - all,                 <lng> - based on ISO 639-2 lang code [e.g., eng]
SUBS_LANG_CODES=''     # <empty> - all,                               <lng> - based on ISO 639-2 lang code [e.g., eng]
EXTRACT_SHORT_SEC='23'
FFMPEG_STRICT=1
OPTIONS_PLOT_SET=0

declare -A commands=(
  [info]="       Show Dolby Vision information            | xtsp       | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [plot]="       Plot L1 dynamic brightness metadata      | xtos       | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [cuts]="       Extract scene-cut frame list(s)          | xtos       | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [extract]="    Extract DV RPU(s) or .hevc base layer(s) | xtosenp    | .mkv, .mp4, .m2ts, .ts, .hevc"
  [frame-shift]="Calculate frame shift                    | b          | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [sync]="       Synchronize Dolby Vision RPU files       | bofnp      | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [inject]="     Sync & Inject Dolby Vision RPU           | boeqflwnmp | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [subs]="       Extract .srt subtitles                   | tocm       | .mkv"
  [remux]="      Remux video file(s)                      | xtoemr     | .mkv, .mp4, .m2ts, .ts"
)
declare -A cmd_description=(
  [frame-shift]="Calculate frame shift of <input> relative to <base-input>"
  [sync]="Synchronize RPU of <input> to align with RPU of <base-input>"
  [inject]="Sync & Inject RPU of <input> into <base-input>"
)
declare -i help_short=0 help_left=15
cmd_options=""

red() {
  echo "$RED$1$N"
}

yellow() {
  echo "$YELLOW$1$N"
}

windows() {
  case "$OSTYPE" in
  msys* | cygwin* | win32*) return 0 ;;
  *) return 1 ;;
  esac
}

trim() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"
  echo "${var%"${var##*[![:space:]]}"}"
}

cmd_info() {
  local info="${commands[$1]}" col="${2:-1}"
  for ((col; col > 1; col--)); do info="${info#*|}"; done
  trim "${info%%|*}"
}

cmd_output_formats() {
  [ "$1" = 'extract' ] && echo "hevc, bin" && return

  local allowed_formats=$(cmd_info "$1" 3)
  allowed_formats=" ${allowed_formats//./},"

  if [[ "$allowed_formats" == *'ts,'* ]]; then
    allowed_formats="${allowed_formats// m2ts,/}"
    allowed_formats="${allowed_formats// ts,/}"
  fi

  trim "${allowed_formats%,}"
}

echo1() {
  echo ""
  echo "$1"
}

printf_safe() {
  local template="$1" arg; shift
  for arg in "$@"; do [ -z "$arg" ] && return; done
  printf "$template" "$@"
}

printf_if() { [ "$1" = 1 ] && printf_safe "${@:2}"; }
logf() { printf "$1\n" "${@:2}" >&2; }
log_t() { logf "\n$1" "${@:2}"; }
log_b() { logf "$1\n" "${@:2}"; }
log_c() { logf "\n$1\n" "${@:2}"; }

log() {
  [ "$2" = 1 ] && echo "" >&2
  echo "$1" >&2
  [ "$2" = 2 ] && echo "" >&2
  return 0
}

log_kill() {
  log "$1, terminating..." "${2:-1}"
  [ "$3" = 1 ] && log "For more information, try '$B--help$N'"
  kill 0
}

fatal_error() {
  [ "$DEBUG_LOG" != 1 ] && log_kill "$1" 2

  local -r msg="$1" index="${2:-2}"
  local function="#${FUNCNAME[$index]}"

  [ "${FUNCNAME[$index + 1]}" != "main" ] && function="#${FUNCNAME[$index + 1]} > $function"

  log_kill "$function: $msg"
}

tmp_trap() {
  [ ! -d "$TMP_DIR" ] && trap 'rm -rf -- "$TMP_DIR"' EXIT
}

check_extension() {
  local -r file="$1" valid_extensions="$2" error_if_not="$3" type="${4:-'file'}" file_extension="${1##*.}"

  if ! echo " $valid_extensions " | grep -qioE " \.?$file_extension,? "; then
    [ "$error_if_not" = 1 ] && fatal_error "The extension of the $type: '$file' is unsupported (supported extension(s): $valid_extensions)"
    return 1
  fi
  return 0
}

filename() {
  local -r filename=$(basename "$1")
  echo "${filename%.*}"
}

clean_filename() {
  local input=$(filename "$1")

  if [[ "$input" =~ (^.*[. ]S[0-9]{1,3}E[0-9]{1,3}) ]]; then
    input="${BASH_REMATCH[1]}"
  elif [[ "$input" =~ (^.*[. ])([0-9]{4}[ .]) ]]; then
    input="${BASH_REMATCH[1]}"
  else
    trim "$input"
    return 1
  fi

  trim "${input//./ }" | tr -s ' '
}

windows_safe_path() {
  local path="$1"
  windows && [[ "$path" =~ ^/([A-Za-z])/ ]] && path="${BASH_REMATCH[1]}:/${path:3}"
  echo "$path"
}

generate_file() {
  local dir="$1" input_file="$2" ext="$3" prefix="$4" output="$5" clean_name="$6" windows_safe_path="$7"

  if [[ -n "$output" ]]; then
    mkdir -p "$(dirname "$output")"
    check_extension "$output" ".${ext#.}" || output="${output}.${ext#.}"
    [ "$windows_safe_path" = 1 ] && windows && output=$(windows_safe_path "$output")
    echo "$output"
    return
  fi

  if [ "$clean_name" = 1 ]; then
    input_file=$(clean_filename "$input_file")
    prefix=""
  else
    input_file=$(filename "$input_file")
  fi

  [ ! -d "$dir" ] && mkdir -p "$dir"
  [ "$windows_safe_path" = 1 ] && windows && dir=$(windows_safe_path "$dir")

  echo "${dir%/}/${prefix:+${prefix%_}_}$input_file.${ext#.}"
}

tmp_file() {
  generate_file "$TMP_DIR" "$1" "$2" "$3" "$4" "$5" "$6"
}

out_file() {
  generate_file "$OUT_DIR" "$1" "$2" "$3" "$4" "$5" "$6"
}

out_hybrid() {
  local input_name=$(filename "$1") input_base="$2" ext="$3" output="$4" raw_rpu="$5" prefix
  [ "$raw_rpu" != 1 ] && prefix="-${RPU_LEVELS//[^0-9]/}"
  out_file "$input_base" "$ext" "HYBRID$prefix-$input_name" "$output"
}

rpu_export_file() {
  local dir="$1" input="$2" short_sample="$3" ext="$4" prefix="$5" output="$6" out_dir="$7"

  if [ "$short_sample" = 1 ]; then
    prefix+="-${EXTRACT_SHORT_SEC}s"
    [ "$out_dir" != 1 ] && dir="$TMP_DIR"
  fi

  generate_file "$dir" "$input" "$ext" "$prefix" "$output"
}

rpu_cuts_file() {
  local -r input="$1" short_sample="$2" out_dir="$3" output="$4"

  rpu_export_file "$OUT_DIR" "$input" "$short_sample" 'txt' "CUTS" "$output" "$out_dir"
}

rpu_l5_file() {
  local -r input="$1" short_sample="$2" output="$3"

  rpu_export_file "$TMP_DIR" "$input" "$short_sample" 'json' "L5" "$output"
}

file_exists() {
  local -r file="$1" var_name="$2" error_if_empty="$3"

  if [[ -z "$file" ]]; then
    [ "$error_if_empty" = 1 ] && fatal_error "'$var_name' var is empty"
    return 1
  fi

  [[ ! -f "$file" ]] && fatal_error "file '$file'${var_name:+ (var: "$var_name")} doesn't exist"
  return 0
}

dovi_input() {
  local -r input=$(to_rpu "$1" "$2" 1)
  ! dovi_tool info -s "$input" 2>&1 | grep -q 'No RPU found'
}

cm4_input() {
  local -r input=$(to_rpu "$1" 0 1)
  dovi_tool info -s "$input" | grep -q 'CM v4.0'
}

p7_input() {
  local -r input=$(to_rpu "$1" "$2" 1)
  dovi_tool info -s "$input" | grep -q 'Profile: 7'
}

to_hevc() {
  local input="$1" short_sample="$2" output="$3" out_dir="$4" prefix='HEVC' type='Base layer' ffmpeg_cmd=()

  file_exists "$input" 'input' 1
  [ "$short_sample" != 1 ] && check_extension "$input" ".hevc" && echo "$input" && return
  check_extension "$input" '.mkv .mp4 .m2ts .ts .hevc' 1

  [ "$FFMPEG_STRICT" = 1 ] && ffmpeg_cmd+=(-strict -2)

  if [ "$short_sample" = 1 ]; then
    prefix+="-${EXTRACT_SHORT_SEC}s"
    ffmpeg_cmd+=(-t "$EXTRACT_SHORT_SEC")
    type+=" sample"
  fi

  [ "$out_dir" = 1 ] && out_dir="$OUT_DIR" || out_dir="$TMP_DIR"
  output=$(generate_file "$out_dir" "$input" 'hevc' "$prefix" "$output")

  local -r input_name=$(basename "$input")
  log "Extracting ${type,,} for: '$input_name' ..." 1

  if [[ ! -f "$output" ]]; then
    ffmpeg -i "$input" -map 0:0 -c copy "${ffmpeg_cmd[@]}" -f hevc "$output" >&2
    log "$type for: '$input_name' extracted - output file: '$output'" 1
  else
    log "The .hevc file: '$output' already exists, skipping..."
  fi

  echo "$output"
}

to_rpu() {
  local input="$1" short_sample="$2" quiet="${3:-$2}" output="$4" out_dir="$5" info="$6" type='RPU' ffmpeg_cmd=()

  file_exists "$input" 'input' 1
  check_extension "$input" ".bin" && echo "$input" && return
  check_extension "$input" '.mkv .mp4 .m2ts .ts .hevc' 1
  local -r input_name=$(basename "$input")

  [ "$FFMPEG_STRICT" = 1 ] && ffmpeg_cmd+=(-strict -2)

  if [ "$short_sample" = 1 ]; then
    [ "$out_dir" = 1 ] && out_dir="$OUT_DIR" || out_dir="$TMP_DIR"
    output=$(generate_file "$out_dir" "$input" 'bin' "RPU-${EXTRACT_SHORT_SEC}s" "$output")
    ffmpeg_cmd+=(-t "$EXTRACT_SHORT_SEC")
    type+=" sample"
  else
    short_sample=''
    output=$(out_file "$input" 'bin' 'RPU' "$output")
  fi

  [ "$quiet" != 1 ] && log "Extracting $type for: '$input_name' ..." 1

  if [[ ! -f "$output" ]]; then
    [ "$quiet" = 1 ] && log "Extracting $type for: '$input_name' ..." 1

    if [[ -z "$short_cmd" ]] && check_extension "$input" ".hevc"; then
      dovi_tool extract-rpu -o "$output" "$input" >/dev/null
    else
      if ! ffmpeg -i "$input" -map 0:0 -c copy "${ffmpeg_cmd[@]}" -f hevc - | dovi_tool extract-rpu -o "$output" - >/dev/null; then
        log_kill "Error while extracting $type for: '$input_name'"
      fi
    fi

    log "$type for: '$input_name' extracted - output file: '$output'"
  elif [ "$quiet" != 1 ]; then
    log "The RPU file: '$output' already exists, skipping..."
  fi

  [ "$info" = 1 ] && info "$output" "$short_sample" "$short_sample" >&2

  echo "$output"
}

to_cm4_rpu() {
  local input="$1" output="$2"
  input=$(to_rpu "$input" 0 1)

  if ! cm4_input "$input"; then
    local -r input_name=$(basename "$input")
    log "Converting '$input_name' to CM v4.0..."

    local -r convert_config=$(tmp_file "$input" 'json' 'EDITOR-CONVERT')
    [[ ! -f "$convert_config" ]] && echo '{ "convert_to_cmv4": true }' >"$convert_config"

    output=$(tmp_file "$input" 'bin' 'CMv4' "$output")
    [[ ! -f "$output" ]] && log "" && dovi_tool_cmv4 editor -i "$input" -j "$convert_config" -o "$output" >&2

    log ""
    log "'$input_name' converted to CM v4.0 - output file: '$output'" 2
    echo "$output"
  else
    echo "$input"
  fi
}

extract() {
  local input="$1" short_sample="$2" output_format="$3" output="$4"
  [[ -z "$output_format" && "$output" == *.* ]] && output_format="${output##*.}"

  if [[ "${output_format,,}" == *hevc* ]]; then
    to_hevc "$input" "$short_sample" "$output" 1 >/dev/null
  else
    to_rpu "$input" "$short_sample" 0 "$output" 1 "$INFO_INTERMEDIATE" >/dev/null
  fi
}

to_rpu_json() {
  local input="$1" short_sample="$2" quick="$3" cuts_output="$4" l5_output="$5" output="$6" prefix=""
  [ "$quick" = 1 ] && prefix+="FRAME_24" || prefix+="ALL"
  [ "$short_sample" = 1 ] && prefix+="-${EXTRACT_SHORT_SEC}s"

  input=$(to_rpu "$input" "$short_sample" 1)
  output=$(tmp_file "$input" 'json' "$prefix" "$output")

  if [[ ! -f "$output" ]]; then
    cuts_output=$(rpu_cuts_file "$input" "$short_sample" 0 "$cuts_output")
    l5_output=$(rpu_l5_file "$input" "$short_sample" "$l5_output")
    if [ "$quick" = 1 ]; then
      dovi_tool info -i "$input" -f 24 >"$output"
      dovi_tool export -i "$input" --data scenes="$cuts_output" --data level5="$l5_output" >/dev/null
    else
      dovi_tool export -i "$input" --data all="$output" --data scenes="$cuts_output" --data level5="$l5_output" >/dev/null
    fi
  fi

  echo "$output"
}

to_rpu_l5() {
  local input="$1" short_sample="$2" output="$3"

  input=$(to_rpu "$input" "$short_sample" 1)
  output=$(rpu_l5_file "$input" "$short_sample" "$output")

  if [[ ! -f "$output" ]]; then
    dovi_tool export -i "$input" --data level5="$output" >/dev/null
  fi

  echo "$output"
}

to_rpu_cuts() {
  local input="$1" short_sample="$2" quiet="${3:-$2}" output="$4" direct="$5"

  if check_extension "$input" ".txt"; then
    file_exists "$input" 'input' 1
    echo "$input"
    return
  fi

  [[ "$short_sample" = 1 && "$direct" = 1 ]] && check_extension "$input" ".bin" && short_sample=0

  local -r input_name=$(basename "$input")
  input=$(to_rpu "$input" "$short_sample" "$quiet")
  output=$(rpu_cuts_file "$input" "$short_sample" "$direct" "$output")

  [ "$quiet" != 1 ] && log "Extracting scene-cuts for: '$input_name' ..." 1

  if [[ ! -f "$output" ]]; then
    dovi_tool export -i "$input" --data scenes="$output" >/dev/null

    [ "$quiet" != 1 ] && log "Scene-cuts for: '$input_name' extracted - output file: '$output'"
  elif [ "$quiet" != 1 ]; then
    log "The scene-cuts file: '$output' already exists, skipping..."
  fi

  echo "$output"
}

rpu_frames() {
  local input=$(to_rpu "$1" 0 1)

  dovi_tool info -s "$input" | grep -oE 'Frames:\s*[0-9]+' | grep -oE '[0-9]+'
}

cut_frame() {
  local -r input="$1" frame="$2"

  grep -qE "(^|\s)$frame($|\s)" "$(to_rpu_cuts "$input" 0 1)"
}

plot_l1() {
  local input="$1" short_sample="$2" intermediate="$3" output="$4"

  [[ "$short_sample" = 1 && "$intermediate" != 1 ]] && check_extension "$input" ".bin" && short_sample=0

  local -r rpu=$(to_rpu "$input" "$short_sample" "$intermediate")
  local -r input_name=$(basename "$input")

  local output_prefix='L1-plot'
  [ "$short_sample" = 1 ] && output_prefix+="-${EXTRACT_SHORT_SEC}s"
  local -r plot=$(generate_file "${PLOTS_DIR:-"$OUT_DIR"}" "$rpu" 'png' "$output_prefix" "$output")

  log "Plotting L1 metadata for: '$input_name' ..." 1

  if [[ ! -f "$plot" ]]; then
    if [ "$short_sample" = 1 ] && check_extension "$input" '.mkv .mp4 .m2ts .ts .hevc'; then
      local -r title="$(basename "$input") (sample duration: ${EXTRACT_SHORT_SEC}s)"
    else
      local -r title=$(basename "$rpu")
    fi

    dovi_tool plot -i "$rpu" -o "$plot" -t "$title" >/dev/null

    log "L1 metadata for: '$input_name' plotted - output file: '$plot'"
  else
    log "The L1 plot file: '$plot' already exists, skipping..."
  fi
}

audio_track_info() {
  local id=$(trim "$1") format="$2" channels="$3" layout="$4" known_only="$5"
  [[ -z "$id" ]] && return

  case "$format" in
  *'DTS-UHD'*) format="DTS:X IMAX" ;;
  *'DTS XLL X IMAX'*) format="DTS:X IMAX" ;;
  *'DTS XLL X'*) format="DTS:X" ;;
  *'DTS XLL'*) format="DTS-HD MA" ;;
  *'DTS-ES'*) format="DTS-ES" ;;
  *'DTS'*) format="DTS" ;;
  *'MLP FBA 16-ch'*) format="TrueHD Atmos" ;;
  *'MLP FBA'*) format="TrueHD" ;;
  *'TrueHD'*) format="TrueHD" ;;
  *'E-AC-3 JOC'*) format="EAC-3 Atmos" ;;
  *'E-AC-3'*) format="EAC-3" ;;
  *'AC-3'*) format="AC-3" ;;
  *) [ "$known_only" = 1 ] && return ;;
  esac

  if [[ -n "$format" ]] && ((channels > 0)); then
    [[ " $layout " == *" LFE "* ]] && format+=" $((channels - 1)).1" || format+=" $((channels)).0"
  fi

  echo "$id|$format"
}

audio_info() {
  local input="$1" known_only="$2" lossless_only="$3" id format channels layout compression

  while IFS='|' read -r id format channels layout compression; do
    [[ "$lossless_only" = 1 && ! "$compression" =~ 'Lossless' ]] && continue
    audio_track_info "$id" "$format" "$channels" "$layout" "$known_only"
  done < <(mediainfo "$input" --Inform='Audio;%StreamOrder%|%Format% %Format_AdditionalFeatures%|%Channel(s)%|%ChannelLayout%|%Compression_Mode%\n')
}

video_info() {
  local input="$1" dv_profile="$2" track_info=() base_layer resolution lossless_audio
  ! check_extension "$input" ".mkv .mp4 .m2ts .ts .hevc" && return

  local -r inform='%HDR_Format%|%Width%|%Height%|%FrameRate%|%MasteringDisplay_ColorPrimaries%|%MasteringDisplay_Luminance%|%MaxCLL%|%MaxFALL%'
  IFS='|' read -ra track_info < <(mediainfo "$input" --Inform="Video;$inform|\n" | head -n 1)

  while IFS='|' read -r id format; do
    lossless_audio+="#$id ($format), "
  done < <(audio_info "$input" 0 1)

  case "$dv_profile" in
  '') base_layer="${track_info[0]}" ;;
  5) base_layer='ICtCp (DoVi P5)' ;;
  *) base_layer="HDR10+P$dv_profile" ;;
  esac

  if [ -n "$base_layer" ]; then
    base_layer+=$(printf_safe ", %s" "${track_info[4]}")
    base_layer+=$(printf_safe " (%s)" "${track_info[5]//cd\/m2/nits}")
    base_layer+=$(printf_safe ", MaxCLL: %s nits" "${track_info[6]%%[^0-9]*}")
    base_layer+=$(printf_safe ", MaxFALL: %s nits" "${track_info[7]%%[^0-9]*}")
  fi

  resolution=$(printf_safe "%s x %s" "${track_info[1]}" "${track_info[2]}")
  [ -n "$resolution" ] && resolution+=$(printf_safe " @ %s" "${track_info[3]}")

  echo "$base_layer|$resolution|${lossless_audio%, }"
}

rpu_cuts_line() {
  local rpu_cuts="$1" line="$2" lines

  ((line < 0)) && lines=$(tail -n "${line#-}" "$rpu_cuts") || lines=$(head -n "$line" "$rpu_cuts")

  (($(echo "$lines" | wc -l) < ${line#-})) && return

  ((line < 0)) && line=$(echo "$lines" | head -n 1) || line=$(echo "$lines" | tail -n 1)
  [[ "$line" =~ ^[0-9]+$ ]] && echo "$line"
}

rpu_info_cuts() {
  local rpu_cuts="$1" line1="$2" line2="$3" cut2_type="$4"

  local -r cut1=$(rpu_cuts_line "$rpu_cuts" "$line1")
  if [[ -z "$cut1" ]]; then
    yellow 'UNKNOWN'
    yellow 'UNKNOWN (1st scene cut missing)'
    return
  fi

  local -r cut2=$(rpu_cuts_line "$rpu_cuts" "$line2")
  if [[ -n "$cut2" ]]; then
    local difference="$((cut2 - cut1))"
    [ "${difference#-}" = 1 ] && red 'YES' || echo 'NO (good)'
  else
    yellow "UNKNOWN$(printf_safe " (%s scene cut missing)" "$cut2_type")"
  fi

  [[ "$cut1" != '0' ]] && red 'NO' || echo 'YES (good)'
}

rpu_info_l5() {
  local -r rpu_l5="$1" edge="$2"

  local -r edge_offsets=$(grep "$edge" "$rpu_l5" | grep -oE "[0-9]+" | sort -nu)
  [ -z "$edge_offsets" ] && yellow 'N/A' && return

  local -r offset_min=$(head -n1 <<<"$edge_offsets") offset_max=$(tail -n1 <<<"$edge_offsets")
  if [ "$offset_min" = "$offset_max" ]; then
    [[ "$offset_min" = '0' && "$edge" != 'left' && "$edge" != 'right' ]] && yellow 0 || echo "$offset_min"
  else
    echo "($offset_min - $offset_max)"
  fi
}

rpu_info_cm4() {
  local rpu_json="$1" short_sample="$2" quick="$3" l8_info l8_tdis l9_spis

  ! grep -q 'cmv40' "$rpu_json" && return

  if [ "$quick" != 1 ]; then
    rpu_json=$(to_rpu_json "$input" "$short_sample" 0)
    local -r rpu_info=$(grep -oE '("target_display_index":[124][4578]?)|("source_primary_index":[02])' "$rpu_json" | sort -u)
    l8_tdis=$(echo "$rpu_info" | grep 'target_display_index')
    l9_spis=$(echo "$rpu_info" | grep 'source_primary_index')
  else
    l8_tdis=$(grep 'target_display_index' "$rpu_json")
    l9_spis=$(grep 'source_primary_index' "$rpu_json")
  fi

  [[ "$l8_tdis" =~ :\ ?1 ]] && l8_info="100 nits"
  [[ "$l8_tdis" =~ :\ ?2[45] ]] && l8_info+=", 300 nits"
  [[ "$l8_tdis" =~ :\ ?2[78] ]] && l8_info+=", 600 nits"
  [[ "$l8_tdis" =~ :\ ?4 ]] && l8_info+=", 1000 nits"
  echo "${l8_info#, }"

  case "$l9_spis" in
  *2*) echo 'BT2020' ;;
  *0*) echo 'P3' ;;
  esac
}

printf_info() {
  printf_safe "  $1\n" "${@:2}"
}

info_summary() {
  local input="$1" short_sample="$2" quick="$3" rpu rpu_json rpu_l5 suffix rpu_cuts
  local dv_profile base_layer resolution lossless_audio l5_top l5_bottom l5_left l5_right l8_trims l9_mdp cuts_zero cuts_cons cuts_end_cons

  rpu=$(to_rpu "$input" "$short_sample" 1)
  rpu_json=$(to_rpu_json "$rpu" "$short_sample" 1)

  dv_profile=$(grep 'dovi_profile' "$rpu_json" | grep -oE '[0-9]+')
  IFS='|' read -r base_layer resolution lossless_audio < <(video_info "$input" "$dv_profile")

  { read -r l8_trims; read -r l9_mdp; } < <(rpu_info_cm4 "$rpu_json" "$short_sample" "$quick")

  rpu_l5=$(to_rpu_l5 "$rpu" "$short_sample")
  l5_top=$(rpu_info_l5 "$rpu_l5" 'top'); l5_bottom=$(rpu_info_l5 "$rpu_l5" 'bottom')
  l5_left=$(rpu_info_l5 "$rpu_l5" 'left'); l5_right=$(rpu_info_l5 "$rpu_l5" 'right')

  rpu_cuts=$(to_rpu_cuts "$rpu" "$short_sample" 1)
  { read -r cuts_cons; read -r cuts_zero; } < <(rpu_info_cuts "$rpu_cuts" 1 2 '2nd')
  [ "$short_sample" != 1 ] && read -r cuts_end_cons < <(rpu_info_cuts "$rpu_cuts" -1 -2)

  printf "\nRPU Input: %s%s\n" "$(basename "$rpu")" "$(printf_if "$short_sample" " (sample duration: ${EXTRACT_SHORT_SEC}s)")"

  dovi_tool info -s "$rpu" | grep -E '^ '

  printf_info "L8 trims: %s" "$l8_trims"
  printf_info "L9 MDP: %s" "$l9_mdp"
  printf_info "L5 offset: TOP=%s BOTTOM=%s, LEFT=%s, RIGHT=%s" "$l5_top" "$l5_bottom" "$l5_left" "$l5_right"
  printf_info "1st Frame is a Scene Cut: %s" "$cuts_zero"
  printf_info "Consecutive Scene Cuts: %s" "$cuts_cons"
  printf_info "Consecutive Last Scene Cuts: %s" "$cuts_end_cons"

  [[ -z "$base_layer" && -z "$resolution" && -z "$lossless_audio" ]] && return

  printf_info "Base Layer: %s" "$base_layer"
  printf_info "Lossless audio tracks: %s" "$lossless_audio"
  printf_info "Resolution/FPS: %s" "$resolution"
  printf_info "Video Input: %s" "$(basename "$input")"
}

info() {
  local input="$1" short_sample="$2" short_input="$3" quick="${4:-1}"

  if ! check_extension "$input" '.mkv .mp4 .m2ts .ts .hevc .bin'; then
    log_t "Cannot print info for '%s' (unsupported file format), skipping..." "$(basename "$input")"
    return
  fi

  log_t "Printing%s info for: '%s' ..." "$(printf_if "$quick" ' quick')" "$(basename "$input")"

  [[ "$short_sample" = 1 && "$short_input" != 1 ]] && check_extension "$input" '.bin' && short_sample=0

  info_summary "$input" "$short_sample" "$quick"

  [ "$INFO_L1_PLOT" = 1 ] && [[ "$short_sample" != 1 || "$OPTIONS_PLOT_SET" = 1 ]] && plot_l1 "$input" "$short_sample" 1
}

calculate_frame_shift() {
  local -r cuts_file="$1" cuts_base_file="$2" fast="$3"

  declare -A visited
  mapfile -t cuts1 <"$cuts_file"
  mapfile -t cuts2 <"$cuts_base_file"
  local -ri size1=${#cuts1[@]} size2=${#cuts2[@]}

  local -i max_misses=10 max_offset=10 min_matches=$((size2 / 2))
  [ "$fast" != 1 ] && max_offset=20 && max_misses="$min_matches"
  local -ri max_offset1=$((size1 > max_offset ? max_offset : size1)) max_offset2=$((size2 > max_offset ? max_offset : size2))

  local -i offset1 offset2 offset shift first_cut last_cut cut matches misses
  for ((offset1 = 0; offset1 < max_offset1; offset1++)); do
    for ((offset2 = 0; offset2 < max_offset2; offset2++)); do
      offset=$((offset2 - offset1))
      shift=$((cuts1[offset1] - cuts2[offset2]))

      [[ -v visited["$offset;$shift"] ]] && continue || visited["$offset;$shift"]=1

      matches=0
      misses=0
      first_cut=$((offset < 0 ? offset * -1 : 0))
      last_cut=$((size2 - offset))
      ((size1 < last_cut)) && last_cut="$size1"

      for ((cut = first_cut; cut < last_cut; cut++)); do
        if ((cuts1[cut] - cuts2[cut + offset] - shift == 0)); then
          matches+=1
        elif ((++misses >= max_misses)); then
          ((matches < min_matches)) && break
        fi
      done

      ((matches >= min_matches)) && break 2
    done
  done

  if ((matches >= min_matches)); then
    local -ri percent=$((matches * 100 / size2))
    log "Found a frame shift: $shift - matches $matches/$size2 ($percent%) scene cuts" 2
    echo "$shift"
  fi
}

frame_shift() {
  local -r input="$1" input_base="$2" providable="$3"
  local -r cuts=$(to_rpu_cuts "$input") cuts_base=$(to_rpu_cuts "$input_base")

  log "Calculating frame shift of '$(basename "$input")' relative to '$(basename "$input_base")'..." 1
  local shift=$(calculate_frame_shift "$cuts" "$cuts_base" 1)

  if [[ -z "$shift" ]]; then
    log "The fast run failed to find a valid frame shift, performing a full run..."
    shift=$(calculate_frame_shift "$cuts" "$cuts_base")
  fi

  if [[ -z "$shift" ]]; then
    local error="The full run failed to find a valid frame shift too"
    [ "$providable" = 1 ] && error+=" (provide a valid '$B--frame-shift$N' manually)"
    fatal_error "$error" 2
  fi

  echo "$shift"
}

duplicate_frame() {
  local -ri source="$1" offset="$2" length="$3"
  local -r config="$4"

  echo "${config:+$config, }{ \"source\": $source, \"offset\": $offset, \"length\": $length }"
}

remove_frames() {
  local -ri start="$1" end="$2"
  local -r config="$3"

  echo "${config:+$config, }\"$start-$end\""
}

editor_config_json() {
  local -r rpu=$(to_rpu "$1") rpu_base=$(to_rpu "$2") frame_shift="$3"

  local -i shift=${frame_shift:-$(frame_shift "$rpu" "$rpu_base" 1)}
  local -ri frames=$(rpu_frames "$rpu") frames_base=$(rpu_frames "$rpu_base")
  local -ri frames_diff=$((frames - frames_base - shift))

  local -i remove_start=0
  local duplicate remove config

  if ((shift > 0)); then
    remove_start="$shift"
    if cut_frame "$rpu" "$shift" || ! cut_frame "$rpu" 0 || ! cut_frame "$rpu_base" 0; then
      remove=$(remove_frames 0 $((remove_start - 1)))
    else
      remove=$(remove_frames 1 "$remove_start")
    fi
  elif ((shift < 0)); then
    shift=$((shift * -1))
    if ! cut_frame "$rpu" 0 || cut_frame "$rpu" 1; then
      duplicate=$(duplicate_frame 0 0 $shift)
    elif cut_frame "$rpu" 0; then
      duplicate=$(duplicate_frame 1 1 $shift)
    else
      duplicate=$(duplicate_frame 1 0 $shift)
    fi
  fi

  if ((frames_diff > 0)); then
    local -ri remove_from=$((frames - frames_diff))
    remove=$(remove_frames $remove_from $((frames - 1)) "$remove")
  elif ((frames_diff < 0)); then
    local -ri src_frame=$((frames - remove_start - 1))
    duplicate=$(duplicate_frame $src_frame $src_frame $((frames_diff * -1)) "$duplicate")
  fi

  [[ -n "$duplicate" ]] && config="\"duplicate\": [ $duplicate ], "
  [[ -n "$remove" ]] && config+="\"remove\": [ $remove ]"

  if [[ -n "$config" ]]; then
    local -r output=$(tmp_file "$rpu" 'json' 'EDITOR-CONFIG')
    echo "{ ${config%, } }" >"$output"
    echo "$output"
  fi
}

sync_rpu() {
  local input="$1" input_base="$2" frame_shift="$3" info="$4" output="$5"
  local -r rpu=$(to_rpu "$input") rpu_base=$(to_rpu "$input_base")
  local -r input_name=$(basename "$input") base_name=$(basename "$input_base")

  log "Syncing '$input_name' with '$base_name' ..." 1
  output=$(out_file "$rpu" 'bin' "SYNCED-$(filename "$rpu_base")" "$output")

  if [[ ! -f "$output" ]]; then
    local -r config=$(editor_config_json "$rpu" "$rpu_base" "$frame_shift")

    if [[ -z "$config" ]]; then
      log "Given RPU files are already in sync, skipping..."
      output="$rpu"
    else
      dovi_tool editor -i "$rpu" -j "$config" -o "$output" >&2
      log "'$input_name' successfully synced with '$base_name' - output file: '$output'" 1
    fi
  else
    log "The RPU file: '$output' already exists, skipping..."
  fi

  if [[ "$info" = 1 && "$INFO_INTERMEDIATE" = 1 ]]; then
    info "$rpu_base" >&2
    info "$output" >&2
  fi

  echo "$output"
}

inject_rpu() {
  local input="$1" input_base="$2" skip_sync="$3" frame_shift="$4" output="$5" exit_if_exists="$6"
  output=$(out_hybrid "$input" "$input_base" 'bin' "$output")

  log "Creating hybrid RPU: '$(basename "$output")'..." 1

  if [[ ! -f "$output" ]]; then
    local rpu_base=$(to_rpu "$input_base") rpu_synced rpu_cm4

    if [ "$skip_sync" = 1 ]; then
      log "Skipping RPU sync..."
      rpu_synced=$(to_rpu "$input")
    else
      rpu_synced=$(sync_rpu "$input" "$rpu_base" "$frame_shift" 0)
      log ""
    fi

    cm4_input "$rpu_synced" && rpu_cm4=$(to_cm4_rpu "$rpu_base")

    local -r sync_config=$(tmp_file "$rpu_synced" 'json' 'EDITOR-SYNC')
    rpu_synced=$(realpath --relative-to="$(pwd)" "$rpu_synced")
    rpu_synced=$(windows_safe_path "$rpu_synced")
    echo "{ \"source_rpu\": \"$rpu_synced\", \"rpu_levels\": [$RPU_LEVELS] }" >"$sync_config"

    if ! dovi_tool editor -i "${rpu_cm4:-"$rpu_base"}" -j "$sync_config" -o "$output" >&2; then
      log_kill "Error while injecting RPU levels: $RPU_LEVELS of '$(basename "$rpu_synced")' into '$(basename "$rpu_base")'" 1
    fi

    log "RPU levels: $RPU_LEVELS of '$(basename "$rpu_synced")' successfully injected into '$(basename "$rpu_base")' - output file: '$output'" 1

    if [ "$INFO_INTERMEDIATE" = 1 ]; then
      info "$rpu_base" >&2
      info "$rpu_synced" >&2
      info "$output" >&2
    fi
  elif [ "$exit_if_exists" = 1 ]; then
    log_kill "The hybrid RPU file: '$output' already exists" 2
  else
    log "The hybrid RPU file: '$output' already exists, skipping..."
  fi

  echo "$output"
}

inject_hevc() {
  local input="$1" input_base="$2" raw_rpu="$3" skip_sync="$4" frame_shift="$5" output="$6" exit_if_exists="$7" rpu_type='Raw' rpu_injected

  output=$(out_hybrid "$input" "$input_base" 'hevc' "$output" "$raw_rpu")
  log "Creating hybrid base layer: '$(basename "$output")'..." 1

  if [[ ! -f "$output" ]]; then
    if [ "$raw_rpu" != 1 ]; then
      rpu_type='Hybrid'
      rpu_injected=$(inject_rpu "$input" "$input_base" "$skip_sync" "$frame_shift")
    elif [ "$skip_sync" != 1 ]; then
      rpu_injected=$(sync_rpu "$input" "$input_base" "$frame_shift" 1)
    else
      log "Skipping raw RPU sync..." 1
      rpu_injected=$(to_rpu "$input")
    fi

    local -r hevc=$(to_hevc "$input_base") base_name=$(basename "$input_base")

    log "Injecting ${rpu_type,,} RPU: '$(basename "$rpu_injected")' into base layer of '$base_name' ..." 1 && log ""

    dovi_tool inject-rpu -r "$rpu_injected" -o "$output" "$hevc" >&2

    [[ ! "$input_base" -ef "$hevc" ]] && rm "$hevc" && log "Intermediate base layer: '$(basename "$hevc")' removed" 1

    log "$rpu_type RPU: '$(basename "$rpu_injected")' successfully injected into base layer of '$base_name' - output file: '$output'" 1
  elif [ "$exit_if_exists" = 1 ]; then
    log_kill "The hybrid base layer: '$output' already exists" 2
  else
    log "The hybrid base layer: '$output' already exists, skipping..."
  fi

  echo "$output"
}

mp4_unremuxable() {
  local -r base_file="$1" hevc="$2" short_sample="$3" input_type="${4:-'--base-input/-b'}"

  [[ -z "$hevc" ]] && check_extension "$base_file" '.mp4' && return 0
  [[ -n "$(audio_info "$base_file" 0 1)" ]] && echo "'$B$input_type$N' contains lossless audio" && return 1
  [[ -n "$hevc" ]] && p7_input "$hevc" "$short_sample" && echo "'--hevc/-r' contains Dolby Vision Profile 7 layer" && return 1
  [[ -z "$hevc" ]] && p7_input "$base_file" "$short_sample" && echo "'$B$input_type$N' contains Dolby Vision Profile 7 layer" && return 1

  return 0
}

mp4_preferred() {
  local -r input="$1" hevc="$2" short_sample="$3"

  dovi_input "${hevc:-"$input"}" "$short_sample" && [[ -z "$(mp4_unremuxable "$input" "$hevc" "$short_sample")" ]]
}

auto_target_format() {
  local -r input="$1" hevc="$2" short_sample="$3" input_type="${4:-"--base-input/-b"}"

  [[ "$input" != *.* ]] && log_kill "Cannot deduce target format ('$B$input_type$N' have no extension)" 2

  local -r target_format="${input##*.}"

  check_extension "$target_format" ".m2ts .ts" && target_format='mkv'
  check_extension "$target_format" '.mkv' && mp4_preferred "$input" "$hevc" "$short_sample" && echo "mp4" && return 0

  echo "${target_format,,}"
}

target_format() {
  local input="$1" target_format="$2" output="$3" valid_extensions="$4" short_sample="$5" hevc="$6" input_type="${7:-"--base-input/-b"}" type="'$B--output-format/-e$N'"

  [[ -z "$target_format" && "$output" == *.* ]] && target_format="${output##*.}" && type="'$B--output/-o$N' format"

  if [[ -z "$target_format" ]]; then
    auto_target_format "$input" "$hevc" "$short_sample" "$input_type"
    return 0
  fi

  if [[ "$output" == *.* ]] && ! check_extension "$output" ".$target_format"; then
    log_kill "Invalid $type: '$target_format' is incompatible with given '$B--output/-o$N': '$(basename "$output")'" 2
  fi

  if ! check_extension "$target_format" "$valid_extensions"; then
    log_kill "Invalid $type: '$target_format' (supported formats: $valid_extensions)" 2
  fi

  if check_extension "$target_format" ".mkv .mp4"; then
    if ! check_extension "$input" ".mkv .mp4 .m2ts .ts"; then
      log_kill "Invalid $type: '$target_format' is incompatible with .${input##*.} '$B$input_type$N'" 2
    elif check_extension "$target_format" ".mp4"; then
      local -r unremuxable_reason=$(mp4_unremuxable "$input" "$hevc" "$short_sample" "$input_type")
      [[ -n "$unremuxable_reason" ]] && log_kill "Invalid $type: '$target_format' ($unremuxable_reason)" 2
    fi

  elif check_extension "$target_format" ".hevc" && ! check_extension "$input" ".mkv .mp4 .m2ts .ts .hevc"; then
    log_kill "Invalid $type: '$target_format' is incompatible with .${input##*.} '$B$input_type$N'" 2
  fi

  echo "${target_format,,}"
}

subtitles() {
  local input="$1" subs="$2" clean_filename="${3// /.}" subs_input

  if [[ -n "$subs" ]]; then
    subs=$(realpath "$subs")
    file_exists "$subs" '' 1
    check_extension "$subs" '.srt' 1
    echo "$subs"
  fi

  [ "$SUBS_AUTODETECTION" != 1 ] && return

  find "$(dirname "$input")" -maxdepth 1 -type f \( -iname "*.srt" \) -print0 | while read -rd $'\0' subs_input; do
    if [[ -z "$subs" || ! "$subs_input" -ef "$subs" ]] && [[ "$(basename "$subs_input")" =~ ^$clean_filename ]]; then
      log "Found matching subtitles: '$(basename "$subs_input")'"
      realpath "$subs_input"
    fi
  done
}

metadata_subs() {
  local -r subs="$(filename "$1")"
  local -r lang_code="${subs##*.}"

  if [[ "$subs" != *.* || ${#lang_code} -lt 2 || ${#lang_code} -gt 3 ]]; then
    echo "" && return
  fi

  case "${lang_code,,}" in
  pl | pol) echo "pol|Polish" ;;
  en | eng) echo "eng|English" ;;
  es | spa) echo "spa|Spanish" ;;
  it | ita) echo "ita|Italian" ;;
  ja | jpn) echo "jpn|Japanese" ;;
  ko | kor) echo "kor|Korean" ;;
  pt | por) echo "por|Portuguese" ;;
  ru | rus) echo "rus|Russian" ;;
  de | ger | deu) echo "ger|German" ;;
  fr | fre | fra) echo "fre|French" ;;
  zh | chi | zho) echo "chi|Chinese" ;;
  *) echo "${lang_code,,}" ;;
  esac
}

metadata_title() {
  local input="$(filename "$1")" title="$2" clean_filename="$3"

  [[ -n "$title" ]] && echo "$title" && return 0

  if [[ "$input" =~ S[0-9]{1,3}E[0-9]{1,3} ]]; then
    [ "$TITLE_SHOWS_AUTO" = 1 ] && echo "$clean_filename"
  elif [ "$TITLE_MOVIES_AUTO" = 1 ]; then
    echo "$clean_filename"
  fi
}

remux_mp4() {
  local input="$1" hevc="$2" subs="$3" title="$4" clean_filename="$5" output="$6"
  local metadata lang subs_title
  local -i input_number=1 audio_track=0 subs_track=0

  local ffmpeg_input=(-i "$input") ffmpeg_copy=(-c copy -c:s mov_text) ffmpeg_map=() ffmpeg_metadata=()

  if [[ -n "$hevc" ]]; then
    ffmpeg_input+=(-i "$hevc")
    ffmpeg_map+=(-map "$((input_number++)):0")
  else
    ffmpeg_map+=(-map "0:v?")
  fi

  ((AUDIO_COPY_MODE < 3)) && ffmpeg_map+=(-map "0:a:0") || ffmpeg_map+=(-map "0:a?")
  if ((TRACK_NAMES_AUTO == 1)); then
    while read -r metadata; do
      metadata="${metadata#*|}"
      [ -n "$metadata" ] && ffmpeg_metadata+=("-metadata:s:a:$((audio_track++))" "title=$metadata")
      ((AUDIO_COPY_MODE < 3)) && break
    done < <(audio_info "$input" 1)
  fi

  while read -r subs; do
    ffmpeg_input+=(-i "$subs")
    ffmpeg_map+=(-map "$((input_number++)):0")
    if ((TRACK_NAMES_AUTO == 1)); then
      metadata=$(metadata_subs "$subs")
      lang="${metadata%%|*}"
      [[ "$metadata" == *\|* ]] && subs_title="${metadata#*|}" || subs_title=""
      [[ -n "$lang" ]] && ffmpeg_metadata+=("-metadata:s:s:$subs_track" "language=$lang")
      [[ -n "$subs_title" ]] && ffmpeg_metadata+=("-metadata:s:s:$subs_track" "title=$subs_title")
    fi
    subs_track+=1
  done < <(subtitles "$input" "$subs" "$clean_filename")

  if [[ "$SUBS_COPY_MODE" = 1 || "${SUBS_COPY_MODE,,}" = 'all' ]]; then
    ffmpeg_map+=(-map "0:s?")
  elif [[ ${#SUBS_COPY_MODE} -eq 3 ]]; then
    ffmpeg_map+=(-map "0:s:m:language:${SUBS_COPY_MODE,,}:?")
  fi

  title=$(metadata_title "$input" "$title" "$clean_filename")
  [[ -n "$title" ]] && ffmpeg_metadata+=(-metadata "title=$title")

  [ "$FFMPEG_STRICT" = 1 ] && ffmpeg_copy+=(-strict -2)
  ffmpeg "${ffmpeg_input[@]}" "${ffmpeg_map[@]}" "${ffmpeg_copy[@]}" "${ffmpeg_metadata[@]}" "$output"
}

remux_mkv() {
  local input="$1" hevc="$2" subs="$3" title="$4" clean_filename="$5" output="$6"
  local metadata id lang name audio_tracks compatibility audio_names=()

  local mkv_merge=(--output "$(windows_safe_path "$output")")

  while read -r subs; do
    if ((TRACK_NAMES_AUTO == 1)); then
      metadata=$(metadata_subs "$subs")
      lang="${metadata%%|*}"
      [[ "$metadata" == *\|* ]] && name="${metadata#*|}" || name=""
      [[ -n "$lang" ]] && mkv_merge+=(--language "0:$lang")
      [[ -n "$name" ]] && mkv_merge+=(--track-name "0:$name")
    fi
    mkv_merge+=("$subs")
  done < <(subtitles "$input" "$subs" "$clean_filename")

  [[ -n "$hevc" ]] && mkv_merge+=("$hevc" --no-video)

  while IFS='|' read -r id name; do
    if [[ "$compatibility" != 1 || "$name" == *'AC-3'* ]]; then
      audio_tracks+="$id,"
      [[ "$TRACK_NAMES_AUTO" = 1 && -n "$name" ]] && audio_names+=(--track-name "$id:$name")
    fi

    [[ "$AUDIO_COPY_MODE" = 1 || "$compatibility" == 1 ]] && break
    [ "$AUDIO_COPY_MODE" = 2 ] && compatibility=1 && [[ "$name" != *'TrueHD'* ]] && break
  done < <(audio_info "$input" 1)
  [[ "$AUDIO_COPY_MODE" != 3 && -n "$audio_tracks" ]] && mkv_merge+=(--audio-tracks "${audio_tracks%,}")
  mkv_merge+=("${audio_names[@]}")

  if [[ "$SUBS_COPY_MODE" = 0 ]]; then
    mkv_merge+=(--no-subtitles)
  elif [[ ${#SUBS_COPY_MODE} -eq 3 && "${SUBS_COPY_MODE,,}" != 'all' ]]; then
    mkv_merge+=(--subtitle-tracks "${SUBS_COPY_MODE,,}")
  fi

  mkv_merge+=("$input")

  title=$(metadata_title "$input" "$title" "$clean_filename")
  [[ -n "$title" ]] && mkv_merge+=(--title "$title")

  mkvmerge "${mkv_merge[@]}"
}

remux() {
  local input="$1" output_format="$2" output="$3" hevc="$4" subs="$5" title="$6" validate_output_format="${7:-1}"

  check_extension "$input" '.mkv .mp4 .m2ts .ts' 1
  [[ -n "$hevc" ]] && check_extension "$hevc" '.hevc' 1

  if [[ -z "$output_format" || "$validate_output_format" != 0 ]]; then
    output_format=$(target_format "$input" "$output_format" "$output" '.mkv .mp4' 1 "$hevc" "--input/-i")
  fi

  output=$(out_file "$input" "$output_format" "REMUXED" "$output" "$CLEAN_FILENAMES")
  [[ -f "$output" ]] && log "The output file: '$(basename "$output")' already exists, skipping..." 1 && return

  log "Remuxing '$(basename "$input")' (output file '$(basename "$output")')..." 1

  local -r clean_filename=$(clean_filename "$input")
  if [[ "$output_format" == *mkv* ]]; then
    remux_mkv "$input" "$hevc" "$subs" "$title" "$clean_filename" "$output"
  elif [[ "$output_format" == *mp4* ]]; then
    remux_mp4 "$input" "$hevc" "$subs" "$title" "$clean_filename" "$output"
  fi

  [[ $? -eq 0 ]] && log "'$(basename "$input")' successfully remuxed - output file: '$output'" 1
}

inject() {
  local input="$1" input_base="$2" raw_rpu="$3" skip_sync="$4" frame_shift="$5" output_format="$6" output="$7" subs="$8" title="$9" type

  check_extension "$input_base" '.mkv .mp4 .m2ts .ts .hevc .bin' 1
  check_extension "$input" '.mkv .mp4 .m2ts .ts .hevc .bin' 1

  output_format=$(target_format "$input_base" "$output_format" "$output" '.mkv .mp4 .hevc .bin')

  [ "$raw_rpu" = 1 ] && type='raw RPU' || type="RPU levels: $RPU_LEVELS"
  log "Injecting $type of '$(basename "$input")' into '$(basename "$input_base")'..." 1

  if [[ "$output_format" == *bin* ]]; then
    [ "$raw_rpu" = 1 ] && log_kill "'$B--raw-rpu/-w$N' cannot be used with .bin outputs" 2
    inject_rpu "$input" "$input_base" "$skip_sync" "$frame_shift" "$output" 1 >/dev/null
  elif [[ "$output_format" == *hevc* ]]; then
    inject_hevc "$input" "$input_base" "$raw_rpu" "$skip_sync" "$frame_shift" "$output" 1 >/dev/null
  else
    output=$(out_file "$input_base" "$output_format" "HYBRID" "$output" "$CLEAN_FILENAMES")
    [[ -f "$output" ]] && log "Hybrid output file: '$(basename "$output")' already exists, skipping..." && return

    local hevc=$(inject_hevc "$input" "$input_base" "$raw_rpu" "$skip_sync" "$frame_shift")

    log "Injecting hybrid base layer: '$(basename "$hevc")' into '$(basename "$input_base")'..." 1
    remux "$input_base" "$output_format" "$output" "$hevc" "$subs" "$title" 0
  fi
}

subs_mapping() {
  local base_output="$1" suffix="$2" spacer="$3" id="$4" tracks="$5" output="$1$2"
  local -i i=1

  while [[ -e "$output" || "$tracks" == *"$output"* ]]; do
    output="$base_output$spacer$((i++))$suffix"
  done

  log "Mapping track $id -> '$output'"

  echo "$id:$output"
}

subs() {
  local input="$1" output="$2" tracks=() suffix spacer select id lang forced sdh vi desc comment

  check_extension "$input" '.mkv' 1

  output=$(out_file "$input" 'srt' '' "$output" "$CLEAN_FILENAMES" 1)
  [[ -n "$output" ]] && check_extension "$output" '.srt' 1 'given output'

  [[ "$(basename "$output")" == *' '* ]] && spacer=" " || spacer="-"
  output="${output%.*}"

  log "Extracting .srt subtitles from '$(basename "$input")'..." 1

  local properties='\(.id) \(.properties.language_ietf) \(.properties.forced_track) \(.properties.flag_hearing_impaired) \(.properties.flag_visual_impaired) \(.properties.flag_text_descriptions) \(.properties.flag_commentary)'
  if [[ -n "$SUBS_LANG_CODES" && "${SUBS_LANG_CODES,,}" != 'all' ]]; then
    select="| select((.properties.language) | test(\"${SUBS_LANG_CODES//,/|}\")) "
  fi

  while read -r id lang forced sdh vi desc comment; do
    suffix=""
    [ "${comment,,}" = 'true' ] && suffix+="${spacer}COMMENTARY"
    [ "${desc,,}" = 'true' ] && suffix+="${spacer}DESCRIPTION"
    [ "${vi,,}" = 'true' ] && suffix+="${spacer}VI"
    [ "${sdh,,}" = 'true' ] && suffix+="${spacer}SDH"
    [ "${forced,,}" = 'true' ] && suffix+="${spacer}FORCED"
    [[ -n "$lang" && "${lang,,}" != 'und' && "${lang,,}" != 'null' ]] && suffix+=".${lang,,}"
    suffix+=".srt"

    tracks+=("$(subs_mapping "$output" "$suffix" "$spacer" "$id" "${tracks[*]}")")
  done < <(mkvmerge -J "$input" | jq -r ".tracks[] | select(.codec == \"SubRip/SRT\") $select| \"$properties\"")

  if [[ ${#tracks[@]} -gt 0 ]]; then
    log ""
    mkvextract "$input" tracks "${tracks[@]}"
  else
    log "No subtitles found in '$(basename "$input")' ($B--lang-codes/-c$N: ${SUBS_LANG_CODES:-'all'}), skipping..."
  fi
}

help_dir() {
  local out_dir="$1" result
  local result=$(realpath --relative-to="$(pwd)" "$out_dir")

  [ "$result" = '.' ] && echo "<working-dir>" && return

  [[ "$result" == *"$out_dir"* || "$result" == ../../* ]] && result="$out_dir"
  [[ "$result" =~ [0-9]{11}/?$ ]] && result="${result//${BASH_REMATCH[0]}/<timestamp>/}"
  [[ ! "$result" =~ ^/ && ! "$result" =~ ^\.\. ]] && result="./$result"

  echo "${result%/}"
}

help0() {
  local help="$1" empty_line="$2" option="$3" line left
  [[ -z "$option" ]] && option=${help:1:1}

  [[ -n "${option// /}" && "ihvN" != *"$option"* && -n "$cmd_options" && "$cmd_options" != *"$option"* ]] && return

  [[ "$empty_line" = 1 && "$help_short" != 1 ]] && echo ""
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    left=${line:0:$help_left}
    echo "  $B${left//</$N<}$N$(trim "${line:$help_left}")"
    [ "$help_short" = 1 ] && break
  done <<<"$help"
  return 0
}

help1() {
  local option="$1" help="$2"
  [[ -z "$help" ]] && help="$1" && option="" || help="    $help"
  help0 "$help" 1 "$option"
}

help() {
  local cmd="$1" p s b t q bin clean; help_left=21
  local -r description=${cmd_description[$cmd]:-$(cmd_info "$cmd")} formats=$(cmd_info "$cmd" 3)
  [[ "$cmd_options" == *b* ]] && b=1
  [[ "$cmd_options" == *t* ]] && t=1
  [[ "$cmd_options" == *q* ]] && q=1
  [[ "$cmd_options" == *s* && "$INFO_L1_PLOT" != 0 ]] && s=1 || p=1
  [[ "$formats" == *bin* ]] && bin=1
  local multiple_inputs="${t:+"[ignored when multiple inputs]"}" default_output_format='auto-detected'
  [ "$cmd" = 'extract' ] && default_output_format='bin'

  case "$cmd_options" in
  *[elc]*) help_left+=9 ;;
  *m*) help_left+=8 ;;
  *[fx]*) help_left+=6 ;;
  *bs*) help_left+=5 ;;
  *t*) help_left+=4 ;;
  *o*) help_left+=2 ;;
  esac

  echo "$description"
  echo1 "${BU}Usage:$N $REMUXER $B$cmd$N [OPTIONS] ${b:+"--base-input <BASE-INPUT> "}[INPUT${t:+"..."}]"
  echo1 "${BU}Arguments:$N"
  help0 "INPUT                         Input file path"
  echo1 "${BU}Options:$N"
  help0 "-i, --input <INPUT>           Input file${t:+"/dir"} path${t:+" [can be used multiple times]"}
                                       ${t:+"For dirs, all supported files within will be used"}
                                       [supported formats: $B$formats$N]"
  help1 "-b, --base-input <INPUT>      Base input file path [${B}required$N]
                                       [supported formats: $B$formats$N]"
  help1 "-x, --formats <F1,...,FN>     Filter files by format in dir inputs
                                       [allowed values: $B${formats//./}$N]"
  help1 "-t, --input-type <TYPE>       Filter files by type in dir inputs
                                       Allowed values:
                                       $B- shows:$N  files with ${B}S01E01$N-like pattern in name
                                       $B- movies:$N non-show files"
  help1 "-o, --output <OUTPUT>         Output file path [default: ${B}generated$N]
                                       $multiple_inputs"
  help1 "-e, --output-format <FORMAT>  Output format [default: $B$default_output_format$N]
                                       [allowed values: $B$(cmd_output_formats "$cmd")$N]"
  help1 "-s, --sample [<SECONDS>]      Process only the first N seconds of input
                                       [default sample duration: ${EXTRACT_SHORT_SEC}s]
                                       ${bin:+"[ignored for $B.bin$N inputs]"}"
  help1 "-q, --skip-sync               Skip RPUs sync (assumes RPUs are already in sync)"
  help1 "-f, --frame-shift <SHIFT>     Frame shift value [default: ${B}auto-calculated$N]
                                       ${q:+"[ignored when $B--skip-sync$N]"}"
  help1 "-l, --rpu-levels <L1,...,LN>  RPU levels to inject [default: $B$RPU_LEVELS$N]
                                       [allowed values: ${B}1-6, 8-11, 254, 255$N]
                                       [ignored when $B--raw-rpu$N]"
  help1 "-w, --raw-rpu                 Inject input RPU instead of transferring levels"
  help1 "-n, --info <0|1>              Controls intermediate info commands [default: $B$INFO_INTERMEDIATE$N]"
  help1 "-p, --plot <0|1>              Controls L1 plotting in info command${p:+" [default: $B$INFO_L1_PLOT$N]"}
                                       ${s:+"[default: $B$INFO_L1_PLOT$N, or ${B}0$N if $B--sample$N is used]"}"
  help1 "-c, --lang-codes <C1,...,CN>  ISO 639-2 lang codes of subtitle tracks to extract
                                       [default: $B${SUBS_LANG_CODES:-all}$N; example value: 'eng,pol']"
  clean="-m, --clean-filenames <0|1>   Controls output filename cleanup [default: $B$CLEAN_FILENAMES$N]
                                       [ignored if $B--output$N is set]
                                       [e.g., 'The.Show.S01E01.HDR' → 'The Show S01E01']
                                       [e.g., 'A.Movie.2025.UHD.2160p.DV' → 'A Movie']"
  [[ "$cmd" != inject && "$cmd" != remux ]] && help1 "$clean"
  help1 "    --out-dir <DIR>           Output files dir path
                                       [default: '$B$(help_dir "$OUT_DIR")$N']"
  help1 "    --tmp-dir <DIR>           Temp files dir path [will be ${B}removed if created$N]
                                       [default: '$B$(help_dir "$TMP_DIR")$N']"
  help1 "-h, --help                    Show help (use '$B--help$N' for a detailed version)"

  [[ "$cmd" != inject && "$cmd" != remux ]] && return
  echo1 "${BU}Options for .mkv / .mp4 output:$N"
  help0 "    --subs <FILE>             $B.srt$N subtitle file path to include
                                       $multiple_inputs"
  help1 "    --find-subs <0|1>         Controls subtitles auto-detection [default: $B$SUBS_AUTODETECTION$N]
                                       If ${B}1$N, searches for matching subs within input's dir"
  help1 "    --copy-subs <OPTION>      Controls input subtitle tracks to copy [default: $B$SUBS_COPY_MODE$N]
                                       Allowed values:
                                       $B- 0:$N     none
                                       $B- 1:$N     all
                                       $B- <lng>:$N based on ISO 639-2 lang code [e.g., eng]"
  help1 "    --copy-audio <OPTION>     Controls input audio tracks to copy [default: $B$AUDIO_COPY_MODE$N]
                                       Allowed values:
                                       $B- 1:$N 1st track only
                                       $B- 2:$N 1st track + compatibility if 1st is TrueHD
                                       $B- 3:$N all"
  help1 "-r, --hevc <FILE>             $B.hevc$N file path to replace input video track
                                       $multiple_inputs"
  help1 "    --title <TITLE>           Metadata title (e.g., movie name)
                                       $multiple_inputs"
  help1 "    --auto-title <0|1>        Controls generation of metadata title
                                       If ${B}1$N, metadata title will match clean filename
                                       [default - shows: $B$TITLE_SHOWS_AUTO$N, movies: $B$TITLE_MOVIES_AUTO$N]
                                       [ignored if $B--title$N is set]"
  help1 "    --auto-tracks <0|1>       Controls generation of some track names [default: $B$TRACK_NAMES_AUTO$N]
                                       [e.g., audio: TrueHD Atmos 7.1, subs: Polish]"
  help1 "$clean"
}

version() {
  echo "Remuxer $VERSION"
}

show_help() {
  local cmd="$1"

  [[ "$2" = 1 || "$2" = '-h' ]] && help_short=1

  if [[ -n "$cmd" ]]; then
    help "$cmd"
    return 0
  fi

  echo "CLI tool for processing DV videos, with a focus on CMv4.0 + P7 CMv2.9 hybrid creation"
  echo1 "${BU}Usage:$N $REMUXER [OPTIONS] <COMMAND>"
  echo1 "${BU}Commands:$N"
  for cmd in info plot cuts extract frame-shift sync inject subs remux; do
    help0 "$cmd           $(cmd_info "$cmd")"
  done
  echo1 "${BU}Options:$N"
  help0 "-h, --help     Show help (use '$B--help$N' for a detailed version)"
  help0 "-v, --version  Show version"
  echo1 "${B}For more information about a command, run:$N"
  echo  "  $REMUXER <COMMAND> --help"
}

option_fatal() {
  log_kill "Invalid '$B$1$N': $2" 2 1
}

option_unsupported() {
  local -r cmd="$1" option="$2" required="$3"
  [[ -n "$required" && -n "$cmd_options" && "$cmd_options" != *"$required"* ]] && log "The $cmd command doesn't support '$option', skipping..."
}

option_empty() {
  local -r value="$1" current="$2" option="$3"
  [[ -z "$value" ]] && log "Detected empty '$option' value, skipping..." && echo "$current"
}

option_repeated() {
  local current="$1" option="$2" reason="$3" value="$4"
  [[ -n "$current" ]] && option_fatal "$option" "${value:+"'$value'" }cannot be specified multiple times${reason:+ ($reason)}"
}

option_valid() {
  local value="$1" current="$2" cmd="$3" option="$4" required="$5"

  option_unsupported "$cmd" "$option" "$required" && return 1
  option_empty "$value" "$current" "$option" && return 1
  option_repeated "$current" "$option"
  return 0
}

valid_input() {
  local input=$(trim "$1") current="$2" cmd="$3" batch="$4" valid_extensions="$5" option="${6:-"INPUT"}"

  option_empty "$input" '' "$option" >/dev/null && return 1
  [[ "$batch" = 0 ]] && option_repeated "$current" "$option" "$cmd command doesn't support batch processing" "$input"

  if [ -d "$input" ]; then
    [ "$batch" = 0 ] && option_fatal "$option" "'$input' is a dir ($cmd command doesn't support dir inputs)"
  elif [ -f "$input" ]; then
    check_extension "$input" "$valid_extensions" 1 "'$option' file"
  else
    log_kill "'$option': '$input' is invalid or doesn't exist" 2
  fi

  return 0
}

parse_base() {
  local value=$(trim "$1") current="$2" cmd="$3" option="$4" required="$5"
  option_valid "$value" "$current" "$cmd" "$option" "$required" || return
  echo "$value"
}

parse_file() {
  local path=$(trim "$1") current="$2" cmd="$3" option="$4" required="$5" valid_extensions="$6" exists="${7:-1}"

  option_valid "$path" "$current" "$cmd" "$option" "$required" || return
  if [[ -e "$path" ]]; then
    [ "$exists" != 1 ] && option_fatal "$option" "'$path' already exists"
    [[ ! -f "$path" ]] && option_fatal "$option" "'$path' exists but is not a file"
  elif [ "$exists" = 1 ]; then
    option_fatal "$option" "'$path' doesn't exist"
  fi
  [[ -n "$valid_extensions" ]] && check_extension "$path" "$valid_extensions" 1 "'$option' file"

  realpath "$path"
}

parse_dir() {
  local path=$(trim "$1") current="$2" cmd="$3" option="$4" required="$5"

  option_valid "$path" "$current" "$cmd" "$option" "$required" || return
  [[ -e "$path" && ! -d "$path" ]] && option_fatal "$option" "'$path' exists but is not a directory"

  echo "$path"
}

parse_option() {
  local value="${1// /}" current="$2" cmd="$3" option="$4" required="$5" allowed_values="$6" regex="$7" splittable="$8" result

  option_valid "$value" "$current" "$cmd" "$option" "$required" || return
  [ "$splittable" = 1 ] && value=${value//,/ }

  for v in $value; do
    result+="$v,"
    if [[ -n "$regex" ]]; then
      [[ "$v" =~ ^$regex$ ]] && continue
    else
      [[ " ${allowed_values//,/} " == *\ $v\ * ]] && continue
    fi
    option_fatal "$option" "'$v' is not a valid value (allowed: $allowed_values)"
  done

  echo "${result%,}"
}

find_filter() {
  local unique_formats=$(tr ',' '\n' <<<"${1// /}" | sort -u) first=1 format

  for format in $unique_formats; do
    [ "$first" = 1 ] && first=0 || echo '-o'
    echo '-iname'
    echo "*.${format#.}"
  done
}

typed_input() {
  local -r input="$1" dir="$2" type="$3"

  case "$type" in
  'shows') [[ "${input#"$dir"}" == *S[0-9][0-9]E[0-9][0-9]* ]] && realpath "$input" ;;
  'movies') [[ "${input#"$dir"}" != *S[0-9][0-9]E[0-9][0-9]* ]] && realpath "$input" ;;
  *) realpath "$input" ;;
  esac
}

parse_inputs() {
  local formats="$1" type="$2" input find_filter=()
  shift 2

  while [[ $# -gt 0 ]]; do
    if [ -d "$1" ]; then
      [ ${#find_filter[@]} -eq 0 ] && mapfile -t find_filter < <(find_filter "$formats")
      find "$1" -maxdepth 1 -type f \( "${find_filter[@]}" \) -print0 | while read -rd $'\0' input; do
        typed_input "$input" "$1" "$type"
      done
    else
      realpath "$1"
    fi
    shift
  done
}

deduplicate_list() {
  local -r deduplicated=$(tr ',' '\n' <<<"${1// /}" | sort -u | tr '\n' ',')
  echo "${deduplicated%,}"
}

deduplicate_array() {
  local item
  for item in "$@"; do echo "$item"; done | sort -u | cat
}

option_ignored() {
  local current="$1" option="$2" reason="$3"
  [ -n "$current" ] && log "$(yellow 'Warning:') '$B$option$N' $reason"
  echo ""
}

batch_ignored() {
  option_ignored "$1" "$2" "has no effect when multiple inputs are specified"
}

parse_args() {
  local cmd="$1"
  shift

  cmd_options=$(cmd_info "$cmd" 2)

  [[ $# -eq 0 ]] && show_help "$cmd" 1 && return

  local allowed_formats=$(cmd_info "$cmd" 3)
  local -i batch=0 sample=0 skip_sync=0 rpu_raw=0

  [[ "$cmd_options" == *t* ]] && batch=1

  local inputs=() input base_input formats input_type output output_format clean_filenames out_dir tmp_dir sample_duration
  local frame_shift rpu_levels info plot lang_codes hevc subs find_subs copy_subs copy_audio title title_auto tracks_auto

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help) show_help "$cmd" "$1"; return ;;
    -v | --version) version; return ;;
    -q | --skip-sync) skip_sync=1; shift; continue ;;
    -w | --raw-rpu) rpu_raw=1; shift; continue ;;
    -s | --sample)
      sample=1
      if [[ ! "$2" =~ ^[1-9][0-9]*$ ]]; then
        shift; continue
      fi
      sample_duration=$(parse_option "$2" "$sample_duration" "$cmd" "$1" 's' '<seconds>' '[1-9][0-9]*')
      ;;
    -x | --formats)                 formats=$(parse_option "$2" "$formats" "$cmd" "$1" 'x' "${allowed_formats//./}" '' 1) ;;
    -t | --input-type)           input_type=$(parse_option "$2" "$input_type" "$cmd" "$1" 't' 'shows, movies') ;;
    -o | --output)                   output=$(parse_file "$2" "$output" "$cmd" "$1" 'o' '' 0) ;;
    -e | --output-format)     output_format=$(parse_option "$2" "$output_format" "$cmd" "$1" 'e' "$(cmd_output_formats "$cmd")") ;;
    -f | --frame-shift)         frame_shift=$(parse_option "$2" "$frame_shift" "$cmd" "$1" 'f' '<number>' '-?[0-9]+') ;;
    -l | --rpu-levels)           rpu_levels=$(parse_option "$2" "$rpu_levels" "$cmd" "$1" 'l' '1-6, 8-11, 254, 255' '([1-689]|1[01]|25[45])' 1) ;;
    -n | --info)                       info=$(parse_option "$2" "$info" "$cmd" "$1" 'n' '0, 1') ;;
    -p | --plot)                       plot=$(parse_option "$2" "$plot" "$cmd" "$1" 'p' '0, 1') ;;
    -c | --lang-codes)           lang_codes=$(parse_option "$2" "$lang_codes" "$cmd" "$1" 'c' '<ISO 639-2 lang codes>' '[a-z]{3}' 1) ;;
    -m | --clean-filenames) clean_filenames=$(parse_option "$2" "$clean_filenames" "$cmd" "$1" 'm' '0, 1') ;;
    -r | --hevc)                       hevc=$(parse_file "$2" "$hevc" "$cmd" "$1" 'r' '.hevc') ;;
    --subs)                            subs=$(parse_file "$2" "$subs" "$cmd" "$1" 'e' '.srt') ;;
    --find-subs)                  find_subs=$(parse_option "$2" "$find_subs" "$cmd" "$1" 'e' '0, 1') ;;
    --copy-subs)                  copy_subs=$(parse_option "$2" "$copy_subs" "$cmd" "$1" 'e' '0, 1, <ISO 639-2 lang code>' '(0|1|[a-z]{3})') ;;
    --copy-audio)                copy_audio=$(parse_option "$2" "$copy_audio" "$cmd" "$1" 'e' '1, 2, 3') ;;
    --title)                          title=$(parse_base "$2" "$title" "$cmd" "$1" 'e') ;;
    --auto-title)                title_auto=$(parse_option "$2" "$title_auto" "$cmd" "$1" 'e' '0, 1') ;;
    --auto-tracks)              tracks_auto=$(parse_option "$2" "$tracks_auto" "$cmd" "$1" 'e' '0, 1') ;;
    --out-dir)                      out_dir=$(parse_dir "$2" "$out_dir" "$cmd" "$1") ;;
    --tmp-dir)                      tmp_dir=$(parse_dir "$2" "$tmp_dir" "$cmd" "$1") ;;
    -b | --base-input)           base_input=$(parse_file "$2" "$base_input" "$cmd" "$1" 'b' "$allowed_formats") ;;
    -i | --input) valid_input "$2" "${inputs[0]}" "$cmd" "$batch" "$allowed_formats" "$1" && inputs+=("$2") ;;
    *) valid_input "$1" "${inputs[0]}" "$cmd" "$batch" "$allowed_formats" && inputs+=("$1"); shift; continue ;;
    esac
    shift; shift
  done

  [ ${#inputs[@]} -eq 0 ] && log_kill "No input specified (use '$B--input/-i$N' or ${B}positional argument$N)" 2 1
  [[ "$cmd_options" == *b* && -z "$base_input" ]] && log_kill "Required option '$B--base-input/-b$N' is missing" 2 1

  mapfile -t inputs < <(parse_inputs "${formats:-$allowed_formats}" "$input_type" "${inputs[@]}")
  [ ${#inputs[@]} -gt 1 ] && mapfile -t inputs < <(deduplicate_array "${inputs[@]}")

  if [ ${#inputs[@]} -gt 1 ]; then
    output=$(batch_ignored "$output" '--output/-o')
    subs=$(batch_ignored "$subs" '--subs')
    hevc=$(batch_ignored "$hevc" '--hevc/-r')
    title=$(batch_ignored "$title" '--title')
  else
    [[ "$cmd_options" == *b* && "$base_input" == "${inputs[0]}" ]] && log_kill "${B}Input$N and '$B--base-input/-b$N' must be different files" 2 1
    [ "$skip_sync" = 1 ] && frame_shift=$(option_ignored "$frame_shift" '--frame-shift/-f' "has no effect when $B--skip-sync$N")
    [[ -n "$output" && "$clean_filenames" = 1 ]] && clean_filenames=$(option_ignored "$clean_filenames" '--clean-filenames/-m' "has no effect when $B--output$N is set")
    [[ -n "$title" ]] && title_auto=$(option_ignored "$title_auto" '--auto-title' "has no effect when $B--title$N is set")
    [[ "$rpu_raw" = 1 ]] && rpu_levels=$(option_ignored "$rpu_levels" '--rpu-levels/-l' "has no effect when $B--rpu_raw$N is set")
  fi

  [[ -n "$out_dir" ]] && OUT_DIR="$out_dir"
  [[ -n "$tmp_dir" ]] && TMP_DIR="$tmp_dir"
  [[ -n "$sample_duration" ]] && EXTRACT_SHORT_SEC="$sample_duration"
  [[ -n "$rpu_levels" ]] && RPU_LEVELS=$(deduplicate_list "$rpu_levels")
  [[ -n "$plot" ]] && INFO_L1_PLOT="$plot" && OPTIONS_PLOT_SET=1
  [[ -n "$info" ]] && INFO_INTERMEDIATE="$info"
  [[ -n "$find_subs" ]] && SUBS_AUTODETECTION="$find_subs"
  [[ -n "$copy_subs" ]] && SUBS_COPY_MODE="$copy_subs"
  [[ -n "$lang_codes" ]] && SUBS_LANG_CODES=$(deduplicate_list "$lang_codes")
  [[ -n "$copy_audio" ]] && AUDIO_COPY_MODE="$copy_audio"
  [[ -n "$title_auto" || -n "$title" ]] && TITLE_SHOWS_AUTO="${title_auto:-0}" && TITLE_MOVIES_AUTO="${title_auto:-0}"
  [[ -n "$tracks_auto" ]] && TRACK_NAMES_AUTO="$tracks_auto"
  [[ -n "$clean_filenames" || -n "$output" ]] && CLEAN_FILENAMES="${clean_filenames:-0}"

  tmp_trap

  for input in "${inputs[@]}"; do
    case "$cmd" in
    info) info "$input" "$sample" 0 0 ;;
    plot) plot_l1 "$input" "$sample" 0 "$output" ;;
    cuts) to_rpu_cuts "$input" "$sample" 0 "$output" 1 >/dev/null ;;
    extract) extract "$input" "$sample" "$output_format" "$output" >/dev/null ;;
    frame-shift) frame_shift "$input" "$base_input" >/dev/null ;;
    sync) sync_rpu "$input" "$base_input" "$frame_shift" 1 "$output" >/dev/null ;;
    inject) inject "$input" "$base_input" "$rpu_raw" "$skip_sync" "$frame_shift" "$output_format" "$output" "$subs" "$title" ;;
    subs) subs "$input" "$output" ;;
    remux) remux "$input" "$output_format" "$output" "$hevc" "$subs" "$title" ;;
    *) log "Unknown command: $cmd" 2; show_help; exit 1 ;;
    esac
  done
}

main() {
  [ $# -eq 0 ] && show_help && exit 0

  local -r cmd="$1"
  shift

  if [[ -v commands[$cmd] ]]; then
    parse_args "$cmd" "$@"
    exit 0
  fi

  case "$cmd" in
  -h | --help) show_help ;;
  -v | --version) version ;;
  *) log "Unknown command: $cmd" 2; show_help; exit 1 ;;
  esac

  exit 0
}

main "$@"
