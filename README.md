# Physically Guided Sparse 5G RSRP Signal Coverage Reconstruction and Residual Machine Learning

[![MATLAB](https://img.shields.io/badge/Platform-MATLAB%20R2026a-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Dataset](https://img.shields.io/badge/Dataset-CIM--5G-green.svg)](https://github.com)
[![Status](https://img.shields.io/badge/Status-Four--Mode%20Architecture%20Verified-brightgreen.svg)](#)

A MATLAB research framework for **physically guided sparse 5G Reference Signal Received Power (RSRP) reconstruction** and **residual learning over propagation-informed spatial fields** using UAV-assisted empirical measurements from the CIM-5G dataset in mountainous urban terrain.

---

## 1. Problem Description

Dense, high-resolution mapping of wireless radio frequency (RF) coverage is vital for 5G cellular network deployment, handover optimization, and drone corridor trajectory planning. However, exhaustive physical drive testing across complex topographies is economically prohibitive and operationally unfeasible in urban and mountainous terrain. 

Standard empirical interpolation techniques (e.g., nearest-neighbor or ordinary Kriging) often ignore the physics of radio propagation, failing to generalize across topographically complex regions or shadowed valleys. Conversely, purely physical ray-tracing models require detailed 3D building and terrain databases that are often unavailable or computationally intractable at large scales.

This research addresses the challenge of **reconstructing continuous 5G signal coverage maps from sparse, non-uniform measurement budgets (1% to 10%)** by systematically integrating:
1. Physical macro-scale propagation modeling (Log-Distance Path Loss),
2. Mathematical geostatistical spatial field reconstruction with sector-aligned anisotropic covariance, and
3. Non-linear machine learning residual learning over the remaining propagation residuals.

---

## 2. Dataset Overview: CIM-5G

The evaluation is conducted on the **CIM-5G dataset** collected across a mountainous urban region in Chongqing, China ($29.50^\circ\text{N}$ to $29.54^\circ\text{N}$, $106.67^\circ\text{E}$ to $106.72^\circ\text{E}$), comprising:
- **81,419 Raw Mobile Measurements:** UAV and ground-based multi-altitude observations of 5G New Radio (NR) Synchronization Signal RSRP (SS-RSRP, dBm), RSRQ, and SINR.
- **10 Base Station Transceivers:** Transmit powers ($P_{\text{tx}} = 24\text{ dBm}$), mechanical and electrical downtilts, carrier frequencies (3.5 GHz band n78), and sector compass azimuths.
- **10,000-Cell Fishnet Grid ($100 \times 100$ at $30\text{m} \times 30\text{m}$ resolution):** Environmental feature raster extractions including Digital Elevation Model (DEM) terrain altitude, Normalized Difference Vegetation Index (NDVI), planar building footprint density, and area-weighted building height.
- **Ground Truth Integrity Protocol:** Exactly **9,448 grid cells** represent genuine physical measurements (`is_observed == 1`, aggregating 67,534 raw records). Exactly **552 cells** are author-interpolated (`is_observed == 0`). In accordance with strict experimental standards, **author-interpolated cells are excluded from all model training and accuracy evaluations**, being utilized only for continuous spatial map rendering.

---

## 3. Why Sparse Coverage Reconstruction Matters

Physical measurement campaigns in practical cellular deployments face severe budget and operational constraints:
- **Flight Trajectory Voids:** UAV surveys encounter battery limitations and line-of-sight dropouts, creating large spatial observation voids.
- **Sampling Regimes:** In practice, operators collect either random spot checks, uniform grid sweeps, or clustered flight trajectories.
- **Goal:** Accurately reconstruct continuous coverage and reliably detect critical weak-signal zones ($\text{RSRP} < -85\text{ dBm}$) using as few as 1% to 10% of total spatial locations.

---

## 4. Research Questions

This project explicitly separates and evaluates four distinct prediction modes (five evaluated models) to answer three fundamental questions:

1. **Theoretical / Physical Baseline:**
   *"What can established propagation and spatial mathematics reconstruct from sparse measurements alone?"*
2. **Machine Learning Alone:**
   *"What predictive capability does a non-linear machine learning model achieve when predicting signal strength directly from environmental and geometric features?"*
3. **Hybrid Synthesis:**
   *"Does residual machine learning over a propagation-informed spatial reconstruction add measurable predictive value beyond the physical baseline?"*

---

## 5. Four Prediction Modes, Five Evaluated Models

To ensure transparent, defensible comparisons, the framework formalizes **four prediction modes** encompassing **five evaluated models**:

```
CIM-5G Sparse Measurements
   │
   ├── Mode A: P0 (LDPL Physics Baseline)
   │
   ├── Mode B: Physics + Mathematical Reconstruction
   │     ├── P1: LDPL + Isotropic Residual Reconstruction
   │     └── P2: LDPL + Sector-Aware Anisotropic Reconstruction
   │                  │
   │                  ▼
   │          OOF P2 residuals (Fold k: fit on tr \ k -> predict k)
   │                  │
   │                  ▼
   │          Residual Random Forest
   │                  │
   │                  ▼
   └── Mode D: P3 (Hybrid Physics + ML Residual Correction)

Separately:
CIM-5G Measurements ──► Mode C: RF (Direct Random Forest ML-Only)
```

- **Mode A $\rightarrow$ P0:** Pure Log-Distance Path Loss physics baseline ($PL_0 = 61.88\text{ dB}, n = 1.46$).
- **Mode B $\rightarrow$ P1, P2:** Mathematical spatial reconstruction using isotropic exponential Kriging ($P_1$) and additive sector-aligned anisotropic SASR ($P_2$).
- **Mode C $\rightarrow$ RF:** ML-only direct Random Forest predicting raw $\text{SS\_RSRP}$ from 16 features.
- **Mode D $\rightarrow$ P3:** Complete hybrid combining physics + anisotropic spatial reconstruction + RF residual correction ($P_3 = P_2 + \text{RF}_{\text{res}}$).

### Model Formulations:

#### Mode A — Pure Theoretical / Physical Baseline ($P_0$)
A calibrated Log-Distance Path Loss (LDPL) model fitted strictly on training distance observations:
$$PL(d) = PL_0 + 10 n \log_{10}\left(\frac{d_{3D}}{d_0}\right)$$
$$\hat{R}_{P0}(d) = P_{\text{tx}} - PL(d)$$
where $P_{\text{tx}} = 24.0\text{ dBm}$, $d_0 = 1.0\text{ m}$, and $PL_0, n$ are estimated via linear least-squares on the training fold. Zero ML or RF features are used in this mode.

#### Mode B — Physics + Mathematical Spatial Reconstruction ($P_1$ & $P_2$)
Reconstructs the spatial shadow residual field $r(x) = y(x) - \hat{R}_{P0}(x)$ using geostatistical Kriging:
- **$P_1$ (Isotropic Residual):** Reconstructs residuals using a global isotropic exponential kernel:
  $$K_{\text{global}}(i,j) = \sigma_g^2 \exp\left(-\frac{d_{ij}}{\ell_g}\right) + \sigma_n^2 \delta_{ij}$$
- **$P_2$ (Additive Sector-Aligned Anisotropic SASR):** Applies the repaired positive semi-definite (PSD) additive kernel:
  $$\mathbf{K}(i,j) = \mathbf{K}_{\text{global}}(i,j) + \mathbf{1}(\text{cell}_i = \text{cell}_j = c) \, \mathbf{K}_{\text{cell}, c}(i,j) + \sigma_n^2 \delta_{ij}$$
  where $\mathbf{K}_{\text{cell}, c}$ projects coordinate offsets onto the serving sector boresight $(\theta_c)$ using verified compass-to-metric axis transformations, eliminating negative eigenvalue matrix collapse.

#### Mode C — Machine Learning Alone (Direct RF)
Uses an independent Random Forest ensemble (`TreeBagger`, 300 trees, minimum leaf size 10) to predict raw $\text{SS\_RSRP}$ directly from 16 environmental, geometric, and antenna features:
$$\hat{R}_{\text{RF}}(x) = f_{\text{RF}}(\mathbf{z}(x))$$

#### Mode D — Hybrid Physics + ML Residual Correction ($P_3$)
The final hybrid model combines physics, geostatistical reconstruction, and non-linear residual learning:
$$\hat{R}_{P3}(x) = \hat{R}_{P2}(x) + \hat{r}_{\text{ML}}(\mathbf{z}(x))$$
where $f_{\text{RF\_res}}$ is trained strictly on held-out out-of-fold (OOF) $P_2$ residuals.

---

## 6. Strict Data Leakage Prevention: Procedural Cross-Validation Proof

In geostatistical Kriging, evaluating $P_2$ in-sample forces $\hat{y}_{P2}(x_i) \approx y_i$. If residual training targets were computed as $y_i - \hat{y}_{P2}(x_i)$, the target residuals would artificially collapse toward zero, causing the ML model to learn nothing useful.

### Procedural Proof of Zero Leakage
Mathematically, non-zero residual variance alone does not prove zero leakage. The definitive proof is the **structural cross-validation procedure**:

```
Fold k
  ↓
Fit LDPL on training folds (tr \ k)
  ↓
Fit P2 / Additive SASR on training folds (tr \ k)
  ↓
Predict held-out fold k:  P2_prediction^OOF
  ↓
Calculate genuine held-out residual:  r_OOF,k = y_k - P2_prediction^OOF
```

1. Training data is partitioned into $K = 5$ disjoint folds.
2. For each fold $k \in \{1, \dots, K\}$:
   - Physical LDPL parameters ($PL_0^{(-k)}, n^{(-k)}$) are calibrated strictly on $tr \setminus k$.
   - Spatial residual reconstruction $\hat{r}_{\text{additive\_SASR}}^{(-k)}$ is conditioned strictly on observations in $tr \setminus k$.
   - Prediction $\hat{y}_{P2}^{(-k)}$ is evaluated on the held-out fold $k$.
   - Held-out residual is calculated: $r_{\text{OOF}, k} = y_k - \hat{y}_{P2}^{(-k)}$.
3. **Empirical Sanity Check (Not Proof):** Out-of-fold residual standard deviation is verified ($\text{std} = 5.25\text{ dB} > 1.0\text{ dB}$). This confirms that the numerical solver evaluated held-out points rather than accidentally reproducing in-sample interpolation.
4. Mode D Random Forest is trained on feature matrix $X_{\text{tr}}$ using $r_{\text{OOF}}$ as target.
5. All test evaluations are performed on strictly held-out test data (20% partition or sparse test indices) never seen during LDPL fitting, Kriging conditioning, or RF training.

---

## 7. Experimental Results and Research Integrity Audit

Evaluated on $N = 1,889$ strictly held-out test observations:

### Standardized Comparison Matrix (Five Evaluated Models)

| Prediction Mode | Model Key | RMSE (dB) | MAE (dB) | $R^2$ | Bias (dB) | Weak-Signal RMSE ($< -85$ dBm) | Coverage $\ge -80$ dBm (%) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Mode A: Calibrated LDPL** | `P0` | **5.78** | 4.25 | 0.463 | -0.12 | 9.54 | 75.97% |
| **Mode B1: LDPL + Isotropic Res** | `P1` | **5.20** | 3.63 | 0.566 | +0.17 | 8.31 | 70.20% |
| **Mode B2: LDPL + Additive SASR** | `P2` | **5.26** | 3.67 | 0.556 | +0.14 | 8.60 | 72.37% |
| **Mode C: Direct Random Forest** | `RF` | **4.44** | 2.98 | 0.684 | -0.11 | 7.84 | 74.38% |
| **Mode D: Hybrid Physics + RF Res** | `P3` | **5.13** | 3.57 | 0.578 | -0.32 | 8.13 | 70.36% |

### Numerical Ablation Deltas ($\Delta$ Decomposition)
- **Spatial Reconstruction Contribution:** $\Delta(P0, P1) = \text{RMSE}_{P0} - \text{RMSE}_{P1} = \mathbf{+0.58\text{ dB}}$
- **Sector Anisotropy Contribution:** $\Delta(P1, P2) = \text{RMSE}_{P1} - \text{RMSE}_{P2} = \mathbf{-0.06\text{ dB}}$
- **ML Residual Contribution:** $\Delta(P2, P3) = \text{RMSE}_{P2} - \text{RMSE}_{P3} = \mathbf{+0.13\text{ dB}}$
- **Direct ML vs Physics+Reconstruction:** $\Delta(P2, \text{RF}) = \text{RMSE}_{P2} - \text{RMSE}_{\text{RF}} = \mathbf{+0.82\text{ dB}}$
- **Total Physical-to-Hybrid Gain:** $\Delta(P0, P3) = \text{RMSE}_{P0} - \text{RMSE}_{P3} = \mathbf{+0.65\text{ dB}}$

### Research Narrative & Integrity Findings

The research story is **not**: *"Our hybrid model beats everything."*  
Scientifically presenting the results this way would be inaccurate. The actual empirical findings are far more interesting and defensible:

1. **Physics Baseline ($P_0$):** Captures large-scale distance decay ($5.78\text{ dB}$ RMSE, $R^2 = 0.463$) using only transceiver slant distance.
2. **Spatial Reconstruction ($P_1$):** Mathematical geostatistical interpolation provides a substantial $+0.58\text{ dB}$ reduction in error ($5.20\text{ dB}$ RMSE), proving that correlated shadow fading is effectively captured by spatial covariance.
3. **Anisotropic Sector Tuning ($P_2$ vs $P_1$):** On this particular dense-grid validation split (80% training density), adding sector-aligned anisotropy ($5.26\text{ dB}$) does not outperform isotropic Kriging ($-0.06\text{ dB}$ delta). Anisotropy provides structural value under directional, sparse flight corridors rather than dense isotropic grids.
4. **Direct Machine Learning (Mode C):** Direct Random Forest achieves the lowest empirical RMSE on this split ($4.44\text{ dB}$) primarily because decision trees non-linearly memorize local spatial coordinates (`Center_X` and `Center_Y` rank #1 and #2 in predictor importance).
5. **Hybrid Residual Correction ($P_3$):** RF residual correction provides a modest, genuine $+0.13\text{ dB}$ improvement over $P_2$ without data leakage (total $+0.65\text{ dB}$ over pure LDPL), while preserving continuous physical decay gradients that direct RF lacks.

---

## 8. Specific Integrity Investigations

### A. Spatial Coordinates Shortcut Investigation in Random Forest
To verify whether Random Forest achieves lower RMSE simply by memorizing geographic coordinates or by learning transferable radio propagation relationships:
- **Direct RF WITH Coordinates (`Center_X`, `Center_Y`):** $\text{RMSE} = \mathbf{4.42\text{ dB}}, \quad R^2 = 0.686$
- **Direct RF WITHOUT Coordinates (Transferable Features Only):** $\text{RMSE} = \mathbf{4.76\text{ dB}}, \quad R^2 = 0.637$
- **Coordinate Shortcut Gain:** $\mathbf{+0.33\text{ dB}}$
- **Finding:** Geographic coordinates provide $\approx 0.33\text{ dB}$ of local spatial fitting gain. Crucially, even without coordinates, non-linear interactions among distance, antenna tilt/azimuth, building height/density, and DEM altitude achieve $4.76\text{ dB}$, outperforming the physical baseline ($5.78\text{ dB}$) and confirming genuine non-linear propagation learning.

### B. Reconciliation of Calibrated LDPL Baseline Parameters
A critical audit reconciled the Phase 02 LDPL calibration ($PL_0 = -106.30\text{ dB}, n = 5.25$) with the integrated grid calibration ($PL_0 = 61.88\text{ dB}, n = 1.46$):
- **Equation & Formulation:** Both implement the exact same formula $\hat{R}_{\text{LDPL}}(d_{3D}) = P_{\text{tx}} - (PL_0 + 10 n \log_{10}(d_{3D} / d_0))$ with $P_{\text{tx}} = 24.0\text{ dBm}, d_0 = 1.0\text{ m}$.
- **Root Cause:** In Phase 02, mobile measurements were matched via `NCI == ECI` to macro base stations located kilometers north, resulting in slant distances of **$3.1\text{km}$ to $17.2\text{km}$ (mean: $9,675\text{m}$)**. Back-projecting that line fit to $1\text{m}$ yielded an unphysical negative intercept ($-106.30\text{ dB}$). In the integrated pipeline, cells are matched to local serving sectors (`True_3D_Dist`), spanning **$14\text{m}$ to $10,375\text{m}$ (mean: $606\text{m}$, median: $418\text{m}$)**.
- **Physical Validity:** Free space path loss at $3.5\text{ GHz}$ at $1\text{m}$ is $43.3\text{ dB}$. The empirical $PL_0 \approx 61.9\text{ dB}$ represents $43.3\text{ dB}$ free-space loss plus $\approx 18.6\text{ dB}$ near-field coupling and feeder losses, which is physically sound for local micro-cells.
- Detailed audit report: [`docs/ldpl_calibration_reconciliation.md`](file:///c:/Users/Armash%20Ansari/OneDrive/Desktop/Projects/Matlab/signal-coverage-maps/docs/ldpl_calibration_reconciliation.md).

---

## 8. Multi-Model Interactive Dashboard

A refactored, modular interactive dashboard (`src/visualization/coverage_dashboard.m`) is included:
- **Model Selector Dropdown:** Dynamically toggle between `Mode A (P0: LDPL)`, `Mode B1 (P1: Isotropic)`, `Mode B2 (P2: SASR)`, `Mode C (Direct RF)`, and `Mode D (P3: Hybrid)`.
- **Precomputed Consumption:** Visualizes full-grid predictions from `results/final/all_models_grid_predictions.csv` instantly without retraining.
- **Interactive Geographic Map:** GeographicAxes with `satellite`, `topographic`, `streets`, and `darkwater` basemaps.
- **Dynamic Threshold Control:** Real-time slider to inspect critical weak-signal zones ($< -85\text{ dBm}$) and coverage percentages ($\ge -70\text{ dBm}, \ge -80\text{ dBm}$).
- **Click-Coordinate Inspection:** Click any location to locate the nearest valid grid cell and simultaneously inspect the predicted RSRP for all five models at that exact coordinate.

---

## 9. Repository Structure

```
signal-coverage-maps/
├── data/
│   └── raw/
│       └── CIM-5G/
│           ├── raw_datas.csv                              # 81,419 raw measurement records
│           ├── base_station_data.csv                      # 10 serving macro base stations
│           └── fishnet_30x30_processed_feature_engineered.csv # 10,000-cell 30m grid
├── src/
│   ├── data/
│   │   ├── load_raw_data.m                                # Raw CSV dataset loader
│   │   └── clean_and_inspect_missing.m                    # Data cleansing and missingness audit
│   ├── baselines/
│   │   ├── ldpl_baseline.m                                # Calibrated Log-Distance Path Loss
│   │   └── isotropic_kriging.m                            # Ordinary geostatistical Kriging
│   ├── reconstruction/
│   │   ├── anisotropic_covariance.m                       # Additive PSD covariance kernel (Kg + Kc)
│   │   ├── anisotropic_kriging.m                          # Sector-aligned spatial reconstruction
│   │   ├── residual_reconstruction.m                      # P1/P2 residual reconstruction pipeline
│   │   └── sector_coordinate_transform.m                  # Compass-to-sector coordinate mapping
│   ├── ml/
│   │   ├── extract_ml_features.m                          # Standardized 16-feature extractor
│   │   ├── train_rf_model.m                               # Mode C direct Random Forest trainer
│   │   ├── compute_oof_residuals.m                        # Zero-leakage K-fold out-of-fold engine
│   │   ├── train_rf_residual.m                            # Mode D residual Random Forest trainer
│   │   ├── predict_rf.m                                   # General RF inference engine
│   │   └── predict_hybrid.m                               # Mode D hybrid prediction synthesizer
│   ├── evaluation/
│   │   ├── evaluate_four_modes.m                          # Standardized multi-mode evaluation
│   │   ├── sparse_sampling.m                              # Random, Uniform, Clustered subsampler
│   │   └── cross_cell_split.m                             # Cell holdout validation split
│   └── visualization/
│       └── coverage_dashboard.m                           # Modular 5-mode interactive UI
├── experiments/
│   ├── 00_environment_test.m                              # Toolbox and environment audit
│   ├── 01_dataset_exploration.m                           # Spatial coverage and data characterization
│   ├── 02_structure_analysis.m                            # Empirical variograms and nonstationarity
│   ├── 03_anisotropic_reconstruction.m                    # Phase 03 SASR reconstruction benchmark
│   ├── validate_p1_vs_p2.m                                # 30-run paired Monte Carlo validation
│   ├── 04_ml_residual.m                                   # ML residual learning & OOF validation
│   ├── 05_model_comparison.m                              # 12-regime 5-mode standardized benchmark
│   ├── 06_interactive_coverage_map.m                      # 10k grid prediction & map export
│   └── run_all.m                                          # Master pipeline execution script
├── models/
│   └── random_forest/                                     # Saved .mat trained models
├── results/
│   ├── reconstruction/                                    # P1 vs P2 validation metrics
│   ├── ml/                                                # Mode C & Mode D benchmark metrics
│   ├── comparison/                                        # Multi-regime comparison CSV & JSON
│   └── final/                                             # 10,000-cell all_models_grid_predictions.csv
├── figures/
│   ├── dataset/                                           # Empirical spatial figures
│   ├── reconstruction_repair/                             # Phase 03-R repair validation figures
│   ├── ml/                                                # Feature importance & actual vs predicted
│   └── final/                                             # Publication 5-mode coverage maps
├── docs/
│   ├── ml_integration_audit.md                            # Comprehensive pre-integration audit
│   ├── ml_integration_report.md                           # Final integration & leakage report
│   └── phase03_repair.md                                  # Additive covariance proof & validation
├── run_all.m                                              # Root entry point
└── README.md
```

---

## 10. Reproducibility & Execution

### Prerequisites
- MATLAB R2022a or newer (developed and verified on MATLAB R2026a).
- Required Toolboxes:
  - **Statistics and Machine Learning Toolbox** (for `TreeBagger`, `fitrensemble`, `cvpartition`)
  - **Mapping Toolbox** (for `geoaxes`, `geoscatter`)

### Quick Start
To run the complete reproducible research pipeline from MATLAB:
```matlab
% Execute the master pipeline:
run_all
```

To run individual experiment phases:
```matlab
addpath(genpath('src'));

% Phase 04: Train Mode C & Mode D with out-of-fold residual learning
eval(fileread('experiments/04_ml_residual.m'));

% Phase 05: Standardized 12-regime comparison across Random/Uniform/Clustered sampling
eval(fileread('experiments/05_model_comparison.m'));

% Phase 06: Generate 10,000-cell coverage maps and launch dashboard
eval(fileread('experiments/06_interactive_coverage_map.m'));
```

To launch the interactive dashboard with precomputed grid predictions:
```matlab
addpath(genpath('src'));
coverage_dashboard('results/final/all_models_grid_predictions.csv');
```

---

## 11. Research Team & Citation

- **Team Members:** Akshya Gharat, Tanisha Chawande, Sejal Shahane, Armash Ansari  
- **Dataset Reference:** Tingting Xu et al., *"A Real-time 5G Macro-cells Signal Dataset for Signal Model Simulation and Prediction within Complex Terrain Areas"*, Chongqing University of Posts and Telecommunications (CQUPT).
