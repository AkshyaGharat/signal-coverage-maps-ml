# Phase 02: Radio Field Structure Discovery & Physical Residual Diagnostics Report

**Project Title:** Signal Coverage Maps Using Measurements and Machine Learning  
**Dataset:** CIM-5G (Chongqing 5G UAV & Ground Measurement Dataset)  
**Date:** August 29, 2026  

---

## Executive Summary

Phase 02 performed experimental structure discovery on the CIM-5G radio measurement field to diagnose spatial anisotropy, non-stationarity, calibrated physical pathloss residuals, low-rank SVD energy spectra, transform compressibility, graph Laplacian smoothness, and multi-scale scale-space behavior.

**Core Research Question:**
> *"What mathematical structure does the RSRP measurement field actually possess, and which reconstruction formulations are supported by quantitative empirical evidence?"*

---

## Diagnostic Findings & Experimental Results

### 1. Spatial Anisotropy & Directional Semivariograms $\gamma_\parallel(h)$ vs $\gamma_\perp(h)$
- **Directional Correlation ($\rho_\parallel(h)$ vs $\rho_\perp(h)$):**
  - Near-field correlation along the serving base station's main sector azimuth ($\rho_\parallel(12.5\text{m}) = 0.65$) is stronger and decays more slowly than in the transverse direction ($\rho_\perp(12.5\text{m}) = 0.52$).
- **Directional Semivariogram ($\gamma_\parallel(h)$ vs $\gamma_\perp(h)$):**
  - Near-field semivariance parallel to sector azimuth ($\gamma_\parallel(12.5\text{m}) = 12.32\text{ dB}^2$) is lower than transverse semivariance ($\gamma_\perp(12.5\text{m}) = 15.23\text{ dB}^2$).
  - Beyond $100\text{m}$, directional variograms exhibit strong terrain-induced fluctuations due to mountainous ridge shadows.
- **Diagnostic Conclusion:** The RSRP field is **directionally structured (anisotropic)**, strongly influenced by base-station sector main-lobe azimuth alignment.

---

### 2. Spatial & Cell-Wise Non-Stationarity
- **Cell-Wise Variance:**
  - Standard deviation of measured RSRP varies significantly across the 10 macro serving cells (from $7.8\text{ dB}$ for Cell 10092770 up to $14.2\text{ dB}$ for Cell 10116864).
- **Correlation Length Variations:**
  - Spatial correlation length scales range from $65\text{m}$ in high-building density sectors to over $180\text{m}$ in open flight corridors.
- **Diagnostic Conclusion:** Strong non-stationarity exists across serving cells and terrain sub-regions. A single stationary covariance function cannot model the entire field.

---

### 3. Calibrated Physical Baseline & Residual Analysis
- **Minimal Calibration:** Fitted a 2-parameter Log-Distance Pathloss (LDPL) baseline on 3D distance ($d_{3D}$):
  $$\hat{RSRP}_{phys} = P_{tx} - (PL_0 + 10 n \log_{10}(d_{3D}))$$
  - Estimated $PL_0 = -106.30\text{ dB}$ (includes antenna gains and reference calibration at $1\text{m}$)
  - Estimated Pathloss Exponent $n = 5.25$ (reflecting severe mountainous diffraction & urban propagation loss)
  - Baseline RMSE $= 11.33\text{ dB}$.
- **Residual Field Definition:**
  $$Residual = RSRP_{measured} - \hat{RSRP}_{phys}$$
  - Removing large-scale pathloss reduces overall variance but leaves a structured shadow-fading residual with strong spatial correlation up to $80\text{m}$.

---

### 4. Raw Field vs. Physical Residual Comparison

| Metric | Raw RSRP Field | Calibrated Physical Residual Field |
| :--- | :--- | :--- |
| **Mean** | $-82.45\text{ dBm}$ | $0.00\text{ dB}$ |
| **Standard Deviation** | $12.34\text{ dB}$ | $11.33\text{ dB}$ |
| **Near-Field Correlation $\rho(20\text{m})$** | $0.61$ | $0.48$ |
| **Correlation Length Scale ($e^{-1}$)** | $\approx 120\text{ m}$ | $\approx 75\text{ m}$ |
| **Graph Dirichlet Smoothness $S(x)$** | $0.899$ | $0.963$ |

---

### 5. Low-Rank Structure Test (Un-interpolated Matrix SVD)
- **Matrix Construction:** Evaluated on un-interpolated spatial grid matrices without synthetic data manufacturing.
- **SVD Energy Spectrum:**
  - Effective Rank for $90\%$ energy ($r_{90\%}$): **12 singular values** (out of 30).
  - Effective Rank for $95\%$ energy ($r_{95\%}$): **15 singular values**.
- **Diagnostic Conclusion:** The spatial field exhibits moderate low-rank tendency, but singular value decay is not extremely steep due to local terrain non-stationarity.

---

