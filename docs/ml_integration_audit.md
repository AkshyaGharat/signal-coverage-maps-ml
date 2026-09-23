# ML Integration Audit & Architectural Synthesis Report

**Project:** Signal Coverage Maps Using Measurements and Machine Learning (`signal-coverage-maps`)  
**Package Audited:** `SignalCoverageML` (Imported from MATLAB Drive archive, ~255 MB)  
**Date:** September 22, 2026  
**Status:** Audit Completed — Architecture Formulated for Four-Mode Prediction & Leakage-Free Hybrid Integration  

---

## Executive Summary

This report establishes the technical foundation for integrating the imported `SignalCoverageML` package into the existing physics-informed spatial reconstruction repository (`signal-coverage-maps`). 

The existing repository implements a mathematically validated, physics-guided spatial reconstruction pipeline:
$$\text{CIM-5G Measurements} \longrightarrow P_0 \text{ (Calibrated LDPL)} \longrightarrow \text{Residual Field} \longrightarrow P_1 \text{ (Isotropic Kriging)} \longrightarrow P_2 \text{ (Additive SASR)}$$
where $P_2$ relies on a repaired positive semi-definite additive covariance model:
$$\mathbf{K}(i,j) = \mathbf{K}_{\text{global}}(i,j) + \mathbf{1}(\text{cell}_i = \text{cell}_j = c) \, \mathbf{K}_{\text{cell}, c}(i,j) + \sigma_n^2 \delta_{ij}$$
which was verified in Phase 03-R to achieve $7.68\text{ dB}$ RMSE under 10% sampling ($\Delta_{\text{anisotropy}} = +0.24\text{ dB}$, paired $p = 4.38 \times 10^{-7}$).

The audit of `SignalCoverageML` reveals:
1. **Target Discrepancy:** The imported ML project predicts **raw RSRP directly** ($\text{SS\_RSRP}$) using Random Forest (`fitrensemble`/`TreeBagger`) and GPR (`fitrgp`). It does **not** predict a residual over physics or spatial reconstruction.
2. **Feature Dominance:** In the imported RF models, distance- and power-related features (`Power_to_Dist_ratio` and `True_3D_Dist`) account for over 50% of the predictor importance. The ML model is spending most of its learning capacity re-learning the logarithmic distance decay that our physical LDPL baseline already models analytically.
3. **Hybrid Gap:** The proposed hybrid model ($P_3 = P_2 + \text{RF}_{\text{residual}}$) does **not** yet exist in either project and must be built from the ground up with strict out-of-fold cross-validation to prevent optimistic residual leakage.
4. **Environment Portability:** Over 25 scripts in `SignalCoverageML` contain hardcoded paths to `/MATLAB Drive/SignalCoverageML`, crashing when executed locally.
5. **Dashboard Monolith:** The imported dashboard (`phase5b_working_prototype.m`, 1,267 lines) only visualizes a single static RF prediction CSV file. It must be refactored into a modular architecture capable of toggling dynamically between all five models ($P_0, P_1, P_2, \text{RF-only}, P_3$).

---

## A. Existing Repository Architecture

The existing repository is organized around rigorous radio propagation modeling, geostatistical variogram analysis, and anisotropic spatial reconstruction:

