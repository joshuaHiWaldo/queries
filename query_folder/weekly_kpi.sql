-- snowflake query to calculate weekly KPIs

WITH Weeks AS (
  SELECT
    TO_CHAR(DATEADD(DAY, 7 * (ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1), '2024-05-05'), 'YYYY-MM-DD') AS Week_Start_Date,
    TO_CHAR(DATEADD(DAY, 6, DATEADD(DAY, 7 * (ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1), '2024-05-05')), 'YYYY-MM-DD') AS Week_End_Date
  FROM
    TABLE(GENERATOR(ROWCOUNT => 5)) -- generate 'x' weeks
),
Valid_Customers AS (
    SELECT wcc.ID, wcc.FIRSTNAME, wcc.LASTNAME, wcc.EMAIL
    FROM WALDO_CUSTOMERS.CUSTOMER wcc
    WHERE wcc.EMAIL LIKE '%@%'
      AND wcc.EMAIL NOT LIKE '%@hiwaldo%'
      AND wcc.EMAIL NOT LIKE '%no-mail%'
      AND LOWER(wcc.FIRSTNAME) NOT LIKE '%test%'
      AND LOWER(wcc.FIRSTNAME) NOT LIKE '%-%'
      AND LOWER(wcc.FIRSTNAME) NOT LIKE '%.%'
      AND LOWER(wcc.LASTNAME) NOT LIKE '%test%'
      AND LOWER(wcc.LASTNAME) NOT LIKE '%-%'
      AND LOWER(wcc.LASTNAME) NOT LIKE '%.%'
      AND NOT REGEXP_LIKE(wcc.FIRSTNAME, '[0-9]')
      AND NOT REGEXP_LIKE(wcc.LASTNAME, '[0-9]')
      AND wcc.REGION = 'US'
      AND wcc.FIRSTNAME IS NOT NULL
),
Valid_Customers_Regions AS (
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
--       AND wcc.REGION = 'US'
--       AND wcc.FIRSTNAME IS NOT NULL
),
Customer_Count AS (
    SELECT w.Week_Start_Date, w.Week_End_Date, COUNT(DISTINCT wcc.ID) as New_Customers
    FROM Weeks w
    JOIN WALDO_CUSTOMERS.CUSTOMER wcc ON CAST(wcc.CREATEDAT as DATE) BETWEEN w.Week_Start_Date AND w.Week_End_Date
    WHERE wcc.ACTIVE = true and wcc.ID IN (SELECT vc.ID FROM Valid_Customers vc)
    GROUP BY w.Week_Start_Date, w.Week_End_Date
),
Revenue AS (
    SELECT w.Week_Start_Date, w.Week_End_Date,
           ROUND(SUM(CASE
                    WHEN woo.REGION = 'US' THEN WOO.GRANDTOTALPRICE / 100
                    WHEN woo.REGION = 'SE' THEN (WOO.GRANDTOTALPRICE / 100) * 0.12
                    WHEN woo.REGION = 'UK' THEN (WOO.GRANDTOTALPRICE / 100) * 1.36
                    WHEN woo.REGION = 'EU' THEN (WOO.GRANDTOTALPRICE / 100) * 1.1
           END),2) AS NET_REVENUE,
           ROUND(SUM(CASE
                    WHEN woo.REGION = 'US' THEN WOO.SUBTOTALPRICE / 100
                    WHEN woo.REGION = 'SE' THEN (WOO.SUBTOTALPRICE / 100) * 0.12
                    WHEN woo.REGION = 'UK' THEN (WOO.SUBTOTALPRICE / 100) * 1.36
                    WHEN woo.REGION = 'EU' THEN (WOO.SUBTOTALPRICE / 100) * 1.1
           END),2) AS GROSS_REVENUE
    FROM Weeks w
    JOIN WALDO_ORDERS.CHARGE woc ON CAST(woc.CREATEDAT as DATE) BETWEEN w.Week_Start_Date AND w.Week_End_Date
    JOIN WALDO_ORDERS."ORDER" woo ON woc.ORDERID = woo.ID
    JOIN WALDO_ORDERS.ORDERCUSTOMER wooc on woo.ID = wooc.ORDERID --AND wooc.CUSTOMERID IN (SELECT vc.ID FROM Valid_Customers_Regions vc)
--     JOIN WALDO_ORDERS."ORDER" woo on TO_CHAR(woo.CREATEDAT, 'YYYY-MM-DD') BETWEEN w.Week_Start_Date AND w.Week_End_Date
--     JOIN WALDO_ORDERS.CHARGE woc on woo.ID = woc.ORDERID
    WHERE woo.STATUS IN ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING')
        AND woc.STATUS = 'SUCCESS'
    GROUP BY w.Week_Start_Date, w.Week_End_Date
),
Revenue_orders AS (
    SELECT w.Week_Start_Date, w.Week_End_Date,
           ROUND(SUM(CASE
                    WHEN woo.REGION = 'US' THEN WOO.GRANDTOTALPRICE / 100
                    WHEN woo.REGION = 'SE' THEN (WOO.GRANDTOTALPRICE / 100) * 0.12
                    WHEN woo.REGION = 'UK' THEN (WOO.GRANDTOTALPRICE / 100) * 1.36
                    WHEN woo.REGION = 'EU' THEN (WOO.GRANDTOTALPRICE / 100) * 1.1
           END),2) AS NET_REVENUE,
           ROUND(SUM(CASE
                    WHEN woo.REGION = 'US' THEN WOO.SUBTOTALPRICE / 100
                    WHEN woo.REGION = 'SE' THEN (WOO.SUBTOTALPRICE / 100) * 0.12
                    WHEN woo.REGION = 'UK' THEN (WOO.SUBTOTALPRICE / 100) * 1.36
                    WHEN woo.REGION = 'EU' THEN (WOO.SUBTOTALPRICE / 100) * 1.1
           END),2) AS GROSS_REVENUE
    FROM Weeks w
    JOIN WALDO_ORDERS."ORDER" woo ON CAST(woo.CREATEDAT as DATE) BETWEEN w.Week_Start_Date AND w.Week_End_Date
    JOIN WALDO_ORDERS.CHARGE woc ON woo.ID = woc.ORDERID
    JOIN WALDO_ORDERS.ORDERCUSTOMER wooc on woo.ID = wooc.ORDERID AND wooc.CUSTOMERID IN (SELECT vc.ID FROM Valid_Customers vc)
    WHERE woo.STATUS IN ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING')
        AND woc.STATUS = 'SUCCESS'
    GROUP BY w.Week_Start_Date, w.Week_End_Date
),
Cancellations as (
    SELECT w.Week_Start_Date, w.Week_End_Date,
           COUNT(DISTINCT CASE WHEN LOWER(USERTYPE) LIKE '%agent%' THEN wrc.ID ELSE 0 END) as AGENT_CANCELLATIONS,
           COUNT(DISTINCT CASE WHEN LOWER(USERTYPE) LIKE '%customer%' THEN wrc.ID ELSE 0 END) as CUSTOMER_CANCELLATIONS,
           COUNT(DISTINCT wrcs.CUSTOMERID) as CANCELLATION, COUNT(DISTINCT wrc.ID) as ALL_CANCEL
    FROM Weeks w
    JOIN WALDO_RENEWALS.CANCELLATION wrc ON CAST(wrc.CREATEDAT as DATE) BETWEEN w.Week_Start_Date AND w.Week_End_Date
    LEFT JOIN WALDO_RENEWALS.CUSTOMERSUBSCRIPTION wrcs ON wrc.CUSTOMERSUBSCRIPTIONID = wrcs.ID
    AND WRCS.STATUS = 'CANCELLED' AND wrcs.CUSTOMERID in (SELECT vc.ID FROM Valid_Customers vc)
    GROUP BY w.Week_Start_Date, w.Week_End_Date
),
only_otp as (
SELECT w.Week_Start_Date, w.Week_End_Date, COUNT(DISTINCT wcc.ID) as count_id
FROM WALDO_CUSTOMERS.CUSTOMER wcc
    JOIN WALDO_ORDERS.ORDERCUSTOMER wooc on wcc.ID = wooc.CUSTOMERID
    JOIN WALDO_ORDERS."ORDER" woo on wooc.ORDERID = woo.ID
    JOIN WALDO_ORDERS.CHARGE woc on woo.ID = woc.ORDERID
    JOIN weeks w on CAST(woc.CREATEDAT as DATE) BETWEEN DATEADD('YEAR', -2, w.Week_End_Date) and w.Week_End_Date
WHERE wcc.ID NOT IN (SELECT DISTINCT CUSTOMERID FROM WALDO_RENEWALS.CUSTOMERSUBSCRIPTION)
AND woc.STATUS = 'SUCCESS' AND LOWER(woo.TAGS) LIKE '%otp%' and wcc.ID IN (SELECT vc.ID FROM Valid_Customers vc)
GROUP BY w.Week_Start_Date, w.Week_End_Date
),
Subscription_Customers AS (
    SELECT w.Week_Start_Date, w.Week_End_Date, COUNT(DISTINCT wcc.ID) as subid
    FROM WALDO_CUSTOMERS.CUSTOMER wcc
    JOIN WALDO_RENEWALS.CUSTOMERSUBSCRIPTION wrcs on wcc.ID = wrcs.CUSTOMERID
    JOIN weeks w on CAST(wrcs.CREATEDAT as DATE) <= w.Week_End_Date
    WHERE wrcs.STATUS IN ('ACTIVE','PAUSED','IMMINENT','OVERDUE','FLAGGED','PENDING','UPCOMING')
    AND wcc.ID IN (SELECT vc.ID FROM Valid_Customers vc)
    GROUP BY w.Week_Start_Date, w.Week_End_Date
    ORDER BY w.Week_Start_Date DESC
)
SELECT r.Week_Start_Date, r.Week_End_Date,
       r.GROSS_REVENUE AS GROSS_REVENUE_BY_CHARGE,
