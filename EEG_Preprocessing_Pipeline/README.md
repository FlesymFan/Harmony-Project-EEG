# EEG Preprocessing Pipeline

Purpose: Converts raw or partially processed EEG data into the `.mat` files used by the ERP and topoplot pipelines.

The original root-level scripts are kept as historical references:

```text
Analysis_ContextEEG_Step1_noICA.m
Analysis_ContextEEG_Step2_withICA.m
Context_EEGAnalyses_Step3.m
```

## Data Folder

The `Data` folder can live anywhere on a user's computer. When a preprocessing function asks for the data folder, give the path to the `Data` folder itself.

The internal structure of `Data` must stay standardized:

```text
Data/
    Subject Data/
        Unprocessed/
            Sub1/
            Sub2/
            ...
        Sub1/
        Sub2/
        ...

    Context Trial Order/
        Sub1/
        Sub2/
        ...
```

Raw `.bdf` files belong in `Data/Subject Data/Unprocessed/Sub#`.

Example raw input file:

```text
Data/Subject Data/Unprocessed/Sub1/Sub1_Cond1_run1.bdf
```

Processed EEG files and subject-level `.mat` files belong in `Data/Subject Data/Sub#`.

Trial-order files belong in `Data/Context Trial Order/Sub#`.

Example trial-order file:

```text
Data/Context Trial Order/Sub1/Sub1_Cond1_run1.mat
```

## Pipeline Index

```text
P1  P1_RawBDFToEpochedNoICA.m
        |
        v
P2  Manual channel/epoch inspection in EEGLAB
        |
        v
P3  P3_EpochedNoICAToICA.m
        |
        v
P4  Manual ICA component rejection in EEGLAB
        |
        v
P5  P5_InterpolateRemovedChannels.m
        |
        v
P6  P6_MatchTrialsToConditions.m
        |
        v
P7  P7_CollectSubjectsByCondition.m
        |
        v
P8  P8_AverageTrialsWithinSubjects.m
        |
        v
ERP pipeline / topoplot pipeline
```

To run a stage, open MATLAB in this folder or add this folder to the MATLAB path, then call the stage by name:

```matlab
P1_RawBDFToEpochedNoICA
```

Each stage asks for the `Data` folder, subject numbers, conditions, runs, and overwrite choices as needed.

## P1: Raw BDF To Epoched No-ICA Set

`P1_RawBDFToEpochedNoICA.m` is adapted from `Analysis_ContextEEG_Step1_noICA.m`.

It reads raw BioSemi `.bdf` files and creates epoched EEGLAB `.set/.fdt` files before ICA.

Expected input:

```text
Data/Subject Data/Unprocessed/Sub1/Sub1_Cond1_run1.bdf
```

Output:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_noICA.set
Data/Subject Data/Sub1/Sub1_Cond1_run1_noICA.fdt
```

Processing choices:

- import BioSemi `.bdf`
- resample to 1024 Hz
- bandpass filter 0.1-15 Hz
- rereference to EXG1/EXG2, the mastoid reference channels
- remove EXG3-EXG8
- epoch from -0.1 to 5 seconds

Run:

```matlab
P1_RawBDFToEpochedNoICA
```

## P2: Manual Channel/Epoch Inspection In EEGLAB

After P1, inspect each `*_noICA.set` file in EEGLAB.

What has been done:

```text
Sub1_Cond1_run1.bdf
    -> Sub1_Cond1_run1_noICA.set
```

What to do:

- inspect channels
- inspect epochs/trials
- remove only clearly bad channels or clearly bad epochs before ICA

What to save:

If nothing was removed, keep:

```text
Sub1_Cond1_run1_noICA.set
```

If a channel was removed, save with the removed channel in the name:

```text
Sub1_Cond1_run1_noICA_B31removed.set
```

If epochs were rejected, include that in the name:

```text
Sub1_Cond1_run1_noICA_epochRejected.set
Sub1_Cond1_run1_noICA_B31removed_epochRejected.set
```

Current examples:

```text
Sub27_Cond#_run#_noICA_B31removed.set
Sub28_Cond#_run#_noICA_B25removed.set
```

Current mapping:

```text
B31 = PO4
B25 = P2
```

What to do next:

Run `P3_EpochedNoICAToICA.m`.

## P3: Epoched No-ICA Set To ICA Set

`P3_EpochedNoICAToICA.m` is adapted from `Analysis_ContextEEG_Step2_withICA.m`.

It reads inspected no-ICA `.set/.fdt` files, assigns channel locations, and runs ICA.

Expected input:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_noICA.set
```

If a channel was removed in P2, P3 expects that suffix:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_noICA_B31removed.set
```

Output:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2.set
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2.fdt
```

If a channel was removed in P2, the output keeps that note:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_B31removed.set
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_B31removed.fdt
```

Processing choices:

- bandpass filter 0.5-10 Hz
- apply channel locations from `BioSemi64.loc`
- remove the missing-channel location from the template if a channel was removed in P2
- run extended ICA

Run:

```matlab
P3_EpochedNoICAToICA
```

## P4: Manual ICA Rejection In EEGLAB

After P3, inspect and reject ICA components in EEGLAB.

What has been done:

```text
Sub1_Cond1_run1_noICA.set
    -> Sub1_Cond1_run1_withICA2.set
