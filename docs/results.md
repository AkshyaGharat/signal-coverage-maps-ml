# Experimental Results & Research Findings

**Project Title:** Signal Coverage Maps Using Measurements and Machine Learning  
**Dataset:** CIM-5G (Chongqing 5G UAV & Ground Measurement Dataset)  

---

## Benchmark Performance Matrix

Evaluated on N = 1,889 held-out test observations from genuine physical measurements:

| Prediction Mode | Model Key | RMSE (dB) | MAE (dB) | R² | Bias (dB) | Weak-Signal RMSE (< −85 dBm) | Coverage ≥ −80 dBm (%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Mode A: Calibrated LDPL** | `P0` | **5.78** | 4.25 | 0.463 | −0.12 | 9.54 | 75.97% |
| **Mode B1: LDPL + Isotropic Kriging** | `P1` | **5.20** | 3.63 | 0.566 | +0.17 | 8.31 | 70.20% |
| **Mode B2: LDPL + Additive SASR** | `P2` | **5.26** | 3.67 | 0.556 | +0.14 | 8.60 | 72.37% |
| **Mode C: Direct Random Forest** | `RF` | **4.44** | 2.98 | 0.684 | −0.11 | 7.84 | 74.38% |
| **Mode D: Hybrid Physics + RF Residual** | `P3` | **5.13** | 3.57 | 0.578 | −0.32 | 8.13 | 70.36% |

---

## Component Ablation (Δ RMSE Decomposition)

| Transition | Comparison | Δ RMSE (dB) | Physical & Methodological Meaning |
| :--- | :--- | :---: | :--- |
| **P0 → P1** | RMSE(P0) − RMSE(P1) | **+0.58** | Spatial covariance captures correlated shadow-fading. |
| **P1 → P2** | RMSE(P1) − RMSE(P2) | **−0.06** | Parity on dense grid; sector anisotropy excels under sparse trajectories. |
| **P2 → P3** | RMSE(P2) − RMSE(P3) | **+0.13** | Genuine ML residual correction gain without data leakage. |
| **P2 → RF** | RMSE(P2) − RMSE(RF) | **+0.82** | Direct RF fits non-linear geographic coordinates (+0.33 dB shortcut). |
| **P0 → P3** | RMSE(P0) − RMSE(P3) | **+0.65** | Total accuracy gain from pure physics to hybrid synthesis. |

![Actual vs Predicted RSRP across Four Modes](../figures/ml/actual_vs_predicted_four_modes.png)

---

## Key Research Insights

### 1. Macro Physics Foundation (P₀)

Explains **46.3%** of total variance (5.78 dB RMSE) using only 3D transceiver distance. This confirms that the Log-Distance Path Loss model provides a meaningful physical baseline even in complex mountainous terrain.

### 2. Spatial Reconstruction Value (P₁)

Geostatistical Kriging adds a significant **+0.58 dB** improvement, proving that local shadow fading is spatially structured. The isotropic exponential kernel captures correlated signal variations across the study area.

### 3. The Coordinate Shortcut in Direct ML

When trained with geographic coordinates (`Center_X`, `Center_Y`), direct RF achieves **4.42 dB** RMSE (R² = 0.686). When coordinates are withheld, RMSE rises to **4.76 dB** (R² = 0.637). This **+0.33 dB** gain represents local coordinate fitting rather than generalized propagation modeling.

### 4. Hybrid Robustness (P₃)

In Mode D, withholding coordinates changes RMSE by only **0.04 dB** (5.07 dB → 5.11 dB). The physical baseline and spatial Kriging handle geometry and shadow fading, freeing the residual RF to learn genuine terrain and antenna interactions.

---

## Related Documentation

- [Methodology & Prediction Modes](methodology.md) — Full mathematical formulations
- [ML Integration Report](ml_integration_report.md) — Complete pipeline details

