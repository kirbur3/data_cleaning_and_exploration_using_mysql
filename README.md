# data_cleaning_and_exploration_using_mysql

This project is listed on my resume as "Automated Data Cleaning and Exploratory Data Analysis in MySQL."

Three-part SQL project on a real-world tech layoffs dataset (2,361 records, 2020-2023).

Tools: MySQL

## Part 1 - Data Cleaning (Data_Cleaning_Project.sql)

Two-stage staging workflow (layoffs_staging → layoffs_staging2) preserving the raw table throughout. Transformations applied in order:
- Deduplication via CTE + ROW_NUMBER() with PARTITION BY across all 9 columns, added as row_num to a second staging table, then deleted where row_num > 1 (CTE DELETE not supported in MySQL, so a workaround is documented in the script)
- TRIM() to remove leading/trailing whitespace from company names
- LIKE-based UPDATE to standardize crypto industry variants ("Crypto", "Crypto Currency", "CryptoCurrency") to a single label
- TRIM(TRAILING '.' FROM country) to fix "United States." entries
- STR_TO_DATE() to convert date column from text to DATE type, followed by ALTER TABLE to change the column's data type
- Self-join to backfill null industry values from matching rows with the same company name
- DELETE for rows where both total_laid_off and percentage_laid_off were null (no analytical value); rows where only one is null are kept intentionally, as they still carry partial information

## Part 2 - Automation (Data_Cleaning_Project_Automated.sql)

Original stored procedure clean_layoffs_data() consolidating the full cleaning workflow into a single CALL statement:
- Re-runnable safely via DROP TABLE IF EXISTS at the start of each run
- Quality report output 1: raw row count, final row count, duplicates removed, and nulls backfilled by industry self-join
- Quality report output 2: column-level null audit across 6 columns (company, industry, total_laid_off, percentage_laid_off, date, country) using CASE WHEN to count nulls and blanks per field
- Comment in procedure documents that companies appearing only once with a null industry won't be backfilled, which is expected behavior, not a bug
- Two flagged results investigated and documented: Blackbaud's null date confirmed as missing in the raw layoffs table (not a conversion error); Bally's industry could not be backfilled because no matching populated row existed, which is an expected limitation of the self-join approach
- Investigation queries for both cases kept at the bottom of the file with notes so the validation can be rerun if needed

## Part 3 - Exploratory Data Analysis (Exploratory_Data_Analysis_Project.sql)

Queried the cleaned staging table to surface layoff trends:
- Total layoffs and percentage layoffs by company, country, industry, and funding stage
- Date range of the dataset (MIN/MAX)
- Companies where percentage_laid_off = 1 (entire workforce laid off), ordered by funds raised to contextualize scale
- Monthly layoff totals via SUBSTRING date parsing, with rolling cumulative sums built in a CTE using SUM() OVER(ORDER BY month)
- DENSE_RANK() window function (partitioned by year) to rank top 5 companies by total layoffs per year

Extra Files: **layoffs.csv**
