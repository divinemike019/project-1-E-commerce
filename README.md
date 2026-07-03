# Project 01 Ecommerce

**Dataset:** Olist Brazilian E-Commerce  
**Source:** https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce  
**Author:** Charlie | TheBuild Data Analysis Programme | June 2026  
**Tools:** MySQL Workbench · Python 3 · Microsoft Excel

---

## Key Finding

AL state averages 9.73 days late. Black Friday Nov 2017 peaked at R$897K. Computers & Accessories leads complaints at 2.14/5 avg score.

---

## Files

| File | Purpose |
|------|---------|
| `sql/p1_ecommerce_analysis.sql` | MySQL schema + all analysis queries |
| `python/p1_ecommerce_analysis.py` | Data cleaning, feature engineering, charts |
| `excel/P1_Ecommerce_Dashboard.xlsx` | Interactive Excel dashboard with charts |

## Folder Structure

```
Project_01_Ecommerce/
├── sql/
│   └── p1_ecommerce_analysis.sql
├── python/
│   └── p1_ecommerce_analysis.py
├── excel/
│   └── P1_Ecommerce_Dashboard.xlsx
├── data/          ← place your CSV files here (not committed)
└── outputs/
    └── charts/    ← Python charts saved here
```

## How to Run

```bash
# 1. Download dataset from URL above and place CSVs in data/
# 2. In MySQL Workbench: open and run the SQL file
# 3. Install Python dependencies
pip install pandas numpy matplotlib seaborn scikit-learn openpyxl
# 4. Run the Python script
python python/p1_ecommerce_analysis.py
# 5. Open the Excel file for the interactive dashboard
```

---
*TheBuild Data Analysis Programme · June 2026*
