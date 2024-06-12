-- Revenue_past_year
SELECT
    TO_CHAR(DATE_TRUNC('year', CURRENT_DATE()), 'YYYY-MM-DD') AS START_DATE,
    TO_CHAR(DATEADD(DAY, -1, CURRENT_DATE()), 'YYYY-MM-DD') AS END_DATE,
    ROUND(COALESCE(SUM(WOO.GRANDTOTALPRICE/100), 0), 2) AS Total_Revenue_Last_Year
FROM
  WALDO_ORDERS."ORDER" WOO
WHERE
  TO_CHAR(WOO.CREATEDAT, 'YYYY-MM-DD') BETWEEN TO_CHAR(DATE_TRUNC('year', CURRENT_DATE()), 'YYYY-MM-DD') AND TO_CHAR(DATEADD(DAY, -1, CURRENT_DATE()), 'YYYY-MM-DD');
