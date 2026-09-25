# EEG Preprocessing Pipeline

This folder contains the cleaned-up preprocessing pipeline for the Mehta Harmony / Context EEG project. It converts raw or partially processed EEG data into the `.mat` files used by the ERP and topoplot pipelines.

The pipeline is intentionally stage-by-stage. There is no single main driver, because some stages require human judgment in EEGLAB, especially channel/epoch inspection and ICA component rejection.

The original root-level scripts are kept as historical references:

```text
Analysis_ContextEEG_Step1_noICA.m
Analysis_ContextEEG_Step2_withICA.m
Context_EEGAnalyses_Step3.m
```

The official pipeline-facing versions live in this folder.

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

The optional P12 timing check is different: it currently reads raw `.bdf`
files directly from `Data/Subject Data/Sub#`. It does not search
`Unprocessed` or `archive` folders.

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

If channels were removed in P2, record each acquisition-channel label in
the filename. P3 detects these suffixes automatically:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_noICA_B31removed.set
Data/Subject Data/Sub1/Sub1_Cond1_run1_noICA_A12removed_B31removed.set
```

Output:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2.set
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2.fdt
```

The output automatically keeps every detected channel-removal note:

```text
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_B31removed.set
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_B31removed.fdt
```

P3 is not customized to particular subjects. It converts `A1`-`A32` and
`B1`-`B32` to positions in the universal `BioSemi64.loc` file, verifies that
the filename agrees with the dataset's channel count, and stops if two
competing processed inputs exist for the same run.

Processing choices:

- bandpass filter 0.5-10 Hz
- apply channel locations from `BioSemi64.loc`
- remove every filename-identified missing-channel location from the template
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
Data/Subject Data/Sub1/Sub1_Cond1_run1_withICA2_A12removed_B31removed_cleaned.set
```

P5 recognizes any valid `A1`-`A32` or `B1`-`B32` removal suffix; it is not
limited to `B25removed` or `B31removed`.

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

P8 can optionally split trials into sequential segments before averaging,
with names like:

```text
Data/EEGDataAvgAcrossTrials_3000to3600_allSubject_cond1.mat
```

The numbers in that optional filename are **trial indices, not milliseconds**.
Use one segment for the standard ERP/topoplot inputs shown above.

Run:

```matlab
P8_AverageTrialsWithinSubjects
```

## Interactive Terminal Guide

This section covers the interactive prompts and common outcomes for P1, P3,
P5, P6, P7, and P8. P2 and P4 are manual EEGLAB stages; see their separate
guides listed below. The examples illustrate behavior, not fixed subject lists
or machine-specific paths.

### Common Input Rules

- Enter the path to the `Data` folder when asked. It may be anywhere on the
  computer, but it must contain `Subject Data` and `Context Trial Order`.
  Pressing Enter alone does not choose a machine-specific Data path.
- A value in brackets is the current default. Press Enter at a later prompt
  to accept it. Subject defaults are detected from the available folders or
  source files and can change when the Data folder changes.
- Subject lists can be entered as `28`, `[27 28]`, or `1:28`. Conditions must
  come from `[1 4 5]`; runs must come from `[1 2]` when a run prompt appears.
  Invalid lists and noninteger subject numbers are rejected and prompted again.
- Yes/no prompts accept `y`, `yes`, `n`, or `no`. The final proceed prompt
  defaults to yes; stage-specific overwrite prompts default to no when present.
- A nonexistent or structurally wrong Data folder is rejected and prompted
  again. P5 also resolves common paths such as the Data folder's parent,
  `Subject Data`, or a `Sub#` folder back to the Data folder. For the other
  stages, enter the Data folder itself.
- Before processing, each automatic stage prints an input check (often called
  `preflight`) showing its selections and source files. It then asks
  `Proceed with P# processing? (y/n) [y]:`. Answer `n` to cancel before
  files are changed. A missing required input stops the stage before this
  confirmation rather than silently omitting the requested subject.

For example, selecting `[27 28]`, conditions `[1 4 5]`, and runs `[1 2]`
requests 12 run files. The subject list printed in the prompts is not a rule
about which subjects may be processed.

### P1 Terminal Outcomes

P1 asks for the Data folder, subjects, conditions, runs, and whether to
overwrite existing no-ICA files. It checks every requested raw BDF in
`Subject Data/Unprocessed/Sub#` before EEGLAB starts. A successful check
prints `P1 preflight passed` and asks for final confirmation.

If overwrite is `n`, an existing output is reported and skipped:

```text
Cond 1 Run 1: skipping existing Sub28_Cond1_run1_noICA.set
```

If a requested BDF is absent, P1 lists the missing paths and stops with
`P1 cannot start until the missing raw .bdf files exist.` P1 is only needed
when starting from raw BDF files, not when a subject already has matched
`.mat` files.

### P3 Terminal Outcomes

