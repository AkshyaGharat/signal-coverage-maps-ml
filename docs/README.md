# Documentation Index

Technical documentation for the **Physically Guided Sparse 5G RSRP Signal Coverage Reconstruction** framework.

---

## Core Documentation

| Document | Description |
| :--- | :--- |
| [Methodology & Prediction Modes](methodology.md) | Mathematical formulations for all four prediction modes, SASR kernel, and cross-validation framework |
| [Experimental Results](results.md) | Benchmark performance matrix, component ablation, and key research insights |
| [Dataset Exploration](dataset_exploration.md) | Spatial, temporal, and physical characterization of the CIM-5G dataset |
| [Structure Analysis](structure_analysis.md) | Empirical variograms, nonstationarity diagnostics, and low-rank spectral analysis |

## Reconstruction & ML Pipeline

| Document | Description |
| :--- | :--- |
| [Anisotropic Reconstruction (SASR)](anisotropic_reconstruction.md) | Sector-Aligned Anisotropic Spatial Reconstruction kernel derivation and ablation |
| [ML Integration Report](ml_integration_report.md) | Full ML pipeline architecture — file inventory, OOF engine, and hybrid predictor |
| [ML Integration Audit](ml_integration_audit.md) | Audit trail for ML integration correctness and leakage-free validation |

## Setup & Calibration

| Document | Description |
| :--- | :--- |
| [Environment Setup](environment_setup.md) | MATLAB toolbox requirements and environment validation |
| [LDPL Calibration Reconciliation](ldpl_calibration_reconciliation.md) | Log-Distance Path Loss calibration parameter derivation and reconciliation |

## Repair & Audit Logs

| Document | Description |
| :--- | :--- |
| [Phase 03 Audit](phase03_audit.md) | Reconstruction phase audit findings |
| [Phase 03 Repair](phase03_repair.md) | Reconstruction phase repair actions |