--        ro.GROSS_REVENUE AS GROSS_REVENUE_BY_ORDERS,
       -- AGENT_CANCELLATIONS, CUSTOMER_CANCELLATIONS,
       c.CANCELLATION as TOTAL_CANCELLATIONS,
       cc.New_Customers,
       oo.count_id as otp,
       sc.subid as sub_customers,
       (oo.count_id + sc.subid) AS Total_Customers,
       ROUND(COALESCE(CANCELLATION /
           NULLIF((oo.count_id + sc.subid), 0), 0) * 100, 2) AS Churn_Percent
FROM Revenue r
    JOIN Cancellations c ON r.Week_Start_Date = c.Week_Start_Date AND r.Week_End_Date = c.Week_End_Date
    JOIN Customer_Count cc on r.Week_Start_Date = cc.Week_Start_Date AND r.Week_End_Date = cc.Week_End_Date
    JOIN Revenue_orders ro on r.Week_Start_Date = ro.Week_Start_Date AND r.Week_End_Date = ro.Week_End_Date
    JOIN only_otp oo on r.Week_Start_Date = oo.Week_Start_Date AND r.Week_End_Date = oo.Week_End_Date
    JOIN Subscription_Customers sc on r.Week_Start_Date = sc.Week_Start_Date AND r.Week_End_Date = sc.Week_End_Date
ORDER BY r.Week_Start_Date desc, r.Week_End_Date DESC;