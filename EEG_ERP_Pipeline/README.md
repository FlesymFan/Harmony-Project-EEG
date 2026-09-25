# EEG ERP Pipeline

This folder contains the ERP visualization pipeline for the Mehta Harmony / Context EEG project. It assumes that EEG preprocessing has already been completed, and it starts from subject-level ERP files:

![ERP pipeline dependency diagram](erp_pipeline_diagram.svg)

Editable diagram source: `erp_pipeline_diagram.drawio`

- `EEGDataAvgAcrossTrials_allSubject_cond1.mat`
- `EEGDataAvgAcrossTrials_allSubject_cond4.mat`
- `EEGDataAvgAcrossTrials_allSubject_cond5.mat`

In these files, each subject has already been averaged across trials within each trial category. In other words, the pipeline starts after the single-trial EEG data have been reduced to one ERP waveform per subject, condition, and trial category.

The original cohort contains these 15 subjects:

`Sub1, Sub2, Sub5, Sub6, Sub8, Sub9, Sub10, Sub11, Sub12, Sub13, Sub14, Sub16, Sub17, Sub19, Sub20`

The later cohort contains `Sub24` through `Sub28`. The number of subjects plotted
depends on which subject fields are present in the selected averaged files; it is
not fixed by this README. This pipeline does not correct differences in stimulus
timing between cohorts, so verify timing compatibility before interpreting a
pooled time-locked waveform.

## Data Level

This ERP pipeline does not start from raw `.bdf` files or single-trial epoched data. It starts from subject-level averaged ERP data.

The data flow is:

1. Raw EEG recording for one subject and run
2. Preprocessed epoched EEG data for each trial
3. Trials grouped by condition and trial category
4. Trials averaged within each subject, condition, and trial category
5. ERP plotting across the included subjects

The files named `EEGDataAvgAcrossTrials_allSubject_cond*.mat` correspond to step 4. They still contain separate subject entries, but within each subject the trial dimension has already been averaged away.

The ERP plotting code then computes grand-average waveforms and standard error across subjects.

Each averaged condition file is organized like this:

```text
EEGDataAvgAcrossTrials_allSubject_cond1.mat
  EEGDataAvg
    Sub1_cond1
      ExpwithSensPrim          = channels x time
      ExpwithoutSensPrim       = channels x time
      UnexpwithSensPrim        = channels x time
      UnexpwithoutSensPrim     = channels x time
      Atonal                   = channels x time
    Sub2_cond1
      same 5 trial-category fields
    ...
```

The condition 4 and condition 5 files have the same structure, with subject fields named `Sub*_cond4` and `Sub*_cond5`.

For each subject and trial category:

```text
before trial averaging: channels x time x trials
after trial averaging:  channels x time
```

The ERP loader then stacks subjects into group arrays:

```text
subject-level input field:  channels x time
group array in S210:        subjects x channels x time
grand average output:       channels x time
```

The `subjects` dimension is the number of subject fields in the loaded file.
The code infers `channels` and `time` from the data; the expected EEG matrix
shape is approximately `64 x 5222` for each subject-level trial-category ERP.

## Conditions

The pipeline uses three condition files:

| Condition number | Label | Meaning |
|---:|---|---|
| 1 | Broadband | Broadband condition |
| 4 | Low High | Low-to-high condition |
| 5 | High Low | High-to-low condition |

Each subject-condition structure is expected to contain these trial-category fields:

- `ExpwithSensPrim`
- `ExpwithoutSensPrim`
- `UnexpwithSensPrim`
- `UnexpwithoutSensPrim`
- `Atonal`

The plotting code derives difference waves internally:

- `Diff_noSP = UnexpwithoutSensPrim - ExpwithoutSensPrim`
- `Diff_withSP = UnexpwithSensPrim - ExpwithSensPrim`

## Main Entry Point

### `S000_main.m`

Interactive driver for the ERP plotting pipeline.

It asks whether to run the full preset figure set or a custom configuration:

- Preset mode runs the full 31-figure set from `S1A0_getPresetConfigs.m`.
- Custom mode either builds a config interactively using `S1B0_configBuilder.m` or loads a user-provided config function.

