--Select Data that we are going to be using

SELECT Location
    , date
    , total_cases
    , new_cases
    , total_deaths
    , population
FROM CovidDeaths
WHERE continent is not NULL
ORDER BY location, date

-- looking at Total Cases vs Total Deaths
--Shows the liklihood of dying if you contract Covid by country

SELECT Location
    , date 
    , total_cases
    , total_deaths
    , (CAST(total_deaths AS FLOAT)/CAST(total_cases AS FLOAT))*100.0 as death_rate
FROM CovidDeaths
WHERE location LIKE '%states%'
    AND continent is not NULL
ORDER BY location, date

--Looking at the Total Cases vs Population
-- Shows what percentage of population got Covid per country

SELECT location
    , date
    , total_cases
    , Population
    , (CAST(total_cases as FLOAT)/CAST(Population as FLOAT))*100 AS Cases_per_pop
FROM CovidDeaths
WHERE location LIKE '%states'
    AND continent is not null
ORDER BY location, date

-- What countries have the highest infection rates compared to population

SELECT location
    , population
    , MAX(total_cases) AS highest_case_cnt
    , (CAST(MAX(total_cases) AS FLOAT)/CAST(Population AS FLOAT))*100 AS infection_rate
FROM CovidDeaths
WHERE continent is not NULL
GROUP BY location, population
ORDER BY infection_rate DESC

-- Showing Countries with highest total death count
SELECT location
    , population
    , MAX(total_deaths) AS highest_death_cnt
    , (CAST(MAX(total_deaths) AS FLOAT)/CAST(Population AS FLOAT))*100 AS death_rate_per_pop
FROM CovidDeaths
WHERE continent is not NULL
GROUP BY location, population
ORDER BY highest_death_cnt DESC

-- Break things up by Continent

-- Showing continents with the highest total death count

-- Method 1: Find the death counts of continents via creating CTE and aggregating highest total death counts of all countries in the continent

WITH continent_deathcount AS (
    SELECT continent
        , location
        , population
        , MAX(total_deaths) AS highest_death_cnt
    FROM CovidDeaths
    WHERE continent is not NULL
    GROUP BY continent, location, population
)

SELECT continent
    , sum(highest_death_cnt) as total_deaths_per_continent
FROM continent_deathcount
GROUP BY continent
ORDER BY total_deaths_per_continent DESC

-- Method 2: Find the death counts of continents via filtering for the continents specifically in the original dataset

SELECT location
    , MAX(total_deaths) AS highest_death_cnt
FROM CovidDeaths
WHERE continent is NULL
GROUP BY location
ORDER BY highest_death_cnt DESC

-- Global numbers

-- Global new cases and new death counts with daily death rate
SELECT date 
    , SUM(new_cases) AS new_cases_globally
    , SUM(new_deaths) AS new_deaths_globally
    , (CAST(SUM(new_deaths) as float)/CAST(SUM(new_cases) as float))*100 AS daily_death_percentage
FROM CovidDeaths
WHERE continent is not NULL
GROUP BY date 
ORDER BY date

-- Global total cases, total deaths, and death rate
SELECT 
     SUM(new_cases) AS new_cases_globally
    , SUM(new_deaths) AS new_deaths_globally
    , (CAST(SUM(new_deaths) as float)/CAST(SUM(new_cases) as float))*100 AS daily_death_percentage
FROM CovidDeaths
WHERE continent is not NULL

-- look at Total population vs vaccinations

--Method 1: Use Windows functions to calculate both rolling vaccination totals as well as rolling vaccinations as percentage of the population

SELECT cd.continent 
    , cd.location 
    , cd.date
    , cd.population
    , cv.new_vaccinations
    , SUM(CAST(cv.new_vaccinations AS float)) OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date) AS rolling_vac_totals
    , SUM((CAST(cv.new_vaccinations AS float)/CAST(cd.population as float))*100) OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date) as rolling_vac_pct_by_pop
FROM CovidDeaths AS cd 
JOIN CovidVaccinations as cv 
    ON cd.location = cv.location 
    AND cd.date = cv.date 
WHERE cd.continent is not NULL
ORDER BY cd.location, cd.date

-- Method 2: Create a Temp table with rolling Vaccination Totals and query the temp table to determine rolling vaccinations as percentage of the population

DROP TABLE if exists #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated
(
    Continent nvarchar(50),
    Location nvarchar(50),
    Date datetime,
    Population numeric,
    New_vaccinations NUMERIC,
    rollin_vac_totals numeric
)

INSERT INTO #PercentPopulationVaccinated
SELECT cd.continent 
    , cd.location 
    , cd.date
    , cd.population
    , cv.new_vaccinations
    , SUM(CAST(cv.new_vaccinations AS float)) OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date) AS rolling_vac_totals
    --, SUM((CAST(cv.new_vaccinations AS float)/CAST(cd.population as float))*100) OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date) as rolling_vac_pct_by_pop
FROM CovidDeaths AS cd 
JOIN CovidVaccinations as cv 
    ON cd.location = cv.location 
    AND cd.date = cv.date 


SELECT *
    , (rollin_vac_totals/Population) * 100 AS rolling_pct_pop_vaccinated
FROM #PercentPopulationVaccinated
WHERE continent is not null
ORDER BY location, date

-- Method 3: Create View to store data for future visualizations

CREATE VIEW PercentPopulationVaccinated AS
SELECT cd.continent 
    , cd.location 
    , cd.date
    , cd.population
    , cv.new_vaccinations
    , SUM(CAST(cv.new_vaccinations AS float)) OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date) AS rolling_vac_totals
    , SUM((CAST(cv.new_vaccinations AS float)/CAST(cd.population as float))*100) OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date) as rolling_vac_pct_by_pop
FROM CovidDeaths AS cd 
JOIN CovidVaccinations as cv 
    ON cd.location = cv.location 
    AND cd.date = cv.date 
WHERE cd.continent is not NULL
