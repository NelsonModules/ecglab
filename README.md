# ecglab

An electrocardiography laboratory for
[Nelson](https://nelson-lang.github.io/nelson-website/). It reads an ECG from
the common open formats, finds the beats, measures the waves, labels the beats,
finds the rhythm, computes heart rate variability and the twelve-lead
measurements, draws the signal on calibrated paper, and reports which record
and which figure each result was checked against.

> **Research software, not a medical device.** ecglab is for research and
> teaching. It is not a medical device and must not be used for clinical
> diagnosis, patient monitoring, treatment decisions, or any medical purpose.

## Install

```
run('/path/to/ecglab/loader.m')
```

Requires Nelson 2.0.0 or later.

## API

| Function | What it does |
| --- | --- |
| `ecglab.readwfdb` | read a WFDB record (all signal formats), with its annotations |
| `ecglab.writewfdb` | write a recording and its annotations as a WFDB record |
| `ecglab.readedf` | read an EDF or EDF+ file, with annotations |
| `ecglab.writeedf` | write a recording and its annotations as EDF+ |
| `ecglab.readcsv` | read an ECG from a text file, one column per lead |
| `ecglab.readishne` | read a Holter recording in the ISHNE format |
| `ecglab.simulate` | make a synthetic ECG with known beats and waves, for tests and demos |
| `ecglab.reference` | download a record from PhysioNet once and read it |
| `ecglab.clean` | remove baseline wander and mains interference |
| `ecglab.quality` | report, window by window, whether the signal is readable |
| `ecglab.detect` | find the beats, with one of seven detectors or their consensus |
| `ecglab.delineate` | find the P, QRS and T onsets, peaks and ends, and the PR, QRS, QT and QTc intervals |
| `ecglab.classify` | label each beat in the five AAMI classes |
| `ecglab.rhythm` | find the rhythm episodes: sinus, atrial fibrillation and others |
| `ecglab.hrv` | heart rate variability (Task Force definitions) in time, frequency and nonlinear measures |
| `ecglab.leads` | twelve-lead measurements: derived leads, frontal axis, global intervals, corrected QT |
| `ecglab.analyze` | run the whole analysis of a recording in one call |
| `ecglab.validate` | compare an analysis against reference annotations following the standards |
| `ecglab.strip` | draw the ECG on calibrated paper (25 mm/s, 10 mm/mV, grid and pulse) |
| `ecglab.chart` | the one-page summary of a recording |
| `ecglab.beat` | view one beat with the detector, delineator and classifier output |
| `ecglab.report` | print the measurement report, or return it as text |
| `ecglab.reporthtml` | the study as a self-contained HTML page, printable to PDF |
| `ecglab.demo` | the guided tour: run the module end to end |

## License

LGPL-3.0-or-later.