```

What to do:

- inspect ICA component maps, activity, spectra, and ICLabel output
- reject clear eye blink, eye movement, muscle, or channel-noise components
- do not reject a component only because ICLabel says it is not "Brain"

What to save:

Save the manually cleaned file as:

```text
Sub1_Cond1_run1_withICA2_cleaned.set
```

If the file had a removed-channel suffix before ICA, P5 can also read a cleaned file that keeps that note:

```text
Sub1_Cond1_run1_withICA2_B31removed_cleaned.set
```

After interpolation, the final pipeline-ready file should use the simple cleaned name:

```text
Sub1_Cond1_run1_withICA2_cleaned.set
```

What to do next:

If a channel was removed before ICA, run `P5_InterpolateRemovedChannels.m`.

If no channel was removed before ICA, move to `P6_MatchTrialsToConditions.m`.

## P5: Interpolate Removed Channels

`P5_InterpolateRemovedChannels.m` restores the full 64-channel BioSemi layout after ICA rejection.

Expected input when a channel was removed:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_B31removed_cleaned.set
```

Output:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_cleaned.set
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_cleaned.fdt
```

This stage uses:

```text
BioSemi64.loc
```

If a subject/run already has 64 channels and is already named `*_withICA2_cleaned.set`, interpolation is not needed.

Run:

```matlab
P5_InterpolateRemovedChannels
```

## P6: Match Trials To Conditions

`P6_MatchTrialsToConditions.m` is adapted from `Context_EEGAnalyses_Step3.m`.

It matches each cleaned EEG run with the corresponding trial-order file and creates one subject-level condition file.

Expected EEG input:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_cleaned.set
Data/Subject Data/Sub1/Sub1_Cond1_run2_withICA2_cleaned.set
```

Older cleaned files named like this are also accepted:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA_cleaned.set
```

P6 only uses these cleaned/interpolated EEGLAB `.set` files as EEG input. It does not use run-level `.mat` files or uncleaned `.set` files.

Expected trial-order input:

```text
Data/Context Trial Order/Sub1/Sub1_Cond1_run1.mat
Data/Context Trial Order/Sub1/Sub1_Cond1_run2.mat
```

P6 only looks for this plain trial-order filename pattern. It does not look for `_TrialOrder.mat` variants.

Output:

```text
Data/Subject Data/Sub1/Sub1_cond1_EEGdata.mat
Data/Subject Data/Sub1/Sub1_cond4_EEGdata.mat
Data/Subject Data/Sub1/Sub1_cond5_EEGdata.mat
```

The output fields are:

```text
UnexpwithSensPrim
UnexpwithoutSensPrim
Atonal
ExpwithSensPrim
ExpwithoutSensPrim
```

At this stage, the trial dimension still exists. Each field is still organized as channel x time x trials.

Run:

```matlab
P6_MatchTrialsToConditions
```

If an older subject-condition already has `Sub#_cond#_EEGdata.mat` but does not have cleaned `.set` run files, P6 keeps the existing matched file and skips rebuilding it.

If an existing matched file and cleaned `.set` run files are both present, P6 asks whether to overwrite that subject-condition file.

## P7: Collect Subjects By Condition

`P7_CollectSubjectsByCondition.m` collects subject-level files into one group file per filtering condition.

Expected input:

```text
Data/Subject Data/Sub1/Sub1_cond1_EEGdata.mat
Data/Subject Data/Sub2/Sub2_cond1_EEGdata.mat
...
```

Output:

```text
Data/EEGData_allSubject_cond1.mat
Data/EEGData_allSubject_cond4.mat
Data/EEGData_allSubject_cond5.mat
```

This is still single-trial data. P7 combines subjects, but it does not average across trials yet.

Run:

```matlab
P7_CollectSubjectsByCondition
```

## P8: Average Trials Within Subjects

`P8_AverageTrialsWithinSubjects.m` averages trials within each subject and trial category.

Expected input:

```text
Data/EEGData_allSubject_cond1.mat
Data/EEGData_allSubject_cond4.mat
Data/EEGData_allSubject_cond5.mat
```

Output:

```text
Data/EEGDataAvgAcrossTrials_allSubject_cond1.mat
Data/EEGDataAvgAcrossTrials_allSubject_cond4.mat
Data/EEGDataAvgAcrossTrials_allSubject_cond5.mat
```

After P8, each subject and trial category is stored as:

```text
channels x time
```

Before P8, each subject and trial category is:

```text
channels x time x trials
```

P8 can also optionally save time-limited averaged files, with names like:

```text
Data/EEGDataAvgAcrossTrials_3000to3600_allSubject_cond1.mat
```

Run:

```matlab
P8_AverageTrialsWithinSubjects
```

## Final Inputs For ERP And Topoplot

The main outputs used by both the ERP pipeline and the topoplot pipeline are:

```text
Data/EEGDataAvgAcrossTrials_allSubject_cond1.mat
Data/EEGDataAvgAcrossTrials_allSubject_cond4.mat
Data/EEGDataAvgAcrossTrials_allSubject_cond5.mat
```

These files contain the trial-averaged subject-level data. The ERP and topoplot pipelines then load these files and perform their own visualization-specific averaging, baseline correction, contrasts, and plotting.

## File Summary

```text
BioSemi64.loc
    64-channel BioSemi location template used during P3 and P5.

P1_RawBDFToEpochedNoICA.m
    Raw .bdf -> epoched no-ICA .set/.fdt.

P2_ManualChannelInspection_EEGLAB.md
    Manual guide for channel and epoch inspection before ICA.

P3_EpochedNoICAToICA.m
    Inspected no-ICA .set/.fdt -> ICA-decomposed .set/.fdt.

P4_ManualICARejection_EEGLAB.md
    Manual guide for ICA component rejection.

P5_InterpolateRemovedChannels.m
    Restores removed channels after ICA rejection.

P6_MatchTrialsToConditions.m
    Cleaned EEG runs + trial-order files -> subject-level condition .mat files.

P7_CollectSubjectsByCondition.m
    Subject-level condition .mat files -> group condition .mat files.

P8_AverageTrialsWithinSubjects.m
    Group condition .mat files -> trial-averaged ERP/topoplot input files.
```
