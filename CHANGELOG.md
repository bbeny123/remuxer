### 2.0.0

- **New commands:**
    - `fix`: Fix or adjust _Dolby Vision RPU(s)_
    - `generate`: Generate _Dolby Vision P8 RPU_ for _HDR10_ video(s)
    - `png`: Extract _video frame(s)_ as `PNG` image(s)
    - `mp3`: Extract _audio track(s)_ as `MP3` file(s)
    - `edl`: Convert _scene-cut_ list between `.txt` and `.edl`
- **Rewritten info command:**
    - New option: `--frames` – print RPU info for selected frames
    - Added support for `--output` option
    - More detailed output
    - Improved performance
- `inject` **command:**
    - New option: `--raw-rpu` – injects input RPU (without making hybrid RPU)
- `extract` **command:**
    - Added support for extracting `.hevc` _base layer_
    - Added support for converting to **ProRes** (`.mov`)
- `plot` **command:**
    - Added support for plotting **L2** and **L8 metadata**
- Increased max tested offset during frame shift calculation
- **Shell tab-completion:** suggests only files with matching extensions
- Bug fixes
- Logging improvements
- Updated for `dovi_tool 2.2.0+` features

### 1.0.3

- Added experimental support for `.m2ts` and `.ts` inputs
- Added optional sample length argument to the `--sample` option

### 1.0.2

- `inject` command logging improvements

### 1.0.1

- `info` command optimizations

### 1.0.0

- Initial version