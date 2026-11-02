# Changelog

All notable changes to the `ecglab` module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Research software, not a medical device.** ecglab is for research and
> teaching. It is not a medical device and must not be used for clinical
> diagnosis, patient monitoring, treatment decisions, or any medical purpose.

## [1.0.0] - 2026-11-02

First public release of `ecglab`. It has twenty-four functions. Each one has a
test and a help page in English and French. Every measured result is in a table,
with the script that produces it. Nothing downloaded is redistributed with the
module.

### Reading and writing

- `ecglab.readwfdb` and `ecglab.writewfdb` read and write PhysioNet WFDB records:
  all signal formats, multi-file and multi-segment records, and the MIT
  annotations (number, subtype, channel, aux text). They are thin adapters over
  the standalone `wfdb` module.
- `ecglab.readedf` and `ecglab.writeedf` read and write EDF and EDF+ in one pass.
  Signals keep their own rates, and the EDF Annotations track is read and written.
  They use the standalone `edf` module.
- `ecglab.readishne` reads a Holter recording in the ISHNE format, using the
  standalone `ishne` module.
- `ecglab.readcsv` reads a delimited text file. It detects the delimiter, a header
  row of lead names, a leading time column, and the French decimal comma.
- The WFDB, EDF and ISHNE formats live in three standalone Nelson modules
  (`wfdb`, `ishne`, `edf`). `ecglab` depends on all three (`>=1.0.0`) instead of
  duplicating them.

### Reference data and simulation

- `ecglab.reference` downloads a record from the open PhysioNet databases
  (`mitdb`, `qtdb`, `nsrdb`, `afdb`, `nstdb`, `ludb`, `ptbdb`, `ptb-xl`) once, then
  reads it. It keeps each database's citation and licence and redistributes
  nothing.
- `ecglab.simulate` builds a recording with known beats, waves, classes and
  rhythm, to test detectors, delineators and classifiers. The beat shape is the
  McSharry closed form, and the RR series comes from the bimodal HRV spectrum. The
  recording can include ventricular ectopy, atrial fibrillation, noise, baseline
  wander and mains.

### Cleaning and quality

- `ecglab.clean` removes baseline wander and mains interference, within the AHA
  filter recommendations. For the baseline: a zero-phase high pass, a two-stage
  sliding median, a cubic spline, or none. For the mains: a zero-phase notch at 50
  or 60 Hz with its harmonics.
- `ecglab.quality` reports, window by window, whether the signal is readable. It
  uses bSQI (Li 2008), kSQI, pSQI and basSQI (Zhao 2018), and the Orphanidou
  (2015) rules.

### Detection and validation

- `ecglab.detect` finds the beats with one of seven detectors or their consensus:
  Pan-Tompkins, Hamilton, Christov, Engelse-Zeelenberg, Elgendi, the curve length
  transform of Zong, and a wavelet detector. Each returns the evidence it used.
  Sensitivity and positive predictivity on the MIT-BIH Arrhythmia Database are in
  `data/ecglab_beats_mitdb.md` (`data/make_ecglab_beats.m`).
- Detector robustness under noise is measured on the MIT-BIH Noise Stress Test
  Database (records 118 and 119, calibrated noise). Every detector holds down to
  about 6 dB. Below that they differ: at -6 dB, Hamilton and Elgendi keep about 82
  percent of their sensitivity, and Pan-Tompkins about half. Table
  `data/ecglab_noise_nstdb.md` (`data/make_ecglab_noise.m`).
- `ecglab.validate` compares a detection against reference annotations, following
  ANSI/AAMI EC57: a 150 ms matching window, a five-minute learning period, the
  five classes N, S, V, F and Q, and paced records flagged. It returns the counts,
  sensitivity, positive predictivity, the timing and RR errors, and the per-class
  matrix.

### Delineation

- `ecglab.delineate` marks the onset, peak and end of the P, QRS and T waves,
  using the wavelet method of Martinez et al. (2004). It returns the PR, QRS and
  QT intervals and the corrected QT (Bazett, Fridericia, Framingham, Hodges). The
  T offset is read to the clinical foot by the tangent method, so the QT interval
  is nearly unbiased: the T-offset error against annotator 1 of the QT Database is
  -4.4 ms, down from -39.7 ms on the slope maximum. `BoundaryFraction` keeps the
  slope-maximum convention if needed.
