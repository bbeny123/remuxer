#!/usr/bin/env bash

shopt -s expand_aliases

readonly N=$(tput sgr0) B=$(tput bold) U=$(tput smul)
readonly RED=$(tput setaf 1) YELLOW=$(tput setaf 3) BLUE=$(tput setaf 4)
readonly BU="$B$U"
readonly REMUXER="$B$(basename "$0")$N" VERSION="2.0.0"
readonly START_TIME=$(date +%s%1N)
readonly DEBUG_LOG='0'
readonly TOOLS_DIR="$(dirname -- "${BASH_SOURCE[0]}")/tools"

alias jq="'$TOOLS_DIR/jq-win64.exe'"                                       # v1.7.1:  https://jqlang.org/download/
alias mediainfo="'$TOOLS_DIR/MediaInfo.exe'"                               # v25.04:  https://mediaarea.net/pl/MediaInfo/Download
alias ffmpeg="'$TOOLS_DIR/ffmpeg.exe' -hide_banner -stats -loglevel error" # v7.1.1:  https://ffmpeg.org/download.html
alias mkvmerge="'$TOOLS_DIR/mkvtoolnix/mkvmerge.exe'"                      # v92.0:   https://mkvtoolnix.download/downloads.html
alias mkvextract="'$TOOLS_DIR/mkvtoolnix/mkvextract.exe'"                  #
alias dovi_tool="'$TOOLS_DIR/dovi_tool.exe'"                               # v2.3.0:  https://github.com/quietvoid/dovi_tool/releases
alias cm_analyze="'$TOOLS_DIR/cm_analyze.exe'"                             # v5.6.1:  https://customer.dolby.com/content-creation-and-delivery/dolby-vision-professional-tools
alias java="java"                                                          # v21.0.7: https://adoptium.net/temurin/releases?version=21&mode=filter&os=any&arch=any
alias sup2sub="java -jar '$TOOLS_DIR/BDSup2Sub.jar'"                       # v5.1.2:  https://raw.githubusercontent.com/wiki/mjuhasz/BDSup2Sub/downloads/BDSup2Sub.jar

OUT_DIR="$(pwd)"
PLOTS_DIR=""                     # <empty> - same as OUT_DIR
TMP_DIR="$(pwd)/temp$START_TIME" # caution: This dir will be removed only if it is created by the script
RPU_LEVELS="3,8,9,11,254"
INFO_INTERMEDIATE='1'            # 0 - disabled,       1 - enabled
PLOT_DEFAULT='L1,L2,L2_MAX,L8T'  # all,none,L1,L2,L2_600,L2_1000,L2_MAX,L8T,L8T_600,L8T_1000,L8T_MAX,L8S,L8S_600,L8S_1000,L8S_MAX,L8S,L8S_600,L8S_1000,L8S_MAX
FIX_CUTS_FIRST='1'               # 0 - disabled,       1 - enabled
FIX_CUTS_CONSEC='1'              # 0 - disabled,       1 - enabled
CLEAN_FILENAMES='1'              # 0 - disabled,       1 - enabled
SUBS_AUTODETECTION='1'           # 0 - disabled,       1 - enabled
TITLE_SHOWS_AUTO='0'             # 0 - disabled,       1 - enabled
TITLE_MOVIES_AUTO='1'            # 0 - disabled,       1 - enabled
TRACK_NAMES_AUTO='1'             # 0 - disabled,       1 - enabled [e.g., audio: DTS 5.1, subs: Polish]
AUDIO_COPY_MODE='3'              # 1 - 1st track only, 2 - 1st + compatibility, 3 - all
SUBS_COPY_MODE='1'               # 0 - none,           1 - all,                 <lng> - based on ISO 639-2 lang code [e.g., eng]
SUBS_LANG_CODES='all'            # <empty> - all,                               <lng> - based on ISO 639-2 lang code [e.g., eng]
TOPSUBS_LANG_CODES='all'         # <empty> - all,                               <lng> - based on ISO 639-2 lang code [e.g., eng]
TOPSUBS_MAX_OFFSET='600'
L1_TUNING='balanced'             # 0 - legacy,         1 - most,   2 - more,    3 - balanced,    4 - less,     5 - least
FFMPEG_STRICT=1                  # 0 - disabled,       1 - enabled
PRORES_PROFILE='3'
PRORES_MACOS='2'
EXTRACT_SHORT_SEC='23'

declare -A commands=(
  [info]="    Show Dolby Vision information                         | xtospu       | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [plot]="    Plot L1/L2/L8 metadata                                | xtosp        | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [shift]="   Calculate frame shift                                 | b            | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [sync]="    Synchronize Dolby Vision RPU files                    | bofnp        | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [fix]="     Fix or adjust Dolby Vision RPU(s)                     | xtojnFHS     | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [generate]="Generate Dolby Vision P8 RPU for HDR10 video(s)       | xtonpFGIP    | .mkv, .mp4, .m2ts, .ts, .hevc, .mov"
  [inject]="  Sync & Inject Dolby Vision RPU                        | boeqflwnmpFH | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [remux]="   Remux video file(s)                                   | xtoemr       | .mkv, .mp4, .m2ts, .ts"
  [extract]=" Extract RPU(s) or base layer(s), or convert to ProRes | xtosenpP     | .mkv, .mp4, .m2ts, .ts, .hevc"
  [cuts]="    Extract scene-cut frame list(s)                       | xtos         | .mkv, .mp4, .m2ts, .ts, .hevc, .bin"
  [subs]="    Extract .srt subtitles                                | tocm         | .mkv"
  [topsubs]=" Extract top-positioned PGS subtitles                  | xtscIY       | .mkv, .mp4, .m2ts, .ts, .sup, .pgs"
  [png]="     Extract video frame(s) as PNG image(s)                | xtok         | .mkv, .mp4, .m2ts, .ts"
  [mp3]="     Extract audio track(s) as MP3 file(s)                 | xtos         | .mkv, .mp4, .m2ts, .ts"
  [edl]="     Convert scene-cut list between .txt and .edl          | xtoI         | .txt, .edl"
)
declare -A cmd_description=(
  [shift]="Calculate frame shift of <input> relative to <base-input>"
  [sync]="Synchronize RPU of <input> to align with RPU of <base-input>"
  [inject]="Sync & Inject RPU of <input> into <base-input>"
  [extract]="Extract DV RPU(s) or .hevc base layer(s), or convert to ProRes (.mov)"
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
  [ "$1" = 'extract' ] && echo "hevc, bin, mov" && return

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
log_command() {
  logf "%s $1" "$B${BLUE}Executing:$N" "${@:2}"
}

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

relative_path() {
  local path="$1" relative_to="${2:-"$(pwd)"}"

  [ "$path" != "/" ] && path="${path%/}"
  [ "$relative_to" != "/" ] && relative_to="${relative_to%/}"

  [ "$path" = "$relative_to" ] && echo "." && return 0

  local appendix="${path##/}" relative
  while
    appendix="${path#"$relative_to"/}"
    [[ "$relative_to" != '/' && "$appendix" = "$path" ]]
  do

    [ "$relative_to" = "$appendix" ] && echo "${relative#/}" && return 0

    relative_to="${relative_to%/*}"
    relative="$relative/.."
  done

  echo "${relative#/}${relative:+${appendix:+/}}${appendix#/}"
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

out_base() {
  local output="$1" ext="${2#.}" suffix="$3"
  [[ -z "$output" ]] && return
  [[ "${output,,}" == *".${ext,,}" ]] && output="${output%.*}"
  echo "$output${suffix:+"-$suffix"}"
}

out_hybrid() {
  local input_name=$(filename "$1") input_base="$2" ext="$3" output="$4" fix="$5" raw_rpu="$6" prefix
  [ "$fix" = 1 ] && prefix="_FIXED"
  [ "$raw_rpu" != 1 ] && prefix+="-${RPU_LEVELS//[^0-9]/}"
  out_file "$input_base" "$ext" "HYBRID$prefix-$input_name" "$output"
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
  local input="$1"

  ! ffmpeg -loglevel info -i "$input" 2>&1 | grep -q 'Stream.*Video.*hevc' && return 1

  input=$(rpu_or_sample "$1" 1)
  ! dovi_tool info -s "$input" 2>&1 | grep -q 'No RPU found'
}

cm40_input() {
  local -r input=$(to_rpu "$1" 0 1)
  dovi_tool info -s "$input" | grep -q 'CM v4.0'
}

cm29_input() {
  local -r input=$(to_rpu "$1" 0 1)
  dovi_tool info -s "$input" | grep -q 'CM v2.9'
}

p7_input() {
  local -r input=$(rpu_or_sample "$1" 1)
  dovi_tool info -s "$input" 2>&1 | grep -q 'Profile: 7'
}

rpu_frames() {
  local input=$(to_rpu "$1" 0 1)
  dovi_tool info -s "$input" | grep -oE 'Frames:\s*[0-9]+' | grep -oE '[0-9]+'
}

to_prores() {
  local input="$1" short_sample="$2" output="$3" prefix='PRORES' type='ProRes' ffmpeg_cmd=()

  file_exists "$input" 'input' 1
  if check_extension "$input" ".mov"; then
    [ "$short_sample" = 1 ] && log_kill "Extracting ProRes sample from a ProRes file is not supported (input: '$input')" 2
    echo "$input" && return
  fi
  check_extension "$input" '.mkv .mp4 .m2ts .ts .hevc' 1

  [ "$short_sample" = 1 ] && type+=" sample" && prefix+="-${EXTRACT_SHORT_SEC}s"
  output=$(out_file "$input" 'mov' "$prefix" "$output")

  local -r input_name=$(basename "$input")
  log_t "Encoding '%s' to %s ..." "$input_name" "$type"

  if [[ ! -f "$output" ]]; then
    if ffmpeg -encoders 2>&1 | grep -q prores_videotoolbox; then
      ffmpeg_cmd+=(-c:v prores_videotoolbox -profile:v "$PRORES_MACOS")
    else
      ffmpeg_cmd+=(-c:v prores_ks -profile:v "$PRORES_PROFILE" -qscale:v 4 -vendor apl0 -pix_fmt yuv422p10le)
    fi
    [ "$short_sample" = 1 ] && ffmpeg_cmd+=(-t "$EXTRACT_SHORT_SEC")

    if ! ffmpeg -loglevel info -i "$input" 2>&1 | grep -q 'Video.*p10le(tv, bt2020nc/bt2020/smpte2084)'; then
      logf "%s '%s' is not HDR10, default color primaries (yuv420p10le/bt2020nc/bt2020/smpte2084) may be wrong - check input" "$(yellow 'Warning:')" "$input_name"
    fi

    log_command 'ffmpeg -i "%s" -map 0:v:0 -map_chapters -1 %s -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc -an "%s"' "$input_name" "${ffmpeg_cmd[*]}" "$(basename "$output")"
    if ! ffmpeg -i "$input" -map 0:v:0 -map_chapters -1 "${ffmpeg_cmd[@]}" -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc -an "$output" >&2; then
      log_kill "$(red 'Error:') Failed to encode '$input' to $type"
    fi

    log_t "Successfully encoded '%s' to %s - output file: '%s'" "$input_name" "$type" "$output"
  else
    logf "The ProRes file: '%s' already exists, skipping..." "$output"
  fi

  echo "$output"
}

to_hevc() {
  local input="$1" bl_only="$2" short_sample="$3" output="$4" out_dir="$5" prefix='HEVC' type='HEVC' ffmpeg_cmd=()

  file_exists "$input" 'input' 1
  [[ "$short_sample" != 1 && "$bl_only" != 1 ]] && check_extension "$input" ".hevc" && echo "$input" && return
  check_extension "$input" '.mkv .mp4 .m2ts .ts .hevc' 1

  [ "$FFMPEG_STRICT" = 1 ] && ffmpeg_cmd+=(-strict -2)
  [ "$bl_only" = 1 ] && prefix+="-BL_ONLY" && type+=" BL"

  if [ "$short_sample" = 1 ]; then
    prefix+="-${EXTRACT_SHORT_SEC}s"
    ffmpeg_cmd+=(-t "$EXTRACT_SHORT_SEC")
    type+=" sample"
  fi

  [ "$out_dir" = 1 ] && out_dir="$OUT_DIR" || out_dir="$TMP_DIR"
  output=$(generate_file "$out_dir" "$input" 'hevc' "$prefix" "$output")

  local -r input_name=$(basename "$input")
  log_t "Extracting %s for: '%s'..." "$type" "$input_name"

  if [[ ! -f "$output" ]]; then
    if [ "$bl_only" != 1 ]; then
      log_command 'ffmpeg -i "%s" -map 0:v:0 -c copy %s -f hevc "%s"' "$input_name" "${ffmpeg_cmd[*]}" "$(basename "$output")"
      ffmpeg -i "$input" -map 0:v:0 -c copy "${ffmpeg_cmd[@]}" -f hevc "$output" >&2
    elif check_extension "$input" ".hevc"; then
      log_command 'dovi_tool demux -b "%s" "%s"' "$(basename "$output")" "$input_name"
      dovi_tool demux -b "$output" -e "$(tmp_file "$input" 'hevc' "EL")" "$input" >&2
    else
      log_command 'ffmpeg -i "%s" -map 0:v:0 -c copy %s -f hevc - | dovi_tool demux -b "%s" -' "$input_name" "${ffmpeg_cmd[*]}" "$(basename "$output")"
      ffmpeg -i "$input" -map 0:v:0 -c copy "${ffmpeg_cmd[@]}" -f hevc - | dovi_tool demux -b "$output" -e "$(tmp_file "$input" 'hevc' "EL")" - >&2
    fi
    log_t "%s for: '%s' extracted - output file: '%s'" "$type" "$input_name" "$output"
  else
    logf "The HEVC file: '%s' already exists, skipping..." "$output"
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
    output=$(out_file "$input" 'bin' 'RPU' "$output")
  fi

  [ "$quiet" != 1 ] && log "Extracting $type for: '$input_name' ..." 1

  if [[ ! -f "$output" ]]; then
    [ "$quiet" = 1 ] && log "Extracting $type for: '$input_name' ..." 1

    if [ "$short_sample" != 1 ] && check_extension "$input" ".hevc"; then
      dovi_tool extract-rpu -o "$output" "$input" >/dev/null
    else
      if ! ffmpeg -i "$input" -map 0:v:0 -c copy "${ffmpeg_cmd[@]}" -f hevc - | dovi_tool extract-rpu -o "$output" - >/dev/null; then
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

rpu_or_sample() {
  local input="$1" quiet="${2:-1}" output

  file_exists "$input" 'input' 1
  check_extension "$input" ".bin" && echo "$input" && return

  output=$(out_file "$input" 'bin' 'RPU')
  [[ -f "$output" ]] && echo "$output" && return

  to_rpu "$input" 1 "$quiet"
}

extract() {
  local input="$1" short_sample="$2" output_format="$3" output="$4"
  [[ -z "$output_format" && "$output" == *.* ]] && output_format="${output##*.}"

  if [[ "${output_format,,}" == *hevc* ]]; then
    to_hevc "$input" 0 "$short_sample" "$output" 1 >/dev/null
  elif [[ "${output_format,,}" == *mov* ]]; then
    to_prores "$input" "$short_sample" "$output" >/dev/null
  else
    to_rpu "$input" "$short_sample" 0 "$output" 1 "$INFO_INTERMEDIATE" >/dev/null
  fi
}

to_rpu_cuts() {
  local input="$1" short_sample="$2" quiet="${3:-$2}" output="$4" direct="$5" prefix="CUTS" dir

  if check_extension "$input" ".txt"; then
    file_exists "$input" 'input' 1
    echo "$input"
    return
  fi

  [[ "$short_sample" = 1 && "$direct" = 1 ]] && check_extension "$input" ".bin" && short_sample=0

  local -r input_name=$(basename "$input")
  input=$(to_rpu "$input" "$short_sample" "$quiet")

  if [ "$short_sample" = 1 ]; then
    prefix+="-${EXTRACT_SHORT_SEC}s"
    [ "$direct" != 1 ] && dir="$TMP_DIR"
  fi
  output=$(generate_file "${dir:-"$OUT_DIR"}" "$input" 'txt' "$prefix" "$output")

  [ "$quiet" != 1 ] && log "Extracting scene-cuts for: '$input_name' ..." 1

  if [[ ! -f "$output" ]]; then
    dovi_tool export -i "$input" --data scenes="$output" >/dev/null

    [ "$quiet" != 1 ] && log "Scene-cuts for: '$input_name' extracted - output file: '$output'"
  elif [ "$quiet" != 1 ]; then
    log "The scene-cuts file: '$output' already exists, skipping..."
  fi

  echo "$output"
}

cut_frame() {
  local -r input="$1" frame="$2"

  grep -qE "(^|\s)$frame($|\s)" "$(to_rpu_cuts "$input" 0 1)"
}

plot_level_nits() {
  local rpu="$1" input_name="$2" level="$3" title="$4" subtitle="$5" output="$6" target_nits="$7" options

  case "${level,,}" in
  l8t) options+=("--plot-type" "l8") ;;
  l8s) options+=("--plot-type" "l8-saturation") ;;
  l8h) options+=("--plot-type" "l8-hue") ;;
  *) options+=("--plot-type" "${level,,}") ;;
  esac

  [ -n "$target_nits" ] && level+="_$target_nits" && subtitle+=" ($target_nits nits)" && options+=("--target-nits" "$target_nits")

  output=$(out_base "$output" 'png' "$level")
  output=$(generate_file "${PLOTS_DIR:-"$OUT_DIR"}" "$rpu" 'png' "$level" "$output")

  log_t "Plotting %s metadata for: '%s' ..." "$subtitle" "$input_name"

  if [[ ! -f "$output" ]]; then
    if dovi_tool plot -i "$rpu" -o "$output" -t "$subtitle – $title" "${options[@]}" >/dev/null; then
      logf "%s metadata for: '%s' plotted - output file: '%s'" "$subtitle" "$input_name" "$output"
    else
      log_b "$(red 'Error:') Failed to plot %s metadata for '%s' , skipping..." "$subtitle" "$input_name"
    fi
  else
    logf "The %s plot file: '%s' already exists, skipping..." "$subtitle" "$output"
  fi
}

