# Environment and Setup Audit Report

**Project Title:** Signal Coverage Maps Using Measurements and Machine Learning  
**Audit Date:** August 28, 2026  
**Operating System:** Windows (AMD64)  
**IDE:** VS Code / Antigravity IDE  

---

## 1. Repository & Project Structure Verification

The repository structure has been established with clean, minimal directories following the recommended layout for MATLAB ML research:

```
signal-coverage-maps/
├── data/
│   └── raw/
│       └── CIM-5G/
│           ├── raw_datas.csv
│           ├── base_station_data.csv
│           ├── Data_Dictionary.xlsx
│           ├── fishnet_30x30_processed_feature_engineered.csv
│           └── README.md
├── src/
│   ├── data/
│   ├── analysis/
│   └── baselines/
├── experiments/
│   └── 00_environment_test.m
├── results/
├── figures/
├── docs/
│   └── environment_setup.md
├── README.md
└── .gitignore
```

- **Raw Dataset Status:** Preserved in `data/raw/CIM-5G/`. Added to `.gitignore` to prevent unauthorized git tracking.
- **Minimal Directories:** Created placeholders (`src/data/`, `src/analysis/`, `src/baselines/`, `figures/`) without premature algorithm implementations or reconstruction folders.

---

## 2. MATLAB Installation Audit

- **MATLAB Executable Status:** **NOT DETECTED on system `PATH` or standard installation locations.**
  - Evaluated locations: `C:\Program Files\MATLAB`, `C:\Program Files (x86)\MATLAB`, `C:\MATLAB`, system environment variables (`PATH`), and Windows Registry uninstall keys.
- **MATLAB Version / Release:** Unresolved locally due to missing executable on `PATH`.

---

## 3. VS Code & MATLAB Extension Audit

- **Extension Installed:** **`mathworks.language-matlab` (v1.3.13)** is installed in VS Code extensions (`C:\Users\Armash Ansari\.vscode\extensions\mathworks.language-matlab-1.3.13`).
- **File Recognition:** `.m` script files are recognized by VS Code with MATLAB syntax highlighting.
- **Code Execution / MATLAB Launch Status:** **Pending Local MATLAB Executable Configuration.**
  - Because `matlab.exe` is not present in the system environment `PATH` or configured in VS Code settings (`MATLAB.installPath`), launching MATLAB scripts or using the MATLAB Command Window/terminal from VS Code is currently blocked.

---

## 4. Installed Toolboxes & Communications Functionality Audit

Due to the lack of an accessible local MATLAB executable during this setup audit, the following target toolboxes and propagation functions could not be live-queried via MATLAB runtime, but their verification script has been prepared in `experiments/00_environment_test.m`:

### Required Research Toolboxes:
1. **Communications Toolbox** (Required for `txsite`, `rxsite`, `propagationModel`, `sigstrength`, `pathloss`, `coverage`, `raytrace`, `los`)
2. **Statistics and Machine Learning Toolbox** (Required for ML baselines, GPR, Random Forest, evaluation)
3. **Mapping Toolbox** (Required for geospatial coordinates and spatial maps)
4. **Signal Processing Toolbox** (Required for signal filtering & RSSI feature extraction)
5. **Image Processing Toolbox** (Required for grid map reconstruction visualization)

---

## 5. Verification Script: `experiments/00_environment_test.m`

A standalone, reproducible test script (`experiments/00_environment_test.m`) was created. When run in MATLAB, it performs automated checks for:
- System version and release information
- Full list of installed products (`ver`)
- License availability for research toolboxes
- RF propagation function existence (`which txsite`, etc.)
- Offline figure generation and PNG saving to `figures/environment_plot_test.png`

---

## 6. Actionable Next Steps & Recommendations

1. **Install MATLAB Desktop (or configure installation path):**
   - Ensure MATLAB (R2023a or newer recommended) is installed on the machine.
   - Add MATLAB's `bin` folder (e.g., `C:\Program Files\MATLAB\R2023b\bin`) to Windows System Environment Variable `PATH`.
2. **Configure VS Code MATLAB Extension:**
   - In VS Code Settings (`settings.json`), set:
     ```json
     "MATLAB.installPath": "C:\\Program Files\\MATLAB\\R2023b"
     ```
3. **Execute Verification Script:**
   - Run `experiments/00_environment_test.m` inside MATLAB or VS Code MATLAB terminal to confirm toolboxes and propagation functions.
