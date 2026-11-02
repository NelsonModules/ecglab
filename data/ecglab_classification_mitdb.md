# Beat classification on the MIT-BIH Arrhythmia Database

Generated 2026-09-13 by data/make_ecglab_classification.m.

- Database: MIT-BIH Arrhythmia Database (mitdb), 22 DS2 record(s) scored.
- Split: de Chazal, O'Dwyer and Reilly 2004, inter-patient. No beat of a DS2 patient is in the training.
- DS1 (train): 101 106 108 109 112 114 115 116 118 119 122 124 201 203 205 207 208 209 215 220 223 230.
- DS2 (test): 100 103 105 111 113 117 121 123 200 202 210 212 213 214 219 221 222 228 231 232 233 234.
- The four paced records 102 104 107 217 are in neither set.
- Detector: pantompkins (the realistic path; the classifier meets detected beats, not reference beats).
- Matching window: 150 ms.
- Class table: dechazal. Reference: the .atr annotations.
- Training beats aligned to the reference .atr locations; test beats detected.
- Model: data/ecglab_classifier.mat, built by data/make_ecglab_classifier.m.
- Nelson build: 2.0.0.0 (Forge).

## Pooled confusion matrix

Rows are the reference class, columns the assigned label. The last row X is a detected beat with no reference within the window (a detector extra); the last column O is a reference beat the detector missed. The per-class figures below use the N..Q by N..Q block; X and O are the detector, reported under it.

| ref \\ label | N | S | V | F | Q | O (missed) |
|---|---:|---:|---:|---:|---:|---:|
| N | 41410 | 224 | 248 | 1767 | 72 | 538 |
| S | 1395 | 83 | 310 | 23 | 1 | 25 |
| V | 674 | 36 | 2002 | 303 | 117 | 89 |
| F | 325 | 1 | 3 | 49 | 0 | 10 |
| Q | 2 | 0 | 1 | 2 | 0 | 2 |
| X (extra) | 10 | 8 | 18 | 7 | 5 | 0 |

## Per-class sensitivity and positive predictivity

Computed on the matched 5 by 5 block (beats the detector found and the validator paired), the way de Chazal reports them: Se = TP / reference beats of the class, +P = TP / beats assigned the class. The de Chazal 2004 column is the reference PAPER's figures, not ours, printed for comparison (their VEB is class V, their SVEB is class S).

| Class | TP | ref | assigned | Se (%) | +P (%) | de Chazal 2004 Se / +P (%) |
|---|---:|---:|---:|---:|---:|---|
| N | 41410 | 43721 | 43806 | 94.7 | 94.5 | 86.9 / 99.2 |
| S | 83 | 1812 | 344 | 4.6 | 24.1 | 75.9 / 38.5 |
| V | 2002 | 3132 | 2564 | 63.9 | 78.1 | 77.7 / 81.9 |
| F | 49 | 378 | 2144 | 13.0 | 2.3 | (not tabulated) |

Overall classification accuracy on the matched beats: 88.8 percent (de Chazal 2004: 85.9 percent). Matched beats: 49048.

## Per-class with the uniform prior

ecglab.classify(..., 'Prior', 'uniform') on the same detected beats. The equal prior lifts the minority-class sensitivity the frequency prior suppresses, at the cost of overall accuracy; the choice belongs to the caller and the purpose (finding the rare beats, or the best overall accuracy). The empirical prior above is the default and the headline of this table.

| Class | TP | ref | assigned | Se (%) | +P (%) | empirical Se / +P (%) |
|---|---:|---:|---:|---:|---:|---|
| N | 35177 | 43721 | 35899 | 80.5 | 98.0 | 94.7 / 94.5 |
| S | 1070 | 1812 | 3239 | 59.1 | 33.0 | 4.6 / 24.1 |
| V | 2072 | 3132 | 2796 | 66.2 | 74.1 | 63.9 / 78.1 |
| F | 124 | 378 | 6845 | 32.8 | 1.8 | 13.0 / 2.3 |

Overall accuracy with the uniform prior: 78.4 percent (empirical: 88.8 percent). The uniform prior trades overall accuracy for minority-class sensitivity.

## Detector contribution

Over the DS2 records the detector (pantompkins) paired 49048 beats, missed 664 and added 48: gross sensitivity 98.66 percent, positive predictivity 99.90 percent. The missed beats are the O column of the matrix, the extras its X row; they are the detector's error, kept apart from the classifier's.

Research software, not a medical device. ecglab is for research and education. It is not a medical device and must not be used for clinical diagnosis, patient monitoring, treatment decisions, or any medical purpose.