For most standard analysis reruns, use preset mode.

## Configuration Files

### `templateConfig.m`

Defines the default configuration structure used by the rest of the pipeline. It includes:

- condition number
- which ERP traces to plot
- whether to plot full trial or target-window close-up
- ROI/channel selection
- plot mode
- standard error display
- individual-subject trace display

### `S1A0_getPresetConfigs.m`

Builds the standard 31 preset figure configurations:

- 4 full-waveform broadband figures
- 27 target-window figures across conditions 1, 4, and 5

The presets cover:

- sensory-primed comparisons
- non-primed comparisons
- difference waves
- left frontal, right frontal, and bilateral frontal ROIs

### `S1B0_configBuilder.m`

Interactive helper for making one custom plotting configuration without manually editing a config struct.

The final two questions control individual-subject traces and standard-error
shading. ROI-average and single-channel figures respond as follows:

| Individual traces | Standard error | Figure layout |
|---|---|---|
| No | No | One panel with the group-average ERP |
| Yes | No | One panel with individual traces and the group-average ERP |
| No | Yes | One panel with the group-average ERP and SEM shading |
| Yes | Yes | Two panels: vertical for the full trial, side by side for the target window |

In the full-trial two-panel layout, both panels contain the same group-average ERP
and use the same time axis. The upper panel shows thin, faint individual traces
without uncertainty shading and uses a fixed -10 to +10 microvolt amplitude
range. The lower panel shows the group mean with mean +/- standard error of the
mean (SEM), without individual traces, and uses a narrower fixed -5 to +5
microvolt range so the SEM remains visible. Only the time axes are linked.

In the target-window two-panel layout, the individual-trace panel is on the left
and the group-mean-with-SEM panel is on the right. Both panels use the same time
axis and the same fixed -10 to +10 microvolt amplitude range, allowing direct
visual comparison across adjacent axes. The figure opens in a wide landscape
layout.

For one-panel ROI-average and single-channel figures, plots containing individual
traces use -10 to +10 microvolts; plots without individual traces use -5 to +5
microvolts. Multi-channel figures follow the same rule. These fixed limits keep
figures comparable across batch runs. Setting `cfg.yLim` manually still overrides
both defaults. Legends use a transparent background and no border.

Multi-channel mode remains a single channel grid even when both options are
enabled, because duplicating the full 20- or 64-channel grid would make each
plot too small. Its individual traces are still thinner and fainter than its
group-average ERP.

ROI-average and single-channel figures with individual traces include an optional
subject-highlight toggle. Set `cfg.highlightSubjects` to choose its subjects;
the default is subjects 24-28. See `S244_cohortHighlight.m` below.

## Pipeline Steps

### `S200_runOneConfig.m`

Runs one complete plotting configuration:

1. Load and organize data with `S210_dataLoading.m`
2. Build time and baseline information with `S220_timeBaselineInfo.m`
3. Resolve ROI/channel indices with `S230_getROILabelAndIndices.m`
4. Create the figure with `S240_plotFigure.m`
5. Save the figure with `S250_saveFigure.m`

### `S210_dataLoading.m`

Loads `EEGDataAvgAcrossTrials_allSubject_cond*.mat` for the requested condition.

This function:

- reads all subject fields from `EEGDataAvg`
- builds subject-level arrays
- computes grand averages
- computes standard error across subjects
- stores metadata such as subject names, channel names, and condition labels

The code uses all subject fields found in the selected averaged file. Check that
the file contains the intended subjects before generating group plots.

### `S220_timeBaselineInfo.m`

Defines time-axis remapping and baseline windows.

The pipeline maps each original waveform length onto a fixed internal 1-5000 remapped coordinate system. This internal coordinate is used for indexing, baseline selection, and onset placement. It is not exactly the same thing as the final x-axis labels shown on the figures.

By default:

- full-trial plots select internal window `1:5000`
- close-up target plots select internal window `3000:4000`
- close-up baseline uses the pre-target internal range around `3000:3100`
- full-trial baseline uses the first 100 internal samples

The ROI and single-channel plotting functions then display only part of that selected window and relabel the x-axis:

