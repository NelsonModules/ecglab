# Beat detection under noise, on the Noise Stress Test Database

Generated 2026-09-14 by data/make_ecglab_noise.m.

- Database: MIT-BIH Noise Stress Test Database (nstdb), records 118 and 119 with calibrated noise added in two-minute bursts.
- Signal-to-noise ratios: 24, 18, 12, 6, 0, -6 dB. Reference: the clean records' own .atr annotations, the same truth at every level.
- Comparator: ANSI/AAMI EC57, 150 ms matching window, 300 s learning period; pooled over the two records.
- Nelson build: 2.0.0.0 (Forge).

## Sensitivity by signal-to-noise ratio (%)

| Detector | 24 dB | 18 dB | 12 dB | 6 dB | 0 dB | -6 dB |
|---|---:|---:|---:|---:|---:|---:|
| pantompkins | 100.0 | 100.0 | 99.8 | 98.2 | 88.3 | 50.0 |
| hamilton | 100.0 | 100.0 | 99.7 | 98.1 | 93.7 | 82.1 |
| christov | 100.0 | 100.0 | 99.7 | 95.3 | 80.8 | 62.6 |
| engzee | 99.6 | 98.8 | 97.0 | 94.4 | 87.4 | 73.4 |
| wavelet | 100.0 | 100.0 | 100.0 | 98.5 | 92.5 | 71.9 |
| elgendi | 100.0 | 99.9 | 99.7 | 97.1 | 89.4 | 81.8 |
| wqrs | 100.0 | 99.5 | 96.6 | 92.0 | 85.4 | 77.3 |

## Positive predictivity by signal-to-noise ratio (%)

| Detector | 24 dB | 18 dB | 12 dB | 6 dB | 0 dB | -6 dB |
|---|---:|---:|---:|---:|---:|---:|
| pantompkins | 99.9 | 99.9 | 96.9 | 81.4 | 70.9 | 55.3 |
| hamilton | 99.9 | 99.9 | 95.1 | 80.4 | 69.9 | 63.8 |
| christov | 99.4 | 97.6 | 91.3 | 82.5 | 73.8 | 65.9 |
| engzee | 99.3 | 98.4 | 87.7 | 73.7 | 66.0 | 60.1 |
| wavelet | 100.0 | 99.7 | 91.3 | 76.9 | 68.1 | 60.4 |
| elgendi | 99.8 | 96.8 | 90.5 | 82.4 | 71.6 | 64.4 |
| wqrs | 100.0 | 98.7 | 87.7 | 73.9 | 65.8 | 62.2 |

Every detector holds its beats down to about 6 dB; below that they part company. In the worst noise (-6 dB) several keep over three quarters of their sensitivity (Hamilton and Elgendi the most, near 82 percent) while Pan-Tompkins falls to about half. These are measurements on two records, a guide to which detector to reach for on noisy data, not a clinical claim.

Research software, not a medical device. ecglab is for research and education. It is not a medical device and must not be used for clinical diagnosis, patient monitoring, treatment decisions, or any medical purpose.
