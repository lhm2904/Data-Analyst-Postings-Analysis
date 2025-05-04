--Creating original table for importing the dataset
CREATE TABLE postings  
(  
    posting_id TEXT,  
    index TEXT,  
    title TEXT,  
    company_name TEXT,  
    location TEXT,  
    via TEXT,  
    description TEXT,  
    extensions TEXT,  
    job_id TEXT,  
    thumbnail TEXT,  
    posted_at TEXT,  
    schedule_type TEXT,  
    work_from_home TEXT,  
    salary TEXT,  
    search_term TEXT,  
    date_time TEXT,  
    search_location TEXT,  
    commute_time TEXT,  
    salary_pay TEXT,  
    salary_rate TEXT,  
    salary_avg TEXT,  
    salary_min TEXT,  
    salary_max TEXT,  
    salary_hourly TEXT,  
    salary_yearly TEXT,  
    salary_standardized TEXT,  
    description_tokens TEXT  
);

--Importing the csv into created table
COPY postings
FROM 'C:\cybe\portfolio\data analyst\gsearch_jobs.csv'
DELIMITER ','
CSV HEADER;

--Creating a duplicate to start cleaning
CREATE TABLE postings_copy AS  
SELECT *  
FROM postings;

--Handling missing values
UPDATE postings_copy  
SET work_from_home = FALSE  
WHERE work_from_home IS NULL;

DELETE  
FROM postings_copy  
WHERE salary IS NULL;

UPDATE postings_copy 
SET location = 'Anywhere'  
WHERE location IS NULL;

--Formatting
UPDATE postings_copy  
SET description = REGEXP_REPLACE(description, '[\n\r]+', ' ', 'g');

