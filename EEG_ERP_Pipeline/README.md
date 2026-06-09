# EEG ERP Pipeline

This folder contains the ERP visualization pipeline for the Mehta Harmony / Context EEG project. It assumes that EEG preprocessing and trial averaging have already been completed, and it starts from the group-ready averaged subject files:

- `EEGDataAvgAcrossTrials_allSubject_cond1.mat`
- `EEGDataAvgAcrossTrials_allSubject_cond4.mat`
- `EEGDataAvgAcrossTrials_allSubject_cond5.mat`

In the current project copy, these files represent the finished 15-subject dataset:

`Sub1, Sub2, Sub5, Sub6, Sub8, Sub9, Sub10, Sub11, Sub12, Sub13, Sub14, Sub16, Sub17, Sub19, Sub20`

Subjects 24-28 are not expected to be included yet. They should be preprocessed and folded into the dataset later.

## Conditions

The pipeline uses three condition files:

| Condition number | Label | Meaning |
|---:|---|---|
| 1 | Broadband | Broadband condition |
| 4 | Low High | Low-to-high condition |
| 5 | High Low | High-to-low condition |

Each subject-condition structure is expected to contain these fields:

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

The current code loops over all subjects found in the loaded file, so it should automatically use the full current 15-subject dataset.

### `S220_timeBaselineInfo.m`

Defines time-axis remapping and baseline windows.

The pipeline maps each original waveform length onto a fixed 1-5000 remapped domain. By default:

- full-trial plots use window `1:5000`
- close-up target plots use window `3000:4000`
- close-up baseline uses the pre-target range around `3000:3100`
- full-trial baseline uses the first 100 remapped samples

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

## Notes From Current Workspace Check

The ERP pipeline was inspected against the current copied dataset. The data files used by this pipeline contain 15 subject fields, matching the current finished participant set.

The code path in `S210_dataLoading.m` loops over all available subject fields, so the ERP pipeline itself does not appear to need changes before continuing preprocessing for subjects 24-28.

During this check, MATLAB did not successfully run in the Codex desktop environment because MATLAB startup stopped before reaching project code:

- default batch launch failed while loading a MATLAB settings plugin
- using a temporary preference folder then failed with MathWorks services/licensing error 5202

Because of that local MATLAB startup issue, this check confirms the pipeline by file structure and source inspection, not by a completed live MATLAB rerun.

## Current Next Data Step

The remaining data-work item is to finish preprocessing subjects 24-28, then regenerate the all-subject and averaged condition files before rerunning the ERP figures.
