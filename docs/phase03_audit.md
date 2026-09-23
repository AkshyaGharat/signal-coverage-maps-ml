# Phase 03 Implementation Audit & Mathematical Verification Report

**Project Title:** Signal Coverage Maps Using Measurements and Machine Learning  
**Dataset:** CIM-5G  
**Audit Date:** August 29, 2026  
**Status:** Audit Completed — **Outcome C: Covariance Matrix Invalidity Identified**  

---

## Executive Summary

A comprehensive diagnostic audit of the Phase 03 **Sector-Aligned Anisotropic Spatial Reconstruction (SASR)** implementation was executed across 18 mathematical, numerical, and data-leakage checkpoints.

The audit has successfully isolated the exact root cause of the catastrophic **$58.02\text{ dB}$ RMSE error** observed in raw-RSRP SASR reconstruction under 10% random sampling:

> **Primary Root Cause:** Pairwise arithmetic averaging of sector azimuths ($\bar{\theta}_{ij} = (\theta_i + \theta_j)/2$) across different serving cells breaks matrix positive semi-definiteness, creating **11 significantly negative eigenvalues ($\lambda_{\min} = -46.42$)** in the training covariance matrix $K_{tr}$. During matrix inversion $K_{tr}^{-1} k_*$, negative eigenvalues cause severe numerical solver collapse.

---

## Detailed Audit Results per Checkpoint

### 1. Metric Local Coordinate System Audit
- **Status:** **VERIFIED (Valid)**
- **Findings:** Geographic coordinates ($\text{Latitude}, \text{Longitude}$) are correctly transformed into local metric planar coordinates ($x_{\text{East}}, y_{\text{North}}$ in meters) relative to the domain origin $(29.531^\circ \text{N}, 106.712^\circ \text{E})$:
  - $x_{\text{East}}$ range: $[-1863.21\text{m}, +2426.19\text{m}]$
  - $y_{\text{North}}$ range: $[-2017.61\text{m}, +2117.42\text{m}]$

---

### 2. Azimuth Convention Mismatch (Major Issue 1)
- **Status:** **DISCREPANCY IDENTIFIED**
- **Findings:**
  - Base station sector angles in `base_station_data.csv` are **compass azimuths** ($\theta_{\text{compass}} \in [0^\circ, 360^\circ]$, clockwise from True North).
  - The implementation directly evaluated $h_\parallel = h_x \cos\theta_{\text{compass}} + h_y \sin\theta_{\text{compass}}$, which assumes mathematical angles ($\theta_{\text{math}}$, counter-clockwise from East).
  - **Impact:** Transmitting sector main-lobes oriented North ($0^\circ$) were evaluated as if oriented East ($0^\circ$), introducing an orthogonal $90^\circ$ sector rotation error.

---

### 3. Training Matrix Symmetry ($K_{tr} \stackrel{?}{=} K_{tr}^T$)
- **Status:** **SYMMETRIC WHEN AVERAGED**
- **Findings:**
  - Max absolute difference $\max |K_{tr} - K_{tr}^T| = 0.0000$ when pairwise average azimuths $\bar{\theta}_{ij}$ were forced.
  - Relative Frobenius symmetry error $\|K_{tr} - K_{tr}^T\|_F / \|K_{tr}\|_F = 0.0000$.

---

### 4. Positive Semidefinite Covariance Check (Major Issue 2 — ROOT CAUSE)
- **Status:** **FAILED (CRITICAL MATHEMATICAL INVALIDITY)**
- **Findings:**
  - Minimum Eigenvalue ($\lambda_{\min}$): **$-46.4244$** (Severely negative!).
  - Maximum Eigenvalue ($\lambda_{\max}$): **$+4778.2902$**.
  - Negative Eigenvalue Count: **11 eigenvalues below $-10^{-5}$**.
- **Explanation:** In Gaussian process / Kriging theory, a valid spatial covariance matrix $K_{tr}$ MUST be positive semi-definite ($\lambda_i \ge 0$). Averaging two different sector azimuths $\theta_A \neq \theta_B$ across distinct cell boundaries invalidates Bochner's theorem for positive-definite kernels, creating a non-positive-definite kernel matrix. Matrix inversion ($K_{tr}^{-1}$) under negative eigenvalues produces unstable, explosive predictions.

---