--Change the single quotes to double quotes in the array column
UPDATE postings_cleaned  
SET skill_required = skill  
FROM (  
     SELECT posting_id,  
            REPLACE(skills::text, '''', '"')::text[] AS skill  
     FROM cleaned_copy) test  
WHERE postings_cleaned.posting_id = test.posting_id;

ALTER TABLE postings_copy
ADD COLUMN job_main TEXT;

UPDATE postings_copy  
SET job_main =  
        CASE  
            WHEN title ~* 'Data Architect|Architect|Architecture|Warehouse'  
                THEN 'Data Architect'  
            WHEN title ~* 'Data quality|Quality assurance|Quality'  
                THEN 'Data Quality Assurance Analyst'  
            WHEN title ~* 'Visualization Analyst|Data viz|Visualization Specialist'  
                THEN 'Data Visualization Analyst'  
            WHEN title ~* 'Analytics Manager'  
                THEN 'Data Analytics Manager'  
            WHEN title ~* 'Business Analyst|BA|Business Analysis'  
                THEN 'Business Analyst'  
            WHEN title ~* 'Data Science|Scientist|Science'  
                THEN 'Data Scientist'  
            WHEN title ~* 'Data Engineer|Engineer|Data Engineering'  
                THEN 'Data Engineer'  
            WHEN title ~* 'Machine Learning Engineer|Machine Learning|ML Engineer|ML' 
                THEN 'Machine Learning Engineer'  
            WHEN title ~* 'Power BI|PBI|Tableau|Looker|Intelligence|Business Intelligence|BI'  
                THEN 'Business Intelligence Analyst'  
            WHEN title ~* 'Systems Analyst|Systems Analytics'  
                THEN 'Business Systems Analyst'  
            WHEN title ~* 'Finance|Financial|Quantitative|Quant|Stock'  
                THEN 'Financial Data Analyst'  
            WHEN title ~* 'Consultant|Consult|Consulting|Analytics Consultant'  
                THEN 'Analytics Consultant'  
            WHEN title ~* 'Programmer|Coder'  
                THEN 'Software Engineer'  
            ELSE 'Data Analyst'  
        END;

ALTER TABLE postings_copy  
    ADD COLUMN job_level TEXT;

UPDATE postings_copy 
SET job_level =  
        CASE  
            WHEN title ~* 'Intern|Co-Op|Coop|Internship' THEN 'Intern'  
            WHEN title ~* 'Sr.|Sr|Senior' THEN 'Senior'  
            WHEN title ~* 'Entry Level|Entry-Level' THEN 'Entry-Level'  
            WHEN title ~* 'Junior' THEN 'Junior'  
            WHEN title ~* 'Associate' THEN 'Associate'  
            WHEN title ~* 'Lead' THEN 'Lead'  
            WHEN title ~* 'Principal' THEN 'Principal'  
            WHEN title ~* 'Manager' THEN 'Manager'  
            WHEN title ~* 'Director' THEN 'Director'  
            WHEN title ~* 'Vice President|VP' THEN 'Vice President'  
            WHEN title LIKE ' I ' THEN 'I'  
            WHEN title LIKE ' II ' THEN 'II'  
            WHEN title LIKE ' III ' THEN 'III'  
        END;

--Renaming
ALTER TABLE postings_copy  
    RENAME COLUMN via TO platform;

--Removing 'via' prefix
UPDATE postings_copy  
SET platform = remove_via.platform  
FROM (  
     SELECT posting_id, REGEXP_REPLACE(platform, 'via (.+)', '\1') AS platform  
     FROM postings_copy) remove_via  
WHERE postings_copy.posting_id = remove_via.posting_id;

--Changing data types
ALTER TABLE postings_copy  
    ALTER COLUMN work_from_home TYPE boolean  
        USING work_from_home::boolean
	ALTER COLUMN date_time TYPE timestamp  
	    USING date_time::timestamp
	ALTER COLUMN salary_standardized TYPE numeric  
	    USING salary_standardized::numeric
	ALTER COLUMN description_tokens TYPE text[]  
        USING REGEXP_REPLACE(description_tokens, '\[(.+)\]', '{\1}')::text[];

--Normalization
--company table
CREATE TABLE job AS  
    (  
    SELECT ROW_NUMBER() OVER () AS job_id,  
           job_title  
    FROM (  
         SELECT DISTINCT job_main AS job_title  
         FROM public.postings_cleaned) title  
    ORDER BY job_id);

--location table
CREATE TABLE location AS  
    (  
    SELECT ROW_NUMBER() OVER () AS location_id,  
           location  
    FROM (  
         SELECT DISTINCT location AS location  
         FROM public.postings_cleaned) title  
    ORDER BY location_id  
);

--Extract the state from location
WITH state_code  
    AS  
(SELECT location_id,  
       REGEXP_REPLACE(location, '^.+, *(..)$', '\1') AS code  
FROM (  
     SELECT *  
     FROM location  
     WHERE location ~* ', *..$') loc)  
  
UPDATE location  
SET state = state_name  
FROM(  
SELECT location_id,  
       code,  
       CASE  
           WHEN code = 'WV' THEN 'West Virginia'  
           WHEN code = 'AR' THEN 'Arkansas'  
           WHEN code = 'WY' THEN 'Wyoming'  
           WHEN code = 'VA' THEN 'Virginia'  
           WHEN code = 'NE' THEN 'Nebraska'  
           WHEN code = 'NM' THEN 'New Mexico'  
           WHEN code = 'MO' THEN 'Missouri'  
           WHEN code = 'CO' THEN 'Colorado'  
           WHEN code = 'NJ' THEN 'New Jersey'  
           WHEN code = 'UT' THEN 'Utah'  
           WHEN code = 'CA' THEN 'California'  
           WHEN code = 'TX' THEN 'Texas'  
           WHEN code = 'OK' THEN 'Oklahoma'  
           WHEN code = 'KS' THEN 'Kansas'  
       END AS state_name  
FROM state_code) naming  
WHERE location.location_id = naming.location_id;

--skill table
CREATE TABLE skill AS  
    (  
    SELECT ROW_NUMBER() OVER ()::int AS skill_id,  
           skill_name  
    FROM (  
         SELECT DISTINCT UNNEST(skill_required) AS skill_name  
         FROM job_postings) skill  
);

--posting_skill table to handle many-to-many relationships
CREATE TABLE posting_skill  
AS (  
   SELECT posting_id,  
          skill_id   FROM (  
        SELECT posting_id,  
               UNNEST(skill_required) AS skill_name  
        FROM job_postings  
        ORDER BY posting_id) name  
        JOIN skill  
       USING (skill_name)  
   ORDER BY posting_id);

--platform table
CREATE TABLE platform AS  
    (  
    SELECT ROW_NUMBER() OVER ()::int AS platform_id,  
           platform AS platform_name  
    FROM (  
         SELECT DISTINCT platform  
         FROM job_postings) via);

--Adding primary keys
ALTER TABLE job_postings  
    ADD PRIMARY KEY (posting_id);
ALTER TABLE job  
    ADD PRIMARY KEY (job_id);
ALTER TABLE location  
    ADD PRIMARY KEY (location_id);
ALTER TABLE skill  
    ADD PRIMARY KEY (skill_id);

--Foreign keys  
ALTER TABLE job_postings  
ADD CONSTRAINT fk_job 
FOREIGN KEY (job_id) REFERENCES job(job_id)  
ON DELETE CASCADE;

ALTER TABLE job_postings  
ADD CONSTRAINT fk_company  
FOREIGN KEY (company_id) REFERENCES company(company_id)  
ON DELETE CASCADE;

ALTER TABLE job_postings  
ADD CONSTRAINT fk_location  
FOREIGN KEY (location_id) REFERENCES location(location_id)  
ON DELETE CASCADE;

ALTER TABLE posting_skill  
ADD CONSTRAINT fk_skill_id  
FOREIGN KEY (skill_id) REFERENCES skill(skill_id)  
ON DELETE CASCADE;

ALTER TABLE posting_skill  
ADD CONSTRAINT fk_post_id  
FOREIGN KEY (posting_id) REFERENCES job_postings(posting_id)  
ON DELETE CASCADE;

--Matching ids from dim tables
--job table
UPDATE job_postings  
SET job_id = roleid.role_id  
FROM (  
     SELECT p.posting_id AS posting_id, j.job_id AS role_id  
     FROM job_postings p FULL OUTER JOIN job j  
         ON p.job_main = j.job_title  
     ORDER BY posting_id) roleid  
WHERE job_postings.posting_id = roleid.posting_id;

--company table
UPDATE job_postings  
SET company_id = comp.comp_id  
FROM (  
     SELECT p.posting_id AS posting_id, c.company_id AS comp_id  
     FROM job_postings p FULL OUTER JOIN company c  
         ON p.company_name = c.company_name  
     ORDER BY posting_id) comp  
WHERE job_postings.posting_id = comp.posting_id;

--location table
UPDATE job_postings  
SET location_id = loc.loc_id  
FROM (  
     SELECT p.posting_id AS posting_id, l.location_id AS loc_id  
     FROM job_postings p FULL OUTER JOIN location l  
         ON p.location = l.location  
     ORDER BY posting_id) loc  
WHERE job_postings.posting_id = loc.posting_id;

--Analysis
--Salary distribution
--Finding bin length
SELECT ROUND((MAX(salary_standardized) - MIN(salary_standardized)) / 7, 0)  
FROM job_postings JOIN job  
    USING (job_id)  
WHERE job_title = 'Data Analyst';

--Dividing the bins
WITH salary_range  
AS (  
    SELECT salary_standardized AS salary,  
           CASE  
               WHEN salary_standardized BETWEEN 15080 AND 102069 THEN '$15,080 - $102,069'  
               WHEN salary_standardized BETWEEN 102070 AND 189058 THEN '$102,070 - $189,058'  
               WHEN salary_standardized BETWEEN 189059 AND 276047 THEN '$189,059 - $276,047'  
               WHEN salary_standardized BETWEEN 276048 AND 363036 THEN '$276,048 - $363,036'  
               WHEN salary_standardized BETWEEN 363037 AND 450025 THEN '$363,037 - $450,025'  
               WHEN salary_standardized BETWEEN 450026 AND 537014 THEN '$450,026 - $537,014'  
               WHEN salary_standardized BETWEEN 537015 AND 624000 THEN '$537,015 - $624,000'  
           END AS range  
    FROM job_postings JOIN job  
        USING (job_id)  
    WHERE job_title = 'Data Analyst'  
)  
  
SELECT range,  
       COUNT(*)  
FROM salary_range  
GROUP BY range;

--Salary trend
SELECT DISTINCT EXTRACT(YEAR FROM date_time) AS year,  
                EXTRACT(MONTH FROM date_time) AS month,  
                ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_standardized )::numeric, 2) AS median_sal  
FROM job_postings JOIN job  
    USING (job_id)  
WHERE job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
GROUP BY year, month  
ORDER BY year, month;

--Most demanded skills
WITH da AS (  
           SELECT *  
           FROM job_postings JOIN job  
               USING (job_id)  
           WHERE job_title = 'Data Analyst'  
             AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
           ORDER BY posting_id)  
  
SELECT skill_name,  
       COUNT(*) AS count  
FROM da JOIN posting_skill  
    USING (posting_id) JOIN skill  
    USING (skill_id)  
GROUP BY skill_name  
ORDER BY count DESC  
LIMIT 10;

--Skills trending
WITH da AS (  
           SELECT *  
           FROM job_postings JOIN job  
               USING (job_id)  
           WHERE job_title = 'Data Analyst'  
             AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
           ORDER BY posting_id)  
  
SELECT EXTRACT(YEAR FROM date_time) AS year,  
       EXTRACT(MONTH FROM date_time) AS month,  
       COUNT(*) FILTER (WHERE skill_name = 'sql') AS sql,  
       COUNT(*) FILTER (WHERE skill_name = 'excel') AS excel,  
       COUNT(*) FILTER (WHERE skill_name = 'tableau') AS tableau,  
       COUNT(*) FILTER (WHERE skill_name = 'power_bi') AS power_bi,  
       COUNT(*) FILTER (WHERE skill_name = 'python') AS python  
FROM da JOIN posting_skill  
    USING (posting_id) JOIN skill  
    USING (skill_id)  
GROUP BY year, month  
ORDER BY year, month;

--Salary by skill
WITH da AS (  
           SELECT *  
           FROM job_postings JOIN job  
               USING (job_id)  
           WHERE job_title = 'Data Analyst'  
             AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
           ORDER BY posting_id)  
  
SELECT skill_name,  
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_standardized) AS median_sal  
FROM da JOIN posting_skill  
    USING (posting_id) JOIN skill  
    USING (skill_id)  
GROUP BY skill_name  
ORDER BY median_sal DESC  
LIMIT 10;


--Skill count vs. average salary
WITH skill_count AS  
         (  
         SELECT posting_id,  
                COUNT(skill_name) AS count,  
                salary_standardized AS salary  
         FROM job_postings JOIN job  
             USING (job_id) JOIN posting_skill  
             USING (posting_id) JOIN skill  
             USING (skill_id)  
         WHERE job_title = 'Data Analyst'  
           AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
         GROUP BY posting_id, salary_standardized  
         ORDER BY posting_id)  
  
SELECT count as skill_count,  
       ROUND(AVG(salary), 0) AS avg_salary  
FROM skill_count  
GROUP BY count  
ORDER BY count;

--Correlation
SELECT ROUND(CORR(salary, skill_count)::numeric, 3)  
FROM (  
     SELECT posting_id,  
            salary_standardized AS salary,  
            COUNT(skill_name) AS skill_count  
     FROM job_postings JOIN job  
         USING (job_id) JOIN posting_skill  
         USING (posting_id) JOIN skill  
         USING (skill_id)  
     WHERE EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
       AND job_title = 'Data Analyst'  
     GROUP BY posting_id, salary_standardized) salary_and_skill;

--Hiring trend
SELECT EXTRACT(YEAR FROM date_time) AS year,  
       EXTRACT(MONTH FROM date_time) AS month,  
       COUNT(*) AS posting_count,  
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_standardized)) AS median_sal  
FROM job_postings JOIN job  
    USING (job_id)  
WHERE EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
  AND job_title = 'Data Analyst'  
GROUP BY year, month  
ORDER BY year, month;

--Work-from-home trend
SELECT DISTINCT EXTRACT(YEAR FROM date_time) AS year,  
                EXTRACT(MONTH FROM date_time) AS month,  
                COUNT(*) FILTER (WHERE work_from_home = TRUE) AS wfh,  
                COUNT(*) FILTER (WHERE work_from_home = FALSE) AS non_wfh  
FROM job_postings JOIN job  
    USING (job_id)  
WHERE EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
  AND job_title = 'Data Analyst'  
GROUP BY year, month  
ORDER BY year, month;

--Highest paid DA titles
SELECT title,  
       ROUND(salary_standardized, 1) AS salary  
FROM job_postings JOIN job  
    USING (job_id)  
WHERE job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
ORDER BY salary DESC  
LIMIT 10;

--Job level distribution
SELECT job_level,  
       COUNT(*) AS count  
FROM job_postings JOIN job  
    USING (job_id)  
WHERE EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
  AND job_title = 'Data Analyst'  
  AND job_level IS NOT NULL  
GROUP BY job_level  
ORDER BY count DESC;

--Salary by job level
SELECT job_level,  
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_standardized)) AS median_sal  
FROM job_postings JOIN job  
    USING (job_id)  
WHERE job_level IS NOT NULL  
  AND job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
GROUP BY job_level  
ORDER BY median_sal DESC;

--Most demanded skills entry-level jobs
WITH da AS (  
           SELECT *  
           FROM job_postings JOIN job  
               USING (job_id)  
           WHERE job_title = 'Data Analyst'  
             AND job_level IN ('Intern', 'Entry-Level', 'Associate', 'Junior')  
             AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
           ORDER BY posting_id)  
  
SELECT skill_name,  
       COUNT(*) AS count  
FROM da JOIN posting_skill  
    USING (posting_id) JOIN skill  
    USING (skill_id)  
GROUP BY skill_name  
ORDER BY count DESC  
LIMIT 10;

--Remote vs. on-site pay
--Salary for remote jobs
SELECT ROUND(salary_standardized, 2)  
FROM job_postings JOIN location  
    USING (location_id) JOIN job  
    USING (job_id)  
WHERE EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
  AND job_title = 'Data Analyst'  
  AND location = 'Anywhere';

--Salary for on-site jobs
SELECT ROUND(salary_standardized, 2)  
FROM job_postings JOIN location  
    USING (location_id) JOIN job  
    USING (job_id)  
WHERE EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
  AND job_title = 'Data Analyst'  
  AND location != 'Anywhere';

--Top hiring companies
SELECT company_name,  
       COUNT(*) AS count  
FROM job_postings JOIN company  
    USING (company_id) JOIN job  
    USING (job_id)  
WHERE job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
GROUP BY company_name  
ORDER BY count DESC  
LIMIT 10;

--Median salary by company
--Median salary distribution
SELECT company_name,  
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_standardized) AS median_sal  
FROM job_postings JOIN company  
    USING (company_id) JOIN job  
    USING (job_id)  
WHERE job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
GROUP BY company_name  
ORDER BY median_sal DESC;

--Preferred platforms of companies
WITH top_platform  
         AS  
         (  
         SELECT company_name,  
                platform_name,                
                COUNT(*) AS count,  
                ROW_NUMBER() OVER (PARTITION BY company_name ORDER BY COUNT(*) DESC) AS rank  
         FROM job_postings JOIN company  
             USING (company_id) JOIN platform  
             USING (platform_id) JOIN job  
             USING (job_id)  
         WHERE job_title = 'Data Analyst'  
           AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
           AND company_name IN ('Upwork', 'Cox Enterprises', 'Talentify.io', 'Insight Global, Inc.', 'Walmart')  
         GROUP BY company_name, platform_name  
         ORDER BY company_name, count DESC)  
  
SELECT company_name,  
       platform_name,       
       count  
FROM top_platform  
WHERE rank < 3;

--Most remote-friendly companies
SELECT company_name,  
       COUNT(*) FILTER (WHERE location = 'Anywhere') AS remote_job,  
       COUNT(*) FILTER (WHERE location != 'Anywhere') AS onsite_job  
FROM job_postings JOIN job  
    USING (job_id) JOIN company  
    USING (company_id) JOIN location  
    USING (location_id)  
WHERE EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
  AND job_title = 'Data Analyst'  
GROUP BY company_name  
ORDER BY remote_job DESC  
LIMIT 10;

--Most popular platforms
SELECT platform_name,  
       COUNT(*) AS count  
FROM job_postings JOIN platform  
    USING (platform_id) JOIN job  
    USING (job_id)  
WHERE job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
GROUP BY platform_name  
ORDER BY count DESC  
LIMIT 10;

--Salary distribution by platform
SELECT platform_name,  
       salary_standardized
FROM job_postings JOIN platform  
    USING (platform_id) JOIN job  
    USING (job_id)  
WHERE job_title = 'Data Analyst'  
  AND platform_name IN  
      ('Upwork', 'LinkedIn', 'ZipRecruiter', 'Indeed', 'Snagajob', 'BeBee', 'Built In', 'aijobs.net', 'The Elite Job',  
       'Ladders')  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
ORDER BY platform_name, salary_standardized DESC;

--Platform hiring trend
SELECT DISTINCT EXTRACT(YEAR FROM date_time) AS year,  
                EXTRACT(MONTH FROM date_time) AS month,  
                COUNT(*) FILTER (WHERE platform_name = 'Upwork') AS upwork,  
                COUNT(*) FILTER (WHERE platform_name = 'LinkedIn') AS linkedin,  
                COUNT(*) FILTER (WHERE platform_name = 'ZipRecruiter') AS ZipRecruiter,  
                COUNT(*) FILTER (WHERE platform_name = 'Indeed') AS Indeed  
FROM job_postings JOIN job  
    USING (job_id) JOIN platform  
    USING (platform_id)
WHERE job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
GROUP BY year, month  
ORDER BY year, month;

--Best platform for remote jobs
SELECT platform_name,  
       COUNT(*) FILTER (WHERE location = 'Anywhere') AS remote,  
       COUNT(*) FILTER (WHERE location != 'Anywhere') AS onsite  
FROM job_postings JOIN job  
    USING (job_id) JOIN platform  
    USING (platform_id) JOIN location  
    USING (location_id)  
WHERE job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
GROUP BY platform_name  
ORDER BY remote DESC, onsite DESC  
LIMIT 10;

--Most popular job locations
SELECT state,  
       COUNT(*) AS count  
FROM job_postings JOIN location  
    USING (location_id) JOIN job  
    USING (job_id)  
WHERE job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
  AND state IS NOT NULL  
GROUP BY state  
ORDER BY count DESC;

--Median salary by state
SELECT state,  
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary_standardized) AS median_sal 
FROM job_postings JOIN location  
    USING (location_id) JOIN job  
    USING (job_id)  
WHERE job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
  AND state IS NOT NULL  
GROUP BY state  
ORDER BY median_sal DESC;

--Job level by state
SELECT state,  
       job_level,       
       COUNT(*) AS count  
FROM job_postings JOIN location  
    USING (location_id) JOIN job  
    USING (job_id)  
WHERE job_title = 'Data Analyst'  
  AND EXTRACT(YEAR FROM date_time) IN (2023, 2024)  
  AND state IS NOT NULL  
  AND job_level IS NOT NULL  
GROUP BY state, job_level  
ORDER BY state, count DESC;