```
signal-coverage-maps/
├── data/
│   └── raw/
│       └── CIM-5G/
│           ├── raw_datas.csv                              (81,419 measurements)
│           ├── base_station_data.csv                      (10 serving base stations)
│           ├── fishnet_30x30_processed_feature_engineered.csv (10,000 grid points)
│           ├── Data_Dictionary.xlsx
│           └── README.md
├── src/
│   ├── data/
│   │   ├── load_raw_data.m                                (Loads raw measurements & base stations)
│   │   └── clean_and_inspect_missing.m                    (Data validation & cleansing)
│   ├── baselines/
│   │   ├── ldpl_baseline.m                                (Calibrated Log-Distance Path Loss)
│   │   └── isotropic_kriging.m                            (Standard isotropic geostatistical GP)
│   ├── reconstruction/
│   │   ├── anisotropic_covariance.m                       (Additive PSD covariance K = Kg + Kc)
│   │   ├── anisotropic_kriging.m                          (SASR solver engine)
│   │   ├── residual_reconstruction.m                      (P1/P2 pipeline: RSRP = LDPL + residual)
│   │   └── sector_coordinate_transform.m                  (Compass to sector-aligned metric axes)
│   ├── analysis/
│   │   ├── compute_directional_variogram.m                (Empirical semivariance along sector axes)
│   │   ├── compute_physical_baseline.m                    (LDPL parameter estimation)
│   │   ├── compute_anisotropy.m, compute_compressibility.m, ...
│   ├── evaluation/
│   │   ├── sparse_sampling.m                              (Random, Uniform, Clustered subsampling)
│   │   ├── cross_cell_split.m                             (Spatial cell holdout validation)
│   │   ├── evaluate_reconstruction.m                      (RMSE, MAE, R2 evaluation)
│   │   └── uncertainty_metrics.m                          (Prediction interval coverage)
├── experiments/
│   ├── 00_environment_test.m
│   ├── 01_dataset_exploration.m
│   ├── 02_structure_analysis.m
│   ├── 03_anisotropic_reconstruction.m
│   ├── audit_phase03.m
│   ├── validate_p1_vs_p2.m                                (30-run paired Monte Carlo validation)
│   └── verify_additive_covariance.m                       (Synthetic PSD verification matrix)
├── results/
│   ├── dataset/dataset_metrics.json
│   ├── structure/structure_summary.json
│   └── reconstruction/phase03_p1_vs_p2_validation.json
└── figures/
    ├── dataset/ (fig01–fig08)
    ├── structure/ (fig01–fig08)
    └── reconstruction_repair/ (fig01–fig06)
```

---

## B. Imported SignalCoverageML Architecture

The imported package was extracted from `MATLAB_DRIVE.zip` into `import/SignalCoverageML/`:

```
import/SignalCoverageML/
├── data/
│   ├── base_station/base_station_data.csv                 (Identical to main CIM-5G)
│   ├── grid/fishnet_30x30_processed_feature_engineered.csv (Identical to main CIM-5G)
│   ├── raw/raw_datas.csv                                  (Identical to main CIM-5G)
│   └── documentation/
├── src/
│   └── ml/
│       ├── baseline/
│       │   ├── evaluate_baselines.m                       (Empty 0 bytes)
│       │   ├── gpr.m                                      (fitrgp wrapper with ardsquaredexponential)
│       │   └── random_forest.m                            (TreeBagger wrapper, 200 trees, leaf 5)
│       ├── improved/
│       │   └── tune_random_forest.m                       (Parametric TreeBagger wrapper)
│       └── sparse/
│           ├── create_sparse_split.m                      (Spatial binning selection)
│           └── create_stratified_sparse_split.m           (Spatial binning + RSRP quartile stratification)
├── experiments/
│   ├── phase1_inspect_dataset.m, phase1a_feature_audit.m, phase1b_feature_redundancy.m
│   ├── phase1c_spatial_split.m, phase1d_weak_signal_analysis.m, phase1e_baseline_weak_metrics.m
│   ├── phase1f_baseline_comparison.m, phase1_rf_baseline.m, phase1_gpr_baseline.m
│   ├── phase2_sparse_experiment.m, phase2a_sparse_sampling_analysis.m
│   ├── phase2b_stratified_sparse_experiment.m, phase2c_sparse_vs_stratified.m
│   ├── phase3a_rf_tuning.m, phase3b_gpr_tuning.m, phase3c_final_model_comparison.m
│   ├── phase3d_optimized_rf.m, phase3e_optimized_gpr_fast.m
│   ├── phase3f_final_rf_selection.m, phase3g_final_rf_vs_gpr.m
│   ├── phase4a_final_model_evaluation.m, phase4b_full_grid_prediction.m
│   ├── phase4c_coverage_analysis.m, phase4d_final_rf_prediction.m
│   ├── phase4e_interactive_analysis.m, phase4f_weak_strong_zone_analysis.m
├── results/ml/ (31 .mat models, 49 .csv result tables)
├── figures/ml/ (82 .png plots)
├── phase5a_signal_coverage_dashboard.m                    (Monolithic dashboard prototype 1)
├── phase5b_interactive_prediction.m                       (Monolithic dashboard prototype 2)
└── phase5b_working_prototype.m                            (Final submission dashboard prototype, 1,267 lines)
```

---

## C. File-by-File Mapping and Inventory