plot_level() {
  local rpu="$1" input_name="$2" verbose="$3" plots=" $4 " level="$5" title="$6" subtitle="$7" output="$8" trims="$9" cm4="${10}" target_nits

  [[ "$plots" != " lx " && "$plots" != *"${level,,}"* ]] && return

  if [[ "$level" == *L8* && "$cm4" != 1 ]]; then
    [ "$verbose" = 1 ] && log_t "Cannot plot %s for: '%s' - CM v4.0 RPU is required, skipping" "$subtitle" "$input_name"
    return
  fi

  if [[ "$level" == *L1* ]]; then
    plot_level_nits "$rpu" "$input_name" "$level" "$title" "$subtitle" "$output"
    return
  fi

  plots=${plots//" ${level,,} "/" ${level,,}_100 "}
  for target_nits in 100 600 1000; do
    [[ "$plots" != " lx " && "$plots" != *" ${level,,}_$target_nits "* ]] && continue

    if [[ "$trims" != *"$target_nits "* ]]; then

      [ "$verbose" = 1 ] && log_t "Cannot plot %s for: '%s' - RPU doesn't contain metadata for %s nits target, skipping" "$subtitle" "$input_name" "$target_nits"
      continue
    fi

    plot_level_nits "$rpu" "$input_name" "$level" "$title" "$subtitle" "$output" "$target_nits"
  done
}

plot_max_target() {
  local trims="$1" prefix="$2" max
  [[ -n "$trims" ]] && max=$(grep -oE "100|600|1000" <<<"$trims" | sort -nu | tail -n 1)
  [[ -n "$max" ]] && echo "$prefix$max"
}

plot() {
  local input="$1" short_sample="$2" verbose="$3" summary="$4" output="$5" direct="$6" plots="$PLOT_DEFAULT"
  local rpu input_name title l2_trims l8_trims cm4

  if [[ -z "$plots" || " $plots " =~ [[:space:]](0|none)[[:space:]] ]]; then
    [ "$direct" = 1 ] && log_kill "Nothing to plot: $B--plot$N is set to$B none$N or$B 0$N" 2 || return
  fi

  rpu=$(to_rpu "$input" "$short_sample" "$verbose")
  input_name=$(basename "$input") && title="$input_name"
  [ "$short_sample" = 1 ] && ! check_extension "$input" '.bin' && title+=" (sample duration: ${EXTRACT_SHORT_SEC}s)"

  [[ " $plots " =~ [[:space:]](1|all)[[:space:]] ]] && plots="lx"

  if [[ "$plots" =~ lx|l2|l8 ]]; then
    [ -z "$summary" ] && summary=$(dovi_tool info -s "$rpu" 2>&1)

    [[ "$plots" =~ lx|l2 ]] && l2_trims=$(grep -i 'L2 trims' <<<"$summary")
    [[ "$plots" == *l2_max* ]] && plots="${plots//l2_max/"$(plot_max_target "$l2_trims" "l2_")"}"

    if [[ "$plots" =~ lx|l8 ]]; then
      l8_trims=$(grep -i 'L8 trims' <<<"$summary")
      grep -q 'CM v4.0' <<<"$summary" && cm4=1
      [[ -n "$l8_trims" && "$plots" == *max* ]] && plots="${plots//max/"$(plot_max_target "$l8_trims")"}"
    fi

    [ "$plots" = 'lx' ] && verbose=0
  fi

  plot_level "$rpu" "$input_name" "$verbose" "$plots" 'L1' "$title" 'L1 Dynamic Brightness' "$output"
  plot_level "$rpu" "$input_name" "$verbose" "$plots" 'L2' "$title" 'L2 Trims' "$output" "$l2_trims"
  plot_level "$rpu" "$input_name" "$verbose" "$plots" 'L8T' "$title" 'L8 Trims' "$output" "$l8_trims" "$cm4"
  plot_level "$rpu" "$input_name" "$verbose" "$plots" 'L8S' "$title" 'L8 Saturation Vectors' "$output" "$l8_trims" "$cm4"
  plot_level "$rpu" "$input_name" "$verbose" "$plots" 'L8H' "$title" 'L8 Hue Vectors' "$output" "$l8_trims" "$cm4"
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

printf_info() {
  printf_safe "  $1\n" "${@:2}"
}

info_summary() {
  local input="$1" short_sample="$2" summary dv_profile base_layer resolution lossless_audio cuts_zero cuts_cons cuts_end_cons
  local -r rpu=$(to_rpu "$input" "$short_sample")

  summary=$(dovi_tool info -s "$rpu" | grep -E '^ ')
  summary=${summary//"top=0,"/"top=$(yellow 0),"}
  summary=${summary//"bottom=0,"/"bottom=$(yellow 0),"}
  summary=${summary//"N/A"/"$(yellow 'N/A')"}

  dv_profile=$(echo "$summary" | grep 'Profile' | grep -oE '[0-9]+')
  IFS='|' read -r base_layer resolution lossless_audio < <(video_info "$input" "$dv_profile")

  local -r rpu_cuts=$(to_rpu_cuts "$rpu" "$short_sample" 1)
  { read -r cuts_cons; read -r cuts_zero; } < <(rpu_info_cuts "$rpu_cuts" 1 2 '2nd')
  [ "$short_sample" != 1 ] && read -r cuts_end_cons < <(rpu_info_cuts "$rpu_cuts" -1 -2)

  printf "\nRPU Input: %s%s\n" "$(basename "$rpu")" "$(printf_if "$short_sample" " (sample duration: ${EXTRACT_SHORT_SEC}s)")"

  echo "$summary"

  printf_info "1st Frame is a Scene Cut: %s" "$cuts_zero"
  printf_info "Consecutive Scene Cuts: %s" "$cuts_cons"
  printf_info "Consecutive Last Scene Cuts: %s" "$cuts_end_cons"

  [[ -z "$base_layer" && -z "$resolution" && -z "$lossless_audio" ]] && return

  printf_info "Base Layer: %s" "$base_layer"
  printf_info "Lossless audio tracks: %s" "$lossless_audio"
  printf_info "Resolution/FPS: %s" "$resolution"
  printf_info "Video Input: %s" "$(basename "$input")"
}

info_frames() {
  local input="$1" short_sample="$2" frames="$3" output="$4" frame frame_info result
  input=$(to_rpu "$input" "$short_sample")

  for frame in ${frames//,/ }; do
    ! frame_info=$(dovi_tool info -i "$input" -f "$frame") && log_kill "Error while getting info for frame '$frame'" 2
    result+=$(printf '"%s": %s,' "$frame" "$(echo "$frame_info" | tail -n +2)")
  done
  result="{ ${result%,} }"

  [ -n "$output" ] && echo "$result" | jq . >"$output"
  echo "" && echo "$result" | jq .
}

info() {
  local input="$1" short_sample="$2" short_input="$3" frames="$4" output="$5" batch="$6" explicit_plot="$7" summary
  local input_name=$(basename "$input") type='Info' ext='txt'

  if ! check_extension "$input" '.mkv .mp4 .m2ts .ts .hevc .bin'; then
    log_t "Cannot print info for '%s' (unsupported file format), skipping..." "$input_name"
    return
  fi

  [[ "$short_sample" = 1 && "$short_input" != 1 ]] && check_extension "$input" '.bin' && short_sample=0

  [ -n "$frames" ] && type="Info (frame(s): $frames)" && ext='json'

  if [ -n "$output" ]; then
    output=$(out_file "$input" "$ext" '' "$output")
    [ "$batch" = 1 ] && output="${output%.*}_${input_name%.*}.$ext"
  fi

  log_t "Printing %s for: '%s' ..." "${type,,}" "$input_name"

  if [ -n "$frames" ]; then
    info_frames "$input" "$short_sample" "$frames" "$output"
  else
    summary=$(info_summary "$input" "$short_sample")
    log "$summary"
    [ -n "$output" ] && echo "$summary" >"$output"
  fi

  [ -n "$output" ] && log_t "%s successfully printed to file: '%s'" "$type" "$output"

  [ "$explicit_plot" != 1 ] && [[ "$short_sample" = 1 || -n "$frames" ]] && return
  plot "$input" "$short_sample" 0 "$summary"
}

png() {
  local input="$1" timestamps="$2" output="$3" ffmpeg_cmd=() base_output timestamped_output timestamp duration

  log_t "Extracting frame(s) as PNG for: '%s' ..." "$(basename "$input")"

  if [ -z "$timestamps" ]; then
    duration=$(mediainfo "$input" --Inform="Video;%Duration%") && duration=$((${duration%%.*} / 1000))

    if ((duration > 1800)); then # 30 minutes
      timestamps="$((duration / 4)),$((duration * 2 / 4)),$((duration * 3 / 4))"
    elif ((duration > 600)); then # 10 minutes
      timestamps="$((duration / 3)),$((duration * 2 / 3))"
    else
      timestamps="$((duration / 2))"
    fi
  fi

  [[ -z "$output" || "$timestamps" == *,* ]] && timestamped_output=1
  output=$(out_file "$input" "png" 'FRAME' "$output") && base_output="${output%.*}"

  if ffmpeg -loglevel info -i "$input" 2>&1 | grep -q 'Video:.*smpte2084'; then
    if ffmpeg -filters | grep -q zscale; then
      ffmpeg_cmd+=(-vf "zscale=t=linear,tonemap=hable")
    else
      logf "%s HDR10 input '%s' detected, but ffmpeg lacks zscale support. Colors may appear incorrect." "$(yellow 'Warning:')" "$(basename "$input")"
    fi
  fi

  for timestamp in ${timestamps//,/ }; do
    [ "$timestamped_output" = 1 ] && output="${base_output}_${timestamp//:/}.png"
    log_t "Extracting frame at approx. %s%s to '%s'. .." "$timestamp" "${duration:+s}" "$(basename "$output")"
    [[ -e "$output" ]] && logf "Output file '%s' already exists, skipping..." "$output" && continue

    ffmpeg -ss "$timestamp" -i "$input" -map_metadata -1 -map_chapters -1 -vframes 1 "${ffmpeg_cmd[@]}" -update 1 "$output"
  done

  log_t "Frame(s) successfully extracted"
}

mp3() {
  local input="$1" short_sample="$2" output="$3" fixed_output="${3:+1}" prefix suffix audio_info id format ffmpeg_mappings=()
  local -r input_name=$(basename "$input")

  log_c "Extracting audio track(s) as MP3 for: '%s' ..." "$input_name"

  audio_info=$(audio_info "$input")
  output=$(out_file "$input" "mp3" '' "$output") && prefix="$(dirname "$output")/" && suffix="$(basename "$output")"

  if [ "$fixed_output" = 1 ]; then
    prefix+="${suffix%.*}" && suffix=""
    [[ "$(echo "$audio_info" | wc -l)" -gt 1 ]] && fixed_output=''
  else
    prefix+="AUDIO" && suffix="_${suffix%.*}"
    [ "$short_sample" = 1 ] && suffix+="_${EXTRACT_SHORT_SEC}s"
  fi

  while IFS='|' read -r id format; do
    if [ -z "$fixed_output" ]; then
      output="${prefix}_${id}_"
      output+=$(echo "${format// /-}" | tr -cd 'a-zA-Z0-9_-')
      output+="${suffix}.mp3"
    fi

    logf "Mapping track #%s (%s) -> '%s'" "$id" "$format" "$output"
    [[ -e "$output" ]] && log_b "Output file '%s' already exists, skipping..." "$output" && continue

    ffmpeg_mappings+=(-map "0:$id" -c:a libmp3lame -q:a 2)
    [ "$short_sample" = 1 ] && ffmpeg_mappings+=(-t "$EXTRACT_SHORT_SEC")
    ffmpeg_mappings+=("$output")
  done <<<"$audio_info"

  if [ "${#ffmpeg_mappings[@]}" -gt 0 ]; then
    ffmpeg -i "$input" "${ffmpeg_mappings[@]}" && log_t "Audio track(s) for '%s' successfully extracted" "$input_name"
  else
    logf "No audio tracks to extract for '%s', skipping...." "$input_name"
  fi
}

txt_to_edl() {
  local input="$1" fps="$2" frames=() frame

  mapfile -t frames <"$input"

  for frame in "${frames[@]}"; do
    [[ ! "$frame" =~ ^[0-9]*$ ]] && logf "Detected a non-numeric value: '%s', aborting..." "$frame" && return 1
  done

  awk -v fps="$fps" '
  function frame_to_timecode(frame, fps) {
    seconds = int(frame / fps)
    hh = int(seconds / 3600)
    mm = int((seconds % 3600) / 60)
    ss = int(seconds % 60)
    ff = int(frame % fps)
    return sprintf("%02d:%02d:%02d:%02d", hh, mm, ss, ff)
  }

  BEGIN { count = 0 }

  { if (NF > 0 && $1 != "") frames[count++] = $1 }

  END {
    if (count < 2) exit 1

    print "TITLE: Scene Cuts"
    print "FCM: NON-DROP FRAME"
    print ""

    current_frame = frame_to_timecode(frames[0], fps)

    for (i = 1; i < count; i++) {
      if (frames[i] == "") exit 1
      next_frame = frame_to_timecode(frames[i], fps)
      printf "%04d  001      V     C        %s %s %s %s  \n", i, current_frame, next_frame, current_frame, next_frame
      current_frame = next_frame
    }
  }' "$input"
}

edl_to_txt() {
  local input="$1" fps="$2"

  awk -v fps="$fps" '
  function timecode_to_frame(timecode, fps) {
    split(timecode, p, ":")
    return (p[1] * 3600 + p[2] * 60 + p[3]) * fps + p[4]
  }

  /^[0-9]+.*[A-Z]+.*[A-Z]+/ {
    print timecode_to_frame($5, fps)
    last = $6
  }

  END {
    if (last) print timecode_to_frame(last, fps)
  }' "$input"
}

edl() {
  local input="$1" fps="${2:-"24"}" output="$3" ext='txt' prefix='FROM_EDL' result

  [[ "$fps" =~ \.0{1,5}$ ]] && fps="${fps%%.*}"

  case "$fps" in
  '23.976' | '23.98' | '24000/1001') fps=24 ;;
  *[/.]* | 0) log_kill "Unsupported $B--fps$N value: $fps" ;;
  esac

  check_extension "$input" ".txt" && ext='edl' && prefix='EDL'
  prefix+="_${fps}"

  log_t "Converting '%s' to .%s (FPS: %s)" "$(basename "$input")" "$ext" "$fps"

  output=$(out_file "$input" "$ext" "$prefix" "$output")
  [[ -e "$output" ]] && logf "Output file '%s' already exists, skipping..." "$output" && return 1

  if [ "$ext" = 'txt' ]; then
    result=$(edl_to_txt "$input" "$fps") || return 1
  else
    result=$(txt_to_edl "$input" "$fps") || return 1
  fi

  echo "$result" >"$output"

  logf "Conversion to .%s completed successfully — output file: '%s'" "$ext" "$output"
}

l6_mdl_safe() {
  local mdl_min="$1" mdl_max="$2"

  if ((mdl_min == 0 && mdl_max == 0)); then
    mdl_min=1 && mdl_max=1000
  elif ((mdl_min == 0)); then
    ((mdl_max == 4000)) && mdl_min=50 || mdl_min=1
  elif ((mdl_max == 0)); then
    ((mdl_min == 50)) && mdl_max=4000 || mdl_max=1000
  fi

  echo "$mdl_min,$mdl_max"
}

rpu_l6_from_l1() {
  local rpu=$(rpu_or_sample "$1") mdl_min="$2" mdl_max="$3" l1 max_cll=0 max_fall=0

  l1=$(dovi_tool info -s "$rpu" 2>&1 | grep 'RPU content light level')

  [[ "$l1" =~ (MaxCLL: ([0-9]+)) ]] && max_cll=$((10#${BASH_REMATCH[2]}))
  [[ "$l1" =~ (MaxFALL: ([0-9]+)) ]] && max_fall=$((10#${BASH_REMATCH[2]}))

  ((max_cll == 0 && max_fall == 0)) && echo "0,0,0,0" && return
  ((mdl_min == 0 && mdl_max == 0 && max_cll >= 2000)) && mdl_max=4000

  echo "$(l6_mdl_safe "$mdl_min" "$mdl_max"),$max_cll,$max_fall"
}

rpu_l6() {
  local rpu=$(rpu_or_sample "$1") l6 mdl_min=0 mdl_max=0 max_cll=0 max_fall=0

  l6=$(dovi_tool info -s "$rpu" 2>&1 | grep 'L6 metadata')

  if [[ "$l6" =~ ([0-9]+)/([0-9]+) ]]; then
    mdl_min=$((10#${BASH_REMATCH[1]}))
    mdl_max=$((10#${BASH_REMATCH[2]}))
  fi

  [[ "$l6" =~ (MaxCLL: ([0-9]+)) ]] && max_cll=$((10#${BASH_REMATCH[2]}))
  [[ "$l6" =~ (MaxFALL: ([0-9]+)) ]] && max_fall=$((10#${BASH_REMATCH[2]}))

  echo "$mdl_min,$mdl_max,$max_cll,$max_fall"
}

video_l6() {
  local input="$1" mdl mdl_min=0 mdl_max=0 max_cll=0 max_fall=0
  check_extension "$input" ".bin" && echo "0,0,0,0" && return

  IFS='|' read -r mdl max_cll max_fall < <(mediainfo "$input" --Inform='Video;%MasteringDisplay_Luminance%|%MaxCLL%|%MaxFALL%\n' | tr -d '\r')

  [[ "$mdl" =~ (min: [0-9]+\.([0-9]+)) ]] && mdl_min=$((10#${BASH_REMATCH[2]}))
  [[ "$mdl" =~ (max: ([0-9]+)) ]] && mdl_max=$((10#${BASH_REMATCH[2]}))
  [[ "$max_cll" =~ ^([0-9]+) ]] && max_cll=$((10#${BASH_REMATCH[1]}))
  [[ "$max_fall" =~ ^([0-9]+) ]] && max_fall=$((10#${BASH_REMATCH[1]}))

  echo "$mdl_min,$mdl_max,$max_cll,$max_fall"
}

detect_l6() {
  local input="$1" video_l6="$2" mdl="${3:-"0,0"}" l6="$4" fallback="$5" mdl_min mdl_max max_cll max_fall
  [ -n "$l6" ] && echo "$l6" && return

  [ "$video_l6" = 1 ] && l6=$(video_l6 "$input") || l6=$(rpu_l6 "$input")
  if [ "$l6" = '0,0,0,0' ] || [[ "$mdl," != '0,0,' && "$l6" != "$mdl,"* ]]; then
    echo "|$fallback" && return
  fi

  IFS=',' read -r mdl_min mdl_max max_cll max_fall <<<"$l6"
  ((mdl_min != 0 && mdl_max != 0 && max_cll != 0 && max_fall != 0)) && echo "$l6" && return

  [ -z "$fallback" ] && ((max_cll != 0 && max_fall != 0)) && fallback="$(l6_mdl_safe "$mdl_min" "$mdl_max"),$max_cll,$max_fall"

  echo "|$fallback"
}

forced_l6() {
  local input="$1" l6="$2" l6_source="$3" l6_source2="$4" mdl_min="$5" mdl_max="$6" max_cll max_fall t
  IFS=',' read -r max_cll max_fall t <<<"$l6"

  if ((mdl_min == 0 && mdl_max == 0)); then
    IFS=',' read -r mdl_min mdl_max t < <(video_l6 "$input")

    if ((mdl_min == 0 && mdl_max == 0)) && [ -n "$l6_source" ]; then
      IFS=',' read -r mdl_min mdl_max t < <(rpu_l6 "$l6_source")
      ((mdl_min == 0 && mdl_max == 0)) && IFS=',' read -r mdl_min mdl_max t < <(video_l6 "$l6_source")
    fi

    if ((mdl_min == 0 && mdl_max == 0)) && [ -n "$l6_source2" ]; then
      IFS=',' read -r mdl_min mdl_max t < <(rpu_l6 "$l6_source2")
      ((mdl_min == 0 && mdl_max == 0)) && IFS=',' read -r mdl_min mdl_max t < <(video_l6 "$l6_source2")
    fi
  fi

  echo "$(l6_mdl_safe "$mdl_min" "$mdl_max"),$max_cll,$max_fall"
}

forced_l6_source() {
  local l6_source="$1" default_mdl_min="$2" default_mdl_max="$3" l6 fallback mdl_min mdl_max max_cll max_fall

  check_extension "$l6_source" '.mov' || IFS='|' read -r l6 fallback < <(detect_l6 "$l6_source" 0)
  IFS='|' read -r l6 fallback < <(detect_l6 "$l6_source" 1 "" "$l6" "$fallback")
  [ -z "$l6" ] && l6="$fallback"
  [ -z "$l6" ] && log_t "%s $B--l6-source$N contains invalid L6 metadata, skipping" "$(yellow 'Warning:')" && return

  IFS=',' read -r mdl_min mdl_max max_cll max_fall <<<"$l6"
  ((mdl_min == 0 && mdl_max == 0)) && mdl_min="$default_mdl_min" && mdl_max="$default_mdl_max"

  echo "$(l6_mdl_safe "$mdl_min" "$mdl_max"),$max_cll,$max_fall"
}

to_l6() {
  local rpu="$1" input="$2" l6="$3" l6_source="$4" l6_source2="$5" mdl_min mdl_max max_cll max_fall fallback

  IFS=',' read -r mdl_min mdl_max max_cll max_fall < <(rpu_l6 "$rpu")

  [[ -n "$l6_source" && -z "$l6" && -z "$l6_source2" ]] && forced_l6_source "$l6_source" "$mdl_min" "$mdl_max" && return
  [ -n "$l6" ] && forced_l6 "$input" "$l6" "$l6_source" "$l6_source2" "$mdl_min" "$mdl_max" && return

  ((mdl_min != 0 && mdl_max != 0 && max_cll != 0 && max_fall != 0)) && return

  IFS='|' read -r l6 fallback < <(detect_l6 "$input" 1 "$mdl_min,$mdl_max")

  if [[ -z "$l6" && -n "$l6_source" ]]; then
    IFS='|' read -r l6 fallback < <(detect_l6 "$l6_source" 0 "$mdl_min,$mdl_max" "$l6" "$fallback")
    IFS='|' read -r l6 fallback < <(detect_l6 "$l6_source" 1 "$mdl_min,$mdl_max" "$l6" "$fallback")
  fi

  if [[ -z "$l6" && -n "$l6_source2" ]]; then
    IFS='|' read -r l6 fallback < <(detect_l6 "$l6_source2" 0 "$mdl_min,$mdl_max" "$l6" "$fallback")
    IFS='|' read -r l6 fallback < <(detect_l6 "$l6_source2" 1 "$mdl_min,$mdl_max" "$l6" "$fallback")
  fi

  [ -n "$l6" ] && echo "$l6" && return
  ((max_cll != 0 && max_fall != 0)) && echo "$(l6_mdl_safe "$mdl_min" "$mdl_max"),$max_cll,$max_fall" && return
  [ -n "$fallback" ] && echo "$fallback" && return
  rpu_l6_from_l1 "$rpu" "$mdl_min" "$mdl_max"
}

fix_rpu_l6() {
  local rpu="$1" input="$2" l6="$3" l6_source="$4" l6_source2="$5" mdl_min mdl_max max_cll max_fall

  IFS=',' read -r mdl_min mdl_max max_cll max_fall < <(to_l6 "$rpu" "$input" "$l6" "$l6_source" "$l6_source2")
  ((mdl_min == 0 || mdl_max == 0)) && return

  printf '"level6": { "min_display_mastering_luminance": %s, "max_display_mastering_luminance": %s, "max_content_light_level": %s, "max_frame_average_light_level": %s }' "$mdl_min" "$mdl_max" "$max_cll" "$max_fall"
}

fix_rpu_l5() {
  local l5="$1" l5_config="$2" top bottom left right config
  [[ -z "$l5" && -z "$l5_config" ]] && return

  if [ -n "$l5_config" ]; then
    config=$(jq 'del(.crop, .drop_l5)' "$l5_config" -c)
  else
    IFS=',' read -r top bottom left right <<<"$l5"
    config=$(printf '{ "presets": [ { "id": 0, "top": %s, "bottom": %s, "left": %s, "right": %s } ], "edits": { "all": 0 } }' "$top" "$bottom" "${left:-0}" "${right:-0}")
  fi

  printf '"active_area": %s,' "$config"
}

fix_rpu_cuts_consecutive() {
  local start="$1" end="$2" type="$3"

  ((start >= end - 1)) && return

  logf "%s consecutive scene-cuts at the %s detected, preparing fix..." "$((end - start + 1))" "$type"
  ((end - start > 99)) && logf "%s Large number of consecutive scene-cuts detected — make sure fixing is intended" "$(yellow 'Warning:')"

  printf '"%s-%s": false,' "$((start + 1))" "$((end - 1))"
}

fix_rpu_cuts() {
  local rpu="$1" cuts_clear="$2" json="$3" quiet="$4" cuts=() cut config range
  [ -n "$json" ] && quiet=1

  [ -n "$cuts_clear" ] && for range in ${cuts_clear//,/ }; do
    [[ "$range" != *-* ]] && range+="-$range"
    config+=$(printf '"%s": false,' "$range")
  done

  [[ "$FIX_CUTS_FIRST" != 1 && "$FIX_CUTS_CONSEC" != 1 ]] && echo "$config" && return

  mapfile -t cuts <"$(to_rpu_cuts "$rpu" "${json:+1}" "$quiet")"
  logf ""

  if [[ "$FIX_CUTS_FIRST" = 1 && "${cuts[0]}" != 0 ]]; then
    logf "First frame is not a scene-cut, preparing fix..."
    config+='"0-0": true,'
  fi

  [ "$FIX_CUTS_CONSEC" != 1 ] && echo "$config" && return
  [ ${#cuts[@]} -eq 0 ] && logf "No scene-cuts found, skipping consecutive scene-cut fixes..." && echo "$config" && return

  local -i start="${cuts[0]}" end="${cuts[-1]}" i

  i="$start" && for cut in "${cuts[@]}"; do
    ((cut != i++)) && ((i--)) && break
  done
  [[ "$start" = 1 && "$FIX_CUTS_FIRST" = 1 ]] && start=0
  config+=$(fix_rpu_cuts_consecutive "$start" "$((i - 1))" 'start')

  i="$end" && for ((cut = ${#cuts[@]} - 1; cut >= 0; cut--)); do
    ((cuts[cut] != i--)) && ((i++)) && break
  done
  config+=$(fix_rpu_cuts_consecutive "$((i + 1))" "$end" 'end')

  echo "$config"
}

fix_rpu_raw() {
  local rpu="$1" json="$2" raw_edited
  [ -z "$json" ] && echo "$rpu" && return

  log_c "Applying raw JSON config: '%s'..." "$(basename "$json")"

  raw_edited=$(tmp_file "$rpu" "bin" 'RAW_EDITED')
  [[ -e "$raw_edited" ]] && log_b "Output file '%s' already exists, skipping..." "$raw_edited" && echo "$rpu" && return

  ! dovi_tool editor -j "$json" -o "$raw_edited" "$rpu" >&2 && log_kill "Failed to apply raw JSON config for '$(basename "$rpu")'" 2

  log_t "Raw JSON config successfully applied"
  echo "$raw_edited"
}

fix_rpu() {
  local input="$1" quiet="${2:-1}" cuts_clear="$3" l5="$4" l6="$5" l5_config="$6" l6_source="$7" json="$8" output="$9" l6_source2="${10}"
  local input_rpu rpu rpu_name config plot

  input_rpu=$(to_rpu "$input" 0 "$quiet") && rpu_name=$(basename "$input_rpu")
  output=$(out_file "$input_rpu" "bin" 'FIXED' "$output")

  log_t "Fixing RPU: '%s' ..." "$rpu_name"
  [[ -e "$output" ]] && logf "Fixed RPU file '%s' already exists, skipping..." "$output" && echo "$output" && return

  rpu=$(fix_rpu_raw "$input_rpu" "$json")

  config="$(fix_rpu_cuts "$rpu" "$cuts_clear" "$json" "$quiet")"
  [ -n "$config" ] && config=$(printf '"scene_cuts": { %s },' "${config%%,}")

  config+=$(fix_rpu_l5 "$l5" "$l5_config")
  config+=$(fix_rpu_l6 "$rpu" "$input" "$l6" "$l6_source" "$l6_source2")

  [[ -z "$config" && -z "$json" ]] && logf "Nothing to fix — skipping..." && echo "$rpu" && return

  if [ -z "$config" ]; then
    mv "$rpu" "$output"
    logf "No auto-fixable issues found, skipping..."
  else
    log_b "Applying RPU fixes..."

    json="$(tmp_file "$rpu" "bin" 'FIX_CONFIG')"
    printf '{ %s }' "${config%%,}" >"$json"

    ! dovi_tool editor -j "$json" -o "$output" "$rpu" >&2 && log_kill "Failed to apply RPU fixes for '$rpu_name'" 2
  fi

  log_t "RPU: '%s' fixed successfully - output: '%s'" "$rpu_name" "$(basename "$output")"

  if [[ "$quiet" != 1 && "$INFO_INTERMEDIATE" = 1 ]]; then
    plot="$PLOT_DEFAULT" && PLOT_DEFAULT=0
    info "$input_rpu" >&2
    info "$output" >&2
    PLOT_DEFAULT="$plot"
  fi

  echo "$output"
}

fix_rpu_examples() {
  local output="$1" example='{
    "active_area": {
      "presets": [
        { "id": 0, "top": 270, "bottom": 270, "left": 0, "right": 0 },
        { "id": 1, "top": 130, "bottom": 130, "left": 0, "right": 0 }
      ],
      "edits": { "all": 0, "150-300": 1 }
    },
    "scene_cuts": { "all": true, "0-39": false },
    "level6": {
        "max_display_mastering_luminance": 4000,
        "min_display_mastering_luminance": 50,
        "max_content_light_level": 1234,
        "max_frame_average_light_level": 300
    }
  }'

  echo "$example" | jq .
  log_t "For more examples and information, visit: https://github.com/quietvoid/dovi_tool/blob/main/docs/editor.md"

  [ -z "$output" ] && return || output=$(out_file "$input" "json" '' "$output")

  log_t "Saving JSON config example to '%s'..." "$(basename "$output")"
  [[ -e "$output" ]] && logf "Output file '%s' already exists, skipping..." "$output" && return

  echo "$example" | jq . >"$output"
  logf "JSON config example saved to '%s'" "$output"
}

mdl_fps() {
  local input="$1" mdl="$2" fps="$3" info_fps info_fps_org info_mdl

  IFS='|' read -r info_fps info_fps_org info_mdl < <(mediainfo "$input" --Inform='Video;%FrameRate_Num%/%FrameRate_Den%|%FrameRate_Original_Num%/%FrameRate_Original_Den%|%MasteringDisplay_ColorPrimaries% %MasteringDisplay_Luminance%\n' | tr -d '\r')

  if [ -z "$mdl" ]; then
    case "$info_mdl" in
    *'max: 1000'*) mdl=20 ;;
    *'max: 2000'*) mdl=30 ;;
    *'max: 4000'*) mdl=7 ;;
    *) mdl=0 ;;
    esac

    [[ "$info_mdl" == *'2020'* ]] && ((mdl++))

    if ((mdl > 6)); then
      logf "Detected input MDL: %s" "$mdl"
    else
      logf "%s Failed to auto-detect MDL, skipping..." "$(yellow 'Warning:')" && return
    fi
  fi

  if [ -z "$fps" ]; then
    [[ -z "$info_fps" || "$info_fps" = "/" ]] && info_fps="$info_fps_org"

    fps="${info_fps%"/1"}" && fps="${fps%"/"}"

    if [ -n "$fps" ]; then
      logf "Detected input FPS: %s" "$fps"
    else
      logf "%s Failed to auto-detect FPS, skipping..." "$(yellow 'Warning:')" && return
    fi
  fi

  echo "$mdl|$fps"
}

parse_l5() {
  local l5="$1"

  [[ -z "$l5" || ! -e "$l5" || ! -s "$l5" ]] && return

  if [ "$(grep -c '"id"' "$l5")" -eq 1 ]; then
    jq -r '.presets[0] | "\(.top),\(.bottom),\(.left),\(.right)"' "$l5"
  else
    echo "file:$l5"
  fi
}

scene_cuts_l5() {
  local input="$1" scene_cuts="$2" l5="$3" variable_l5="$4" mov_input="$5" cuts_output l5_output

  [[ -n "$variable_l5" ]] && l5=$(parse_l5 "$variable_l5")

  if [ "$mov_input" != 1 ] && [[ -z "$scene_cuts" || -z "$l5" ]]; then
    input=$(to_rpu "$input" 0 1)
    cuts_output=$(tmp_file "$input" 'txt' 'CUTS')
    l5_output=$(tmp_file "$input" 'json' 'L5')

    dovi_tool export -i "$input" --data scenes="$cuts_output" --data level5="$l5_output" >/dev/null

    [[ -z "$scene_cuts" || ! -s "$scene_cuts" ]] && scene_cuts="$cuts_output"
    [[ -z "$l5" ]] && l5=$(parse_l5 "$l5_output")
  fi

  [[ -z "$scene_cuts" || ! -s "$scene_cuts" ]] && logf "%s Failed to extract scene-cuts from input, skipping..." "$(yellow 'Warning:')" && return
  [[ -z "$l5" ]] && l5="0,0,0,0"

  echo "$scene_cuts"
  echo "$l5"
}

fix_scene_cuts() {
  local prores="$1" scene_cuts="$2" frames cuts_output cuts_temp
  check_extension "$scene_cuts" '.edl' && return

  cuts_output=$(tmp_file "$input" 'txt' 'CUTS')

  if [ "$(rpu_cuts_line "$scene_cuts" 1)" != 0 ]; then
    cuts_temp=$(tmp_file "$input" 'txt' 'CUTS-tmp')
    { echo "0"; cat "$scene_cuts"; } >"$cuts_temp" && mv "$cuts_temp" "$cuts_output" && scene_cuts="$cuts_output"
  fi

  frames=$(mediainfo "$prores" --Inform="Video;%FrameCount%" | tr -d '\r')
  if [[ -n "$frames" && "$(rpu_cuts_line "$scene_cuts" -1)" -lt "$frames" ]]; then
    [[ ! "$scene_cuts" -ef "$cuts_output" ]] && cp "$scene_cuts" "$cuts_output" && scene_cuts="$cuts_output"
    echo "$frames" >>"$cuts_output"
  fi

  echo "$scene_cuts"
}

generate_variable_l5() {
  local prores="$1" scene_cuts="$2" mdl="$3" fps="$4" variable_l5="$5" xml="$6" presets=() cuts=() edits l5 preset range cuts_dynamic cuts_tmp xml_first xml_mid xml_tmp
  local -i id from to i=0

  while read -r from; do
    cuts[from]=1
  done <"$scene_cuts"

  while IFS=',' read -r id l5; do
    presets[id]="$l5"
  done < <(jq -r '.presets[] | "\(.id),\(.left) \(.right) \(.top) \(.bottom)"' "$variable_l5" | tr -d '\r')

  edits=$(jq -r '.edits | to_entries[] | "\(.key) \(.value)"' "$variable_l5" | tr -d '\r' | sort -n -t'-')

  while read -r id; do
    [[ ! -v presets[id] ]] && log_kill "$(red 'Error:') Variable L5 preset with id '$id' not found in the config" 2
  done < <(echo "$edits" | cut -d' ' -f2 | sort -u)

  while IFS='-' read -r from to; do
    [[ ! -v cuts[from] ]] && log_kill "$(red 'Error:') Variable L5 ranges must start at a valid scene-cut; invalid range start: '$from'" 2
    [[ ! -v cuts[$((to + 1))] ]] && log_kill "$(red 'Error:') Variable L5 ranges must end just before a scene-cut; invalid range end: '$to'" 2
  done < <(echo "$edits" | cut -d' ' -f1)

  cuts_dynamic=$(tmp_file "$input" 'txt' 'CUTS-DYNAMIC') && cp "$scene_cuts" "$cuts_dynamic"
  cuts_tmp=$(tmp_file "$input" 'txt' 'CUTS-TMP')
  xml_tmp=$(tmp_file "$input" 'xml' 'GENERATED-TMP') && rm -f "$xml_tmp"
  xml_first=$(tmp_file "$input" 'xml' 'GENERATED-FIRST') && rm -f "$xml_first"
  xml_mid=$(tmp_file "$input" 'xml' 'GENERATED-MID')

  while read -r range id; do
    from=${range%-*}
    read -ra preset <<<"${presets["$id"]}"

    awk -v f="$from" '$0 == f {p=1} p' "$cuts_dynamic" >"$cuts_tmp" && mv "$cuts_tmp" "$cuts_dynamic"

    logf && log_command 'cm_analyze -s <cuts-tmp> -m %s -r %s --source-format "pq bt2020" -f %s --letterbox %s --analysis-tuning %s <prores> <output-tmp>' "$mdl" "$fps" "$range" "${preset[*]}" "$L1_TUNING"

    if ! cm_analyze -s "$cuts_dynamic" -m "$mdl" -r "$fps" --source-format "pq bt2020" -f "$range" --letterbox "${preset[@]}" --analysis-tuning "$L1_TUNING" "$prores" "$xml_tmp"; then
      log_t "%s Failed to generate DV P8 RPU xml for range '%s', skipping..." "$(red 'Error:')" "$range" && return 1
    fi

    if ((i++ == 0)); then
      mv "$xml_tmp" "$xml_first"
    else
      awk '/<Shot>/ && !s {s=NR} /<\/Shot>/ {e=NR} {l[NR]=$0} END {for(i=s;i<=e;i++) print l[i]}' "$xml_tmp" >>"$xml_mid"
    fi
  done <<<"$edits"

  awk '/<\/Shot>/ {last=NR} {line[NR]=$0} END {for(i=1;i<=last;i++) print line[i]}' "$xml_first" >"$xml"
  cat "$xml_mid" >>"$xml"
  awk '/<\/Shot>/ {last=NR} {line[NR]=$0} END {for(i=last+1;i<=NR;i++) print line[i]}' "$xml_first" >>"$xml"
}

generate() {
  local input="$1" scene_cuts="$2" mdl="$3" fps="$4" l5="$5" l5_a="$6" l5v="$7" l5v_a="$8" l6="$9" output="${10}" mov_input prores xml l6 l5_top l5_bottom l5_left l5_right
  check_extension "$input" '.mov' && mov_input=1

  [ -z "$l5_a" ] && l5_a="$l5" && [ -z "$l5" ] && l5="auto"
  [ -z "$l5v_a" ] && l5v_a="$l5v"

  log_t "Generating DV P8 RPU for: '%s'..." "$(basename "$input")"
  output=$(out_file "$input" "bin" 'GENERATED' "$output")
  [[ -e "$output" ]] && logf "Generated RPU file '%s' already exists, skipping..." "$output" && return

  IFS='|' read -r mdl fps < <(mdl_fps "$input" "$mdl" "$fps")
  [[ -z "$mdl" || -z "$fps" ]] && return

  { read -r scene_cuts; read -r l5_a; } < <(scene_cuts_l5 "$input" "$scene_cuts" "$l5_a" "$l5v_a" "$mov_input")
  [[ -z "$scene_cuts" ]] && return

  [[ "$l5_a" == file:* ]] && l5v_a="${l5_a#file:}" && l5_a="" || l5v_a=""
  [ "$l5" = 'auto' ] && l5="$l5_a"

  prores=$(to_prores "$input")
  scene_cuts=$(fix_scene_cuts "$prores" "$scene_cuts")
  xml=$(out_file "$input" "xml" 'GENERATED' "$output")

  if [[ ! -e "$xml" ]]; then
    log_t "Generating DV P8 RPU xml..."

    if [ -n "$l5v_a" ]; then
      ! generate_variable_l5 "$prores" "$scene_cuts" "$mdl" "$fps" "$l5v_a" "$xml" && return
    else
      IFS=',' read -r l5_top l5_bottom l5_left l5_right <<<"$l5_a"

      log_command 'cm_analyze -s "%s" -m %s -r %s --source-format "pq bt2020" --letterbox %s %s %s %s --analysis-tuning %s <prores> <output>' \
        "$(basename "$scene_cuts")" "$mdl" "$fps" "${l5_left:-0}" "${l5_right:-0}" "${l5_top:-0}" "${l5_bottom:-0}" "$L1_TUNING"

      if ! cm_analyze -s "$scene_cuts" -m "$mdl" -r "$fps" --source-format "pq bt2020" --letterbox "${l5_left:-0}" "${l5_right:-0}" "${l5_top:-0}" "${l5_bottom:-0}" --analysis-tuning "$L1_TUNING" "$prores" "$xml"; then
        log_t "%s Failed to generate DV P8 RPU xml, skipping..." "$(red 'Error:')" && return
      fi
    fi
  else
    logf "Generated RPU xml file '%s' already exists, skipping..." "$(basename "$xml")"
  fi

  if ! dovi_tool generate --xml "$xml" -o "$output"; then
    log_t "%s Failed to generate DV P8 RPU, skipping..." "$(red 'Error:')" && return
  fi

  log_t "Successfully generated DV P8 RPU for: '%s' - output: '%s'" "$(basename "$input")" "$output"
  output=$(fix_rpu "$output" 1 "" "$l5" "$l6" "$l5v" "$input")
  [ "$INFO_INTERMEDIATE" = 1 ] && info "$output" >&2
}

generate_l5_examples() {
  local output="$1" example='{
    "presets": [
      { "id": 0, "top": 270, "bottom": 270, "left": 0, "right": 0 },
      { "id": 1, "top": 130, "bottom": 130, "left": 0, "right": 0 }
    ],
    "edits": { "0-149": 0, "150-300": 1, "301-399": 0, "400-599": 1, "600-999": 0 }
  }'

  echo "$example" | jq .

  [ -z "$output" ] && return || output=$(out_file "$input" "json" '' "$output")

  log_t "Saving variable L5 example to '%s'..." "$(basename "$output")"
  [[ -e "$output" ]] && logf "Output file '%s' already exists, skipping..." "$output" && return

  echo "$example" | jq . >"$output"
  logf "Variable L5 example saved to '%s'" "$output"
}

calculate_frame_shift() {
  local -r cuts_file="$1" cuts_base_file="$2" fast="$3"

  declare -A visited
  mapfile -t cuts1 <"$cuts_file"
  mapfile -t cuts2 <"$cuts_base_file"
  local -ri size1=${#cuts1[@]} size2=${#cuts2[@]}

  local -i max_misses=10 max_offset=100 min_matches=$((size2 / 2))
  [ "$fast" != 1 ] && max_misses="$min_matches"
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
    [ "$providable" = 1 ] && error+=" (provide a valid '$B--shift$N' manually)"
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
  local input="$1" input_base="$2" skip_sync="$3" frame_shift="$4" fix="$5" l5="$6" l6="$7" cuts_clear="$8" output="$9" exit_if_exists="${10}"
  local rpu_base rpu_synced rpu_injected rpu_fixed cmv40_transferable
  output=$(out_hybrid "$input" "$input_base" 'bin' "$output" "$fix")

  log_t "Creating hybrid RPU: '%s'..." "$(basename "$output")"

  if [[ -f "$output" ]]; then
    [ "$exit_if_exists" = 1 ] && log_kill "The hybrid RPU file: '$output' already exists" 2
    logf "The hybrid RPU file: '%s' already exists, skipping..." "$output"
    echo "$output" && return
  fi

  [ "$fix" = 1 ] && rpu_injected=$(out_hybrid "$input" "$input_base" 'bin') || rpu_injected="$output"

  if [[ ! -f "$rpu_injected" ]]; then
    rpu_base=$(to_rpu "$input_base")

    if [ "$skip_sync" = 1 ]; then
      log "Skipping RPU sync..."
      rpu_synced=$(to_rpu "$input")
    else
      rpu_synced=$(sync_rpu "$input" "$rpu_base" "$frame_shift" 0)
      log ""
    fi

    cm40_input "$rpu_synced" && cm29_input "$rpu_base" && cmv40_transferable='"allow_cmv4_transfer": true,'

    local -r transfer_config=$(tmp_file "$rpu_synced" 'json' 'EDITOR-TRANSFER')
    rpu_synced=$(realpath "$rpu_synced") && rpu_synced=$(windows_safe_path "$rpu_synced")
    echo "{ $cmv40_transferable \"source_rpu\": \"$rpu_synced\", \"rpu_levels\": [$RPU_LEVELS] }" >"$transfer_config"

    if ! dovi_tool editor -i "$rpu_base" -j "$transfer_config" -o "$rpu_injected" >&2; then
      log_kill "Error while injecting RPU levels: $RPU_LEVELS of '$(basename "$rpu_synced")' into '$(basename "$rpu_base")'" 1
    fi

    log "RPU levels: $RPU_LEVELS of '$(basename "$rpu_synced")' successfully injected into '$(basename "$rpu_base")' - output file: '$rpu_injected'" 1
  else
    logf "The hybrid RPU file: '%s' already exists, skipping..." "$rpu_injected"
  fi

  if [ "$fix" = 1 ]; then
    rpu_fixed=$(fix_rpu "$rpu_injected" 1 "$cuts_clear" "$l5" "$l6" "" "$input_base" "" "$output" "$input")
    [[ ! "$rpu_fixed" -ef "$output" ]] && cp "$rpu_fixed" "$output"
  fi

  if [ "$INFO_INTERMEDIATE" = 1 ]; then
    [ -n "$rpu_base" ] && info "$rpu_base" >&2
    [ -n "$rpu_synced" ] && info "$rpu_synced" >&2
    [ "$fix" = 1 ] && [[ -z "$rpu_fixed" || ! "$rpu_injected" -ef "$rpu_fixed" ]] && info "$rpu_injected" >&2
    info "$output" >&2
  fi

  echo "$output"
}

inject_hevc() {
  local input="$1" input_base="$2" raw_rpu="$3" skip_sync="$4" frame_shift="$5" fix="$6" l5="$7" l6="$8" cuts_clear="$9" output="${10}" exit_if_exists="${11}" rpu_type='Raw' rpu_injected bl_only=0

  output=$(out_hybrid "$input" "$input_base" 'hevc' "$output" "$fix" "$raw_rpu")
  log_t "Creating hybrid base layer: '%s'..." "$(basename "$output")"

  if [[ ! -f "$output" ]]; then
    if [ "$raw_rpu" != 1 ]; then
      rpu_type='Hybrid'
      rpu_injected=$(inject_rpu "$input" "$input_base" "$skip_sync" "$frame_shift" "$fix" "$l5" "$l6" "$cuts_clear")
      fix=0
    elif [ "$skip_sync" != 1 ]; then
      rpu_injected=$(sync_rpu "$input" "$input_base" "$frame_shift" 1)
    else
      log_t "Skipping raw RPU sync..."
      rpu_injected=$(to_rpu "$input")
      [ "$INFO_INTERMEDIATE" = 1 ] && info "$rpu_injected" >&2
    fi

    if [ "$fix" = 1 ]; then
      local -r rpu_fixed=$(fix_rpu "$rpu_injected" 1 "$cuts_clear" "$l5" "$l6" "" "$input_base" "" "" "$input")
      [[ "$INFO_INTERMEDIATE" = 1 && ! "$rpu_fixed" -ef "$rpu_injected" ]] && info "$rpu_fixed" >&2
      rpu_injected="$rpu_fixed"
    fi

    [ "$raw_rpu" = 1 ] && ! p7_input "$rpu_injected" && p7_input "$input_base" && bl_only=1

    local -r hevc=$(to_hevc "$input_base" "$bl_only") basename=$(basename "$input_base") rpu_basename=$(basename "$rpu_injected")
    log_c "Injecting %s RPU: '%s' into base layer of '%s'..." "${rpu_type,,}" "$rpu_basename" "$basename"

    dovi_tool inject-rpu -r "$rpu_injected" -o "$output" "$hevc" >&2

    [[ ! "$input_base" -ef "$hevc" ]] && rm "$hevc" && log_t "Intermediate base layer: '%s' removed" "$(basename "$hevc")"

    log_t "%s RPU: '%s' successfully injected into base layer of '%s' - output file: '%s'" "$rpu_type" "$rpu_basename" "$basename" "$output"
  elif [ "$exit_if_exists" = 1 ]; then
    log_kill "The hybrid base layer: '$output' already exists" 2
  else
    logf "The hybrid base layer: '%s' already exists, skipping..." "$output"
  fi

  echo "$output"
}

mp4_unremuxable() {
  local -r base_file="$1" hevc="$2" input_type="${3:-'--base-input/-b'}"

  [[ -z "$hevc" ]] && check_extension "$base_file" '.mp4' && return 0
  [[ -n "$(audio_info "$base_file" 0 1)" ]] && echo "'$B$input_type$N' contains lossless audio" && return 1
  [[ -n "$hevc" ]] && p7_input "$hevc" && echo "'--hevc/-r' contains Dolby Vision Profile 7 layer" && return 1
  [[ -z "$hevc" ]] && p7_input "$base_file" && echo "'$B$input_type$N' contains Dolby Vision Profile 7 layer" && return 1

  return 0
}

mp4_preferred() {
  local -r input="$1" hevc="$2"

  dovi_input "${hevc:-"$input"}" && [[ -z "$(mp4_unremuxable "$input" "$hevc")" ]]
}

auto_target_format() {
  local -r input="$1" hevc="$2" input_type="${3:-"--base-input/-b"}"

  [[ "$input" != *.* ]] && log_kill "Cannot deduce target format ('$B$input_type$N' have no extension)" 2

  local -r target_format="${input##*.}"

  check_extension "$target_format" ".m2ts .ts" && target_format='mkv'
  check_extension "$target_format" '.mkv' && mp4_preferred "$input" "$hevc" && echo "mp4" && return 0

  echo "${target_format,,}"
}

target_format() {
  local input="$1" target_format="$2" output="$3" valid_extensions="$4" hevc="$5" input_type="${6:-"--base-input/-b"}" type="'$B--output-format/-e$N'"

  [[ -z "$target_format" && "$output" == *.* ]] && target_format="${output##*.}" && type="'$B--output/-o$N' format"

  if [[ -z "$target_format" ]]; then
    auto_target_format "$input" "$hevc" "$input_type"
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
      local -r unremuxable_reason=$(mp4_unremuxable "$input" "$hevc" "$input_type")
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
    file_exists "$subs" '' 1
    check_extension "$subs" '.srt' 1
    realpath "$subs"
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

  log_command 'ffmpeg %s %s %s %s %s' "${ffmpeg_input[*]}" "${ffmpeg_map[*]}" "${ffmpeg_copy[*]}" "${ffmpeg_metadata[*]}" "$(basename "$output")"
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

  log_command 'mkvmerge %s' "${mkv_merge[*]}"
  mkvmerge "${mkv_merge[@]}"
}

remux() {
  local input="$1" output_format="$2" output="$3" hevc="$4" subs="$5" title="$6" validate_output_format="${7:-1}"

  check_extension "$input" '.mkv .mp4 .m2ts .ts' 1
  [[ -n "$hevc" ]] && check_extension "$hevc" '.hevc' 1

  if [[ -z "$output_format" || "$validate_output_format" != 0 ]]; then
    output_format=$(target_format "$input" "$output_format" "$output" '.mkv .mp4' "$hevc" "--input/-i")
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
  local input="$1" input_base="$2" raw_rpu="$3" skip_sync="$4" frame_shift="$5" l5="$6" l6="$7" cuts_clear="$8" output_format="$9" output="${10}" subs="${11}" title="${12}" fix type

  check_extension "$input_base" '.mkv .mp4 .m2ts .ts .hevc .bin' 1
  check_extension "$input" '.mkv .mp4 .m2ts .ts .hevc .bin' 1

  output_format=$(target_format "$input_base" "$output_format" "$output" '.mkv .mp4 .hevc .bin')
  [[ -n "$l5" || -n "$cuts_clear" || "$FIX_CUTS_FIRST" = 1 || "$FIX_CUTS_CONSEC" = 1 ]] && fix=1

  [ "$raw_rpu" = 1 ] && type='raw RPU' || type="RPU levels: $RPU_LEVELS"
  log "Injecting $type of '$(basename "$input")' into '$(basename "$input_base")'..." 1

  if [[ "$output_format" == *bin* ]]; then
    [ "$raw_rpu" = 1 ] && log_kill "'$B--raw-rpu/-w$N' cannot be used with .bin outputs" 2
    inject_rpu "$input" "$input_base" "$skip_sync" "$frame_shift" "$fix" "$l5" "$l6" "$cuts_clear" "$output" 1 >/dev/null
  elif [[ "$output_format" == *hevc* ]]; then
    inject_hevc "$input" "$input_base" "$raw_rpu" "$skip_sync" "$frame_shift" "$fix" "$l5" "$l6" "$cuts_clear" "$output" 1 >/dev/null
  else
    output=$(out_file "$input_base" "$output_format" "HYBRID${fix:+"_FIXED"}" "$output" "$CLEAN_FILENAMES")
    [[ -f "$output" ]] && log "Hybrid output file: '$(basename "$output")' already exists, skipping..." && return

    local hevc=$(inject_hevc "$input" "$input_base" "$raw_rpu" "$skip_sync" "$frame_shift" "$fix" "$l5" "$l6" "$cuts_clear")

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
    log "No subtitles found in '$(basename "$input")' ($B--lang/-c$N: ${SUBS_LANG_CODES:-'all'}), skipping..."
  fi
}

extract_pgs() {
  local input="$1" sample="$2" out_dir="${3%/}" ffmpeg_input=() ffmpeg_args=() lang_filter track id lang output

  check_extension "$input" '.mkv .mp4 .m2ts .ts' 1

  log_c "Extracting PGS subtitles"

  TOPSUBS_LANG_CODES="${TOPSUBS_LANG_CODES,,}"
  [[ -n "$TOPSUBS_LANG_CODES" && "$TOPSUBS_LANG_CODES" != 'all' ]] && lang_filter="\((${TOPSUBS_LANG_CODES//,/|})\)"

  while IFS= read -r track; do
    [[ ! "$track" =~ Stream\ \#[0-9]+:([0-9]+)\(([a-zA-Z]+)\) ]] && continue
    id="${BASH_REMATCH[1]}" && lang="${BASH_REMATCH[2]}"

    output="$out_dir/$id"
    [[ "${track,,}" == *'(comment)'* ]] && output+="-COMMENT"
    [[ "${track,,}" == *'(descriptions)'* ]] && output+="-DESC"
    [[ "${track,,}" == *'(visual impaired)'* ]] && output+="-VI"
    [[ "${track,,}" == *'(hearing impaired)'* ]] && output+="-SDH"
    [[ "${track,,}" == *'(forced)'* ]] && output+="-FORCED"
    [[ -n "$lang" && "${lang,,}" != 'und' && "${lang,,}" != 'null' ]] && output+=".${lang,,}"
    output+=".sup"

    logf "Mapping track %s -> '%s'" "$id" "$(basename "$output")"
    ffmpeg_args+=(-map "0:$id" -c copy "$output")
  done < <(ffmpeg -loglevel info -i "$input" 2>&1 | grep -E "Stream #0:[0-9]*$lang_filter.*Subtitle.*pgssub")

  if [[ ${#ffmpeg_args[@]} -eq 0 ]]; then
    logf "%s No subtitles found in '%s' ($B--lang/-c$N: ${TOPSUBS_LANG_CODES:-'all'}), skipping..." "$(yellow 'Warning:')" "$(basename "$input")"
    return 1
  fi

  mkdir -p "$out_dir"

  [ "$sample" = 1 ] && ffmpeg_input+=(-t "$EXTRACT_SHORT_SEC")
  ffmpeg_input+=(-i "$input" -map_chapters -1)

  logf '' && log_command 'ffmpeg %s %s' "${ffmpeg_input[*]}" "${ffmpeg_args[*]}"
  ffmpeg "${ffmpeg_input[@]}" "${ffmpeg_args[@]}"

  log_t "PGS subtitles successfully extracted - output dir: '%s'" "$out_dir"
}

topsubs_fps() {
  local input="$1" fps="$2" info_fps info_fps_org

  if [ -n "$fps" ]; then
    fps="${fps%"/1"}" && fps="${fps%"/"}"
  elif check_extension "$input" '.mkv .mp4 .m2ts .ts'; then
    IFS='|' read -r info_fps info_fps_org < <(mediainfo "$input" --Inform='Video;%FrameRate_Num%/%FrameRate_Den%|%FrameRate_Original_Num%/%FrameRate_Original_Den%\n' | tr -d '\r')

    [[ -z "$info_fps" || "$info_fps" = "/" ]] && info_fps="$info_fps_org"
    fps="${info_fps%"/1"}" && fps="${fps%"/"}"

    if [ -n "$fps" ]; then
      logf "Detected input FPS: %s" "$fps"
    else
      logf "%s Failed to auto-detect FPS, using default FPS: 23.976" "$(yellow 'Warning:')" && fps="23.976"
    fi
  else
    logf "Using default FPS: 23.976" && fps="23.976"
  fi

  case "$fps" in
  '24000/1001') fps="23.976" ;;
  '30000/1001') fps="29.97" ;;
  *'/'*) log_kill "Unsupported $B--fps$N value: $fps" ;;
  esac

  echo "$fps"
}

find_topsubs() {
  local input="$1" fps="$2" out_dir="${3%/}" output y png out_png start
  local -r tmp_dir="${TMP_DIR%/}/PGS_$(date +%s%3N)"
  local -i i=0

  [[ ! -s "$input" ]] && return 1

  output=$(generate_file "$tmp_dir" "$input" 'xml')

  log_t "Searching for top-positioned subtitles (Y ≤ %s) in PGS: '%s'" "$TOPSUBS_MAX_OFFSET" "$(basename "$input")"

  logf '' && log_command "sup2sub -T %s -o <tmp-dir> '%s'" "$fps" "$(basename "$input")"
  if sup2sub -T "${fps:-"23.976"}" -o "$output" "$input" >/dev/null && [[ -s "$output" ]]; then
    logf "Successfully demuxed PGS subs: '%s'" "$(basename "$input")"
  else
    logf "Failed to demux PGS subs: '%s'" "$(basename "$input")" && return 1
  fi

  while IFS='|' read -r y png start; do
    out_png="${png%.*}_Y-${y}_${start//[:.]/-}.png"

    ((i++ == 0)) && log_t 'Found top-positioned subtitles (Start timestamp -> Y-Offset -> Filename):'
    logf "  [%s] %s -> Y=%s -> %s" "$i" "$start" "$y" "$out_png"

    mv "$tmp_dir/$png" "$out_dir/$out_png"
  done < <(
    awk -v offset="$TOPSUBS_MAX_OFFSET" '
    /<Event.*InTC=/ {
      match($0, /InTC="([0-9:\.]+)"/, a);
      start = a[1]
    }
    /<Graphic.*Y=/ {
      match($0, /Y="([0-9]+)"/, y);
      match($0, />([^<]*\.png)</, f);
      if (y[1] <= offset) print y[1] "|" f[1] "|" start
    }
  ' "$output"
  )

  if ((i > 0)); then
    mv "$output" "$out_dir/"
  else
    log_t 'No top-positioned subtitles found...'
  fi
}

topsubs() {
  local input="$1" sample="$2" fps="$3" out_dir
  ! check_extension "$input" '.mkv .mp4 .m2ts .ts' && sample=0

  out_dir=$(out_file "$input" 'sup' 'PGS')
  out_dir="${out_dir%.*}" && [ "$sample" = 1 ] && out_dir+="_${EXTRACT_SHORT_SEC}s"

  log_t "Extracting top-positioned PGS subtitles from '%s' - output dir: '%s'" "$(basename "$input")" "$out_dir"
  [[ -e "$out_dir" ]] && logf "%s Output dir '%s' already exists, skipping..." "$(yellow 'Warning:')" "$out_dir" && return

  fps=$(topsubs_fps "$input" "$fps")

  if check_extension "$input" '.mkv .mp4 .m2ts .ts'; then
    ! extract_pgs "$input" "$sample" "$out_dir" && return

    while IFS= read -r -d '' input; do
      find_topsubs "$input" "$fps" "$out_dir"
    done < <(find "$out_dir" -maxdepth 1 -type f -name "*.sup" -print0)
  else
    mkdir -p "$out_dir"
    find_topsubs "$input" "$fps" "$out_dir"
  fi
}

help_dir() {
  local out_dir="$1" result="$1"
  [[ "$result" == /* ]] && result=$(relative_path "$out_dir")

  [ "$result" = '.' ] && echo "<working-dir>" && return

  [[ "$result" == *"$out_dir"* || "$result" == ../../* ]] && result="$out_dir"
  [[ "$result" =~ [0-9]{11}/?$ ]] && result="${result//${BASH_REMATCH[0]}/<timestamp>/}"
  [[ ! "$result" =~ ^/ && ! "$result" =~ ^\.\. ]] && result="./$result"

  echo "${result%/}"
}

help0() {
  local help="$1" empty_line="$2" option="$3" line left
  [[ -z "$option" ]] && option=${help:1:1}

  [[ -n "${option// /}" && -n "$cmd_options" && "ihvN" != *"$option"* && "$cmd_options" != *"$option"* ]] && return

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
  local cmd="$1" s b t q i G bin clean multiple_inputs output_info default_l5 default_l6 default_plot_info default_output='generated' default_output_format='auto-detected' default_fps default_langs subs_action="extract"
  local -r description=${cmd_description[$cmd]:-$(cmd_info "$cmd")} formats=$(cmd_info "$cmd" 3)
  [[ "$cmd_options" == *b* ]] && b=1
  [[ "$cmd_options" == *t* ]] && t=1 && multiple_inputs='[ignored when multiple inputs]'
  [[ "$cmd_options" == *q* ]] && q=1
  [[ "$cmd_options" == *G* ]] && default_l5="same as input" || G=1
  [[ "$cmd" != 'plot' && "$cmd_options" == *s* && "${PLOT_DEFAULT,,}" != "none" && "$PLOT_DEFAULT" != 0 ]] && s=1
  [[ "$formats" == *bin* ]] && bin=1
  [ "$cmd" = 'extract' ] && default_output_format='bin'
  [ "$cmd" != 'plot' ] && i=1
  [ "$cmd" = 'info' ] && default_output='<print to console>' && default_plot_info="/$B--frames$N" || output_info="$multiple_inputs"
  [ "$cmd" = 'edl' ] && default_fps='23.976'
  [ "$cmd" = 'inject' ] && default_l6='keep if present, else auto-detect'
  [ "$cmd" = 'generate' ] && default_l6='auto-detected'
  [ "$cmd" = 'topsubs' ] && default_langs="$TOPSUBS_LANG_CODES" && subs_action="process" || default_langs="$SUBS_LANG_CODES"

  case "$cmd_options" in
  *H*) help_left+=17 ;;
  *G*) help_left+=16 ;;
  *[eF]*) help_left+=15 ;;
  *m*) help_left+=14 ;;
  *P*) help_left+=13 ;;
  *[bxsY]*) help_left+=11 ;;
  *[ltku]*) help_left+=10 ;;
  *S*) help_left+=9 ;;
  *[opc]*) help_left+=8 ;;
  *) help_left+=6 ;;
  esac

  echo "$description"
  echo1 "${BU}Usage:$N $REMUXER $B$cmd$N [OPTIONS] ${b:+"--base-input <BASE-INPUT> "}[INPUT${t:+"..."}]"
  echo1 "${BU}Arguments:$N"
  help0 "INPUT                           Input file path"
  echo1 "${BU}Options:$N"
  help0 "-i, --input <INPUT>             Input file${t:+"/dir"} path${t:+" [can be used multiple times]"}
                                         ${t:+"For dirs, all supported files within will be used"}
                                         [supported formats: $B$formats$N]"
  help1 "-b, --base-input <INPUT>        Base input file path [${B}required$N]
                                         [supported formats: $B$formats$N]"
  help1 "-x, --formats <F1[,...]>        Filter files by format in dir inputs
                                         [allowed values: $B${formats//./}$N]"
  help1 "-t, --input-type <TYPE>         Filter files by type in dir inputs
                                         Allowed values:
                                         $B- shows:$N  files with ${B}S01E01$N-like pattern in name
                                         $B- movies:$N non-show files"
  help1 "-o, --output <OUTPUT>           Output file path [default: $B$default_output$N]
                                         $output_info"
  help1 "-e, --output-format <FORMAT>    Output format [default: $B$default_output_format$N]
                                         [allowed values: $B$(cmd_output_formats "$cmd")$N]"
  help1 "-u, --frames <F1[,...]>         Print RPU info for given frames"
  help1 "-k, --time [<T1[,...]>]         Approx. frame timestamp(s) in ${B}[[HH:]MM:]SS$N format
                                         [default: based on video duration (max. 3 frames)]"
  help1 "-s, --sample [<SECONDS>]        Process only the first N seconds of input
                                         [default sample duration: $B${EXTRACT_SHORT_SEC}s$N]
                                         ${bin:+"[ignored for $B.bin$N inputs]"}"
  help1 'P' "--profile <0-5>             Controls ProRes encoding profile (${B}0$N = Proxy, ${B}5$N = 4444 XQ)
                                         [default: $B$PRORES_PROFILE$N (macOS: $B$PRORES_MACOS$N)]"
  help1 "-q, --synced                    Skip RPUs sync (assumes RPUs are already in sync)"
  help1 "-f, --shift <SHIFT>             Frame shift value [default: ${B}auto-calculated$N]
                                         ${q:+"[ignored when $B--synced$N]"}"
  help1 "-l, --levels <L1[,...]>         RPU levels to inject [default: $B$RPU_LEVELS$N]
                                         [allowed values: ${B}1-6, 8-11, 254, 255$N]
                                         [ignored when $B--raw-rpu$N]"
  help1 "-w, --raw-rpu                   Inject input RPU instead of transferring levels"
  help1 'G' "--cuts <FILE>               Scene-cuts file path [default: ${B}extracted from input$N]
                                         [supported formats: $B.txt, .edl$N]"
  help1 'G' "--tuning <0-5>              Controls L1 analysis tuning [default: ${B}$L1_TUNING$N]
                                         Allowed values:
                                         $B- 0 / legacy$N   – Legacy CM4
                                         $B- 1 / most$N     – Most Highlight Detail (Darkest)
                                         $B- 2 / more$N     – More Highlight Detail
                                         $B- 3 / balanced$N – Balanced
                                         $B- 4 / less$N     – Less Highlight Detail
                                         $B- 5 / least$N    – Least Highlight Detail (Brightest)"
  help1 'I' "--fps <FPS>                 Frame rate [default: $B${default_fps:-"auto-detected"}$N]
                                         [example values: ${B}23.976, 24000/1001, 24, 25$N]"
  help1 'G' "--mdl <MDL>                 Mastering display [default: ${B}auto-detected$N]
                                         Allowed values:
                                         $B- 7  / P3_4000$N – 4000-nit P3
                                         $B- 8  / BT_4000$N – 4000-nit BT.2020
                                         $B- 20 / P3_1000$N – 1000-nit P3
                                         $B- 21 / BT_1000$N – 1000-nit BT.2020
                                         $B- 30 / P3_2000$N – 2000-nit P3
                                         $B- 31 / BT_2000$N – 2000-nit BT.2020"
  help1 'F' "--l5 <T,B[,L,R]>            ${G:+"Set "}Dolby Vision L5 active area offsets
                                         [defaults: $B${default_l5:-"L=0, R=0"}$N]
                                         <Top, Bottom, Left, Right>"
  help1 'G' "--l5-analysis <T,B[,L,R]>   L5 active area offsets (for analysis only)
                                         [defaults: ${B}same as --l5$N]
                                         <Top, Bottom, Left, Right>"
  help1 'G' "--l5v <FILE>                Variable L5 metadata JSON config
                                         Use $B--l5v-example$N for sample"
  help1 'G' "--l5v-analysis <FILE>       Variable L5 metadata JSON config (for analysis only)
                                         [defaults: ${B}same as --l5v$N]
                                         Use $B--l5v-example$N for sample"
  help1 'G' "--l5v-example               Show example JSON for $B--l5v/--l5v-analysis$N"
  help1 'F' "--l6 <MAX_CLL,MAX_FALL>     ${G:+"Set "}Dolby Vision L6 MaxCLL/MaxFALL
                                         ${default_l6:+"[default: $B$default_l6$N]"}"
  help1 'S' "--l6-source <FILE>          File path to use for L6 MaxCLL/FALL detection
                                         [supported formats: ${B}.mkv, .mp4, .m2ts, .ts, .hevc, .bin$N]
                                         [ignored if $B--l6$N is set]"
  help1 'H' "--cuts-clear <FS-FE[,...]>  Clear scene-cut flag in specified frame ranges"
  help1 'F' "--cuts-first <0|1>          Force first frame as scene-cut [default: $B$FIX_CUTS_FIRST$N]"
  help1 'F' "--cuts-consecutive <0|1>    Controls consecutive scene-cuts fixing [default: $B$FIX_CUTS_CONSEC$N]"
  help1 "-j, --json <FILE>               JSON config file path (applied before auto-fixes)
                                         Use $B--json-example$N for samples"
  help1 'j' "--json-example              Show examples for $B--json$N option"
  help1 "-n, --info <0|1>                Controls intermediate info commands [default: $B$INFO_INTERMEDIATE$N]"
  help1 "-p, --plot <P1[,...]>           Controls L1/L2/L8${i:+" intermediate"} plotting
                                         [default: $B$PLOT_DEFAULT$N${s:+" (${B}none$N if $B--sample$N$default_plot_info)"}]
                                         Allowed values:
                                         $B- 0 / none$N
                                         $B- 1 / all$N
                                         $B- L1$N         – L1 Dynamic Brightness
                                         $B- L2[_NITS]$N  – L2 Trims
                                         $B- L8T[_NITS]$N – L8 Trims
                                         $B- L8S[_NITS]$N – L8 Saturation Vectors
                                         $B- L8H[_NITS]$N – L8 Hue Vectors
                                         ${B}NITS$N = 100 (default), 600, 1000 or MAX (highest available)
                                         L8 plots require CM v4.0 RPU"
  help1 "-c, --lang <C1[,...]>           ISO 639-2 lang codes of subtitle tracks to $subs_action
                                         [default: $B${default_langs:-all}$N; example value: 'eng,pol']"
  help1 'Y' "--max-y <MAX_OFFSET>        Maximum Y offset to consider subs as top-positioned
                                         [default: $B$TOPSUBS_MAX_OFFSET$N]"
  clean="-m, --clean-filenames <0|1>     Controls output filename cleanup [default: $B$CLEAN_FILENAMES$N]
                                         [ignored if $B--output$N is set]
                                         [e.g., 'The.Show.S01E01.HDR' → 'The Show S01E01']
                                         [e.g., 'A.Movie.2025.UHD.2160p.DV' → 'A Movie']"
  [[ "$cmd" != inject && "$cmd" != remux ]] && help1 "$clean"
  help1 "    --out-dir <DIR>             Output files dir path
                                         [default: '$B$(help_dir "$OUT_DIR")$N']"
  help1 "    --tmp-dir <DIR>             Temp files dir path [will be ${B}removed if created$N]
                                         [default: '$B$(help_dir "$TMP_DIR")$N']"
  help1 "-h, --help                      Show help (use '$B--help$N' for a detailed version)"

  [[ "$cmd" != inject && "$cmd" != remux ]] && return
  echo1 "${BU}Options for .mkv / .mp4 output:$N"
  help0 "    --subs <FILE>               $B.srt$N subtitle file path to include
                                         $multiple_inputs"
  help1 "    --subs-find <0|1>           Controls subtitles auto-detection [default: $B$SUBS_AUTODETECTION$N]
                                         If ${B}1$N, searches for matching subs within input's dir"
  help1 "    --subs-copy <0|1|LNG>       Controls input subtitle tracks to copy [default: $B$SUBS_COPY_MODE$N]
                                         Allowed values:
                                         $B- 0:$N     none
                                         $B- 1:$N     all
                                         $B- <lng>:$N based on ISO 639-2 lang code [e.g., eng]"
  help1 "    --audio-copy <1|2|3>        Controls input audio tracks to copy [default: $B$AUDIO_COPY_MODE$N]
                                         Allowed values:
                                         $B- 1:$N 1st track only
                                         $B- 2:$N 1st track + compatibility if 1st is TrueHD
                                         $B- 3:$N all"
  help1 "-r, --hevc <FILE>               $B.hevc$N file path to replace input video track
                                         $multiple_inputs"
  help1 "    --title <TITLE>             Metadata title (e.g., movie name)
                                         $multiple_inputs"
  help1 "    --title-auto <0|1>          Controls generation of metadata title
                                         If ${B}1$N, metadata title will match clean filename
                                         [default - shows: $B$TITLE_SHOWS_AUTO$N, movies: $B$TITLE_MOVIES_AUTO$N]
                                         [ignored if $B--title$N is set]"
  help1 "    --tracks-auto <0|1>         Controls generation of some track names [default: $B$TRACK_NAMES_AUTO$N]
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
  for cmd in info plot shift sync fix generate inject remux extract cuts subs topsubs png mp3 edl; do
    help0 "$cmd            $(cmd_info "$cmd")"
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
  local value="${1// /}" current="$2" cmd="$3" option="$4" required="$5" allowed_values="$6" regex="$7" splittable="$8" required_items="$9" result
  local -i i=0
  value="${value,,}"

  option_valid "$value" "$current" "$cmd" "$option" "$required" || return
  [ "$splittable" = 1 ] && value=${value//,/ }

  for v in $value; do
    result+="$v," && i+=1
    if [[ -n "$regex" ]]; then
      [[ "$v" =~ ^$regex$ ]] && continue
    else
      [[ " ${allowed_values//,/ } " == *\ $v\ * ]] && continue
    fi
    option_fatal "$option" "'$v' is not a valid value (allowed: $allowed_values)"
  done

  [[ -n "$required_items" && ! "$i" =~ ^$required_items$ ]] && option_fatal "$option" "must contain ${required_items//|/ or } items (found $i: '${result%,}')"

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
      find "$1" -maxdepth 1 -type f \( ! -name '.*' -a \( "${find_filter[@]}" \) \) -print0 | while read -rd $'\0' input; do
        typed_input "$input" "$1" "$type"
      done
    else
      realpath "$1"
    fi
    shift
  done
}

deduplicate_list() {
  if [ "$2" != 1 ]; then
    local -r deduplicated=$(tr ',' '\n' <<<"${1// /}" | sort -u | tr '\n' ',')
  else
    local -r deduplicated=$(tr ',' '\n' <<<"${1// /}" | sort -nu | tr '\n' ',')
  fi
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
  local -i batch=0 sample=0 skip_sync=0 rpu_raw=0 json_examples=0 explicit_plot=0 l5_examples=0

  [[ "$cmd_options" == *t* ]] && batch=1

  local inputs=() input base_input formats input_type output output_format clean_filenames out_dir tmp_dir sample_duration
  local frames frame_shift rpu_levels info plot lang_codes hevc subs find_subs copy_subs copy_audio title title_auto tracks_auto timestamps
  local cuts_clear cuts_first cuts_consecutive json prores_profile tuning fps mdl scene_cuts l5 l5_a l5v l5v_a l6_source l6 max_y

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help) show_help "$cmd" "$1"; return ;;
    -v | --version) version; return ;;
    -q | --synced) skip_sync=1; shift; continue ;;
    -w | --raw-rpu) rpu_raw=1; shift; continue ;;
    -s | --sample)
      sample=1
      if [[ ! "$2" =~ ^[1-9][0-9]*$ ]]; then
        shift; continue
      fi
      sample_duration=$(parse_option "$2" "$sample_duration" "$cmd" "$1" 's' '<seconds>' '[1-9][0-9]*')
      ;;
    --json-example) json_examples=1 && output=''; shift; continue ;;
    --l5v-example) l5_examples=1 && output=''; shift; continue ;;
    -x | --formats)                 formats=$(parse_option "$2" "$formats" "$cmd" "$1" 'x' "${allowed_formats//./}" '' 1) ;;
    -t | --input-type)           input_type=$(parse_option "$2" "$input_type" "$cmd" "$1" 't' 'shows, movies') ;;
    -o | --output)                   output=$(parse_file "$2" "$output" "$cmd" "$1" 'o' '' 0) ;;
    -e | --output-format)     output_format=$(parse_option "$2" "$output_format" "$cmd" "$1" 'e' "$(cmd_output_formats "$cmd")") ;;
    -f | --shift)               frame_shift=$(parse_option "$2" "$frame_shift" "$cmd" "$1" 'f' '<number>' '-?[0-9]+') ;;
    -u | --frames)                   frames=$(parse_option "$2" "$frames" "$cmd" "$1" 'u' '<frame-number>' '(0|[1-9][0-9]*)' 1) ;;
    -k | --time)                 timestamps=$(parse_option "$2" "$timestamps" "$cmd" "$1" 'k' '[[HH:]MM:]SS[.MMM]' '(((([0-5]?[0-9]:){1,2}[0-5]?[0-9])|[0-9]+)(\.[0-9]{1,3})?)' 1) ;;
    -l | --levels)               rpu_levels=$(parse_option "$2" "$rpu_levels" "$cmd" "$1" 'l' '1-6, 8-11, 254, 255' '([1-689]|1[01]|25[45])' 1) ;;
    -n | --info)                       info=$(parse_option "$2" "$info" "$cmd" "$1" 'n' '0, 1') ;;
    -p | --plot)                       plot=$(parse_option "$2" "$plot" "$cmd" "$1" 'p' '<none, all, L1, L2[_NITS}, L8T[_NITS}, L8H[_NITS}, L8S[_NITS}>' '(0|1|none|all|l1|(l(2|8t|8s|8h)(_(100|600|1000|max))?))' 1) ;;
    -c | --lang)                 lang_codes=$(parse_option "$2" "$lang_codes" "$cmd" "$1" 'c' '<ISO 639-2 lang codes>' '[a-z]{3}' 1) ;;
    -m | --clean-filenames) clean_filenames=$(parse_option "$2" "$clean_filenames" "$cmd" "$1" 'm' '0, 1') ;;
    -r | --hevc)                       hevc=$(parse_file "$2" "$hevc" "$cmd" "$1" 'r' '.hevc') ;;
    -j | --json)                       json=$(parse_file "$2" "$json" "$cmd" "$1" 'F' '.json') ;;
    --cuts)                      scene_cuts=$(parse_file "$2" "$scene_cuts" "$cmd" "$1" 'G' '.txt .edl') ;;
    --l5v)                              l5v=$(parse_file "$2" "$l5v" "$cmd" "$1" 'G' '.json') ;;
    --l5v-analysis)                   l5v_a=$(parse_file "$2" "$l5v_a" "$cmd" "$1" 'G' '.json') ;;
    --l6-source)                  l6_source=$(parse_file "$2" "$l6_source" "$cmd" "$1" 'S' '.mkv .mp4 .m2ts .ts .hevc .bin') ;;
    --tuning)                        tuning=$(parse_option "$2" "$tuning" "$cmd" "$1" 'G' '0, legacy, 1, most, 2, more, 3, balanced, 4, less, 5, least') ;;
    --mdl)                              mdl=$(parse_option "$2" "$mdl" "$cmd" "$1" 'G' '7, P3_4000, 8, BT_4000, 20, P3_1000, 21, BT_1000, 30, P3_2000, 31, BT_2000', '([78]|[23][01]|(bt|p3)_[124]000)') ;;
    --fps)                              fps=$(parse_option "$2" "$fps" "$cmd" "$1" 'I' '<frame-rate>' '[0-9]{1,5}([./][0-9]{1,5})?') ;;
    --profile)               prores_profile=$(parse_option "$2" "$prores_profile" "$cmd" "$1" 'P' '0, 1, 2, 3, 4, 5') ;;
    --l5)                                l5=$(parse_option "$2" "$l5" "$cmd" "$1" 'F' '<offset>' '[0-9]+' 1 '2|4') ;;
    --l5-analysis)                     l5_a=$(parse_option "$2" "$l5_a" "$cmd" "$1" 'G' '<offset>' '[0-9]+' 1 '2|4') ;;
    --l6)                                l6=$(parse_option "$2" "$l6" "$cmd" "$1" 'F' '<nits-number>' '[0-9]+' 1) ;;
    --cuts-clear)                cuts_clear=$(parse_option "$2" "$cuts_clear" "$cmd" "$1" 'H' '<frame-range>' '[0-9]+(-[0-9]+)?' 1) ;;
    --cuts-first)                cuts_first=$(parse_option "$2" "$cuts_first" "$cmd" "$1" 'F' '0, 1') ;;
    --cuts-consecutive)    cuts_consecutive=$(parse_option "$2" "$cuts_consecutive" "$cmd" "$1" 'F' '0, 1') ;;
    --max-y)                          max_y=$(parse_option "$2" "$max_y" "$cmd" "$1" 'Y' '<max-offset>' '[0-9]+') ;;
    --subs)                            subs=$(parse_file "$2" "$subs" "$cmd" "$1" 'e' '.srt') ;;
    --subs-find)                  find_subs=$(parse_option "$2" "$find_subs" "$cmd" "$1" 'e' '0, 1') ;;
    --subs-copy)                  copy_subs=$(parse_option "$2" "$copy_subs" "$cmd" "$1" 'e' '0, 1, <ISO 639-2 lang code>' '(0|1|[a-z]{3})') ;;
    --audio-copy)                copy_audio=$(parse_option "$2" "$copy_audio" "$cmd" "$1" 'e' '1, 2, 3') ;;
    --title)                          title=$(parse_base "$2" "$title" "$cmd" "$1" 'e') ;;
    --title-auto)                title_auto=$(parse_option "$2" "$title_auto" "$cmd" "$1" 'e' '0, 1') ;;
    --tracks-auto)              tracks_auto=$(parse_option "$2" "$tracks_auto" "$cmd" "$1" 'e' '0, 1') ;;
    --out-dir)                      out_dir=$(parse_dir "$2" "$out_dir" "$cmd" "$1") ;;
    --tmp-dir)                      tmp_dir=$(parse_dir "$2" "$tmp_dir" "$cmd" "$1") ;;
    -b | --base-input)           base_input=$(parse_file "$2" "$base_input" "$cmd" "$1" 'b' "$allowed_formats") ;;
    -i | --input) valid_input "$2" "${inputs[0]}" "$cmd" "$batch" "$allowed_formats" "$1" && inputs+=("$2") ;;
    *) valid_input "$1" "${inputs[0]}" "$cmd" "$batch" "$allowed_formats" && inputs+=("$1"); shift; continue ;;
    esac
    shift; shift
  done

  [ "$json_examples" = 1 ] && fix_rpu_examples "$output" && return
  [ "$l5_examples" = 1 ] && generate_l5_examples "$output" && return

  [ ${#inputs[@]} -eq 0 ] && log_kill "No input specified (use '$B--input/-i$N' or ${B}positional argument$N)" 2 1
  [[ "$cmd_options" == *b* && -z "$base_input" ]] && log_kill "Required option '$B--base-input/-b$N' is missing" 2 1

  mapfile -t inputs < <(parse_inputs "${formats:-$allowed_formats}" "$input_type" "${inputs[@]}")
  [ ${#inputs[@]} -gt 1 ] && mapfile -t inputs < <(deduplicate_array "${inputs[@]}")

  if [ ${#inputs[@]} -gt 1 ]; then
    [ "$cmd" != 'info' ] && output=$(batch_ignored "$output" '--output/-o')
    subs=$(batch_ignored "$subs" '--subs')
    hevc=$(batch_ignored "$hevc" '--hevc/-r')
    title=$(batch_ignored "$title" '--title')
  else
    batch=0
    [[ "$cmd_options" == *b* && "$base_input" == "${inputs[0]}" ]] && log_kill "${B}Input$N and '$B--base-input/-b$N' must be different files" 2 1
    [ "$skip_sync" = 1 ] && frame_shift=$(option_ignored "$frame_shift" '--shift/-f' "has no effect when $B--synced$N")
    [[ -n "$output" && "$clean_filenames" = 1 ]] && clean_filenames=$(option_ignored "$clean_filenames" '--clean-filenames/-m' "has no effect when $B--output$N is set")
    [[ -n "$title" ]] && title_auto=$(option_ignored "$title_auto" '--title-auto' "has no effect when $B--title$N is set")
    [[ "$rpu_raw" = 1 ]] && rpu_levels=$(option_ignored "$rpu_levels" '--levels/-l' "has no effect when $B--rpu_raw$N is set")
  fi

  [[ -n "$l5v" && -n "$l5" && -s "$l5v" ]] && l5=$(option_ignored "$l5" '--l5' "has no effect when $B--l5v$N is set")
  [[ -n "$l5v_a" || -n "$l5v" ]] && [[ -n "$l5_a" ]] && [[ -s "$l5v_a" || -s "$l5v" ]] && l5_a=$(option_ignored "$l5_a" '--l5-analysis' "has no effect when $B--l5v/--l5v-analysis$N is set")
  [[ -n "$l6_source" && -n "$l6" && -s "$l6_source" ]] && l6_source=$(option_ignored "$l6_source" '--l6_source' "has no effect when $B--l6$N is set")

  [[ -n "$out_dir" ]] && OUT_DIR="$out_dir"
  [[ -n "$tmp_dir" ]] && TMP_DIR="$tmp_dir"
  [[ -n "$sample_duration" ]] && EXTRACT_SHORT_SEC="$sample_duration"
  [[ -n "$rpu_levels" ]] && RPU_LEVELS=$(deduplicate_list "$rpu_levels" 1)
  [[ -n "$info" ]] && INFO_INTERMEDIATE="$info"
  [[ -n "$plot" ]] && PLOT_DEFAULT=$(deduplicate_list "$plot") && explicit_plot=1
  [[ -n "$cuts_first" ]] && FIX_CUTS_FIRST="$cuts_first"
  [[ -n "$cuts_consecutive" ]] && FIX_CUTS_CONSEC="$cuts_consecutive"
  [[ -n "$find_subs" ]] && SUBS_AUTODETECTION="$find_subs"
  [[ -n "$copy_subs" ]] && SUBS_COPY_MODE="$copy_subs"
  [[ -n "$lang_codes" ]] && SUBS_LANG_CODES=$(deduplicate_list "$lang_codes") && TOPSUBS_LANG_CODES="$SUBS_LANG_CODES"
  [[ -n "$max_y" ]] && TOPSUBS_MAX_OFFSET="$max_y"
  [[ -n "$copy_audio" ]] && AUDIO_COPY_MODE="$copy_audio"
  [[ -n "$title_auto" || -n "$title" ]] && TITLE_SHOWS_AUTO="${title_auto:-0}" && TITLE_MOVIES_AUTO="${title_auto:-0}"
  [[ -n "$tracks_auto" ]] && TRACK_NAMES_AUTO="$tracks_auto"
  [[ -n "$clean_filenames" || -n "$output" ]] && CLEAN_FILENAMES="${clean_filenames:-0}"
  [[ -n "$frames" ]] && frames="$(deduplicate_list "$frames" 1)"
  [[ -n "$timestamps" ]] && timestamps="$(deduplicate_list "$timestamps")"
  [[ -n "$prores_profile" ]] && PRORES_PROFILE="$prores_profile" && PRORES_MACOS="$prores_profile"
  [[ -n "$tuning" ]] && L1_TUNING="$tuning"

  PLOT_DEFAULT="${PLOT_DEFAULT,,}" && PLOT_DEFAULT="${PLOT_DEFAULT//,/ }"

  case "${L1_TUNING,,}" in
  0 | legacy) L1_TUNING="0" ;;
  1 | most) L1_TUNING="1" ;;
  2 | more) L1_TUNING="2" ;;
  4 | less) L1_TUNING="4" ;;
  5 | least) L1_TUNING="5" ;;
  *) L1_TUNING="3" ;;
  esac

  if [[ -n "$mdl" ]]; then
    case "${mdl^^}" in
    7 | P3_4000) mdl=7 ;;
    8 | BT_4000) mdl=8 ;;
    20 | P3_1000) mdl=20 ;;
    21 | BT_1000) mdl=21 ;;
    30 | P3_2000) mdl=30 ;;
    31 | BT_2000) mdl=31 ;;
    esac
  fi

  tmp_trap

  for input in "${inputs[@]}"; do
    case "$cmd" in
    info) info "$input" "$sample" 0 "$frames" "$output" "$batch" "$explicit_plot" ;;
    plot) plot "$input" "$sample" "$explicit_plot" "" "$output" 1 ;;
    shift) frame_shift "$input" "$base_input" >/dev/null ;;
    sync) sync_rpu "$input" "$base_input" "$frame_shift" 1 "$output" >/dev/null ;;
    fix) fix_rpu "$input" 0 "$cuts_clear" "$l5" "$l6" "" "$l6_source" "$json" "$output" >/dev/null ;;
    generate) generate "$input" "$scene_cuts" "$mdl" "$fps" "$l5" "$l5_a" "$l5v" "$l5v_a" "$l6" "$output" >/dev/null ;;
    inject) inject "$input" "$base_input" "$rpu_raw" "$skip_sync" "$frame_shift" "$l5" "$l6" "$cuts_clear" "$output_format" "$output" "$subs" "$title" ;;
    remux) remux "$input" "$output_format" "$output" "$hevc" "$subs" "$title" ;;
    extract) extract "$input" "$sample" "$output_format" "$output" >/dev/null ;;
    cuts) to_rpu_cuts "$input" "$sample" 0 "$output" 1 >/dev/null ;;
    subs) subs "$input" "$output" ;;
    topsubs) topsubs "$input" "$sample" "$fps" ;;
    png) png "$input" "$timestamps" "$output" ;;
    mp3) mp3 "$input" "$sample" "$output" ;;
    edl) edl "$input" "$fps" "$output" ;;
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