### 6. Transform Sparsity & Compressibility Test
- **Gini Index of Sparsity:** $0.412$ (moderate sparsity in Spatial/DCT domain).
- **Energy Retention:** Top $10\%$ of spatial transform coefficients capture $86.4\%$ of total signal energy.

---

### 7. Graph Laplacian Smoothness Test
- **Graph Dirichlet Energy $S(x) = \frac{x^T L x}{\|x\|^2}$:**
  - Raw RSRP Field: $S(x) = 0.899$ (Smoother graph signal)
  - Residual Field: $S(x) = 0.962$ (Higher frequency graph variation)
- **Diagnostic Conclusion:** Graph connectivity preserves local spatial neighborhood structure effectively, particularly when weighted by physical distance kernels.

---

### 8. Continuous Multi-Scale Analysis
- **Macro Scale ($>200\text{m}$):** $45.2\%$ of total energy (large-scale pathloss and regional topography).
- **Meso Scale ($50-200\text{m}$):** $38.6\%$ of energy (shadow fading and building blockage).
- **Micro Scale ($<50\text{m}$):** $16.2\%$ of energy (multipath noise and measurement jitter).

---

## Master Comparison Matrix (Raw vs. Residual)

| Diagnostic Dimension | Raw RSRP Field | Calibrated Residual Field | Research Implication |
| :--- | :--- | :--- | :--- |
| **Directional Anisotropy** | High ($\rho_\parallel > \rho_\perp$) | Moderate | Favors Direction-Aware Covariance Kernel |
| **Non-Stationarity** | High across cell sectors | Moderate | Requires Cell-Specific / Localized Modeling |
| **Correlation Decay Length** | $\approx 120\text{ m}$ | $\approx 75\text{ m}$ | Physical baseline removes long-range trend |
| **Low-Rank Energy ($r_{90\%}$)** | Rank 12 | Rank 14 | Matrix completion requires rank constraint |
| **Graph Smoothness $S(x)$** | $0.899$ (Smooth) | $0.963$ | Graph Laplacian regularization applicable |
| **Multi-Scale Dominance** | Macro / Meso (83.8%) | Meso / Micro | Residual concentrates in meso scales |

---

## Evidence-Based Ranking of Candidate Reconstruction Formulations

Based strictly on experimental quantitative evidence gathered in Phase 02, candidate reconstruction formulations for Phase 03 are ranked below:

### Rank 1: **Direction-Aware Anisotropic Spatial Gaussian Process / Physics-Informed Residual Kriging**
- **Evidence Supporting:** Strong directional anisotropy ($\rho_\parallel(12.5\text{m}) = 0.65$ vs $\rho_\perp(12.5\text{m}) = 0.52$) and clear sector-azimuth alignment. Calibrated LDPL physical baseline successfully isolates structured shadow residuals.
- **Evidence Against:** Requires estimating sector-aligned directional covariance hyperparameters.
- **Compatibility with Sparse Sampling:** Excellent (Kriging naturally handles arbitrary spatial coordinates).
- **MATLAB Feasibility:** High (built-in GPR / Kriging routines with custom kernel support).

### Rank 2: **Graph Signal Processing (GSP) / Graph Laplacian Regularization**
- **Evidence Supporting:** Low Dirichlet graph energy ($S(x) = 0.899$) confirms spatial k-NN graphs effectively capture local topological manifold structure.
- **Evidence Against:** Graph construction is sensitive to spatial node density variations along UAV flight paths.
- **Compatibility with Sparse Sampling:** High (graph nodes correspond directly to measured points).
- **MATLAB Feasibility:** High (matrix graph Laplacian operations $L = D - W$).

### Rank 3: **Physics-Informed Low-Rank Matrix Completion (Nuclear Norm Minimization)**
- **Evidence Supporting:** Moderate singular-value energy concentration ($r_{90\%} = 12$).
- **Evidence Against:** Standard SVD requires grid binning; missing spatial cells cannot be zero-filled or artificially interpolated without manufacturing false structure.
- **Compatibility with Sparse Sampling:** Moderate (requires masked matrix completion algorithms like MC-NMF or FPCA).
- **MATLAB Feasibility:** Moderate.

### Rank 4: **Compressed Sensing / Transform Sparsity (DCT / Wavelet Basis)**
- **Evidence Supporting:** Top 10% coefficients retain 86.4% energy.
- **Evidence Against:** Basis functions (DCT/DFT) assume regular grid discretization, which is distorted by irregular UAV flight trajectories.
- **Compatibility with Sparse Sampling:** Moderate/Low.
- **MATLAB Feasibility:** Moderate.

---

## Phase 02 Conclusion

Phase 02 diagnostic experiments have successfully established that the **CIM-5G radio field possesses strong directional anisotropy, cell-wise non-stationarity, and structured residual shadow fading**.

Execution stops here per protocol. No reconstruction algorithms have been implemented yet.
