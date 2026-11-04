# Config comparison (iterate set, 45 videos × runs [1, 2, 3], reference `tr-ost-mute`)

## Completeness

| config | scored runs | missing |
|---|---|---|
| `tr-ost-mute` | 135/135 | – |
| `tr-ost-mute-cat` | 135/135 | – |
| `tr-ost-mute-cat-refine` | 133/135 | 22_u17_r03_m_01 run1, 22_u17_r03_m_01 run3 |
| `tr-ost-mute-cat-refine-nosplit` | 123/135 | 22_u16_r03_c_02 run3, 22_u17_r03_c_02 run3, 22_u17_r03_c_03 run1, 22_u17_r03_m_01 run2, 07_u01_r02_m_01 run2, 07_u02_r03_c_01 run1, 07_u02_r03_c_01 run2, cc4d_22_21 run1, cc4d_22_24 run3, cc4d_22_26 run2, cc4d_22_4 run1, cc4d_22_4 run2 |

## Pooled per domain (all scored runs)

Step hit = judged (Muse Spark); temporal IoU F1 = judge-free. Spread = min–max of the pooled F1 across runs.

| domain | config | step hit P | R | F1 | F1 spread | IoU F1 | steps / guide |
|---|---|---|---|---|---|---|---|
| PC repair (16) | `tr-ost-mute` | 0.47 | 0.48 | **0.47** | 0.46–0.49 | 0.74 | 8.8 |
| PC repair (16) | `tr-ost-mute-cat` | 0.54 | 0.53 | **0.54** | 0.51–0.55 | 0.76 | 8.5 |
| PC repair (16) | `tr-ost-mute-cat-refine` | 0.35 | 0.47 | **0.40** | 0.35–0.42 | 0.65 | 11.8 |
| PC repair (16) | `tr-ost-mute-cat-refine-nosplit` | 0.52 | 0.52 | **0.52** | 0.51–0.54 | 0.76 | 8.5 |
| Drill bit (23) | `tr-ost-mute` | 0.61 | 0.63 | **0.62** | 0.57–0.65 | 0.79 | 4.9 |
| Drill bit (23) | `tr-ost-mute-cat` | 0.61 | 0.62 | **0.61** | 0.55–0.67 | 0.80 | 4.8 |
| Drill bit (23) | `tr-ost-mute-cat-refine` | 0.42 | 0.58 | **0.49** | 0.48–0.49 | 0.69 | 6.5 |
| Drill bit (23) | `tr-ost-mute-cat-refine-nosplit` | 0.64 | 0.64 | **0.64** | 0.58–0.69 | 0.81 | 4.8 |
| Omelet (6) | `tr-ost-mute` | 0.38 | 0.41 | **0.40** | 0.37–0.42 | 0.68 | 14.4 |
| Omelet (6) | `tr-ost-mute-cat` | 0.41 | 0.47 | **0.44** | 0.39–0.48 | 0.70 | 15.8 |
| Omelet (6) | `tr-ost-mute-cat-refine` | 0.28 | 0.50 | **0.36** | 0.34–0.37 | 0.58 | 24.5 |
| Omelet (6) | `tr-ost-mute-cat-refine-nosplit` | 0.39 | 0.46 | **0.42** | 0.41–0.43 | 0.68 | 16.0 |

## Reference noise

Per video, the standard deviation of step hit F1 across the 3 runs of `tr-ost-mute` (median over videos), and the pooled F1 difference between two halves of the reference's own runs (run 1 vs run 2) — a config difference smaller than this is not distinguishable from rerunning the same config.

| domain | median per-video SD | run 1 vs run 2 pooled F1 |
|---|---|---|
| PC repair | 0.08 | 0.47 vs 0.49 (-0.02) |
| Drill bit | 0.13 | 0.57 vs 0.65 (-0.08) |
| Omelet | 0.07 | 0.39 vs 0.37 (+0.02) |

## Paired per-video difference vs `tr-ost-mute`: step hit F1 (judged)

3-run mean per video, config minus reference. Wins/losses ignore |diff| < 0.01. Sign test two-sided; interval = bootstrap 95% over videos.

