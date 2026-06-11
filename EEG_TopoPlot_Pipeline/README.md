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

Functions:

1. Loads default settings from `config.m`
2. Optionally asks the user for custom settings with `configBuilder.m`
3. Loads the requested averaged ERP data file
4. Computes baseline-corrected scalp values for the selected subject or subjects
5. Creates either a single-subject figure or a multi-subject canvas
6. Saves the figure as a MATLAB `.fig`

The `Data` folder must be on the MATLAB path unless the `EEGDataAvgAcrossTrials_allSubject_cond*.mat` files are already in the current folder.

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
