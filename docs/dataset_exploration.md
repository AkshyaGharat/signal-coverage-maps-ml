# Phase 01: Dataset Exploration and Spatial/Physical Characterization Report

**Project Title:** Signal Coverage Maps Using Measurements and Machine Learning  
**Dataset:** CIM-5G (Chongqing 5G UAV & Ground Measurement Dataset)  
**Date:** August 29, 2026  

---

## Executive Summary & Physical Field Insights

This report summarizes the spatial, temporal, and physical characterization of the **CIM-5G dataset** collected in a mountainous urban terrain (Chongqing, China).

The primary research question addressed in this phase is:
> **"What does our actual radio measurement field look like?"**

### Key Diagnostic Findings:
1. **Strong Local Spatial Correlation:** Near-field measurements ($h < 50\text{ m}$) exhibit high spatial autocorrelation ($\rho(10\text{m}) > 0.6$). Spatial correlation decays steadily beyond 100 m, confirming that the continuous 5G radio field possesses underlying spatial structure suitable for spatial reconstruction models.
2. **Terrain & Occlusion Nonstationarity:** The semivariance $\gamma(h)$ increases rapidly from $9.7\text{ dB}^2$ at 10 m to over $90\text{ dB}^2$ at 150 m. This sharp growth reflects heavy shadowing and multipath fading introduced by mountainous topography and building structures.
3. **Serving Cell Association:** Of the **81,419** raw measurement records, **81,077 (99.58%)** are strictly matched to base stations via global cell identities (`NCI == ECI`). Only **342 records (0.42%)** are unassigned due to missing/ambiguous identifiers.
4. **Observation vs. Interpolation Boundary:** In the grid-aggregated file (`fishnet_30x30_processed_feature_engineered.csv`), direct field observations (`is_observed = 1`) represent real measurements, whereas `is_interpolated = 1` grid cells are author-generated synthetic estimates. **Interpolated grid values will NOT be treated as ground truth in future research phases.**

---

## Detailed Audit Findings (20 Checklist Items)

### 1. Record Count
- **`raw_datas.csv`**: **81,419** measurement rows.
- **`base_station_data.csv`**: **10** base-station records.
- **`fishnet_30x30_processed_feature_engineered.csv`**: **10,000** grid cell records ($100 \times 100$ fishnet grid).

---

### 2. Column Inventory & Verified Meanings

| File | Column Name | Verified Meaning / Description | Data Type |
| :--- | :--- | :--- | :--- |
| `raw_datas.csv` | `ID` | Sequential record index | Integer |
| `raw_datas.csv` | `TIME(BeiJing)` | Beijing timestamp (YYYYMMDD HH:mm:ss.SSS) | Datetime |
| `raw_datas.csv` | `LATITUDE`, `LONGITUDE` | GNSS WGS84 geographic coordinates | Float64 |
| `raw_datas.csv` | `ACCURACY(M)` | Horizontal positioning uncertainty (meters) | Float64 |
| `raw_datas.csv` | `SPEED(M/s)` | Cellular-Pro logged application data-rate indicator (Mbit/s) | Float64 |
| `raw_datas.csv` | `IS_OUTDOOR` | Outdoor measurement flag ($1 = \text{outdoor}$) | Integer |
| `raw_datas.csv` | `NCI` | 5G New Radio Cell Identity (Global 36-bit identifier) | Int64 |
| `raw_datas.csv` | `GNODEB`, `GCELLID` | Base station ID & local sector cell ID | Integer |
| `raw_datas.csv` | `NR_PCI` | Physical Cell Identity ($0 - 1007$) | Integer |
| `raw_datas.csv` | `SS_RSRP` | Synchronization Signal RSRP ($\text{dBm}$) | Float64 |
| `raw_datas.csv` | `SS_RSRQ` | Synchronization Signal RSRQ ($\text{dB}$) | Float64 |
| `raw_datas.csv` | `SS_SINR` | Synchronization Signal SINR ($\text{dB}$) | Float64 |
| `base_station_data.csv` | `CGI`, `ECI` | EUTRAN / NR Global Cell Identity | Int64 |
| `base_station_data.csv` | `LATITUDE (processed)`, `LONGITUDE (processed)` | Physical base-station coordinates | Float64 |
| `base_station_data.csv` | `angle` | Antenna sector azimuth ($\text{degrees}$ from North) | Float64 |
| `base_station_data.csv` | `Electrical Tilt`, `Mechanical Tilt` | Antenna vertical downtilts ($\text{degrees}$) | Float64 |
| `base_station_data.csv` | `Antenna transmit power(dBm)` | Transmit power ($P_{tx} = 24\text{ dBm}$) | Float64 |
| `base_station_data.csv` | `Height` | Base station height above ground ($13\text{m} - 35\text{m}$) | Float64 |

---

### 3. Missing Value Analysis
- `SS_RSRP`, `LATITUDE`, `LONGITUDE`: **0 missing values (100% complete)**.
- `NCI`: 342 records missing (`0.42%`).
- `SS_RSRQ`, `SS_SINR`: Clean without missing flags.

---

### 4. Duplicate Records
- Exact row duplicates across all 21 columns in `raw_datas.csv`: **0 duplicates**.

---

### 5. Latitude & Longitude Ranges
- **Latitude Bounds:** $[29.505013^\circ \text{N}, 29.601311^\circ \text{N}]$
- **Longitude Bounds:** $[106.670173^\circ \text{E}, 106.758841^\circ \text{E}]$

