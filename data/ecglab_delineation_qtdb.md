# Wave delineation on the QT Database

Generated 2026-09-14 by data/make_ecglab_delineation.m.

- Database: QT Database (qtdb), 105 record(s) requested, 105 measured against annotator 1, 11 against annotator 2.
- Lead: the channel the manual marks were made on (signal 0 on every QT Database record, so the first lead).
- Boundary setting: QRS onset and offset read outward to 0.06 of the slope maximum (Martinez et al. 2004).
- Matching window: 150 ms (QRS peak).
- Error convention: delineated minus manual, in milliseconds; a negative mean is early.
- CSE tolerance: the accepted standard deviation of a program boundary (survey 5.3); the QT Database is two-lead Holter data, so the SD exceeding it on P and QRS onset is expected (survey 5.6).
- Nelson build: 2.0.0.0 (Forge).

## Annotator 1 (.q1c), every record

| Fiducial | Mean +/- SD (ms) | n | Se (%) | CSE tol (ms) | SD within CSE |
|---|---:|---:|---:|---:|:---:|
| Pon | 41.62 +/- 27.33 | 2525 | 80.65 | 10.2 | no |
| Ppeak | 0.83 +/- 25.04 | 2525 | 80.65 | - | - |
| Poff | -30.56 +/- 26.21 | 2525 | 80.65 | 12.7 | no |
| QRSon | -8.77 +/- 33.40 | 3560 | 100.00 | 6.5 | no |
| Q | - | 0 | - | - | - |
| R | -9.31 +/- 14.42 | 3560 | 100.00 | - | - |
| S | - | 0 | - | - | - |
| QRSoff | 13.77 +/- 44.62 | 3560 | 100.00 | 11.6 | no |
| J | - | 0 | - | - | - |
| Ton | 89.66 +/- 88.64 | 1381 | 100.00 | - | - |
| Tpeak | 11.94 +/- 62.94 | 3479 | 100.00 | - | - |
| Toff | -4.38 +/- 70.34 | 3479 | 100.00 | 30.6 | no |

_Pooled over 105 records, sel100, sel102, sel103, sel104, sel114, sel116, sel117, sel123, sel14046, sel14157, sel14172, sel15814, sel16265, sel16272, sel16273, sel16420, sel16483, sel16539, sel16773, sel16786, sel16795, sel17152, sel17453, sel213, sel221, sel223, sel230, sel231, sel232, sel233, sel30, sel301, sel302, sel306, sel307, sel308, sel31, sel310, sel32, sel33, sel34, sel35, sel36, sel37, sel38, sel39, sel40, sel41, sel42, sel43, sel44, sel45, sel46, sel47, sel48, sel49, sel50, sel51, sel52, sel803, sel808, sel811, sel820, sel821, sel840, sel847, sel853, sel871, sel872, sel873, sel883, sel891, sele0104, sele0106, sele0107, sele0110, sele0111, sele0112, sele0114, sele0116, sele0121, sele0122, sele0124, sele0126, sele0129, sele0133, sele0136, sele0166, sele0170, sele0203, sele0210, sele0211, sele0303, sele0405, sele0406, sele0409, sele0411, sele0509, sele0603, sele0604, sele0606, sele0607, sele0609, sele0612, sele0704._

## Annotator 2 (.q2c), the eleven doubly annotated records

| Fiducial | Mean +/- SD (ms) | n | Se (%) | CSE tol (ms) | SD within CSE |
|---|---:|---:|---:|---:|:---:|
| Pon | - | 0 | - | 10.2 | - |
| Ppeak | - | 0 | - | - | - |
| Poff | - | 0 | - | 12.7 | - |
| QRSon | -2.45 +/- 19.00 | 372 | 100.00 | 6.5 | no |
| Q | - | 0 | - | - | - |
| R | -6.37 +/- 7.64 | 372 | 100.00 | - | - |
| S | - | 0 | - | - | - |
| QRSoff | 12.78 +/- 33.12 | 372 | 100.00 | 11.6 | no |
| J | - | 0 | - | - | - |
| Ton | -52.00 +/- 11.31 | 2 | 100.00 | - | - |
| Tpeak | 10.94 +/- 41.72 | 370 | 100.00 | - | - |
| Toff | -14.37 +/- 46.57 | 370 | 100.00 | 30.6 | no |

_Pooled over 11 records, sel100, sel102, sel103, sel114, sel116, sel117, sel123, sel213, sel221, sel223, sel230._
