# EEG ERP Pipeline

This folder contains the ERP visualization pipeline. 

REQUIRES / PREREQS: 
- EEG preprocessing
- Trial averaging

The inputs to this pipeline are group-ready averaged subject files:
- `EEGDataAvgAcrossTrials_allSubject_cond1.mat`
- `EEGDataAvgAcrossTrials_allSubject_cond4.mat`
- `EEGDataAvgAcrossTrials_allSubject_cond5.mat`

## Conditions

The pipeline uses three condition files:

| Condition number | Label |
|---:|---|
| 1 | Broadband |
| 4 | Low High |
| 5 | High Low |

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

Main driver for the ERP plotting pipeline.

It asks whether to run the full preset figure set (31 figures) or a custom configuration:

- Preset mode runs the full 31-figure set from `S1A0_getPresetConfigs.m`.
- Custom mode either builds a config interactively using `S1B0_configBuilder.m` or loads a user-provided config function.

#### (Take this out later) For the conference paper, use preset mode.

---

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

---

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

### `S220_timeBaselineInfo.m`

Defines time-axis remapping and baseline windows.

The pipeline maps each original waveform length onto a fixed internal 1-5000 remapped coordinate system. 
#### Note: This internal coordinate is used for indexing, baseline selection, and onset placement. It is not exactly the same thing as the final x-axis labels shown on the figures.

By default:
- full-trial plots select internal window 1:5000
- close-up target plots select internal window 3000:4000
- close-up baseline uses the pre-target internal range between 3000:3100
- full-trial baseline uses the first 100 internal samples

The ROI and single-channel plotting functions then display only part of that selected window and relabel the x-axis:
- full-waveform figures display internal x-limits 1:4600, with tick labels shifted. (i.e., internal 0/100/600/3100 corresponds to displayed -100/0/500/3000 ms
- close-up figures display internal x-limits approximately 3000:3600, with tick labels shifted so internal 3000/3100 corresponds to displayed 2900/3000 ms

So the visualization uses a shifted display convention: displayed time is internal remapped time minus 100 ms (for the purpose of indicating the baseline before the onset of the stimulus, in which we indicate that as t = 0)

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

---

## Plotting Files

### `S241_plotROI.m`

Plots ROI-averaged ERP traces.

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

## Expected Outputs

Preset mode should generate 31 `.fig` files:

- 4 full-waveform broadband figures
- 9 target-window difference-wave figures
- 9 target-window sensory-primed figures
- 9 target-window non-primed figures
