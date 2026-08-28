# EEG Stats Pipeline
Input: 
`EEGDataAvgAcrossTrials_allSubject_cond{1,4,5}.mat`.

```matlab
results = P0_Main();
```

## Overview

```
P1  config
P2  prepare data
      |
      +-- P3A  mean amplitude            branch A, parametric (ANOVA)
      |   P4A  rmANOVA and t-tests
      |
      +-- P3B  cluster permutation       branch B, nonparametric (Cluster-based permutation)
      |   P4B  cluster summary
      |
P5  save
```

`P0_Main` runs branch B before branch A. Branch B needs no latency window and
so cannot be biased by one; branch A does.

---

## P1_Config

**Required** Nothing.
**Effect** Returns every setting the pipeline reads.
**Modify** The only file you should need to edit for a normal run.

| setting | effect | modify when |
|---|---|---|
| `conditionNumbers` | which filtering conditions enter the design | analysing a subset |
| `chordSOA_ms` | places the target chord at 6 × SOA = 3000 ms | the cohort's stimulus rate differs |
| `baselineWin_ms` | per-subject baseline, relative to target onset | you want a longer baseline |
| `roiNames` | electrodes averaged before testing | once, before looking at results |
| `eranWin_ms` | branch A amplitude window | testing a different latency range |
| `clusterWin_ms` | branch B search window | the effect may lie outside 0–600 ms |
| `clusterDomain` | `'roi'` time only, `'scalp'` channel × time | you need scalp topography |
| `nPermutations` | precision of the cluster p | 5000 is fine; 10000 for publication |
| `runParametric` / `runNonparametric` | which branches run | running one branch alone |

---

## P2_PrepareData

**Required** `cfg` from `P1_Config`; the P8 files on the path.
**Effect** Loads every filtering condition, builds the millisecond axis from
`srate` and `epochStart_ms`, baseline-corrects each subject against the
pre-target window, resolves `roiNames` to row indices.
**Modify** `conditionNumbers`, `baselineWin_ms`, `roiNames`.

Errors rather than proceeding if subject count, channel count, sample count
or subject *order* differ across conditions — a repeated-measures design with
misaligned subjects produces numbers that look fine and mean nothing.

---

## Branch A — parametric

### P3A_MeanAmplitude

**Required** `D` from `P2_PrepareData`.
**Effect** Collapses each subject's ROI waveform to one mean amplitude per
design cell, over `eranWin_ms` relative to target onset.
**Modify** `eranWin_ms`, `roiNames`.

Atonal amplitudes are computed but excluded from the ANOVA table: Atonal has
no Expectancy or Priming level, so it needs its own one-way test.

### P4A_RunANOVA

**Required** `amp` from `P3A_MeanAmplitude`. `fitrm`/`ranova` need the
Statistics Toolbox; the t-tests use local helpers and run without it.
**Effect** Repeated-measures ANOVA, Expectancy (2) × Priming (2) ×
Filtering (3), all within subject. Plus one-sample t-tests of each difference
wave against zero, with Cohen's dz and a CI.
**Modify** `alpha`, `contrasts`.

The ERAN is the **main effect of Expectancy**. **Expectancy × Priming** is the
question the project is about: does the effect survive when context and target
share no pitches. If Mauchly p < .05, read `pValueGG`, not `pValue`.

---

## Branch B — nonparametric

### P3B_ClusterPermutation

**Required** `D` from `P2_PrepareData`. No toolbox.
**Effect** Cluster-based permutation test of one difference wave against zero
(Maris & Oostenveld, 2007). One-sample t at every point, threshold at
`clusterAlpha`, group adjacent survivors into clusters, sum t within each,
then sign-flip subjects `nPermutations` times to build the null distribution
of the largest cluster mass.
**Modify** `clusterWin_ms`, `clusterAlpha`, `nPermutations`, `clusterDomain`.

A significant cluster means an effect exists somewhere in the tested window.
**Cluster extent is not a confidence interval on onset or offset.** Do not
write "the ERAN began at 152 ms" from it.

### P4B_ClusterSummary

**Required** the cluster results from `P3B_ClusterPermutation`.
**Effect** Flattens every cluster into one table sorted by p, starring those
below `alpha`.
**Modify** `alpha`.

An empty table means no cluster passed the *forming* threshold. That is not
the same as no effect — widen `clusterWin_ms` or lower `clusterAlpha` before
concluding anything from it.

---

## P5_SaveResults

**Required** `saveTables` true and write access to `outDir`.
**Effect** Timestamped CSVs prefixed `A_` and `B_` by branch, plus a `.mat`
holding everything including the permutation null.
**Modify** `outDir`, `saveTables`.

---

## Constraints

**Timing** All windows are relative to the target chord at 3000 ms, correct
for the original cohort. The 2025 subjects have a different chord rate; change
`chordSOA_ms` and run them separately rather than pooling.

**ROI** Default is the thesis ROI (Fz, F3, F4, FCz, FC3, FC4; Leino et al.
2007), not the F7/F8/FT7/FT8 set the ERP presets use. Choosing it after seeing
results invalidates the p-value.

**Order** Fix `eranWin_ms` before reading branch B output, or state in the
write-up that the window came from the data.

**Filenames** These `P*` names do not collide with the preprocessing `P1_Raw…`
through `P8_Average…`, since MATLAB resolves on the full function name. Keep
the folders separate anyway.

## Validation

The cluster algorithm was checked against simulated data: on pure noise it
produced a significant cluster in 5.5% of runs (nominal 5%), and it detected a
d = 0.8 effect spanning 60 samples in 50/50 runs. Nothing else has been run in
MATLAB — treat the first run as a test.

## Not built

Cluster result plotting; Atonal one-way test; effect-size CIs for ANOVA terms;
power analysis for reporting a null.
