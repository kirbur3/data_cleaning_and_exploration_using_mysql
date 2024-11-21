-- Exploratory Data Analysis #find insights

SELECT *
FROM layoffs_staging2;


SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_staging2;

SELECT * #Note: 1 in percentage_laid_off means 100% of the company was laid off
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC; #to get largest funds_raised_millions amount at the top

SELECT company, SUM(total_laid_off) #looking at which companies laid the most people off
FROM layoffs_staging2
GROUP BY company
ORDER BY 2 DESC; #2 stands for 2nd collumn that was selected (SUM(total_laid_off) in this case)

SELECT MIN(`date`), MAX(`date`) #looking at date range of when these people got laid off
FROM layoffs_staging2;


SELECT country, SUM(total_laid_off) #looking at which countries laid the most people off
FROM layoffs_staging2
GROUP BY country
ORDER BY 2 DESC;

SELECT *
FROM layoffs_staging2;

SELECT YEAR(`date`), SUM(total_laid_off) #looking at how many people were laid off each year 
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY 1 DESC; #most recent year at top





#looking at progression of layoffs
SELECT SUBSTRING(`date`,1,7) AS `MONTH`, SUM(total_laid_off) #getting the sum of layoffs for each month
FROM layoffs_staging2
WHERE SUBSTRING(`date`,1,7) IS NOT NULL
GROUP BY `MONTH`
ORDER BY 1 ASC
; #earliest year-month at top

WITH Rolling_Total AS
(
SELECT SUBSTRING(`date`,1,7) AS `MONTH`, SUM(total_laid_off) AS total_off #total people laid off that month
FROM layoffs_staging2
WHERE SUBSTRING(`date`,1,7) IS NOT NULL
GROUP BY `MONTH`
ORDER BY 1 ASC
)
SELECT `MONTH`, total_off,
SUM(total_off) OVER(ORDER BY `MONTH`) AS rolling_total 
FROM Rolling_Total; #adding each month's total layoffs Ex: the rolling_total 36338 in 2020-04 is 26710 + rolling_total 9628



SELECT company, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company
ORDER BY 2 DESC;

#looking at how many people the companies were laying off per year
SELECT company, YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
ORDER BY 3 DESC; #having the company and year with the most layoffs at the top

WITH Company_Year (company, years, total_laid_off) AS #ranking which companies laid off the most people per year
(
SELECT company, YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
), Company_Year_Rank AS
(SELECT *, DENSE_RANK() OVER (PARTITION BY years ORDER BY total_laid_off DESC) AS Ranking #partition by doesn't roll everything up in one col and dense_rank produces no gaps in ranking values 
FROM Company_Year
WHERE years IS NOT NULL
)
SELECT *
FROM Company_Year_Rank
WHERE Ranking <= 5 #top five companies that laid the most people off
;


