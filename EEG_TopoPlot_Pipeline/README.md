# EEG Topoplot Pipeline

This folder contains the subject-wise and multi-subject scalp topoplot pipeline.

REQUIRES / PREREQS:
- Preprocessing
- Trial averaging for each subject
- The averaged ERP data files used by the ERP pipeline

The inputs to this pipeline are averaged subject files:
- `EEGDataAvgAcrossTrials_allSubject_cond1.mat`
- `EEGDataAvgAcrossTrials_allSubject_cond4.mat`
- `EEGDataAvgAcrossTrials_allSubject_cond5.mat`

The same data-preparation, baseline-correction, condition-selection, interpolation, and head-template code is used for both plot modes:

- **single-subject mode**: one subject, with one or more topoplot conditions/contrasts
- **multi-subject mode**: multiple subjects drawn on the same canvas with a shared color scale

---

## Note on Data Structure

The input files named `EEGDataAvgAcrossTrials_allSubject_cond1/4/5.mat` contain separate subject entries, but within each subject, the trial dimension has already been averaged away. The data are organized like this:

```text
EEGDataAvgAcrossTrials_allSubject_cond1.mat
  EEGDataAvg
    Sub1_cond1
      ExpwithSensPrim          = 64 channels x 5222 time
      ExpwithoutSensPrim       = 64 channels x 5222 time
      UnexpwithSensPrim        = 64 channels x 5222 time
      UnexpwithoutSensPrim     = 64 channels x 5222 time
      Atonal                   = 64 channels x 5222 time
    Sub2_cond1
      same 5 trial-category fields
    ...
```

For topoplot generation, the pipeline converts each selected subject and each selected condition/contrast into:

```text
selected subject waveform: channels x time
baseline-corrected window: channels x selected time window
topoplot values:           channels x 1
```

The final scalp map shows one value per electrode/channel. In multi-subject mode, this same computation is repeated across the selected subjects and then arranged onto one tiled figure.

---

## Filtering Conditions

The pipeline uses three filtering condition files:

| Condition number | Label |
|---:|---|
| 1 | Broadband |
| 4 | Low High |
| 5 | High Low |

The default is:

```matlab
cfg.conditionNumber = 1;
```

---

## Topoplot Conditions / Contrasts

Each subject-condition structure is expected to contain these fields:

- `ExpwithSensPrim`
- `ExpwithoutSensPrim`
- `UnexpwithSensPrim`
- `UnexpwithoutSensPrim`
- `Atonal`

The topoplot pipeline can plot:

- `Exp_withSP`
- `Unexp_withSP`
- `Diff_withSP`
- `Exp_noSP`
- `Unexp_noSP`
- `Diff_noSP`
- `Atonal`

The difference waves are computed internally:

- `Diff_withSP = UnexpwithSensPrim - ExpwithSensPrim`
- `Diff_noSP = UnexpwithoutSensPrim - ExpwithoutSensPrim`

The default is:

```matlab
cfg.plotConditions = {'Diff_withSP'};
```

---

## Main Entry Point

### `main.m`

Main script for the topoplot pipeline.

It:

1. Loads default settings from `config.m`
2. Optionally asks the user for custom settings with `configBuilder.m`
3. Loads the requested averaged ERP data file
4. Computes baseline-corrected scalp values for the selected subject or subjects
5. Creates either a single-subject figure or a multi-subject canvas
6. Saves the figure as a MATLAB `.fig`

To run:

```matlab
cd('path/to/Mehta/EEG_TopoPlot')
addpath('path/to/Mehta/Data')
main
```

The `Data` folder must be on the MATLAB path unless the `EEGDataAvgAcrossTrials_allSubject_cond*.mat` files are already in the current folder.

---

## Frame Series Generator

Animation-related helper files live in:

```text
topoplot_animation
```

These files are separate from the main subject-wise and multi-subject topoplot pipeline. They reuse the main topoplot functions, but only for generating, renaming, or inspecting animation frames.

### `topoplotFrameSeries.m`

Standalone helper for generating a sequence of multi-subject topoplot frames.

This file is not called by `main.m`. It is meant for cases where you want to make many manually saved frames and later assemble them into a pseudo-video.
By default, it walks through the frame-series settings interactively. Press Enter at the first prompt to answer each parameter question, or type `y` to use the default frame-series settings.

To run:

```matlab
cd('path/to/Mehta/EEG_TopoPlot/topoplot_animation')
addpath('path/to/Mehta/Data')
topoplotFrameSeries
```

It asks for:

- whether to use the default frame-series settings
- subject indices
- filtering condition
- condition/contrast to plot
- first window start
- last window start
- window width
- window-start increment
- output folder

Default frame settings:

```text
first window start     = 3100
last window start      = 3700
window width           = 50
window-start increment = 20
multi-subject columns  = 5
maximize before saving = yes
wait after maximizing  = 20 seconds
PNG export resolution  = 150
show channel labels    = yes
electrode dot size     = 10
save .fig files        = no
color scale            = fixed across all frames
```

Before saving, this helper prepares every requested time window once and computes one shared symmetric color scale across the full frame series. That shared scale is then reused for every PNG, so the colorbar does not change from frame to frame.

Example generated windows:

```text
3100:3150
3120:3170
3140:3190
...
3700:3750
```

The output folder is cleaned every time `topoplotFrameSeries.m` runs. By default, frames are saved into:

