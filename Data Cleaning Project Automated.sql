
DROP PROCEDURE IF EXISTS clean_layoffs_data;

DELIMITER //

CREATE PROCEDURE clean_layoffs_data()
BEGIN

	DECLARE raw_count INT;
    DECLARE duplicate_count INT;
    DECLARE null_industry_before INT;
    DECLARE null_industry_after INT;
    DECLARE backfilled_count INT;
    DECLARE final_count INT;
    
    #QUALITY CHECK: checking if there are the correct amount of rows in the original data
    SELECT COUNT(*) INTO raw_count FROM layoffs;
    
    DROP TABLE IF EXISTS layoffs_staging;
    DROP TABLE IF EXISTS layoffs_staging2;
    
    
    
    CREATE TABLE layoffs_staging
    LIKE layoffs;
    
    INSERT INTO layoffs_staging #insert the data
    SELECT *
    FROM layoffs;
    
    
    
    
    CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT    #added col to help find duplicates
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO layoffs_staging2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location,
industry, total_laid_off, percentage_laid_off, `date`, stage,
 country, funds_raised_millions) AS row_num
FROM layoffs_staging; #inserted a copy of all the columns and added the row_num col


-- Removing Duplicates

#QUALITY CHECK: checking how many duplicates were found
SELECT COUNT(*) INTO duplicate_count FROM layoffs_staging2 WHERE row_num > 1;

DELETE
FROM layoffs_staging2
WHERE row_num > 1; #deleting duplicates

-- Standardizing Data  #finding issues with data and then fixing them

UPDATE layoffs_staging2 #getting rid of extra whitespace
SET company = TRIM(company);

UPDATE layoffs_staging2 #making all the crypto industries have the same name because they're the same thing
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging2 #getting rid of extra '.' after United States (otherwise would have two labels: 'United States' or 'United States.')
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Date Conversion and Null Backfilling

#note: date will come back null if the original text was blank or in a weird format
#checked this with Blackbaud (1 case) and the raw layoffs table already had a null date for it, so this is just missing source data, not a bug in the conversion
UPDATE layoffs_staging2 #time series so shouldn't be a text col but a date col
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y'); #this is the standard date format in MySQL but still a text data type

ALTER TABLE layoffs_staging2 #changing the actual data type
MODIFY COLUMN `date` DATE;

    
#trying to populate as many null and blank values as possible with the data available
UPDATE layoffs_staging2 #setting all industry col blanks to nulls
SET industry = NULL
WHERE industry = '';

#QUALITY CHECK: checking how many insdustry nulls there are
SELECT COUNT(*) INTO null_industry_before FROM layoffs_staging2 WHERE industry IS NULL;

#companies that only show up once with a null industry won't get fixed, that's expected not a bug
UPDATE layoffs_staging2 t1 #populating industry rows with nulls (populating 1 industry row that's null with one that's not but that has the same company name)
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;    

#QUALITY CHECK: checking how many insdustry nulls are there now after join
SELECT COUNT(*) INTO null_industry_after FROM layoffs_staging2 WHERE industry IS NULL;

SET backfilled_count = null_industry_before - null_industry_after;

#both total_laid_off and percentage_laid_off are null so not sure if they laid anyone off at all so will delete the data (it's just not trustworthy)
DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

ALTER TABLE layoffs_staging2 #don't need row_num col anymore
DROP COLUMN row_num;

#QUALITY CHECK: checking how many rows there are in total now at the end
SELECT COUNT(*) INTO final_count FROM layoffs_staging2;

#reporting the QUALITY CHECK amounts
SELECT raw_count AS raw_row_amount, final_count AS final_row_amount, duplicate_count AS duplicates_found_amount, backfilled_count AS nulls_filled_amount;

#reporting how many nulls there are in each important column at the end for a final QUALITY CHECK
#total_laid_off and percentage_laid_off nulls are expected here, the earlier delete only removes rows where BOTH are null
#rows with just one of them filled in still have some value so they're kept on purpose
SELECT SUM(CASE WHEN company IS NULL OR company = '' THEN 1 ELSE 0 END) AS company_nulls,
SUM(CASE WHEN industry IS NULL OR industry = '' THEN 1 ELSE 0 END) AS industry_nulls,
SUM(CASE WHEN total_laid_off IS NULL THEN 1 ELSE 0 END) AS total_laid_off_nulls,
SUM(CASE WHEN percentage_laid_off IS NULL  OR percentage_laid_off = '' THEN 1 ELSE 0 END) AS percentage_laid_off_nulls,
SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END) AS date_nulls,
SUM(CASE WHEN country IS NULL OR country = '' THEN 1 ELSE 0 END) AS country_nulls
FROM layoffs_staging2;


END //

DELIMITER ;

CALL clean_layoffs_data();



#these aren't part of the actual cleaning process, just queries I used to dig into the date_nulls = 1 result from the quality check
#kept them here so I can rerun them later if I need to double check this again
#Investigation Notes:
SELECT * FROM layoffs_staging2 WHERE date IS NULL;
SELECT * FROM layoffs_staging WHERE company = 'Blackbaud';