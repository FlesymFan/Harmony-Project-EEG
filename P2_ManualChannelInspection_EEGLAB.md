# P2 Manual Channel/Epoch Inspection In EEGLAB

## What Has Been Done

`P1_RawBDFToEpochedNoICA.m` has converted the raw `.bdf` files into epoched
no-ICA EEGLAB datasets.

Expected input files:

```text
Sub##_Cond#_run#_noICA.set
```

## What Do I Need To Do

Open each `*_noICA.set` file in EEGLAB and visually inspect the epoched data.

Check for:

- clearly bad channels
- clearly bad epochs/trials
- large drifts, jumps, or recording artifacts that should not go into ICA

If a channel is clearly unusable, remove that channel before ICA.

If an epoch/trial is clearly unusable, reject that epoch before ICA.

## What Should I Save

If no channel or epoch was removed, keep the original file:

```text
Sub##_Cond#_run#_noICA.set
```

If a channel was removed, save with the removed channel in the name:

```text
Sub##_Cond#_run#_noICA_B##removed.set
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

If epochs/trials were rejected, include that in the suffix:

```text
Sub##_Cond#_run#_noICA_epochRejected.set
Sub##_Cond#_run#_noICA_B##removed_epochRejected.set
```

## What To Do Next

Run `P3_EpochedNoICAToICA.m` on the inspected no-ICA files.