- full-waveform figures display internal x-limits approximately `1:4600`, with tick labels shifted so internal `100` corresponds to displayed `0 ms`, internal `600` to `500 ms`, and internal `3100` to `3000 ms`
- close-up figures display internal x-limits approximately `3000:3600`, with tick labels shifted so internal `3100` corresponds to displayed `3000 ms`

So the visualization uses a shifted display convention: roughly, displayed time is internal remapped time minus 100 ms. This keeps the target chord at the expected displayed time while preserving the internal remapped indexing used by the data arrays.

Note: `S243_plotMultiChannel.m` currently sets the same x-limits and onset lines, but does not explicitly relabel the x-ticks. If using multi-channel mode for publication figures, check whether its x-axis should be updated to match the ROI and single-channel display convention.

### `S230_getROILabelAndIndices.m`

Maps ROI channel names to row indices in the data matrix.

The main preset ROIs are:

- Left frontal: `F7, F3, FT7, FC3`
- Right frontal: `F4, F8, FC4, FT8`
- Bilateral frontal: left + right frontal channels

### `S240_plotFigure.m`

Dispatches plotting to the correct plotting function based on `cfg.plotMode`:

- `roiAverage`
- `singleChannel`
- `multiChannel`

## Plotting Files

### `S241_plotROI.m`

Plots ROI-averaged ERP traces. This is the main plotting mode used by the preset 31-figure set.

### `S242_plotSingleChannel.m`

Plots ERP traces for one selected channel.

### `S243_plotMultiChannel.m`

Plots ERP traces across multiple channels.

### `S244_cohortHighlight.m`

Adds the highlight button to ROI-average and single-channel figures that show
individual subject traces. It targets subjects 24-28 by default, or the list in
`cfg.highlightSubjects`. Clicking the button makes those subject traces thicker
and changes their colors; clicking again restores their original appearance.
It does not change the EEG data, the group mean, the SEM, or any statistics.
Saved interactive `.fig` files need this function on the MATLAB path for their
button to work after reopening.

### `S245_FigureDeck.m`

Optional browser for saved ERP `.fig` files. It filters figures by trial view,
filtering condition, plotted content, and ROI, then opens one as a previous/next
deck or several for comparison. It is not called by `S000_main.m` and does not
process EEG data. If a saved figure has individual traces, the browser can also
restore its subject-highlight button through `S244_cohortHighlight.m`.

### `S250_saveFigure.m`

Saves each figure as a MATLAB `.fig` file in a `figures` folder under the current MATLAB working directory.

Output filenames include:

- preset index
- config name
- condition number
- condition label
- plot mode

Example:

`01_Full_Broadband_SP_LeftFrontal_cond1_Broadband_roiAverage.fig`

## How To Run

The scripts load data files by filename, so the averaged data files must be either:

- in MATLAB's current folder, or
- in a folder that has been added to the MATLAB path.

Recommended run pattern:

```matlab
cd('path/to/Mehta/EEG_ERP_Pipeline')
addpath('path/to/Mehta/Data')
S000_main
```

Then choose preset mode when prompted:

```text
Use preset 31-figure set? (y/n): y
```

With this approach, figures will be saved to:

```text
Mehta/EEG_ERP_Pipeline/figures
```

Alternative run pattern:

```matlab
cd('path/to/Mehta/Data')
addpath('path/to/Mehta/EEG_ERP_Pipeline')
S000_main
```

With this approach, figures will be saved to:

```text
Mehta/Data/figures
```

## Expected Outputs

Preset mode should generate 31 `.fig` files:

- 4 full-waveform broadband figures
- 9 target-window difference-wave figures
- 9 target-window sensory-primed figures
- 9 target-window non-primed figures

The current project copy already contains a complete 31-file output set in:

```text
Mehta/EEG_ERP_Pipeline/figures
```

## Dataset Updates

When preprocessing changes the subject set, regenerate the P7 all-subject files
and the P8 averaged files before rerunning ERP plots. Confirm the subject count
shown on each figure and keep cohort timing differences in mind. Cohort ERP
comparison and EEG autocorrelation timing diagnostics are not part of this
plotting pipeline.