| Imported ML File | Purpose / Role | Inputs | Outputs | Depends On | Duplicates Main Repo? | Disposition |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `src/ml/baseline/random_forest.m` | Fits `TreeBagger` (200 trees, leaf 5) | `XTrain, yTrain, XPredict` | `model, yPred` | Stats & ML Toolbox | No | Refactor into `src/ml/` |
| `src/ml/baseline/gpr.m` | Fits `fitrgp` (ARD SE kernel) | `XTrain, yTrain, XPredict` | `model, yPred, yStd` | Stats & ML Toolbox | Overlaps `isotropic_kriging.m` | Retain as reference |
| `src/ml/improved/tune_random_forest.m` | Parameterized `TreeBagger` | `XTrain, yTrain, XPredict, numTrees, leaf` | `model, yPred` | Stats & ML Toolbox | No | Refactor into `src/ml/` |
| `src/ml/sparse/create_sparse_split.m` | Spatial grid binning sampler | `data, budget, seed` | `sparseData` | None | Overlaps `sparse_sampling.m` | Harmonize with main |
| `src/ml/sparse/create_stratified_sparse_split.m` | Stratified grid binning sampler | `data, budget, seed` | `stratifiedData` | None | No | Add to `src/evaluation/` |
| `phase1a_feature_audit.m` | Identifies leakage & missing features | `fishnet_30x30...csv` | Console / report | None | No | Document in audit |
| `phase1b_feature_redundancy.m` | Correlation matrix (|r| > 0.90) | `fishnet_30x30...csv` | Correlation table | None | No | Reused feature subset |
| `phase1c_spatial_split.m` | 4-quadrant train/val/test split | `fishnet_30x30...csv` | `phase1_spatial_split.csv`| None | Distinct from MC splits | Preserve benchmark split |
| `phase1_rf_baseline.m` | Trains initial RF baseline | `phase1_spatial_split.csv` | Metrics, plots | `TreeBagger` | No | Baseline Mode C |
| `phase2_sparse_experiment.m` | RF on sparse budgets (5%–30%) | `phase1_spatial_split.csv` | `results/ml/*.csv` | `TreeBagger` | Overlaps budget evaluation | Standardize to 1%–10% |
| `phase3d_optimized_rf.m` | Evaluates leaf size / tree depth | Sparse / stratified CSVs | `phase3d_best_rf_model.mat`| `fitrensemble` | No | Reused hyperparameters |
| `phase3f_final_rf_selection.m` | Final RF selection (30% stratified) | Spatial split CSV | `phase3f_best_rf_model.mat`| `TreeBagger` | No | Reference for Mode C |
| `phase4b_full_grid_prediction.m` | Generates 10k grid predictions | Grid CSV + RF model | Prediction table | `predict` | No | Standardize grid engine |
| `phase4d_final_rf_prediction.m` | Generates final grid CSV | Grid CSV + RF model | `phase4d_...csv` | `predict` | No | Pre-computed Mode C |
| `phase4f_weak_strong_zone_analysis.m` | Classifies weak/strong zones | Prediction CSV | Classification metrics | None | No | Integrate in dashboard |
| `phase5b_working_prototype.m` | Interactive UI with geoaxes | `phase4d_...csv` | UI figure window | App Designer / UI | No | Refactor into modular app |

---

## D. Current ML Target

In all scripts and saved models across `SignalCoverageML`:
$$\text{Target Variable} = \mathbf{SS\_RSRP} \text{ (dBm)}$$

- The imported ML models **directly predict raw RSRP**.
- They do **not** predict a residual over LDPL ($y - \hat{y}_{\text{LDPL}}$) nor over the anisotropic spatial reconstruction ($y - \hat{y}_{P2}$).
- Under our architectural taxonomy, the imported model corresponds strictly to **MODE C (ML-Only / Direct RF RSRP)**.

---

## E. Current ML Features

Through the audits in `phase1a` and `phase1b`, `SignalCoverageML` eliminated collinear features ($|r| > 0.90$, such as `Match_Dist` vs `True_3D_Dist` with $r = 0.9999$, and band encodings with $r > 0.98$). 