P3 asks for the Data folder, subjects, conditions, runs, and whether to
overwrite existing ICA files. It checks for inspected `*_noICA*.set` inputs
and `BioSemi64.loc`, then prints `P3 preflight passed` if they are present.
An existing ICA output is skipped when overwrite is `n`.

Removed-channel notes in the P2 filename are detected automatically. For
example, `*_noICA_B31removed.set` produces
`*_withICA2_B31removed.set`. If two competing processed inputs exist for
one run, P3 stops and asks you to resolve that ambiguity. Missing no-ICA
files or the channel-location file also stop the run. P3 runs ICA but does
not reject components; that remains the manual P4 step.

### P5 Terminal Outcomes

P5 asks for the Data folder, subjects, conditions, and runs. It does **not**
ask an overwrite question. Its `overwriteExisting` setting is fixed to
`false`. After `P5 preflight passed`, it asks for final confirmation.

- A final `*_withICA2_cleaned.set` that already has all 64 channels is
  reported as already interpolated and is not saved again.
- If that cleaned file is missing a channel, P5 names the missing channel,
  saves an independent `*_beforeInterpolation.set` backup, interpolates,
  and writes the final 64-channel `*_withICA2_cleaned.set` file.
- A cleaned file with a valid `A#removed` or `B#removed` suffix can also be
  read. If the required cleaned source is missing, P5 lists the missing
  paths and stops before processing.

P5 prefers an existing plain `*_withICA2_cleaned.set` over a suffixed
source. If that plain file is an older 64-channel final version, P5 will
skip it; verify which file is active before rerunning interpolation.

### P6 Terminal Outcomes

P6 asks for the Data folder, subjects, conditions, and runs. It expects
cleaned run-level `.set` files and matching trial-order `.mat` files for
each subject-condition that must be generated or rebuilt. After
`P6 input check passed`, it asks for final confirmation.

- If a verified `Sub#_cond#_EEGdata.mat` already exists but the cleaned
  `.set`/trial-order inputs are incomplete, P6 keeps that matched file.
- If the matched file and all rebuild inputs exist, P6 asks **for that
  subject-condition** whether to overwrite it. The default answer is no.
- If no matched file exists and all inputs are present, P6 generates it.
- If no usable matched file and required inputs are missing, P6 lists the
  missing `.set` or trial-order files and stops before processing.

P6 needs trial-order indices to refer to the EEG epochs that still exist.
If epochs were removed but their original trial indices remain in the
trial-order file, an error such as `indices outside 1..114` means those
files no longer align. Do not silently renumber or ignore those indices.

### P7 Terminal Outcomes

P7 asks for the Data folder, subjects, and conditions, but not runs. It
checks that every requested `Sub#_cond#_EEGdata.mat` exists and contains
usable `EEGdata_cond`, then prints `P7 preflight passed` and asks for final
confirmation. Missing or unusable subject-condition files stop it.

P7 **replaces** each selected `Data/EEGData_allSubject_cond#.mat` with a
group file containing exactly the requested subjects. Running P7 for only
Sub28 does not add Sub28 to an existing 20-subject file; it creates a
Sub28-only group file. Select the full intended cohort for final outputs.

### P8 Terminal Outcomes

P8 asks for the Data folder, conditions, and `Number of trial segments`
(default `1`); it does not ask for subject numbers or runs. The segment
count must be a positive whole number. It checks the selected P7 group
files, prints `P8 preflight passed`, and asks for final confirmation.

With one segment, P8 writes the standard
`EEGDataAvgAcrossTrials_allSubject_cond#.mat` files. With more than one
segment, it divides each subject/category's trials into sequential chunks
and writes trial-range-named files instead. It does not split the time
axis. Missing group files stop the stage. P8 overwrites outputs for the
selected conditions, so its subject set is whatever P7 last placed in
those group files.

### Where To Start

- Already have subject-level `Sub#_cond#_EEGdata.mat` files: start at P7.
- Have cleaned/interpolated `.set` files but no matched `.mat`: start at P6.
- Have only raw `.bdf` files: follow P1, manual P2, P3, manual P4, P5,
  P6, P7, then P8. If no channel was removed, P5 has no interpolation to do.

## Optional P12: Raw BDF Timing Check

`P12_BDFTrialStartIntervalCheck.m` is an independent timing audit, not a
preprocessing stage. It reads trial-start triggers from the raw BioSemi
Status channel in `Data/Subject Data/Sub#` BDF files. It ignores copies in
`archive` and `Unprocessed`, and it does not use processed EEG amplitudes.

```matlab
P12_BDFTrialStartIntervalCheck('C:\path\to\Data')
```

P12 prints one line per run with the trigger count and median start-to-start
interval, then a short old/new cohort summary, and opens an on-screen
scatter plot. It does not return a table or save CSV, FIG, or PNG files.
If a condition's expected trial-start trigger code is missing, it stops
rather than substituting a different Status event. A read failure for an
individual file is reported as `SKIPPED`; check the final subject/run
counts before interpreting the plot. Start-to-start interval is not the
same as within-trial chord SOA.

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
