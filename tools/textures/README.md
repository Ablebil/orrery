# Body Texture Preparation

Builds the surface textures of Io, Europa, Ganymede, Callisto, Titan, Ceres, and Pluto from public-domain global mosaics published by the USGS Astrogeology Science Center. Generated files are bundled with the game.

## Requirements

- [uv](https://docs.astral.sh/uv/)
- Internet access to download about 1 GB of GeoTIFF mosaics. Downloads are cached and verified against the published MD5 checksums.

## Usage

From this directory:

```
uv run prepare_textures.py
```

On Windows without a local Python, run it inside WSL or Linux with `UV_LINK_MODE=copy` when the repository is on a Windows drive.

| Option | Default | Purpose |
|---|---|---|
| `--cache` | `tools/textures/cache` | Download directory for the source mosaics |
| `--output` | `godot/assets/textures/bodies` | Destination for `<id>.jpg` |
| `--only` | all | Body ids to process, for example `--only io pluto` |

## Processing

| Step | Purpose |
|---|---|
| Masked box downsampling to 2048 × 1024 | Averages only pixels that hold imagery, so missing data does not darken the result |
| Pyramid gap filling with horizontal wrap | Fills unimaged areas with blurred surroundings without a seam at the date line |
| Percentile stretch (0.5 % to 99.5 %) | Normalizes brightness across mosaics |
| Two-color tint | Colors grayscale mosaics (Europa, Callisto, Titan, Ceres, Pluto) with approximate true-color tones |
| Recentering | Moves longitude 0 to the image center to match the other body textures |

| Body | Source mosaic |
|---|---|
| Io | `Io_GalileoSSI-Voyager_Global_Mosaic_ClrMerge_1km.tif` |
| Europa | `Europa_Voyager_GalileoSSI_global_mosaic_500m.tif` |
| Ganymede | `Ganymede_Voyager_GalileoSSI_Global_ClrMosaic_1435m.tif` |
| Callisto | `Callisto_Voyager_GalileoSSI_global_mosaic_1km.tif` |
| Titan | `Titan_ISS_P19658_Mosaic_Global_4km.tif` |
| Ceres | `Ceres_Dawn_FC_DLR_global_20ppd_Oct2015.tif` |
| Pluto | `Pluto_NewHorizons_Global_Mosaic_300m_Jul2017_8bit.tif` |
