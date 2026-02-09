# remuxer

`remuxer` is a *CLI tool* for processing ***DV*** videos, with a focus on **CMv4.0 + P7 CMv2.9** hybrid
creation.

> The script is partially based on **[DoVi_Scripts](https://github.com/R3S3t9999/DoVi_Scripts)**

---

## Prerequisites

### Shell

**Requirements:** `Bash 4.1+` and `GNU coreutils`

- On Unix-based systems (**Linux**, **macOS**), these are typically pre-installed.
- On **Windows**, [Git Bash](https://git-scm.com/downloads/win) provides a compatible environment.

> The script was primarily tested on **Windows** (using **Git Bash**), but should also work on other platforms with
> compatible external tool binaries.

### External Tools

All required external tools must be downloaded and placed in the directory specified by the `TOOLS_DIR` variable.
> **Note:** If a ***non-default directory*** or ***tool names*** are used, update `TOOLS_DIR` variable and the
> corresponding `alias` definitions at the top of the script.

- [`jq`](https://jqlang.org/download/) (v1.7.1)
- [`MediaInfo`](https://mediaarea.net/en/MediaInfo/Download) (v25.04)
- [`ffmpeg`](https://ffmpeg.org/download.html) (v7.1.1)
- [`mkvtoolnix`](https://mkvtoolnix.download/downloads.html) (v92.0)
    - `mkvmerge.exe`
    - `mkvextract.exe`
- [`dovi_tool`](https://github.com/quietvoid/dovi_tool/releases) (v2.3.0)
- [`cm_analyze`](https://customer.dolby.com/content-creation-and-delivery/dolby-vision-professional-tools) (v5.6.1) — optional (used by `generate` command)
- `extract` (ProRes) & `generate` commands (FEL input):
    - [VapourSynth](https://www.vapoursynth.com) (R73)
        - `vspipe.exe`
        - [ffms2](https://github.com/FFMS/ffms2/releases) VS plugin (v5.0)
        - [FelBaker](https://github.com/bbeny123/felbaker/releases) VS plugin (v1.0.0)
- `topsubs` command only:
    - [`Java JRE/JDK`](https://adoptium.net/temurin/releases?version=21&mode=filter&os=any&arch=any) (v21.0.7)
    - [`BDSup2Sub`](https://github.com/mjuhasz/BDSup2Sub) (v5.1.2 [`.jar`](https://raw.githubusercontent.com/wiki/mjuhasz/BDSup2Sub/downloads/BDSup2Sub.jar))

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

| Variable<br/>CLI&nbsp;option                          | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Allowed&nbsp;values                                                                                                                                                                                                                           |
|-------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `OUT_DIR`<br/>*`--out-dir`*                           | Output directory                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | *\<path>*<br/>**Default:** `working dir`                                                                                                                                                                                                      |
| `TMP_DIR`<br/>*`--tmp-dir`*                           | Temporary directory for intermediate files<br/>*Will be **auto-removed** if created by the script*                                                                                                                                                                                                                                                                                                                                                                                                                                  | *\<path>*<br/>**Default:** auto‑created&nbsp;in *`working dir`*                                                                                                                                                                               |
| `PLOTS_DIR`                                           | L1 plots output directory                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | *\<path>*<br/>**Default:** same as `OUT_DIR`                                                                                                                                                                                                  |
| `RPU_LEVELS`<br/>*`--levels`*                         | RPU levels used by **inject** command<br/>**Valid RPU levels:** 1-6, 8-11, 254, 255                                                                                                                                                                                                                                                                                                                                                                                                                                                 | *\<comma-separated RPU levels list>*<br/>**Default:** `3,8,9,11,254` *(CMv4.0 levels)*                                                                                                                                                        |
| `INFO_INTERMEDIATE`<br/>*`--info`*                    | Intermediate **info** commands                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `0` - disabled<br/>`1` - enabled *(default)*                                                                                                                                                                                                  |
| `PLOT_DEFAULT`<br/>*`--plot`*                         | Default plotting mode<br/>**Valid values:**<table><tbody><tr><td>**0** / **none**</td><td>none</td></tr><tr><td>**1** / **all**</td><td>all available</td></tr><tr><td>**L1**</td><td>L1 Dynamic Brightness</td></tr><tr><td>**L2[_NITS]**</td><td>L2 Trims</td></tr><tr><td>**L8T[_NITS]**</td><td>L8 Trims</td></tr><tr><td>**L8S[_NITS]**</td><td>L8 Saturation Vectors</td></tr><tr><td>**L8H[_NITS]**</td><td>L8 Hue Vectors</td></tr><tr><td colspan="2">`NITS` - 100 *(default)*, 600, 1000 or MAX</td></tr></tbody></table> | *\<comma-separated list>*<br/>**Default:** `L1,L2,L2_MAX,L8T`                                                                                                                                                                                 |
| `FIX_CUTS_FIRST`<br/>*`--cuts-first`*                 | Force first frame as scene-cut                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `0` - disabled<br/>`1` - enabled *(default)*                                                                                                                                                                                                  |
| `FIX_CUTS_CONSEC`<br/>*`--cuts-consecutive`*          | Consecutive scene-cuts fixing                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `0` - disabled<br/>`1` - enabled *(default)*                                                                                                                                                                                                  |
| `CLEAN_FILENAMES`<br/>*`--clean-filenames`*           | Clean *output* filenames<br/>**Examples:**<br/>&nbsp;&nbsp;**•** *Show.S01E01.HDR* → *Show S01E01*<br/>&nbsp;&nbsp;**•** *A.Movie.2025.2160p.DV* → *A&nbsp;Movie*                                                                                                                                                                                                                                                                                                                                                                   | `0` - disabled<br/>`1` - enabled *(default)*                                                                                                                                                                                                  |
| `SUBS_AUTODETECTION`<br/>*`--subs-find`*              | Additional subtitles auto-detection                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | `0` - disabled<br/>`1` - enabled *(default)*                                                                                                                                                                                                  |
| `TITLE_SHOWS_AUTO`<br/>*`--title-auto`*               | Generation of **TV shows** metadata title<br/>*(based on **input's filename**)*                                                                                                                                                                                                                                                                                                                                                                                                                                                     | `0` - disabled *(default)*<br/>`1` - enabled                                                                                                                                                                                                  |
| `TITLE_MOVIES_AUTO`<br/>*`--title-auto`*              | Generation of **movies** metadata title<br/>*(based on **input's filename**)*                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `0` - disabled<br/>`1` - enabled *(default)*                                                                                                                                                                                                  |
| `TRACK_NAMES_AUTO`<br/>*`--tracks-auto`*              | Generation of some metadata track names<br/>**Examples:**<br/>&nbsp;&nbsp;**• audio:** *TrueHD Atmos 7.1*<br/>&nbsp;&nbsp;**• subs:** *Polish*                                                                                                                                                                                                                                                                                                                                                                                      | `0` - disabled<br/>`1` - enabled *(default)*                                                                                                                                                                                                  |
| `AUDIO_COPY_MODE`<br/>*`--audio-copy`*                | Input's audio tracks copy mode                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `1` - 1st track only<br/>`2` - 1st + compatibility if 1st is *TrueHD*<br/>`3` - all *(default)*<br/>                                                                                                                                          |
| `SUBS_COPY_MODE`<br/>*`--subs-copy`*                  | Input's subtitle tracks copy mode                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `0` - none<br/>`1` - all *(default)*<br/>`<lng>` - ISO 639-2 lang code based                                                                                                                                                                  |
| `SUBS_LANG_CODES`<br/>*`--lang`*                      | Subtitle language ISO 639-2 codes to extract<br/>*(**subs** command only)*                                                                                                                                                                                                                                                                                                                                                                                                                                                          | *\<comma-separated ISO 639-2 codes>*<br/>**Default:** `all`                                                                                                                                                                                   |
| `TOPSUBS_LANG_CODES`<br/>*`--lang`*                   | Subtitle language ISO 639-2 codes to process<br/>*(**topsubs** command only)*                                                                                                                                                                                                                                                                                                                                                                                                                                                       | *\<comma-separated ISO 639-2 codes>*<br/>**Default:** `all`                                                                                                                                                                                   |
| `TOPSUBS_MAX_OFFSET`<br/>*`--max-y`*                  | Y offset to consider subs as top-positioned<br/>*(**topsubs** command only)*                                                                                                                                                                                                                                                                                                                                                                                                                                                        | *\<offset in pixels>*<br/>**Default:** `600`                                                                                                                                                                                                  |
| `PRORES_PROFILE`<br/>`PRORES_MACOS`<br/>*`--profile`* | Default **ProRes** encoding profile by encoder:<br/>&nbsp;&nbsp;**•** `PRORES_PROFILE` → `prores_ks`<br/>&nbsp;&nbsp;**•** `PRORES_MACOS` → `prores_videotoolbox`                                                                                                                                                                                                                                                                                                                                                                   | `0` - 422 Proxy<br/>`1` - 422 LT<br/>`2` - 422 *(default `PRORES_MACOS`)*<br/>`3` - 422 HQ *(default `PRORES_PROFILE`)*<br/>`4` - 4444<br/>`5` - 4444 XQ                                                                                      |
| `L1_TUNING`<br/>*`--tuning`*                          | **DV L1** analysis tuning                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `0` / `legacy` - Legacy CM4<br/>`1` / `most` - Most Highlight Detail<br/>`2` / `more` - More Highlight Detail<br/>`3` / `balanced` - Balanced *(default)*<br/>`4` / `less` - Less Highlight Detail<br/>`5` / `least` - Least Highlight Detail |
| `EXTRACT_SHORT_SEC`                                   | Sample duration in seconds<br/>*(related with **--sample** option)*                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | *\<duration in seconds>*<br/>**Default:** `23`                                                                                                                                                                                                |
| `FFMPEG_STRICT`                                       | Controls FFmpeg experimental strict mode<br/>**Note:** Avoid using **untrusted inputs** if `1`                                                                                                                                                                                                                                                                                                                                                                                                                                      | `0` - disabled<br/>`1` - enabled *(default)*                                                                                                                                                                                                  |
| `FELBAKER_PATH`                                       | Absolute path to `FelBaker` **VS plugin**<br/>_If empty, plugin must be auto-detected by **VS**_                                                                                                                                                                                                                                                                                                                                                                                                                                    | *\<abosulte path>*<br/>**Default:** `felbaker.dll`                                                                                                                                                                                            |
| `FFMS2_PATH`                                          | Absolute path to `FFMS2` **VS plugin**<br/>_If empty, plugin must be auto-detected by **VS**_                                                                                                                                                                                                                                                                                                                                                                                                                                       | *\<abosulte path>*<br/>**Default:** `ffms2.dll`                                                                                                                                                                                               |
| `FFMS2_THREADS`                                       | Number of decoding threads used by `FFMS2`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | *\<threads number>*<br/>**Default:** `4`                                                                                                                                                                                                      |

---

## Usage

```bash
Usage: remuxer [OPTIONS] <COMMAND>

Commands:
  info           Show DV information
  plot           Plot L1/L2/L8 metadata
  shift          Calculate frame shift
  sync           Synchronize DV RPU files
  fix            Fix or adjust DV RPU(s)
  generate       Generate DV P8 RPU for HDR10 video(s)
  inject         Sync & Inject DV RPU
  remux          Remux video file(s)
  extract        Extract RPU(s) or base layer(s), or convert to ProRes
  cuts           Extract scene-cut frame list(s)
  subs           Extract .srt subtitles
  topsubs        Extract top-positioned PGS subtitles
  png            Extract video frame(s) as PNG image(s)
  mp3            Extract audio track(s) as MP3 file(s)
  edl            Convert scene-cut list between .txt and .edl

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

**Description:** Show *DV* information

```bash
Usage: remuxer info [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>       Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>  Filter files by format in dir inputs
  -t, --input-type <TYPE>   Filter files by type in dir inputs
  -o, --output <OUTPUT>     Output file path [default: <print to console>]
  -u, --frames <F1[,...]>   Print RPU info for given frames
  -s, --sample [<SECONDS>]  Process only the first N seconds of input
  -p, --plot <P1[,...]>     Controls L1/L2/L8 intermediate plotting
```

### `plot` command

**Description:** Plot **L1/L2/L8** metadata

```bash
Usage: remuxer plot [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>       Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>  Filter files by format in dir inputs
  -t, --input-type <TYPE>   Filter files by type in dir inputs
  -o, --output <OUTPUT>     Output file path [default: generated]
  -s, --sample [<SECONDS>]  Process only the first N seconds of input
  -p, --plot <P1[,...]>     Controls L1/L2/L8 plotting
```

### `shift` command

**Description:** Calculate *frame shift* of `<input>` relative to `<base-input>`

```bash
Usage: remuxer shift [OPTIONS] --base-input <BASE-INPUT> [INPUT]

Options:
  -i, --input <INPUT>       Input file path
  -b, --base-input <INPUT>  Base input file path [required]
```

### `sync` command

**Description:** Synchronize *RPU* of `<input>` to align with *RPU* of `<base-input>`

```bash
Usage: remuxer sync [OPTIONS] --base-input <BASE-INPUT> [INPUT]

Options:
  -i, --input <INPUT>       Input file path
  -b, --base-input <INPUT>  Base input file path [required]
  -o, --output <OUTPUT>     Output file path [default: generated]
  -f, --shift <SHIFT>       Frame shift value [default: auto-calculated]
  -n, --info <0|1>          Controls intermediate info commands [default: 1]
  -p, --plot <P1[,...]>     Controls L1/L2/L8 intermediate plotting
```

### `fix` command

**Description:** Fix or adjust *DV RPU(s)*

```bash
Usage: remuxer fix [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>             Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>        Filter files by format in dir inputs
  -t, --input-type <TYPE>         Filter files by type in dir inputs
  -o, --output <OUTPUT>           Output file path [default: generated]
      --l5 <T,B[,L,R]>            Set DV L5 active area offsets
      --l6 <MAX_CLL,MAX_FALL>     Set DV L6 MaxCLL/MaxFALL
      --l6-source <FILE>          File path to use for L6 MaxCLL/FALL detection
      --cuts-clear <FS-FE[,...]>  Clear scene-cut flag in specified frame ranges
      --cuts-first <0|1>          Force first frame as scene-cut [default: 1]
      --cuts-consecutive <0|1>    Controls consecutive scene-cuts fixing [default: 1]
  -j, --json <FILE>               JSON config file path (applied before auto-fixes)
      --json-example              Show examples for --json option
  -n, --info <0|1>                Controls intermediate info commands [default: 1]
```

### `generate` command

**Description:** Generate *DV P8 RPU* for *HDR10* video(s)

```bash
Usage: remuxer generate [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>            Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>       Filter files by format in dir inputs
  -t, --input-type <TYPE>        Filter files by type in dir inputs
  -o, --output <OUTPUT>          Output file path [default: generated]
      --profile <0-5>            Controls ProRes encoding profile (0 = Proxy, 5 = 4444 XQ)
      --el <FILE>                EL .hevc [req. matching P7 FEL .hevc BL input]
      --cuts <FILE>              Scene-cuts file path [default: extracted from input]
      --tuning <0-5>             Controls L1 analysis tuning [default: balanced]
      --fps <FPS>                Frame rate [default: auto-detected]
      --mdl <MDL>                Mastering display [default: auto-detected]
      --l5 <T,B[,L,R]>           DV L5 active area offsets
      --l5-analysis <T,B[,L,R]>  L5 active area offsets (for analysis only)
      --l5v <FILE>               Variable L5 metadata JSON config
      --l5v-analysis <FILE>      Variable L5 metadata JSON config (for analysis only)
      --l5v-example              Show example JSON for --l5v/--l5v-analysis
      --l6 <MAX_CLL,MAX_FALL>    DV L6 MaxCLL/MaxFALL
      --cuts-first <0|1>         Force first frame as scene-cut [default: 1]
      --cuts-consecutive <0|1>   Controls consecutive scene-cuts fixing [default: 1]
  -n, --info <0|1>               Controls intermediate info commands [default: 1]
  -p, --plot <P1[,...]>          Controls L1/L2/L8 intermediate plotting
```

### `inject` command

**Description:** Sync & Inject RPU of `<input>` into `<base-input>`

```bash
Usage: remuxer inject [OPTIONS] --base-input <BASE-INPUT> [INPUT]

Options:
  -i, --input <INPUT>             Input file path
  -b, --base-input <INPUT>        Base input file path [required]
  -o, --output <OUTPUT>           Output file path [default: generated]
  -e, --output-format <FORMAT>    Output format [default: auto-detected]
  -q, --synced                    Skip RPUs sync (assumes RPUs are already in sync)
  -f, --shift <SHIFT>             Frame shift value [default: auto-calculated]
  -l, --levels <L1[,...]>         RPU levels to inject [default: 3,8,9,11,254]
  -w, --raw-rpu                   Inject input RPU instead of transferring levels
      --l5 <T,B[,L,R]>            Set DV L5 active area offsets
      --l6 <MAX_CLL,MAX_FALL>     Set DV L6 MaxCLL/MaxFALL
      --cuts-clear <FS-FE[,...]>  Clear scene-cut flag in specified frame ranges
      --cuts-first <0|1>          Force first frame as scene-cut [default: 1]
      --cuts-consecutive <0|1>    Controls consecutive scene-cuts fixing [default: 1]
  -n, --info <0|1>                Controls intermediate info commands [default: 1]
  -p, --plot <P1[,...]>           Controls L1/L2/L8 intermediate plotting

Options for .mkv / .mp4 output:
      --subs <FILE>               .srt subtitle file path to include
      --subs-find <0|1>           Controls subtitles auto-detection [default: 1]
      --subs-copy <0|1|LNG>       Controls input subtitle tracks to copy [default: 1]
      --audio-copy <1|2|3>        Controls input audio tracks to copy [default: 3]
      --title <TITLE>             Metadata title (e.g., movie name)
      --title-auto <0|1>          Controls generation of metadata title
      --tracks-auto <0|1>         Controls generation of some track names [default: 1]
  -m, --clean-filenames <0|1>     Controls output filename cleanup [default: 1]
```

### `remux` command

**Description:** Remux `.mkv`, `.mp4`, `.m2ts` or `.ts` file(s)

```bash
Usage: remuxer remux [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>           Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>      Filter files by format in dir inputs
  -t, --input-type <TYPE>       Filter files by type in dir inputs
  -o, --output <OUTPUT>         Output file path [default: generated]
  -e, --output-format <FORMAT>  Output format [default: auto-detected]

Options for .mkv / .mp4 output:
      --subs <FILE>             .srt subtitle file path to include
      --subs-find <0|1>         Controls subtitles auto-detection [default: 1]
      --subs-copy <0|1|LNG>     Controls input subtitle tracks to copy [default: 1]
      --audio-copy <1|2|3>      Controls input audio tracks to copy [default: 3]
  -r, --hevc <FILE>             .hevc file path to replace input video track
      --title <TITLE>           Metadata title (e.g., movie name)
      --title-auto <0|1>        Controls generation of metadata title
      --tracks-auto <0|1>       Controls generation of some track names [default: 1]
  -m, --clean-filenames <0|1>   Controls output filename cleanup [default: 1]
```

### `extract` command

**Description:** Extract *DV RPU(s)* or `.hevc` base layer(s), or convert to **ProRes** (`.mov`)

```bash
Usage: remuxer extract [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>           Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>      Filter files by format in dir inputs
  -t, --input-type <TYPE>       Filter files by type in dir inputs
  -o, --output <OUTPUT>         Output file path [default: generated]
  -e, --output-format <FORMAT>  Output format [default: bin]
  -s, --sample [<SECONDS>]      Process only the first N seconds of input
      --profile <0-5>           Controls ProRes encoding profile (0 = Proxy, 5 = 4444 XQ)
      --el <FILE>               EL .hevc [req. .mov output + matching P7 FEL .hevc BL input]
  -n, --info <0|1>              Controls intermediate info commands [default: 1]
  -p, --plot <P1[,...]>         Controls L1/L2/L8 intermediate plotting
```

### `cuts` command

**Description:** Extract *scene-cut* frame list(s)

```bash
Usage: remuxer cuts [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>       Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>  Filter files by format in dir inputs
  -t, --input-type <TYPE>   Filter files by type in dir inputs
  -o, --output <OUTPUT>     Output file path [default: generated]
  -s, --sample [<SECONDS>]  Process only the first N seconds of input
```

### `subs` command

**Description:** Extract `.srt` subtitles

```bash
Usage: remuxer subs [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>          Input file/dir path [can be used multiple times]
  -t, --input-type <TYPE>      Filter files by type in dir inputs
  -o, --output <OUTPUT>        Output file path [default: generated]
  -c, --lang <C1[,...]>        ISO 639-2 lang codes of subtitle tracks to extract
  -m, --clean-filenames <0|1>  Controls output filename cleanup [default: 1]
```

### `topsubs` command

**Description:** Extract **top-positioned** `PGS` subtitles

```bash
Usage: remuxer topsubs [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>       Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>  Filter files by format in dir inputs
  -t, --input-type <TYPE>   Filter files by type in dir inputs
  -s, --sample [<SECONDS>]  Process only the first N seconds of input
      --fps <FPS>           Frame rate [default: auto-detected]
  -c, --lang <C1[,...]>     ISO 639-2 lang codes of subtitle tracks to process
      --max-y <MAX_OFFSET>  Maximum Y offset to consider subs as top-positioned
```

### `png` command

**Description:** Extract *video frame(s)* as `PNG` image(s)

> Useful for checking **DV L5** offsets by measuring black bars (e.g., using `MS Paint`)

```bash
Usage: remuxer png [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>       Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>  Filter files by format in dir inputs
  -t, --input-type <TYPE>   Filter files by type in dir inputs
  -o, --output <OUTPUT>     Output file path [default: generated]
  -k, --time [<T1[,...]>]   Approx. frame timestamp(s) in [[HH:]MM:]SS format
```

### `mp3` command

**Description:** Extract *audio track(s)* as `MP3` file(s)

> Useful for checking **audio tracks** alignment (e.g., using
> [***Sonic Visualizer***](https://github.com/sonic-visualiser/sonic-visualiser))

```bash
Usage: remuxer mp3 [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>       Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>  Filter files by format in dir inputs
  -t, --input-type <TYPE>   Filter files by type in dir inputs
  -o, --output <OUTPUT>     Output file path [default: generated]
  -s, --sample [<SECONDS>]  Process only the first N seconds of input
```

### `edl` command

**Description:** Convert *scene-cut list* between `.txt` and `.edl`

```bash
Usage: remuxer edl [OPTIONS] [INPUT...]

Options:
  -i, --input <INPUT>       Input file/dir path [can be used multiple times]
  -x, --formats <F1[,...]>  Filter files by format in dir inputs
  -t, --input-type <TYPE>   Filter files by type in dir inputs
  -o, --output <OUTPUT>     Output file path [default: generated]
      --fps <FPS>           Frame rate [default: 23.976]
```
