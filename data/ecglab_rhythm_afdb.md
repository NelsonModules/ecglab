# Atrial fibrillation on the AF Database

Generated 2026-09-12 by data/make_ecglab_rhythm.m.

- Database: MIT-BIH Atrial Fibrillation Database (afdb), 23 record(s) requested, 23 scored.
- Detection: ecglab.rhythm with its default window of 128 beats, stepped one beat, on beats from the default detector; the RR series alone (no delineation), so the coefficient of sample entropy and the normalised RMSSD decide.
- Thresholds: coefficient of sample entropy above -1 at template length one with a tolerance of 0.1 of the mean RR, and a normalised RMSSD above 0.1; taken from the literature (survey 5.8), not fitted to this database.
- Reference: the record's own .atr rhythm marks; the label scored is fixed to AFIB (the episodes basis takes no option to name another rhythm, as validate.m owns the option set; atrial flutter and junctional rhythm count as not-AFIB, the detector not separating them from the RR series).
- Figures: ANSI/AAMI EC57 episode and duration sensitivity and positive predictivity (epicmp, survey 5.1), and the per-second atrial fibrillation sensitivity and specificity and Cohen's kappa over the two labels.
- Published per-window figures, for comparison only and measured by those papers on this database, not here: Tateno and Glass 2001 Se 94.4 Sp 97.2; Petrenas et al. 2015 Se 97.1 Sp 98.3 (survey 5.8).
- Nelson build: 2.0.0.0 (Forge).

## Per record

| Record | Ref AF ep | Det AF ep | Ep Se | Ep +P | Dur Se | Dur +P | Sec Se | Sec Sp | Kappa | Ref AF min |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 04015 | 7 | 7 | 85.7 | 57.1 | 97.0 | 10.3 | 97.0 | 94.5 | 0.176 | 4.0 |
| 04043 | 82 | 54 | 69.5 | 94.4 | 73.2 | 92.0 | 73.2 | 98.3 | 0.771 | 132.0 |
| 04048 | 7 | 2 | 28.6 | 100.0 | 55.9 | 100.0 | 56.1 | 100.0 | 0.717 | 6.0 |
| 04126 | 7 | 21 | 85.7 | 28.6 | 96.7 | 36.4 | 96.8 | 93.4 | 0.502 | 23.0 |
| 04746 | 5 | 1 | 40.0 | 100.0 | 99.7 | 99.8 | 99.7 | 99.7 | 0.995 | 325.9 |
| 04908 | 8 | 9 | 75.0 | 55.6 | 91.0 | 88.8 | 91.1 | 99.0 | 0.890 | 51.4 |
| 04936 | 36 | 30 | 86.1 | 100.0 | 89.3 | 98.5 | 89.3 | 96.4 | 0.798 | 442.7 |
| 05091 | 8 | 0 | 0.0 | - | 0.0 | - | 0.0 | 100.0 | 0.000 | 1.4 |
| 05121 | 20 | 11 | 95.0 | 90.9 | 92.8 | 97.2 | 92.8 | 95.4 | 0.869 | 386.8 |
| 05261 | 11 | 8 | 27.3 | 37.5 | 78.0 | 39.8 | 78.0 | 98.4 | 0.518 | 8.0 |
| 06426 | 26 | 13 | 92.3 | 100.0 | 99.2 | 97.9 | 99.2 | 55.3 | 0.628 | 585.2 |
| 06453 | 6 | 2 | 33.3 | 100.0 | 62.9 | 79.7 | 62.8 | 99.8 | 0.699 | 6.2 |
| 06995 | 6 | 17 | 66.7 | 17.6 | 98.4 | 88.0 | 98.4 | 88.0 | 0.858 | 289.3 |
| 07162 | 1 | 1 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | - | 1.000 | 613.7 |
| 07859 | 1 | 8 | 100.0 | 100.0 | 98.6 | 100.0 | 98.6 | - | 0.000 | 613.7 |
| 07879 | 2 | 9 | 50.0 | 66.7 | 98.8 | 99.1 | 98.8 | 98.7 | 0.974 | 370.0 |
| 07910 | 5 | 4 | 80.0 | 100.0 | 99.4 | 98.1 | 99.4 | 99.6 | 0.985 | 97.8 |
| 08215 | 2 | 2 | 100.0 | 100.0 | 99.9 | 100.0 | 99.9 | 100.0 | 0.998 | 494.6 |
| 08219 | 39 | 29 | 100.0 | 37.9 | 97.2 | 60.7 | 97.2 | 82.6 | 0.655 | 132.5 |
| 08378 | 5 | 8 | 80.0 | 100.0 | 90.1 | 99.5 | 90.1 | 99.9 | 0.932 | 128.3 |
| 08405 | 2 | 1 | 100.0 | 100.0 | 100.0 | 99.7 | 100.0 | 99.3 | 0.995 | 443.2 |
| 08434 | 3 | 3 | 100.0 | 33.3 | 99.1 | 66.0 | 99.2 | 97.9 | 0.782 | 23.7 |
| 08455 | 2 | 1 | 50.0 | 100.0 | 98.7 | 100.0 | 98.7 | 100.0 | 0.979 | 423.3 |

## Pooled over the database

| Figure | Gross | Average |
|---|---:|---:|
| Episode sensitivity | 75.6 | - |
| Episode positive predictivity | 71.8 | - |
| Duration sensitivity | 97.0 | 87.7 |
| Duration positive predictivity | 95.3 | 84.2 |
| Per-second sensitivity | 97.0 | 87.7 |
| Per-second specificity | 96.8 | 95.1 |
| Per-second Cohen kappa | 0.935 | - |

_Pooled reference atrial fibrillation: 5602.6 min over 291 episodes; detected 5700.3 min over 241 episodes._

_For comparison, the per-window figures those papers report on this database (not a figure of EC57, and not measured here): Tateno and Glass 2001 Se 94.4 Sp 97.2; Petrenas et al. 2015 Se 97.1 Sp 98.3._
