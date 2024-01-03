/*
Covid 19 Data Exploration 
Data source: https://ourworldindata.org/covid-deaths up to April 2021
Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Casting data types
For insights, see: Findings from SQL data explorations.xlsx
*/

Select *
From SQL_Project.dbo.Deaths
Where continent is not null 
order by 3,4


-- Select Data that we are going to be starting with

Select Location, date, total_cases, new_cases, total_deaths, population
From SQL_Project.dbo.Deaths
Where continent is not null 
order by 1,2




-- Total Cases vs Total Deaths
-- Shows likelihood of dying in Southeast Asian Countries below

Select Location, date, total_cases,total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
From SQL_Project.dbo.Deaths
Where location in ('Philippines', 'Singapore', 'Malaysia', 'Thailand', 'Indonesia', 'Vietnam')
and continent is not null 
order by 1,2




-- Total Cases (Total Infected) vs Population
-- Shows percent of population infected with Covid (total_cases) in SEA

Select Location, date, Population, total_cases,  (total_cases/population)*100 as PercentPopulationInfected
From SQL_Project.dbo.Deaths
Where location in ('Philippines', 'Singapore', 'Malaysia', 'Thailand', 'Indonesia', 'Vietnam')
order by 1,2




-- Shows all countries ordered by Maximum Percent Infected vs Population
-- Can filter select SEA countries using the excel file instead of SQL
-- SEA Where clause is commented out

Select Location, Population, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From SQL_Project.dbo.Deaths
--Where location in ('Philippines', 'Singapore', 'Malaysia', 'Thailand', 'Indonesia', 'Vietnam')
Group by Location, Population
order by PercentPopulationInfected desc




-- Countries with Highest Death Count per Population
-- Fortunately, no need to use Cast for Total_deaths column as it was imported correctly as float by SQL Server 2017 
-- Would have used this to cast the Total_deaths as integer: MAX(CAST(Total_deaths as int)) as TotalDeathCount


Select Location, Population, MAX(Total_deaths) as TotalDeathCount, MAX(Total_deaths)/Population*100 as PercentDeaths
From SQL_Project.dbo.Deaths
--Where location in ('Philippines', 'Singapore', 'Malaysia', 'Thailand', 'Indonesia', 'Vietnam')
Where continent is not null 
Group by Location, Population
order by TotalDeathCount desc




-- BREAKING THINGS DOWN BY CONTINENT

-- Showing continents with the highest total death counts and total continent population

Select continent, MAX(Total_deaths) as TotalDeathCount, sum(distinct(population)) as ContinentPopulation
From SQL_Project.dbo.Deaths
--Where location in ('Philippines', 'Singapore', 'Malaysia', 'Thailand', 'Indonesia', 'Vietnam')
Where continent is not null 
Group by continent
order by TotalDeathCount desc



-- GLOBAL NUMBERS


-- Using SUM of new_deaths
Select SUM(new_cases) as total_cases, SUM(new_deaths) as total_new_deaths, SUM(new_deaths)/SUM(new_cases)*100 as DeathPercentage
From SQL_Project.dbo.Deaths
--Where location in ('Philippines', 'Singapore', 'Malaysia', 'Thailand', 'Indonesia', 'Vietnam')
where continent is not null 
--Group By date
order by 1,2



-- Total Population vs Vaccinations
-- Shows Percentage of Population that has received at least one Covid Vaccine

-- new_vaccinations column is per hundred, hence the float data type
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations) OVER (Partition by dea.location Order By dea.location, dea.date) as RollingPeopleVaccinated
From SQL_Project.dbo.Deaths dea
Join SQL_Project.dbo.Vaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
order by 2,3



-- Using CTE to Calculate Additional Daily Cases 


With CTE as (
    Select continent, location, date, total_cases,
        LAG(total_cases) OVER (PARTITION BY location ORDER BY date) AS previous_case_count
    From SQL_Project.dbo.Deaths dea  
)
Select location, date, total_cases,
    (total_cases - previous_case_count) as daily_growth
From CTE
Where previous_case_count IS NOT NULL
and continent is not null;




-- Select top 10 countries with the highest Additional Daily Cases
-- CTE1 as Daily growth, and CTE2 as Average daily growth table

--CTE1
WITH DailyGrowth as (
    Select continent, location, date, 
        total_cases - LAG(total_cases) OVER (PARTITION BY location Order By date) as daily_growth
    From SQL_Project.dbo.Deaths dea  
    Where continent IS NOT NULL
)
--CTE2
, AvgDailyGrowth as (
    Select continent, location, AVG(daily_growth) as avg_daily_growth
    From DailyGrowth
    Group By continent, location
)

Select TOP 10 
    location, 
    AVG(avg_daily_growth) as overall_avg_daily_growth
From AvgDailyGrowth
Group By location
Order By overall_avg_daily_growth DESC;




-- Using Temp Tables 


-- Dropping the Temp Tables if they exist
Drop Table if exists #TempDailyGrowth;
Drop Table if exists #TempAvgDailyGrowth;



-- Creating a Temp Table to store daily growth
Create Table #TempDailyGrowth (
    continent nvarchar(255),
    location nvarchar(255),
    date date,
    daily_growth int
);


Insert Into #TempDailyGrowth (continent, location, date, daily_growth)
Select continent, location, date, 
    total_cases - LAG(total_cases) OVER (PARTITION BY location Order By date) as daily_growth
From SQL_Project.dbo.Deaths dea  
Where continent IS NOT NULL;

-- Using Temp Table to calculate average daily growth
Create Table #TempAvgDailyGrowth (
    continent nvarchar(255),
    location nvarchar(255),
    avg_daily_growth flosat
);

Insert Into #TempAvgDailyGrowth (continent, location, avg_daily_growth)
Select continent, location, AVG(daily_growth) as avg_daily_growth
From #TempDailyGrowth
Group By continent, location;

-- Getting the top 10 locations based on overall average daily growth
Select TOP 10 
    location, AVG(avg_daily_growth) as overall_avg_daily_growth
From #TempAvgDailyGrowth
Group By location
Order By overall_avg_daily_growth DESC;



-- Creating Views to store data for later updates


-- Daily Infections View
Create View DailyInfections as
   Select  location, date,
       SUM(new_cases) as total_infections
   From  SQL_Project.dbo.Deaths
   Group By location, date;
GO

-- Daily Deaths View
Create View DailyDeaths as
   Select location, date,
       SUM(new_deaths) as total_deaths
   From  SQL_Project.dbo.Deaths
   Group By location, date;
GO

-- VaccinationProgress View
Create View VaccinationProgress as
   Select location, date,
       MAX(total_vaccinations) as total_vaccinations
   From SQL_Project.dbo.Vaccinations
   Group By location, date;

GO


