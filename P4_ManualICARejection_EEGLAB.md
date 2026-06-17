# P4 Manual ICA Rejection In EEGLAB

## What Has Been Done

`P3_EpochedNoICAToICA.m` has filtered the inspected no-ICA files, assigned
channel locations, and run ICA.

Expected input files:

```text
Sub##_Cond#_run#_withICA2.set
Sub##_Cond#_run#_withICA2_B##removed.set
```

## What Do I Need To Do

Open each ICA-decomposed `.set` file in EEGLAB and inspect the ICA components.

Reject components that clearly reflect artifacts, such as:

- eye blinks
- eye movements
- muscle activity
- channel noise

Do not reject a component only because the ICLabel category is not "Brain".
Use the component scalp map, activity, spectrum, and ICLabel together.

## What Should I Save

Save the manually cleaned final file as:

```text
Sub##_Cond#_run#_withICA2_cleaned.set
```

If the file had a removed-channel suffix before ICA, still save the final
cleaned file with the simple final name:

```text
Sub##_Cond#_run#_withICA2_cleaned.set
```

This naming is important because later pipeline stages look for the cleaned
files using this convention.

## What To Do Next

If any channel was removed before ICA, run `P5_InterpolateRemovedChannels.m`.

If no channel was removed before ICA, move directly to
`P6_MatchTrialsToConditions.m`.