| domain | config | mean diff | 95% interval | wins / losses / ties | sign test p |
|---|---|---|---|---|---|
| PC repair | `tr-ost-mute-cat` | +0.053 | -0.002 … +0.114 | 10 / 2 / 4 | 0.04 |
| PC repair | `tr-ost-mute-cat-refine` | -0.083 | -0.136 … -0.032 | 3 / 12 / 1 | 0.04 |
| PC repair | `tr-ost-mute-cat-refine-nosplit` | +0.049 | -0.014 … +0.117 | 9 / 6 / 1 | 0.61 |
| Drill bit | `tr-ost-mute-cat` | +0.001 | -0.053 … +0.051 | 12 / 10 / 1 | 0.83 |
| Drill bit | `tr-ost-mute-cat-refine` | -0.124 | -0.172 … -0.075 | 2 / 20 / 1 | 0.00 |
| Drill bit | `tr-ost-mute-cat-refine-nosplit` | +0.025 | -0.018 … +0.071 | 11 / 10 / 2 | 1.00 |
| Omelet | `tr-ost-mute-cat` | +0.043 | +0.003 … +0.084 | 5 / 1 / 0 | 0.22 |
| Omelet | `tr-ost-mute-cat-refine` | -0.032 | -0.116 … +0.053 | 2 / 3 / 1 | 1.00 |
| Omelet | `tr-ost-mute-cat-refine-nosplit` | +0.033 | -0.011 … +0.082 | 3 / 2 / 1 | 1.00 |

## Paired per-video difference vs `tr-ost-mute`: temporal IoU F1 (judge-free)

3-run mean per video, config minus reference. Wins/losses ignore |diff| < 0.01. Sign test two-sided; interval = bootstrap 95% over videos.

| domain | config | mean diff | 95% interval | wins / losses / ties | sign test p |
|---|---|---|---|---|---|
| PC repair | `tr-ost-mute-cat` | +0.017 | -0.023 … +0.054 | 10 / 5 / 1 | 0.30 |
| PC repair | `tr-ost-mute-cat-refine` | -0.095 | -0.128 … -0.063 | 1 / 15 / 0 | 0.00 |
| PC repair | `tr-ost-mute-cat-refine-nosplit` | +0.020 | -0.013 … +0.055 | 10 / 6 / 0 | 0.45 |
| Drill bit | `tr-ost-mute-cat` | +0.014 | -0.013 … +0.043 | 13 / 8 / 2 | 0.38 |
| Drill bit | `tr-ost-mute-cat-refine` | -0.093 | -0.128 … -0.055 | 3 / 20 / 0 | 0.00 |
| Drill bit | `tr-ost-mute-cat-refine-nosplit` | +0.020 | -0.006 … +0.047 | 15 / 7 / 1 | 0.13 |
| Omelet | `tr-ost-mute-cat` | +0.018 | -0.009 … +0.042 | 4 / 1 / 1 | 0.38 |
| Omelet | `tr-ost-mute-cat-refine` | -0.093 | -0.183 … -0.002 | 2 / 4 / 0 | 0.69 |
| Omelet | `tr-ost-mute-cat-refine-nosplit` | -0.010 | -0.040 … +0.020 | 2 / 3 / 1 | 1.00 |

## By participant: step hit F1 3-run mean difference vs reference (mean over the participant's videos)

| domain | participant | videos | `tr-ost-mute-cat` | `tr-ost-mute-cat-refine` | `tr-ost-mute-cat-refine-nosplit` |
|---|---|---|---|---|---|
| Drill bit | u01 | 5 | -0.02 | -0.18 | -0.06 |
| Drill bit | u02 | 6 | -0.06 | -0.08 | +0.08 |
| Drill bit | u15 | 4 | +0.11 | -0.08 | +0.08 |
| Drill bit | u16 | 4 | -0.00 | -0.08 | +0.02 |
| Drill bit | u17 | 4 | +0.01 | -0.20 | +0.00 |
| Omelet | person 1 | 3 | +0.01 | -0.01 | +0.01 |
| Omelet | person 6 | 3 | +0.08 | -0.06 | +0.05 |
| PC repair | u01 | 4 | +0.01 | -0.13 | -0.04 |
| PC repair | u15 | 4 | +0.01 | -0.05 | -0.01 |
| PC repair | u16 | 4 | +0.06 | -0.10 | +0.06 |
| PC repair | u17 | 4 | +0.13 | -0.05 | +0.19 |

## Per video: step hit F1, 3-run mean

