# FieldTrip ROI Cluster Tests

This folder is separate from `EEG_StatsAnalysis`. It uses FieldTrip's
`ft_timelockstatistics` instead of the custom permutation implementation.
Neither pipeline changes the P8 averages or the cleaned EEG files.

## Install FieldTrip

FieldTrip is not currently on this computer's MATLAB path. Get the toolbox
from [FieldTrip's official download page](https://www.fieldtriptoolbox.org/download/)
and extract it to a folder of your choice. The folder you enter when running
`FT0_RunOldCohort` must contain `ft_defaults.m`. The launcher adds only that
root directory to the current MATLAB session and then calls `ft_defaults`.
Do **not** add all FieldTrip subfolders with `genpath`.

## Run

In MATLAB, set the Current Folder to `EEG_Stats_FieldTrip` and call:

```matlab
FT0_RunOldCohort
```

Enter the `Data` folder containing the three P8 files, then the FieldTrip
toolbox root folder. The launcher validates inputs and asks before testing.
You may also pass both folders directly as arguments. Results go into a dated
subfolder of `fieldtrip_results` here; existing result folders are not reused.

## Design

- Default subjects: the 15 older participants only, not subjects 24-28.
- Inputs: `EEGDataAvgAcrossTrials_allSubject_cond{1,4,5}.mat`.
- Default contrasts: unexpected minus expected, with sensory priming and without.
- Default ROI: mean of Fz, F3, F4, FCz, FC3, and FC4; one virtual `ROI` channel.
- Time: 0-600 ms relative to the nominal 3000-ms target onset.
- Baseline: -100 to 0 ms relative to the target, applied separately to each
  expected and unexpected subject average.
- Statistics: paired two-sided dependent-samples T, temporal clusters only,
  5000 Monte Carlo randomizations per contrast by default. FieldTrip corrects
  cluster p-values across time; Holm additionally adjusts the smallest cluster
  p from each of the tests selected in `FT1_Config`.

## Change What To Test

Edit `FT1_Config.m` before starting a new run. `subjectIDs` selects named P8
subject fields, `conditionNumbers` selects available condition files,
`contrasts` contains the display name and the expected/unexpected P8 field
names, and `roiNames` contains BioSemi64 electrode labels. Timing, windows,
permutations, random seed, and output folder are also configured there.
The launcher prints these active choices before asking for confirmation; the
saved summary reports the same choices and the actual number of tests.
Changing FT1 while the launcher is waiting at its confirmation prompt does
not alter that in-memory run: cancel and start a new run to use the edits.

This is a **time-only ROI test**, not a whole-scalp channel-time cluster test.
The six family-adjusted p-values should be treated as the primary outcome;
cluster boundaries are descriptive, not precise onset/offset estimates.
Changing `subjectIDs` to include the newer cohort does not fix its different
target timing. Do not pool old and new subjects until target timing and
averaging are aligned and verified. This script does not generate figures;
plotting subject or ROI waveforms requires a separate visualization step.

## Full-Trial Difference Figures

After running all three frontal ROIs, call `FT5_PlotOldCohortDifferences` to
create 18 full-trial Unexpected - Expected figures (three filtering conditions,
two priming contrasts, three ROIs). It reads the newest saved FieldTrip run
for each ROI, verifies that its settings match `FT1_Config`, and saves FIG and
PNG files under `fieldtrip_results/full_trial_differences`. Each figure uses
only the old 15 subjects and the same target-pre baseline as the test. The
shaded target window is the only period tested; context chords are displayed
but were not tested. Significant cluster spans are marked only when a saved
test survives its six-test Holm correction.

The FieldTrip setup and paired-test design follow the official
[installation guide](https://www.fieldtriptoolbox.org/faq/matlab/installation/)
and [cluster-permutation tutorial](https://www.fieldtriptoolbox.org/tutorial/stats/cluster_permutation_timelock/).