- `ecglab.validate` can score waves: the signed error per fiducial against
  reference annotations, with the CSE tolerance beside each. It is measured on the
  QT Database (`data/ecglab_delineation_qtdb.md`) and on the twelve-lead
  Lobachevsky University Database (200 records, 2400 leads,
  `data/ecglab_delineation_ludb.md`). On LUDB the peaks are accurate on every lead
  (P peak -1.6 ms, R +7.6 ms, T peak +7.4 ms), the QRS and T are found on every
  beat, and the P on about 82 percent. The boundary scatter is still above the CSE
  tolerances.

### Classification

- `ecglab.classify` labels each beat in the five AAMI classes. It uses a linear
  discriminant on the RR rhythm, a QRS-width feature, a post-beat interval feature
  and the beat shape, from a shipped model (`data/ecglab_classifier.mat`, built by
  `data/make_ecglab_classifier.m`). It is measured between patients on the de
  Chazal DS2 records (`data/ecglab_classification_mitdb.md`): overall accuracy
  88.8 percent (de Chazal 2004: 85.9), ventricular sensitivity 63.9 percent. The
  `Prior` option trades the classes off: `'uniform'` raises supraventricular
  sensitivity to 59.1 percent and ventricular to 66.2 percent, at an overall
  accuracy of 78.4 percent.

### Rhythm

- `ecglab.rhythm` finds atrial fibrillation from the RR series: the coefficient of
  sample entropy (Lake and Moorman 2011) and the normalised successive-difference
  scatter, with thresholds from the literature. It is measured on the 23
  signal-bearing records of the MIT-BIH AF Database (`data/ecglab_rhythm_afdb.md`):
  episodes Se 75.6 / +P 71.8, duration Se 97.0 / +P 95.3, per second Se 97.0 / Sp
  96.8, Cohen's kappa 0.935.

### Heart rate variability

- `ecglab.hrv` measures heart rate variability by the 1996 Task Force definitions.
  Time domain: SDNN, SDANN, RMSSD, pNN50, the triangular index, TINN. Frequency
  domain: VLF, LF and HF by Welch, Lomb-Scargle or an autoregressive model.
  Non-linear: Poincare SD1 and SD2, DFA alpha1 and alpha2, sample and approximate
  entropy. The estimator, resampling, detrending, bands and ectopic rule are
  stored beside every number.

### Twelve-lead measurements

- `ecglab.leads` derives the standard leads a recording lacks. It measures the
  frontal QRS axis, the global PR, QRS and QT, the corrected QT, and the
  Sokolow-Lyon voltage. It prints the AHA/ACC/HRS normal range beside each value,
  with an inside/outside flag. These are measurements, not a diagnosis.

### The whole study, and its report

- `ecglab.analyze` runs the whole chain in one call and returns one
  `ecglab.analysis` struct. It detects the beats once and shares that series with
  the delineation, classification, rhythm and HRV. A step that cannot run leaves
  its field empty with a reason in `analysis.notes`, instead of stopping the
  study.
- `ecglab.report` writes the study as text, in English or French. The
  research-only disclaimer is the first and last line. Intervals are printed
  beside their normal ranges as flags, never as a diagnosis.
- `ecglab.reporthtml` writes the study as one self-contained HTML file that opens
  in any browser and prints to PDF. It holds the disclaimer banner, the summary
  chart, the calibrated strip, one beat, and the full text report. The pages are
  embedded as vector SVG by default.

### The reading pages

- `ecglab.strip` draws the ECG on calibrated grid paper at 25 mm/s and 10 mm/mV.
  The calibration is kept in the saved file. Layouts: 3x4 with a rhythm strip,
  6x2, 12x1, and a single lead.
- `ecglab.chart` draws the one-page summary from an `ecglab.analyze` result: the
  header tiles beside their normal ranges, the lanes on one shared time axis, the
  detector's evidence, the variability and the Poincare plot.
- `ecglab.beat` shows one beat with its fiducials and intervals, the detector's
  evidence and a class card. It pages through the record by moving the objects the
  figure already holds.

### Conventions

- One data model for every function: a recording (samples one column per lead in
  physical units, leads, units, rate, provenance) and annotations as columns
  (sample, time, symbol, num, subtype, channel, aux) in the PhysioNet vocabulary.
- Every public function has a help page in English and French and a test. Every
  file is pure ASCII. The readers are timed, and never call the core functions
  that are slow on a long record.
