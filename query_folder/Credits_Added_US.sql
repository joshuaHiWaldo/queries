-- CREDIT ADDED
WITH Valid_Customers AS (
    SELECT wcc.ID, wcc.FIRSTNAME, wcc.LASTNAME, wcc.EMAIL
    FROM WALDO_CUSTOMERS.CUSTOMER wcc
    WHERE wcc.EMAIL LIKE '%@%'
      AND wcc.EMAIL NOT LIKE '%@hiwaldo%'
      AND wcc.EMAIL NOT LIKE '%no-mail%'
      AND LOWER(wcc.FIRSTNAME) NOT LIKE '%test%'
--       AND LOWER(wcc.FIRSTNAME) NOT LIKE '%-%'
--       AND LOWER(wcc.FIRSTNAME) NOT LIKE '%.%'
      AND LOWER(wcc.LASTNAME) NOT LIKE '%test%'
--       AND LOWER(wcc.LASTNAME) NOT LIKE '%-%'
--       AND LOWER(wcc.LASTNAME) NOT LIKE '%.%'
--       AND NOT REGEXP_LIKE(wcc.FIRSTNAME, '[0-9]')
--       AND NOT REGEXP_LIKE(wcc.LASTNAME, '[0-9]')
      AND wcc.REGION = 'US'
--       AND wcc.FIRSTNAME IS NOT NULL
)
SELECT TO_CHAR(wccl.CREATEDAT, 'YYYY') as year_date,
       ROUND(SUM(CASE WHEN wccl.VALUEADDED > 0 THEN wccl.VALUEADDED/100 END),2) as CREDIT_ADDED
FROM WALDO_CUSTOMERS.CUSTOMERCREDITLOG wccl
WHERE wccl.CUSTOMERID IN (SELECT DISTINCT vc.ID FROM Valid_Customers vc)
group by year_date
ORDER BY year_date;