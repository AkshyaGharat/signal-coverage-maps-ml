# Sample Dataset

This directory contains a minimal sample of the CIM-5G dataset sufficient to run a quick sanity check of the codebase **without downloading the full dataset**.

## Files

| File | Rows | Description |
| :--- | :---: | :--- |
| `raw_datas_sample.csv` | 200 | Random sample of raw RSRP mobile measurements (5G SS-RSRP, dBm) |
| `base_station_data.csv` | 10 | Full base station table (coordinates, transmit power, sector azimuths, tilts) — identical to full dataset |
| `fishnet_sample.csv` | 100 | First 100 rows of the 30 m × 30 m fishnet grid with environmental features |

## Full Dataset

The complete CIM-5G dataset (≈ 17 MB) is included in the repository under `data/raw/CIM-5G/`. No external download is required.

| File | Size | Description |
| :--- | :---: | :--- |
| `raw_datas.csv` | 14.2 MB | 81,419 raw mobile measurements |
| `fishnet_30x30_processed_feature_engineered.csv` | 2.5 MB | 10,000-cell fishnet grid |
| `base_station_data.csv` | 18 KB | Base station metadata |
| `Data_Dictionary.xlsx` | 12 KB | Column definitions and units |

## Data Source

Tingting Xu et al., *"A Real-time 5G Macro-cells Signal Dataset for Signal Model Simulation and Prediction within Complex Terrain Areas"*, Chongqing University of Posts and Telecommunications (CQUPT).
