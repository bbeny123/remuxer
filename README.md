# remuxer

`remuxer` is a *CLI tool* for processing ***Dolby Vision*** videos, with a focus on **CMv4.0 + P7 CMv2.9** hybrid
creation.

> The script is partially based on **[DoVi_Scripts](https://github.com/R3S3t9999/DoVi_Scripts)**

---

## Prerequisites

### Shell

**Requirements:** `Bash 4.0+` and `GNU coreutils`

- On Unix-based systems (**Linux**, **macOS**), these are typically pre-installed.
- On **Windows**, [Git Bash](https://git-scm.com/downloads/win) provides a compatible environment.

> The script was primarily tested on **Windows** (using **Git Bash**), but should also work on other platforms with
> compatible external tool binaries.

### External Tools

All required external tools must be downloaded and placed in the directory specified by the `TOOLS_DIR` variable.
> If a ***non-default directory*** or ***tool names*** are used, update `TOOLS_DIR` variable and the corresponding
`alias` definitions at the top of the script.

- [`jq`](https://jqlang.org/download/) (v1.7.1)
- [`MediaInfo`](https://mediaarea.net/en/MediaInfo/Download) (v25.04)
- [`ffmpeg`](https://ffmpeg.org/download.html) (v7.1.1)
- [`mkvtoolnix`](https://mkvtoolnix.download/downloads.html) (v92.0)
    - `mkvmerge.exe`
    - `mkvextract.exe`
- [`dovi_tool`](https://github.com/quietvoid/dovi_tool/releases) (v2.2.0)
- `dovi_tool` v1.5.3 — the last version supporting `convert_to_cmv4` (required by `inject` command):
    - A **modified build** of `dovi_tool` v1.5.3 is **included** in this
      repository: [tools/dovi_tool_cmv4.exe](tools/dovi_tool_cmv4.exe)
      > This custom version skips injecting default L9 and L11 metadata during RPU conversion to CMv4.  
      > Source: `DoVi_Scripts -> dovi_tool_2.9_to_4.0.exe`  
      > License: [tools/LICENSE-dovi_tool_cmv4](tools/LICENSE-dovi_tool_cmv4) (thanks ***@quietvoid***)

      > **Note:** The original [v1.5.3 release](https://github.com/quietvoid/dovi_tool/releases/tag/1.5.3) *may* also
      work, but it has **not been tested** with `remuxer`.  
      > For full compatibility, using the included modified version is recommended.

> The versions listed above are those with which `remuxer` was tested.  
> Other versions may work, but compatibility is not guaranteed.

### Tab Completion *(Optional)*

To enable tab-completion, run:

```bash
source remuxer_complete.sh
```

By default, completion is configured for the `remuxer` alias.  
If you're using a different alias or command name, either modify the last line in `remuxer_complete.sh`, or run:

```bash
source remuxer_complete.sh
complete -F _remuxer_complete <your_alias>
```

To enable completion permanently, add the appropriate lines to `~/.bash_profile` or `~/.bashrc`.
> **Note:** Use *absolute paths* in shell profiles — relative paths may not resolve correctly.

---

## Configuration

The script’s default behavior can be **customized** using variables defined at the top of the script.  
Most of these variables can also be **overridden** at runtime using the corresponding CLI options.

| Variable<br/>CLI&nbsp;option                | Description                                                                                                                                                       | Allowed&nbsp;values                                                                                  |
|---------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| `OUT_DIR`<br/>*`--out-dir`*                 | Output directory                                                                                                                                                  | *\<path>*<br/>**Default:** `working dir`                                                             |
| `TMP_DIR`<br/>*`--tmp-dir`*                 | Temporary directory for intermediate files<br/>*Will be **auto-removed** if created by the script*                                                                | *\<path>*<br/>**Default:** auto‑created&nbsp;in *`working dir`*                                      |
| `PLOTS_DIR`                                 | L1 plots output directory                                                                                                                                         | *\<path>*<br/>**Default:** same as `OUT_DIR`                                                         |
| `RPU_LEVELS`<br/>*`--rpu-levels`*           | RPU levels used by **inject** command<br/>**Valid RPU levels:** 1-6, 8-11, 254, 255                                                                               | *\<comma-separated RPU levels list>*<br/>**Default:** `3,8,9,11,254` *(CMv4.0 levels)*               |
| `INFO_INTERMEDIATE`<br/>*`--info`*          | Intermediate **info** commands                                                                                                                                    | `0` - disabled<br/>`1` - enabled *(default)*                                                         |
| `INFO_L1_PLOT`<br/>*`--plot`*               | L1 plotting in **info** command                                                                                                                                   | `0` - disabled<br/>`1` - enabled *(default)*                                                         |
| `CLEAN_FILENAMES`<br/>*`--clean-filenames`* | Clean *output* filenames<br/>**Examples:**<br/>&nbsp;&nbsp;**•** *Show.S01E01.HDR* → *Show S01E01*<br/>&nbsp;&nbsp;**•** *A.Movie.2025.2160p.DV* → *A&nbsp;Movie* | `0` - disabled<br/>`1` - enabled *(default)*                                                         |
| `SUBS_AUTODETECTION`<br/>*`--find-subs`*    | Additional subtitles auto-detection                                                                                                                               | `0` - disabled<br/>`1` - enabled *(default)*                                                         |
| `TITLE_SHOWS_AUTO`<br/>*`--auto-title`*     | Generation of **TV shows** metadata title<br/>*(based on **input's filename**)*                                                                                   | `0` - disabled *(default)*<br/>`1` - enabled                                                         |
| `TITLE_MOVIES_AUTO`<br/>*`--auto-title`*    | Generation of **movies** metadata title<br/>*(based on **input's filename**)*                                                                                     | `0` - disabled<br/>`1` - enabled *(default)*                                                         |
| `TRACK_NAMES_AUTO`<br/>*`--auto-tracks`*    | Generation of some metadata track names<br/>**Examples:**<br/>&nbsp;&nbsp;**• audio:** *TrueHD Atmos 7.1*<br/>&nbsp;&nbsp;**• subs:** *Polish*                    | `0` - disabled<br/>`1` - enabled *(default)*                                                         |
| `AUDIO_COPY_MODE`<br/>*`--copy-audio`*      | Input's audio tracks copy mode                                                                                                                                    | `1` - 1st track only<br/>`2` - 1st + compatibility if 1st is *TrueHD*<br/>`3` - all *(default)*<br/> |
| `SUBS_COPY_MODE`<br/>*`--copy-subs`*        | Input's subtitle tracks copy mode                                                                                                                                 | `0` - none<br/>`1` - all *(default)*<br/>`<lng>` - ISO 639-2 lang code based                         |
| `SUBS_LANG_CODES`<br/>*`--lang-codes`*      | Subtitle language ISO 639-2 codes to extract<br/>*(**subs** command only)*                                                                                        | *\<comma-separated ISO 639-2 codes>*<br/>**Default:** `all`                                          |
| `EXTRACT_SHORT_SEC`                         | Sample duration in seconds<br/>*(related with **--sample** option)*                                                                                               | *\<duration in seconds>*<br/>**Default:** `23`                                                       |
| `FFMPEG_STRICT`                             | Controls FFmpeg experimental strict mode<br/>**Note:** Avoid using **untrusted inputs** if `1`                                                                    | `0` - disabled<br/>`1` - enabled *(default)*                                                         |

---

## Usage

```bash
Usage: remuxer [OPTIONS] <COMMAND>

Commands:
  info           Show Dolby Vision information
  plot           Plot L1 dynamic brightness metadata
  frame-shift    Calculate frame shift
  sync           Synchronize Dolby Vision RPU files
  inject         Sync & Inject Dolby Vision RPU
  remux          Remux video file(s)
  extract        Extract DV RPU(s) or .hevc base layer(s)
  cuts           Extract scene-cut frame list(s)
  subs           Extract .srt subtitles
  png            Extract video frame(s) as PNG image(s)
  mp3            Extract audio track(s) as MP3 file(s)

Options:
  -h, --help     Show help (use '--help' for a detailed version)
  -v, --version  Show version

For more information about a command, run:
  remuxer <COMMAND> --help
```

### Common Options

The following ***options*** are available for **<ins>all commands</ins>:**

```bash
Options:
      --out-dir <DIR>  Output files dir path
      --tmp-dir <DIR>  Temp files dir path [will be removed if created]
  -h, --help           Show help (use '--help' for a detailed version)
```

### `info` command

**Description:** Show *Dolby Vision* information

```bash
Usage: remuxer info [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>        Input file/dir path [can be used multiple times]
  -x, --formats <F1,...,FN>  Filter files by format in dir inputs
  -t, --input-type <TYPE>    Filter files by type in dir inputs
  -o, --output <OUTPUT>      Output file path [default: <print to console>]
  -u, --frames <F1,...,FN>   Print RPU info for given frames
  -s, --sample [<SECONDS>]   Process only the first N seconds of input
  -p, --plot <0|1>           Controls L1 plotting in info command
```

### `plot` command

**Description:** Plot L1 dynamic brightness metadata

```bash
Usage: remuxer plot [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>        Input file/dir path [can be used multiple times]
  -x, --formats <F1,...,FN>  Filter files by format in dir inputs
  -t, --input-type <TYPE>    Filter files by type in dir inputs
  -o, --output <OUTPUT>      Output file path [default: generated]
  -s, --sample [<SECONDS>]   Process only the first N seconds of input
```

### `frame-shift` command

**Description:** Calculate *frame shift* of `<input>` relative to `<base-input>`

```bash
Usage: remuxer frame-shift [OPTIONS] --base-input <BASE-INPUT> [INPUT]

Options:
  -i, --input <INPUT>       Input file path
  -b, --base-input <INPUT>  Base input file path [required]
```

### `sync` command

**Description:** Synchronize *RPU* of `<input>` to align with *RPU* of `<base-input>`

```bash
Usage: remuxer sync [OPTIONS] --base-input <BASE-INPUT> [INPUT]

Options:
  -i, --input <INPUT>        Input file path
  -b, --base-input <INPUT>   Base input file path [required]
  -o, --output <OUTPUT>      Output file path [default: generated]
  -f, --frame-shift <SHIFT>  Frame shift value [default: auto-calculated]
  -n, --info <0|1>           Controls intermediate info commands [default: 1]
  -p, --plot <0|1>           Controls L1 plotting in info command [default: 1]
```

### `inject` command

**Description:** Sync & Inject RPU of `<input>` into `<base-input>`

```bash
Usage: remuxer inject [OPTIONS] --base-input <BASE-INPUT> [INPUT]

Options:
  -i, --input <INPUT>           Input file path
  -b, --base-input <INPUT>      Base input file path [required]
  -o, --output <OUTPUT>         Output file path [default: generated]
  -e, --output-format <FORMAT>  Output format [default: auto-detected]
  -q, --skip-sync               Skip RPUs sync (assumes RPUs are already in sync)
  -f, --frame-shift <SHIFT>     Frame shift value [default: auto-calculated]
  -l, --rpu-levels <L1,...,LN>  RPU levels to inject [default: 3,8,9,11,254]
  -w, --raw-rpu                 Inject input RPU instead of transferring levels
  -n, --info <0|1>              Controls intermediate info commands [default: 1]
  -p, --plot <0|1>              Controls L1 plotting in info command [default: 1]

Options for .mkv / .mp4 output:
      --subs <FILE>             .srt subtitle file path to include
      --find-subs <0|1>         Controls subtitles auto-detection [default: 1]
      --copy-subs <OPTION>      Controls input subtitle tracks to copy [default: 1]
      --copy-audio <OPTION>     Controls input audio tracks to copy [default: 3]
      --title <TITLE>           Metadata title (e.g., movie name)
      --auto-title <0|1>        Controls generation of metadata title
      --auto-tracks <0|1>       Controls generation of some track names [default: 1]
  -m, --clean-filenames <0|1>   Controls output filename cleanup [default: 1]
```

### `remux` command

**Description:** Remux `.mkv`, `.mp4`, `.m2ts` or `.ts` file(s)

```bash
Usage: remuxer remux [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>           Input file/dir path [can be used multiple times]
  -x, --formats <F1,...,FN>     Filter files by format in dir inputs
  -t, --input-type <TYPE>       Filter files by type in dir inputs
  -o, --output <OUTPUT>         Output file path [default: generated]
  -e, --output-format <FORMAT>  Output format [default: auto-detected]

Options for .mkv / .mp4 output:
      --subs <FILE>             .srt subtitle file path to include
      --find-subs <0|1>         Controls subtitles auto-detection [default: 1]
      --copy-subs <OPTION>      Controls input subtitle tracks to copy [default: 1]
      --copy-audio <OPTION>     Controls input audio tracks to copy [default: 3]
  -r, --hevc <FILE>             .hevc file path to replace input video track
      --title <TITLE>           Metadata title (e.g., movie name)
      --auto-title <0|1>        Controls generation of metadata title
      --auto-tracks <0|1>       Controls generation of some track names [default: 1]
  -m, --clean-filenames <0|1>   Controls output filename cleanup [default: 1]
```

### `extract` command

**Description:** Extract *Dolby Vision RPU(s)* or `.hevc` base layer(s)

```bash
Usage: remuxer extract [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>           Input file/dir path [can be used multiple times]
  -x, --formats <F1,...,FN>     Filter files by format in dir inputs
  -t, --input-type <TYPE>       Filter files by type in dir inputs
  -o, --output <OUTPUT>         Output file path [default: generated]
  -e, --output-format <FORMAT>  Output format [default: bin]
  -s, --sample [<SECONDS>]      Process only the first N seconds of input
  -n, --info <0|1>              Controls intermediate info commands [default: 1]
  -p, --plot <0|1>              Controls L1 plotting in info command
```

### `cuts` command

**Description:** Extract *scene-cut* frame list(s)

```bash
Usage: remuxer cuts [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>        Input file/dir path [can be used multiple times]
  -x, --formats <F1,...,FN>  Filter files by format in dir inputs
  -t, --input-type <TYPE>    Filter files by type in dir inputs
  -o, --output <OUTPUT>      Output file path [default: generated]
  -s, --sample [<SECONDS>]   Process only the first N seconds of input
```

### `subs` command

**Description:** Extract `.srt` subtitles

```bash
Usage: remuxer subs [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>           Input file/dir path [can be used multiple times]
  -t, --input-type <TYPE>       Filter files by type in dir inputs
  -o, --output <OUTPUT>         Output file path [default: generated]
  -c, --lang-codes <C1,...,CN>  ISO 639-2 lang codes of subtitle tracks to extract
  -m, --clean-filenames <0|1>   Controls output filename cleanup [default: 1]
```

### `png` command

**Description:** Extract *video frame(s)* as `PNG` image(s)

> Useful for checking **Dolby Vision L5** offsets by measuring black bars (e.g., using `MS Paint`)

```bash
Usage: remuxer png [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>        Input file/dir path [can be used multiple times]
  -x, --formats <F1,...,FN>  Filter files by format in dir inputs
  -t, --input-type <TYPE>    Filter files by type in dir inputs
  -o, --output <OUTPUT>      Output file path [default: generated]
  -k, --time [<T1,...TN>]    Approx. frame timestamp(s) in [[HH:]MM:]SS format
```

### `mp3` command

**Description:** Extract *audio track(s)* as `MP3` file(s)

> Useful for checking **audio tracks** alignment (e.g., using
> [***Sonic Visualizer***](https://github.com/sonic-visualiser/sonic-visualiser))

```bash
Usage: remuxer mp3 [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>        Input file/dir path [can be used multiple times]
  -x, --formats <F1,...,FN>  Filter files by format in dir inputs
  -t, --input-type <TYPE>    Filter files by type in dir inputs
  -o, --output <OUTPUT>      Output file path [default: generated]
  -s, --sample [<SECONDS>]   Process only the first N seconds of input
```