---

### 6. Altitude Range
- **Flight & Ground Altitude (`ALT_M_`):** $[1.33\text{m}, 252.00\text{m}]$ above ground level (AGL).

---

### 7. Timestamp & Temporal Coverage
- **Data Collection Period:** May 23, 2025 – November 14, 2025.
- Captures UAV drive-test trajectories and ground measurement sessions over multiple months.

---

### 8. Unique Cell IDs
- **Unique NCIs:** 10 global 5G cells.
- **Unique GNODEBs:** 10 base station nodes.
- **Unique PCIs:** 10 physical cell identities.

---

### 9. Base-Station & Serving Cell Hierarchy
- Each `GNODEB` corresponds to a unique 5G macro site.
- Matching rule: `raw_datas.csv` (`NCI`) matches `base_station_data.csv` (`ECI`).

---

### 10. RSRP Summary Statistics

| Metric | Value |
| :--- | :--- |
| **Total Count** | $81,419$ |
| **Minimum** | $-120.00\text{ dBm}$ |
| **Maximum** | $-44.00\text{ dBm}$ |
| **Mean** | $-82.45\text{ dBm}$ |
| **Median** | $-81.00\text{ dBm}$ |
| **Standard Deviation** | $12.34\text{ dB}$ |
| **5th Percentile** | $-105.00\text{ dBm}$ |
| **25th Percentile** | $-90.00\text{ dBm}$ |
| **75th Percentile** | $-74.00\text{ dBm}$ |
| **95th Percentile** | $-63.00\text{ dBm}$ |

---

### 11–14. Visualizations Summary

- **Figure 1 (`figures/dataset/fig01_rsrp_distribution.png`):** Displays a unimodal, slightly left-skewed bell curve centered at $-81\text{ dBm}$.
- **Figure 2 (`figures/dataset/fig02_geographic_measurements.png`):** Shows high-density UAV grid flight paths and ground mobile trajectories.
- **Figure 3 (`figures/dataset/fig03_geographic_rsrp_map.png`):** Color-coded spatial distribution showing strong signal hot-spots near base stations and signal attenuation in valley regions.
- **Figure 4 (`figures/dataset/fig04_measurement_density.png`):** Highlights uneven spatial sampling density along specific flight corridors.

---

### 15. Physical Base Station Parameters (`base_station_data.csv`)
- **Transmit Power:** $24\text{ dBm}$ across all serving cells.
- **Antenna Heights:** $13\text{m}$ to $35\text{m}$.
- **Azimuth Angles:** Ranging from $40^\circ$ to $220^\circ$.
- **Mechanical Tilts:** $0^\circ$ to $8^\circ$.

---

### 16–17. Fishnet 30x30 Grid Audit (Observed vs. Interpolated)
- `is_observed = 1`: **1,842 grid cells** contain direct UAV/ground measurements.
- `is_interpolated = 1`: **8,158 grid cells** were synthetic estimates created by dataset authors.
- **Rule Enforced:** `is_interpolated = 1` cells will NOT be used as ground truth for model evaluation.

---

### 18–19. Distance Metrics & Pathloss Curve
- **Matching Efficiency:** **81,077 / 81,419 (99.58%)** matched via `NCI == ECI`.
- **Figure 5 (`figures/dataset/fig05_rsrp_vs_distance.png`):** RSRP vs. 2D distance shows clear distance-dependent attenuation overlaid with significant shadowing variance ($\pm 15\text{ dB}$).

---

### 20. Spatial Autocorrelation & Correlation Decay
- **Figure 8 (`figures/dataset/fig08_spatial_correlation_vs_distance.png`):**
  - $\rho(h=10\text{m}) \approx 0.62$
  - $\rho(h=50\text{m}) \approx 0.61$
  - $\rho(h=100\text{m}) \approx 0.49$
  - $\rho(h=200\text{m}) \approx 0.22$
  - Beyond $300\text{m}$, correlation decays toward $0.0$.

---

## Answers to Core Research Questions (A–F)

### A. What the dataset actually contains
81,419 high-precision 5G RSRP/RSRQ/SINR measurement points collected by UAVs and ground UEs over complex mountainous terrain in Chongqing, matched with 10 physical macro base stations.

### B. Which features are reliable and usable
- **Reliable Inputs:** `LATITUDE`, `LONGITUDE`, `SS_RSRP`, `NCI`, `TIME`, base station physical parameters (`LATITUDE`, `LONGITUDE`, `Height`, `Antenna transmit power`, `angle`).
- **Unreliable / Non-Physical:** `NR_PCI` alone (non-unique identifier); `is_interpolated = 1` grid cells (synthetic author artifacts).

### C. Important data-quality issues
- Non-uniform spatial sampling density (dense along flight paths, sparse elsewhere).
- 342 unassigned records lacking NCI match.

### D. What spatial representation appears appropriate
A 2D continuous spatial domain with elevation/dem overlay or a 3D spatial coordinate representation $(x, y, z)$.

### E. What information we can use for later physical modeling
- Base station 3D locations $(x_{bs}, y_{bs}, h_{bs})$, transmit power $P_{tx}$, antenna heights, and sector azimuth angles.
- UE 3D positions $(x, y, z)$ and measured RSRP values.

### F. Recommended next mathematical analyses
Investigate the **mathematical structure of the radio field**: evaluate spatial nonstationarity, directional anisotropy along sector azimuths, and spatial correlation length scale before deciding on reconstruction algorithms.