The resulting 16 validated features used in `phase3d_optimized_rf.m` are:
1. `Center_X` (Longitude in degrees, ~106.67°E)
2. `Center_Y` (Latitude in degrees, ~29.50°N)
3. `NDVI_center` (Normalized Difference Vegetation Index)
4. `Building_Coverage` (Building ground footprint ratio)
5. `Weighted_Height` (Mean building height weighted by area)
6. `DEM_center` (Digital Elevation Model terrain elevation in meters)
7. `Base_Central_frequency_point` (5G NR carrier channel number)
8. `Base_Electronic_downtilt` (Antenna electrical downtilt in degrees)
9. `Base_Mechanical_downtilt` (Antenna mechanical downtilt in degrees)
10. `Base_Power` (Transmit power in dBm, nominally 24 dBm)
11. `True_3D_Dist` (3D Euclidean distance to serving cell in meters)
12. `Match_Angle_sin` (Sine of angle between receiver line-of-sight and base station orientation)
13. `Match_Angle_cos` (Cosine of angle to sector boresight)
14. `Base_Direction_angle_sin` (Sine of sector azimuth)
15. `Base_Direction_angle_cos` (Cosine of sector azimuth)
16. `Power_to_Dist_ratio` ($P_{\text{tx}} / d_{3D}$)

### Critical Observation on Feature Importance
From `results/ml/phase3d_feature_importance.csv`:
- `Power_to_Dist_ratio`: **0.0552** (Rank 1)
- `True_3D_Dist`: **0.0434** (Rank 2)
- `Center_Y`: **0.0287** (Rank 3)
- `DEM_center`: **0.0151** (Rank 4)
- `Center_X`: **0.0138** (Rank 5)
- Environmental clutter (`Building_Coverage`, `Weighted_Height`, antenna angles): **< 0.006**

**Physical Interpretation:** When trained directly on raw RSRP, the Random Forest spends its primary tree splits approximating the global logarithmic path loss $10n \log_{10}(d)$. Because decision trees approximate smooth logarithmic curves with piecewise constants, direct RF prediction produces step-like artifacts across distance gradients.

---

## F. Current Train / Test Methodology

`SignalCoverageML` utilized two distinct splitting strategies:

1. **Spatial Quadrant Split (`phase1c_spatial_split.m`):**
   - The 100 $\times$ 100 fishnet grid (10,000 cells) was split geometrically:
     - **Train:** Western half ($\text{Grid\_Col} \le 50$, 5,000 cells)
     - **Validation:** Southeastern quadrant ($\text{Grid\_Col} > 50, \text{Grid\_Row} > 50$, 2,500 cells)
     - **Test:** Northeastern quadrant ($\text{Grid\_Col} > 50, \text{Grid\_Row} \le 50$, 2,500 cells)
   - Performance of tuned RF on test quadrant: $\text{RMSE} \approx 5.94\text{ dB}$ to $6.00\text{ dB}$, $R^2 \approx 0.40$ to $0.41$.

2. **Sparse Grid Sampling (`phase2` & `phase3`):**
   - Subsampled the training half down to budgets: 5% (250 cells), 10% (500 cells), 20% (1,000 cells), 30% (1,500 cells).
   - Random grid selection vs RSRP-stratified grid selection.

---

## G. Data Leakage Risks and Prevention

A rigorous audit identified three critical leakage risks:

### 1. In-Sample Residual Fitting Leakage (HIGH RISK for Mode D)
- **The Risk:** If residual targets are computed as $\text{RF\_target}_i = y_i - \hat{y}_{P2}(x_i)$ where $\hat{y}_{P2}$ was fitted using observation $(x_i, y_i)$, Kriging exact interpolation (or near-exact interpolation with small nugget $\sigma_n^2$) forces $\hat{y}_{P2}(x_i) \approx y_i$.
- **Consequence:** The training residuals collapse artificially toward zero. The Random Forest learns nothing useful and collapses on unseen test points.
- **Prevention Strategy:** We MUST generate training residual targets using **Out-Of-Fold (OOF) cross-validation**:
  $$\text{RF\_target}_i = y_i - \hat{y}_{P2}^{(-k(i))}(x_i)$$
  where $\hat{y}_{P2}^{(-k(i))}$ is predicted using a model fitted strictly on training data excluding fold $k(i)$. Zero in-sample interpolation leakage is permitted.

### 2. Spatial Autocorrelation Leakage
- **The Risk:** If test locations are located within the spatial correlation range ($\ell_g \approx 200\text{m}$) of randomly selected training points, the test evaluation reflects local memorization rather than spatial generalization.
- **Prevention Strategy:** Retain both:
  - Strict block/quadrant holdouts and cross-cell holdouts (Cells 1–8 train $\rightarrow$ Cells 9–10 test).
  - Explicit Monte Carlo sparse sampling evaluations across Random, Uniform, and Clustered trajectory regimes, identically applied to all modes.