```text
topoplot_animation/topoplot_frames
```

Example filename:

```text
frame_0001_3100_3150.png
```

### `prepareFramesForPhotoshop.m`

Small helper for copying generated frame files into Photoshop-friendly names.

Run:

```matlab
cd('path/to/Mehta/EEG_TopoPlot/topoplot_animation')
prepareFramesForPhotoshop
```

It copies files from:

```text
topoplot_animation/topoplot_frames
```

into:

```text
topoplot_animation/topoplot_frames_photoshop
```

with simple names:

```text
frame_0001.png
frame_0002.png
frame_0003.png
```

Then in Photoshop, use `File > Open`, select `frame_0001.png`, check `Image Sequence`, and open it.

### `topoplotFrameViewer.m`

Small MATLAB viewer for inspecting generated frames with exact frame-by-frame control.

Run:

```matlab
cd('path/to/Mehta/EEG_TopoPlot/topoplot_animation')
topoplotFrameViewer
```

By default, it opens frames from:

```text
topoplot_animation/topoplot_frames
```

Controls:

- slider: move to a specific frame
- `Prev` / `Next`: move one frame at a time
- left/right arrow keys: move one frame at a time
- hold left/right arrow keys: continuously step frames until the key is released
- frame number box: jump to an exact frame

This is better than Photoshop for scientific inspection because one slider step equals exactly one saved PNG frame.

---

## Configuration Files

### `config.m`

Defines the default settings for the pipeline. It includes:

- plot mode
- filtering condition number
- subject index or subject list
- topoplot window start
- topoplot window width
- chord onset locations
- baseline length before chord onset
- selected condition/contrast
- output folder
- whether to use interactive configuration

Default settings:

```matlab
cfg.plotMode = 'single';
cfg.conditionNumber = 1;
cfg.subjectIndices = 1;
cfg.windowStart_remap = 3100;
cfg.windowWidth_remap = 50;
cfg.plotConditions = {'Diff_withSP'};
```

### `configBuilder.m`

Interactive helper for custom topoplots.

It asks for:

- plot mode: single subject or multi-subject
- subject index or subject list
- filtering condition
- topoplot window start
- topoplot window width
- condition/contrast to plot

---

## Time Window and Baseline

The pipeline uses the same internal remapped time coordinate convention as the ERP pipeline.

The topoplot window is defined by:

```matlab
cfg.windowStart_remap
cfg.windowWidth_remap
```

For example:

```matlab
cfg.windowStart_remap = 3100;
cfg.windowWidth_remap = 50;
```

gives:

```text
topoplot window = 3100:3150
```

The chord onsets are hard-coded in `config.m`:

```matlab
cfg.chordOnsets_remap = [100, 600, 1100, 1600, 2100, 2600, 3100];
```

The pipeline automatically finds the closest chord onset at or before the topoplot window start. It then uses the 100 remapped units immediately before that chord onset as the baseline.

For example, if:

```text
topoplot window = 3100:3150
```

then:

```text
selected chord onset = 3100
baseline window = 3000:3099
```

Each channel is baseline-corrected before the selected time window is averaged.

---

## Pipeline Steps

### `loadData.m`

Loads the selected `EEGDataAvgAcrossTrials_allSubject_cond*.mat` file.

### `scalpValues.m`

Prepares the channel values that will be drawn on the scalp.

This function:

1. Selects the requested subject or subjects
2. Selects the requested condition or contrast
3. Finds the relevant chord onset
4. Computes the baseline window
5. Baseline-corrects each channel
6. Averages the selected topoplot time window

For one subject, it returns:

```text
channels x conditions
```

For multiple subjects, it returns:

```text
channels x conditions x subjects
```

### `timeWindow.m`

Maps a remapped time window back to the original sample indices.

### `plotFigure.m`

Creates the figure canvas.

For one subject, it can draw:

- one scalp map if one condition/contrast is selected
- one row of scalp maps if multiple conditions/contrasts are selected

For multiple subjects, it draws:

- one tiled canvas with every selected subject
- one shared color scale across all subjects and conditions
- a default 3 x 5 layout when subjects `1:15` are selected

### `saveFigure.m`

Saves the generated figure as a MATLAB `.fig` file.

---

## Plotting Files

### `scalpMapPanel.m`

Draws one scalp map into one axes/panel.

It handles:

- color scaling
- heatmap display
- electrode dots
- electrode labels
- optional colorbar

### `scalpInterpolation.m`

Interpolates electrode values across the scalp.

This is where the heatmap smoothness settings live, including:

- interpolation grid resolution
- virtual boundary points
- circular mask
- contour levels

### `headTemplate.m`

Draws the topoplot head template:

- head circle
- nose
- ears

This is the file to edit if the head shape, nose, or ears need adjustment.

### `channelLayout.m`

Defines the 64-channel label order and approximate XY coordinates used for plotting.

---

## Expected Outputs

Single-subject figures are saved into:

```text
topo_subjectwise
```

Example filename:

```text
Topo_Subj1_Sub1_cond1_cond1_Diff_withSP_3100_3150.fig
```

Multi-subject figures are saved into:

```text
topo_multisubject
```

Example filename:

```text
Topo_MultiSubj_Subj1-15_cond1_nCond1_Diff_withSP_3100_3150.fig
```

The output figure title includes:

- subject label, or number of subjects
- selected topoplot condition/contrast
- topoplot time window
- selected chord onset
- baseline window