| video | `tr-ost-mute` | `tr-ost-mute-cat` | `tr-ost-mute-cat-refine` | `tr-ost-mute-cat-refine-nosplit` |
|---|---|---|---|---|
| 22_u01_r07_c_01 | 0.47 | 0.47 | 0.37 | 0.40 |
| 22_u01_r07_c_02 | 0.38 | 0.47 | 0.33 | 0.47 |
| 22_u01_r07_c_03 | 0.46 | 0.50 | 0.27 | 0.39 |
| 22_u01_r07_m_01 | 0.57 | 0.47 | 0.41 | 0.47 |
| 22_u15_r03_c_01 | 0.46 | 0.46 | 0.39 | 0.53 |
| 22_u15_r03_c_02 | 0.46 | 0.48 | 0.50 | 0.41 |
| 22_u15_r03_c_03 | 0.43 | 0.44 | 0.43 | 0.36 |
| 22_u15_r03_m_01 | 0.48 | 0.48 | 0.28 | 0.48 |
| 22_u16_r03_c_01 | 0.43 | 0.75 | 0.47 | 0.68 |
| 22_u16_r03_c_02 | 0.42 | 0.44 | 0.38 | 0.48 |
| 22_u16_r03_c_03 | 0.39 | 0.49 | 0.35 | 0.49 |
| 22_u16_r03_m_01 | 0.55 | 0.36 | 0.19 | 0.36 |
| 22_u17_r03_c_01 | 0.53 | 0.84 | 0.40 | 0.88 |
| 22_u17_r03_c_02 | 0.57 | 0.68 | 0.68 | 0.80 |
| 22_u17_r03_c_03 | 0.58 | 0.62 | 0.49 | 0.65 |
| 22_u17_r03_m_01 | 0.49 | 0.58 | 0.40 | 0.63 |
| 07_u01_r02_c_01 | 0.52 | 0.40 | 0.17 | 0.33 |
| 07_u01_r02_c_02 | 0.64 | 0.75 | 0.45 | 0.68 |
| 07_u01_r02_c_03 | 0.85 | 0.70 | 0.67 | 0.77 |
| 07_u01_r02_c_04 | 0.64 | 0.70 | 0.56 | 0.57 |
| 07_u01_r02_m_01 | 0.58 | 0.59 | 0.46 | 0.57 |
| 07_u02_r03_c_01 | 0.52 | 0.38 | 0.36 | 0.80 |
| 07_u02_r03_c_02 | 0.43 | 0.44 | 0.40 | 0.44 |
| 07_u02_r03_c_03 | 0.64 | 0.48 | 0.58 | 0.69 |
| 07_u02_r03_c_04 | 0.84 | 0.86 | 0.62 | 0.79 |
| 07_u02_r03_c_05 | 0.93 | 0.59 | 0.71 | 0.90 |
| 07_u02_r03_m_01 | 0.33 | 0.56 | 0.54 | 0.56 |
| 07_u15_r04_c_01 | 0.84 | 0.81 | 0.67 | 0.75 |
| 07_u15_r04_c_02 | 0.07 | 0.25 | 0.07 | 0.17 |
| 07_u15_r04_c_03 | 0.38 | 0.61 | 0.46 | 0.61 |
| 07_u15_r04_m_01 | 0.63 | 0.70 | 0.40 | 0.70 |
| 07_u16_r04_c_01 | 0.30 | 0.30 | 0.26 | 0.37 |
| 07_u16_r04_c_02 | 0.82 | 0.89 | 0.73 | 0.83 |
| 07_u16_r04_c_03 | 0.59 | 0.56 | 0.44 | 0.57 |
| 07_u16_r04_m_01 | 0.51 | 0.47 | 0.47 | 0.53 |
| 07_u17_r03_c_01 | 0.96 | 0.93 | 0.65 | 0.93 |
| 07_u17_r03_c_02 | 0.69 | 0.77 | 0.59 | 0.82 |
| 07_u17_r03_c_03 | 0.73 | 0.59 | 0.58 | 0.71 |
| 07_u17_r03_m_01 | 0.49 | 0.63 | 0.26 | 0.43 |
| cc4d_22_10 | 0.37 | 0.34 | 0.51 | 0.34 |
| cc4d_22_13 | 0.44 | 0.50 | 0.32 | 0.43 |
| cc4d_22_21 | 0.21 | 0.34 | 0.17 | 0.35 |
| cc4d_22_24 | 0.51 | 0.53 | 0.32 | 0.50 |
| cc4d_22_26 | 0.48 | 0.51 | 0.47 | 0.50 |
| cc4d_22_4 | 0.36 | 0.41 | 0.40 | 0.45 |