### 3. Hyperparameter Tuning Leakage
- **The Risk:** Estimating LDPL parameters ($PL_0, n$), variogram ranges ($a_\parallel, a_\perp$), or RF tree parameters on the entire dataset.
- **Prevention Strategy:** All physical parameters, covariance parameters, and tree hyperparameters must be estimated strictly on the active training subset of each Monte Carlo fold.

---

## H. Current Prediction Pipeline & Path Issues

The imported code cannot run cleanly in its current state:
1. **Hardcoded Root Path:** Over 25 scripts begin with `projectRoot = '/MATLAB Drive/SignalCoverageML'; cd(projectRoot);`.
2. **Missing Source References:** Several scripts fail if not run with specific working directories.
3. **Monolithic Prototype:** `phase5b_working_prototype.m` contains the UI layout, data filtering, statistics calculations, threshold logic, coordinate lookups, and graphics callbacks in a single file.

---

## I. What Can Be Reused

1. **TreeBagger / Ensemble Configurations:**
   - Hyperparameters validated in Phase 3D/3F: `NumLearningCycles = 300`, `MinLeafSize = 10`, `Method = 'regression'`.
2. **Engineered Feature Definitions:**
   - The 16 pruned features from `fishnet_30x30_processed_feature_engineered.csv` capturing terrain elevation, building density/height, antenna downtilts, and sector geometry.
3. **Dashboard UI Layout & Interactions:**
   - Dark theme palette (`bgColor = [0.035 0.055 0.085]`).
   - `GeographicAxes` integration with topographic/satellite basemaps.
   - Dynamic weak-signal threshold slider and threshold metrics.
   - Traceable click-to-grid coordinate query engine.
4. **Diagnostic Metrics:**
   - Weak-signal coverage statistics ($\text{RSRP} < -85\text{ dBm}$, $\ge -70\text{ dBm}$, $\ge -80\text{ dBm}$).

---

## J. What Must Be Refactored

1. **Decouple Data & Feature Engine:**
   - Create modular functions in `src/ml/`: `extract_ml_features.m`, `train_rf_model.m`, `train_hybrid_rf.m`, `predict_rf.m`.
2. **Eliminate Hardcoded Paths:**
   - Use dynamic relative paths anchored to the project root.
3. **Build the Out-Of-Fold Residual Target Generator:**
   - Function `compute_oof_p2_residuals.m` to generate valid, leakage-free residual targets for Mode D.
4. **Decouple Dashboard from Hardcoded CSVs:**
   - Make the dashboard consume a unified prediction struct/table containing columns for all 5 models ($P_0, P_1, P_2, P_{\text{RF}}, P_3$).
5. **Interactive Model Selector:**
   - Add a dropdown component to the dashboard allowing instantaneous switching between:
     - `Mode A: LDPL (Physics Baseline)`
     - `Mode B1: LDPL + Isotropic Kriging (P1)`
     - `Mode B2: LDPL + Additive SASR (P2)`
     - `Mode C: Random Forest (ML-Only)`
     - `Mode D: Physics + RF Residual Hybrid (P3)`

---

## K. Connection to P0, P1, and P2

| Model Code | Theoretical Basis | Mathematical Formulation | Role in Pipeline |
| :--- | :--- | :--- | :--- |
| **$P_0$** | Calibrated LDPL | $\hat{R}_{P0}(d) = P_{\text{tx}} - (PL_0 + 10n \log_{10}(d_{3D}))$ | Macro-scale physics baseline |
| **$P_1$** | LDPL + Isotropic Residual | $\hat{R}_{P1}(x) = \hat{R}_{P0}(x) + \sum w_i r_i$ using $K_{\text{global}}$ | Macro-physics + isotropic spatial correlation |
| **$P_2$** | LDPL + Additive SASR | $\hat{R}_{P2}(x) = \hat{R}_{P0}(x) + \sum w_i r_i$ using $K_{\text{global}} + K_{\text{cell}}$ | Macro-physics + sector-aligned anisotropic spatial field |
| **Mode C** | Direct Random Forest | $\hat{R}_{\text{RF}}(x) = f_{\text{RF}}(z(x))$ | Pure ML benchmark (predicts raw RSRP) |
| **$P_3$** | Hybrid Physics + ML | $\hat{R}_{P3}(x) = \hat{R}_{P2}(x) + f_{\text{RF\_res}}(z(x))$ | Complete hybrid: physics + spatial field + ML clutter residual |

---

## L. Proposed P3 Hybrid Architecture

The hybrid architecture decomposes signal propagation into three complementary scales:

