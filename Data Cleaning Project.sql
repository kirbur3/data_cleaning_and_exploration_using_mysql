-- Data Cleaning Project

SELECT * #original table
FROM layoffs;


-- 1. Remove Duplicates
-- 2. Standardized the Data
-- 3. Null Values or Blank Values
-- 4. Remove Any Columns or ROWS


 #copy all data from raw table into staging table
CREATE TABLE layoffs_staging
LIKE layoffs;


SELECT *
FROM layoffs_staging; #gives all of the columns

INSERT layoffs_staging #insert the data
SELECT *
FROM layoffs;


SELECT *, #making col called row_num
ROW_NUMBER() OVER(
PARTITION BY company, industry, total_laid_off, percentage_laid_off, `date`) AS row_num
FROM layoffs_staging;

WITH duplicate_cte AS #we can filter where the row number is greater than 2. If it has two or above that means there's duplicates.
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location,
industry, total_laid_off, percentage_laid_off, `date`, stage,
 country, funds_raised_millions) AS row_num
FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;


SELECT * #looking for duplicates
FROM layoffs_staging
WHERE company = 'Casper';


WITH duplicate_cte AS #can do something like this in Microsoft SQL Server but can't do this in MySQL because you cannot update a CTE (a delete statement is like an update statement)
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location,
industry, total_laid_off, percentage_laid_off, `date`, stage,
 country, funds_raised_millions) AS row_num
FROM layoffs_staging
)
DELETE
FROM duplicate_cte
WHERE row_num > 1; #identifying these row numbers in the CTE and deleting them from it and that would delete them from the actual table


#instead creating another table that has this extra row and then deleting it where that row is equal to two 
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
  `row_num` INT #added
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT *
FROM layoffs_staging2
WHERE row_num > 1; #row_num = 1 means no duplicates. anything more than 1 means there are duplicates

INSERT INTO layoffs_staging2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location,
industry, total_laid_off, percentage_laid_off, `date`, stage,
 country, funds_raised_millions) AS row_num
FROM layoffs_staging; #inserted a copy of all the columns and added the row_num col



DELETE
FROM layoffs_staging2
WHERE row_num > 1; #deleting duplicates

SELECT *
FROM layoffs_staging2;


-- Standardizing data  #finding issues with data and then fixing them

SELECT company, TRIM(company) #trimming the company col because there is an extra space in the beginning
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);


SELECT DISTINCT industry #looking at the different industries
FROM layoffs_staging2
;

UPDATE layoffs_staging2 #making all the crypto industries have the same name because they're the same thing
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';


SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging2
ORDER BY 1;

UPDATE layoffs_staging2 #some of the USA names have a '.' at the end and want them all to be standardized with no '.'
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

SELECT `date` 
FROM layoffs_staging2;


UPDATE layoffs_staging2 #time series so shouldn't be a text col but a date col
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y'); #this is the standard date format in MySQL


ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

#trying to populate as many null and blank values as possible
SELECT * #looking at rows with 2 null values
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
OR industry = '';

SELECT *
FROM layoffs_staging2
WHERE company LIKE 'Bally%';

SELECT t1.industry, t2.industry #looking for 1 industry row that's null and one that's not with the same company name
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;

UPDATE layoffs_staging2 t1 #populating those industry rows
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

SELECT *
FROM layoffs_staging2;



SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;


DELETE #deleting the rows with 2 null values because they aren't very useful
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT *
FROM layoffs_staging2;

ALTER TABLE layoffs_staging2 #don't need row_num col anymore
DROP COLUMN row_num;
