WITH Weeks AS (
  SELECT
    TO_CHAR(DATEADD(DAY, 7 * (ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1), '2023-06-04'), 'YYYY-MM-DD') AS Week_Start_Date,
    TO_CHAR(DATEADD(DAY, 6, DATEADD(DAY, 7 * (ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1), '2023-06-04')), 'YYYY-MM-DD') AS Week_End_Date
  FROM
    TABLE(GENERATOR(ROWCOUNT => 54)) -- generate 'x' weeks
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
Product_Filter AS (
    SELECT DISTINCT ID FROM WALDO_CATALOG.CATALOGPLAN cp
    WHERE cp.ID = 13
    -- 13-18
),
Subscription_Orders AS (
    SELECT w.Week_Start_Date, w.Week_End_Date, cpvl.SKU, opv.NAME, woo.PLANID, COUNT(DISTINCT woo.ID) as order_count
    FROM Weeks w
    JOIN WALDO_ORDERS."ORDER" woo ON TO_CHAR(woo.CREATEDAT, 'YYYY-MM-DD') BETWEEN w.Week_Start_Date AND w.Week_End_Date
    JOIN WALDO_ORDERS.CHARGE woc on woo.ID = woc.ORDERID
    JOIN WALDO_ORDERS.ORDERCUSTOMER wooc on woc.ORDERID = wooc.ORDERID
    JOIN WALDO_ORDERS.ORDERPRODUCTVARIANT opv on wooc.ORDERID = opv.ORDERID
    JOIN WALDO_CATALOG.CATALOGPRODUCTVARIANTLOCALE cpvl on opv.PRODUCTVARIANTID = cpvl.PRODUCTVARIANTID
    WHERE wooc.CUSTOMERID IN (SELECT DISTINCT vc.ID from Valid_Customers vc)
    AND woc.STATUS = 'SUCCESS' AND woo.STATUS IN ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING')
--     AND woo.PLANID = (SELECT pf.ID FROM Product_Filter pf)
    -- Filter for only vitamin/hydra Boost
--     AND (lower(opv.NAME) LIKE '%vitamin%' OR lower(opv.NAME) LIKE '%hydra boost%')
--     AND lower(opv.NAME) NOT LIKE '%trial%'
    GROUP BY w.Week_Start_Date, w.Week_End_Date, cpvl.SKU, opv.NAME, woo.PLANID--, woo.TAGS
)
SELECT so.Week_Start_Date, so.Week_End_Date,
--        SUM(so.order_count)
       CASE WHEN so.PLANID = 13 THEN 'Hydra Boost Monthly'
           WHEN so.PLANID = 14 THEN 'Vitamin Monthly'
           WHEN so.PLANID = 15 THEN 'Hydra Boost Quarterly'
           WHEN so.PLANID = 16 THEN 'Vitamin Quarterly'
           WHEN so.PLANID = 17 THEN 'Hydra Boost Bi-annual'
           WHEN so.PLANID = 18 THEN 'Vitamin Bi-annual'
           WHEN so.PLANID IS NULL THEN 'OTP'
           ELSE 'Unknown'
           END as "PLAN_TYPE",
--        so.PLANID,
       so.NAME, so.SKU, so.order_count
FROM Subscription_Orders so
-- group by so.Week_Start_Date, so.Week_End_Date
ORDER BY so.Week_Start_Date desc, so.Week_End_Date desc, order_count desc;