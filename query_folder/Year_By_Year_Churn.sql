WITH allmonth AS (
    SELECT DISTINCT TO_CHAR(wrcs.CREATEDAT, 'YYYY-MM') AS my
    FROM WALDO_RENEWALS.CUSTOMERSUBSCRIPTION AS wrcs
),
retention_counts AS (
    SELECT
        am1.my AS month_year,
        am2.my AS end_month_year,
        COUNT(DISTINCT
            CASE
                WHEN month_year = end_month_year
                         AND TO_CHAR(wrcs.CREATEDAT, 'YYYY-MM') = month_year
                    THEN wrcs.CUSTOMERID
                WHEN month_year != end_month_year
                         AND TO_CHAR(wrcs.CREATEDAT, 'YYYY-MM') = month_year
                         AND TO_CHAR(wrcs.NEXTRENEWAL, 'YYYY-MM') >= end_month_year
                    THEN wrcs.CUSTOMERID
            END) AS retention_count
    FROM
        allmonth am1
    CROSS JOIN
        allmonth am2
    JOIN
        WALDO_RENEWALS.CUSTOMERSUBSCRIPTION AS wrcs
    ON
        am1.my = TO_CHAR(wrcs.CREATEDAT, 'YYYY-MM')
        AND TO_CHAR(wrcs.NEXTRENEWAL, 'YYYY-MM') >= am2.my
        AND am1.my <= am2.my
    WHERE
        wrcs.STATUS NOT IN ('REJECTED', 'CORRUPTED')
        AND month_year >= '2018-07'
        AND end_month_year >= '2018-07'
        AND wrcs.NEXTRENEWAL IS NOT NULL
        AND wrcs.REGION in ('CST', 'MST', 'PST', 'EST')
--         AND wrcs.REGION = 'UK' -- 'EU' 'SE'
    GROUP BY
        month_year, end_month_year
)
SELECT
    rc.month_year as start_month_year,
    rc.end_month_year,
    rc.retention_count,
    COUNT(DISTINCT CASE WHEN wrcs.PLANID = 13 THEN wrcs.CUSTOMERID END) AS Monthly_Original,
    COUNT(DISTINCT CASE WHEN wrcs.PLANID = 14 THEN wrcs.CUSTOMERID END) AS Monthly_Vitamin,
    COUNT(DISTINCT CASE WHEN wrcs.PLANID = 15 THEN wrcs.CUSTOMERID END) AS Quarterly_Original,
    COUNT(DISTINCT CASE WHEN wrcs.PLANID = 16 THEN wrcs.CUSTOMERID END) AS Quarterly_Vitamin,
    COUNT(DISTINCT CASE WHEN wrcs.PLANID = 17 THEN wrcs.CUSTOMERID END) AS Biannual_Original,
    COUNT(DISTINCT CASE WHEN wrcs.PLANID = 18 THEN wrcs.CUSTOMERID END) AS Biannual_Vitamin,
    COUNT(DISTINCT CASE WHEN wrcs.PLANID NOT IN (13, 14, 15, 16, 17, 18) THEN wrcs.CUSTOMERID END) AS Unknown_Plan
FROM
    retention_counts rc
JOIN
    WALDO_RENEWALS.CUSTOMERSUBSCRIPTION AS wrcs
ON
    TO_CHAR(wrcs.CREATEDAT, 'YYYY-MM') = rc.month_year
    AND TO_CHAR(wrcs.NEXTRENEWAL, 'YYYY-MM') >= rc.end_month_year
WHERE rc.month_year <= rc.end_month_year
  AND wrcs.NEXTRENEWAL IS NOT NULL
  AND wrcs.STATUS NOT IN ('REJECTED', 'CORRUPTED')
  AND wrcs.REGION in ('CST', 'MST', 'PST', 'EST')
--   AND wrcs.REGION = 'UK' -- 'EU' 'SE'
GROUP BY
    rc.month_year, rc.end_month_year, rc.retention_count
order by
    rc.month_year, rc.end_month_year;