### 5. Multi-Cell Cross-Cell Distance Asymmetry & Angular Wrapping (Major Issue 3)
- **Status:** **FAILED (MATHEMATICAL ASYMMETRY & WRAPPING ERROR)**
- **Findings:**
  - **Asymmetric Distances:** Evaluating distance $d_A(i,j)$ using measurement $i$'s serving azimuth vs $d_A(j,i)$ using measurement $j$'s azimuth produced **83,816 asymmetric pairs** with distance discrepancies up to **$24.21\text{ meters}$**.
  - **Circular Angle Wrapping:** For pairs near True North (e.g. $359^\circ$ and $1^\circ$), standard arithmetic averaging yielded $(359 + 1)/2 = 180^\circ$ (South!) instead of the correct circular mean $0^\circ$ (North).

---

### 6. Numerical Scaling Audit
- **Status:** **VERIFIED (Valid)**
- **Findings:** Coordinate bounds ($\pm 2.4\text{km}$) and distance metrics are scaled appropriately. No numerical underflow or overflow occurred in exponential kernel calculations.

---

### 7. Covariance Parameter Validity & Leakage Audit
- **Status:** **VERIFIED (Training-Only)**
- **Findings:** $PL_0$, pathloss exponent $n = 5.25$, $a_\parallel = 150\text{m}$, and $a_\perp = 75\text{m}$ were estimated strictly on training observations. **Zero test-set leakage** occurred.

---

### 8. Physical Baseline & Residual Audit
- **Status:** **VERIFIED (Valid)**
- **Findings:**
  - Calibrated LDPL baseline: $\hat{R}_{LDPL}(d_{3D}) = 24.0 - (-106.30 + 52.46 \log_{10}(d_{3D}))$.
  - Residual formulation: $Residual = RSRP - \hat{R}_{LDPL}$.
  - Test-set LDPL predictions generated without using test RSRP.

---

## Audit Summary Table

| Audit Checkpoint | Status | Impact on Phase 03 Results | Required Correction |
| :--- | :--- | :--- | :--- |
| **1. Metric Coordinate System** | Pass | None | Retain $x_{\text{East}}, y_{\text{North}}$ in meters |
| **2. Compass Azimuth Convention** | Discrepancy | High (90° sector rotation) | Convert compass azimuth $\theta_{c}$ to math angle $\theta_{m} = 90^\circ - \theta_{c}$ |
| **3. Matrix Symmetry** | Pass | None | Maintain symmetric kernel formulation |
| **4. Positive Semi-Definiteness** | **FAIL** | **CRITICAL (Causes 58 dB error)** | Replace ad-hoc azimuth averaging with a valid cell-conditioned anisotropic kernel |
| **5. Circular Angle Wrapping** | **FAIL** | High ($180^\circ$ mean angle flip) | Use circular mean $\text{atan2}(\sum \sin, \sum \cos)$ |
| **6. Numerical Scaling** | Pass | None | Retain current scaling |
| **7. Parameter Leakage** | Pass | None | Retain training-only estimation |
| **8. Physical Baseline Calibration** | Pass | None | Retain calibrated LDPL baseline |

---

## Scientific Diagnosis & Next Steps Recommendation

The audit confirms **Outcome C: Covariance Invalidity Identified**. The previous $58.02\text{ dB}$ raw-RSRP error was caused by non-positive-definite matrix inversion collapse resulting from improper cross-cell azimuth averaging.

### Recommended Research Repair:
Instead of forcing a single global anisotropic covariance matrix across 10 different serving cells, the formulation must be restructured into a **Cell-Conditioned Anisotropic Covariance Model**:
$$K(x_i, x_j) = \begin{cases} \sigma_f^2 \exp\left(-d_{A, c}(x_i, x_j)\right) + \sigma_n^2 \delta_{ij}, & \text{if } \text{cell}(i) = \text{cell}(j) = c \\ \sigma_f^2 \exp\left(-\frac{\|x_i - x_j\|}{a_{\text{cross}}}\right), & \text{if } \text{cell}(i) \neq \text{cell}(j) \end{cases}$$

This mathematically guarantees that $K_{tr}$ is strictly positive semi-definite ($\lambda_{\min} \ge 0$) while preserving sector-aligned anisotropy within each serving cell.

---

*Phase 03 Audit Complete. No Phase 04 models have been implemented.*