$$\mathbf{RSRP}(x) = \underbrace{\mathbf{R}_{\text{LDPL}}(x)}_{\text{Large-scale distance decay}} + \underbrace{\mathbf{r}_{\text{spatial}}(x)}_{\text{Correlated spatial shadow field (P2)}} + \underbrace{\mathbf{r}_{\text{clutter}}(x)}_{\text{Nonlinear environmental / antenna interaction (ML)}} + \epsilon$$

### 1. Training Phase:
1. Divide training observations into $K$ spatial folds (e.g. $K = 5$).
2. For each fold $k$:
   - Calibrate LDPL baseline on $tr \setminus k$.
   - Reconstruct $P_2$ predictions on fold $k$: $\hat{R}_{P2}^{(-k)}(x_{tr, k})$.
   - Compute true held-out residual: $e_{k} = y_{tr, k} - \hat{R}_{P2}^{(-k)}(x_{tr, k})$.
3. Concatenate out-of-fold residuals: $\mathbf{e}_{\text{OOF}} = [e_1; e_2; \dots; e_K]$.
4. Train Random Forest ensemble $f_{\text{RF\_res}}$ using features $Z_{\text{tr}}$ and targets $\mathbf{e}_{\text{OOF}}$:
   $$f_{\text{RF\_res}} = \text{fitrensemble}(Z_{\text{tr}}, \mathbf{e}_{\text{OOF}}, \text{'Method'}, \text{'Bag'}, \dots)$$

### 2. Prediction Phase:
For any unmeasured location $x_*$ with features $z_*$:
1. Compute physical path loss $\hat{R}_{P0}(x_*)$.
2. Compute spatial residual field reconstruction $\hat{r}_{P2}(x_*)$.
3. Predict remaining clutter residual: $\hat{r}_{\text{ML}}(x_*) = f_{\text{RF\_res}}(z_*)$.
4. Synthesize final prediction:
   $$\hat{R}_{P3}(x_*) = \hat{R}_{P0}(x_*) + \hat{r}_{P2}(x_*) + \hat{r}_{\text{ML}}(x_*)$$

---

## M. Files to be Created or Modified

### New / Refactored Modules (`src/ml/` and `src/visualization/`):
- `src/ml/extract_ml_features.m`: Standardized feature matrix preparation from tables.
- `src/ml/train_rf_model.m`: Standardized direct RF trainer for Mode C.
- `src/ml/compute_oof_residuals.m`: K-fold out-of-fold $P_2$ residual calculator.
- `src/ml/train_rf_residual.m`: Residual RF trainer for Mode D.
- `src/ml/predict_hybrid.m`: Combined $P_3$ prediction engine.
- `src/visualization/coverage_dashboard.m`: Refactored interactive 5-mode UI.
- `src/visualization/generate_paper_figures.m`: Publication-quality comparison figures.

### New / Updated Experiments (`experiments/`):
- `experiments/04_ml_residual.m`: Trains Mode C and Mode D with out-of-fold residual verification.
- `experiments/05_model_comparison.m`: Unified 5-mode benchmark across budgets and protocols.
- `experiments/06_interactive_coverage_map.m`: Generates grid predictions for all 5 modes and launches dashboard.
- `experiments/run_all.m`: Single master execution pipeline with configuration flags.

### Documentation & Repository Root:
- `docs/ml_integration_audit.md` (this report).
- `docs/four_mode_architecture.md`: Detailed mathematical and algorithmic specification.
- `README.md`: Overhauled research story.

---

## N. Discrepancies and Inconsistencies Found

1. **Target Semantics:** The user request envisioned that `SignalCoverageML` might already predict residuals. The audit proves conclusively that `SignalCoverageML` predicts **raw RSRP directly**. Mode D (residual learning) must be newly implemented.
2. **Feature Set Variations:** `phase3d` used 16 features (including sine/cosine transforms of angles and power-to-distance ratio), whereas `phase3f` reverted to raw angles and included UAV speed. We will standardize on the physics-justified trigonometric set from `phase3d`.
3. **Hardcoded Directories:** All imported experiment files contained non-portable `/MATLAB Drive/...` paths that fail on local workstations.
4. **Sample Space Compatibility:** The main repository evaluated raw UAV flight measurements ($N = 81,077$), while `SignalCoverageML` evaluated the aggregated 30m $\times$ 30m fishnet grid ($N = 10,000$). The standardized benchmark must evaluate both the sparse measurement points and map the final predictions onto the 10,000-cell grid for coverage mapping.
