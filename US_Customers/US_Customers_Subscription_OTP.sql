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
customer_orders AS (
    SELECT w.Week_Start_Date, w.Week_End_Date, cpvl.SKU, opv.NAME, woo.PLANID, woo.TAGS, COUNT(DISTINCT woo.ID) as order_count
    FROM Weeks w
    JOIN WALDO_ORDERS."ORDER" woo ON TO_CHAR(woo.CREATEDAT, 'YYYY-MM-DD') BETWEEN w.Week_Start_Date AND w.Week_End_Date
    JOIN WALDO_ORDERS.ORDERCUSTOMER wooc ON woo.ID = wooc.ORDERID
    JOIN WALDO_ORDERS.CHARGE woc ON wooc.ORDERID = woc.ORDERID
    JOIN WALDO_ORDERS.ORDERPRODUCTVARIANT opv on woc.ORDERID = opv.ORDERID
    JOIN WALDO_CATALOG.CATALOGPRODUCTVARIANTLOCALE cpvl on opv.PRODUCTVARIANTID = cpvl.PRODUCTVARIANTID
    WHERE woc.STATUS = 'SUCCESS' AND woo.STATUS IN ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING')
    and wooc.CUSTOMERID IN (SELECT DISTINCT vc.ID FROM Valid_Customers vc)
--     AND (lower(opv.NAME) LIKE '%vitamin%' OR lower(opv.NAME) LIKE '%hydra boost%')
--     AND lower(opv.NAME) NOT LIKE '%trial%'
    GROUP BY w.Week_Start_Date, w.Week_End_Date, cpvl.SKU, opv.NAME, woo.PLANID, woo.TAGS
    ORDER BY w.Week_Start_Date, w.Week_End_Date
),
customer_order_sum AS (
    SELECT co.Week_Start_Date, co.Week_End_Date, sum(co.order_count) as order_count
    FROM customer_orders co
    WHERE co.PLANID IS NOT NULL
    GROUP BY co.Week_Start_Date, co.Week_End_Date
),
customer_order_null AS (
    SELECT co.Week_Start_Date, co.Week_End_Date, sum(co.order_count) as order_count
    FROM customer_orders co
--     WHERE co.PLANID IS NULL
    WHERE lower(co.TAGS) like '%otp%'
    GROUP BY co.Week_Start_Date, co.Week_End_Date
),
customer_orders_customer AS (
    SELECT w.Week_Start_Date, w.Week_End_Date,
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 13 THEN wooc.CUSTOMERID END ) as "ACTIVE - Hydra Boost Monthly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 14 THEN wooc.CUSTOMERID END ) as "ACTIVE - Vitamin Monthly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 15 THEN wooc.CUSTOMERID END ) as "ACTIVE - Hydra Boost Quarterly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 16 THEN wooc.CUSTOMERID END ) as "ACTIVE - Vitamin Quarterly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 17 THEN wooc.CUSTOMERID END ) as "ACTIVE - Hydra Boost Bi-annual",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 18 THEN wooc.CUSTOMERID END ) as "ACTIVE - Vitamin Bi-annual",
           count(DISTINCT wooc.CUSTOMERID) as active_customer_count
    FROM Weeks w
    JOIN WALDO_ORDERS."ORDER" woo ON TO_CHAR(woo.CREATEDAT, 'YYYY-MM-DD') BETWEEN w.Week_Start_Date AND w.Week_End_Date
    JOIN WALDO_ORDERS.ORDERCUSTOMER wooc ON woo.ID = wooc.ORDERID
    JOIN WALDO_ORDERS.CHARGE woc on wooc.ORDERID = woc.ORDERID
    JOIN WALDO_RENEWALS.CUSTOMERSUBSCRIPTION wrcs on wooc.CUSTOMERID = wrcs.CUSTOMERID
    JOIN WALDO_ORDERS.ORDERPRODUCTVARIANT opv on woc.ORDERID = opv.ORDERID
    JOIN WALDO_CATALOG.CATALOGPRODUCTVARIANTLOCALE cpvl on opv.PRODUCTVARIANTID = cpvl.PRODUCTVARIANTID
    WHERE woc.STATUS = 'SUCCESS' AND woo.STATUS IN ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING')
    and wooc.CUSTOMERID IN (SELECT DISTINCT vc.ID FROM Valid_Customers vc)
--     AND (lower(opv.NAME) LIKE '%vitamin%' OR lower(opv.NAME) LIKE '%hydra boost%')
--     AND lower(opv.NAME) NOT LIKE '%trial%'
    AND LOWER(woo.TAGS) NOT LIKE '%otp%'
    GROUP BY w.Week_Start_Date, w.Week_End_Date
    ORDER BY w.Week_Start_Date, w.Week_End_Date
),
only_otp AS (
    SELECT w.Week_Start_Date, w.Week_End_Date, count(DISTINCT wooc.CUSTOMERID) as order_count
    FROM Weeks w
    JOIN WALDO_ORDERS."ORDER" woo ON TO_CHAR(woo.CREATEDAT, 'YYYY-MM-DD') BETWEEN w.Week_Start_Date AND w.Week_End_Date
    JOIN WALDO_ORDERS.ORDERCUSTOMER wooc ON woo.ID = wooc.ORDERID
    JOIN WALDO_ORDERS.CHARGE woc on wooc.ORDERID = woc.ORDERID
    WHERE woc.STATUS = 'SUCCESS' AND woo.STATUS IN ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING')
    AND LOWER(woo.TAGS) LIKE '%otp%'
      AND wooc.CUSTOMERID NOT IN (SELECT DISTINCT CUSTOMERID FROM WALDO_RENEWALS.CUSTOMERSUBSCRIPTION)
      AND wooc.CUSTOMERID IN (SELECT DISTINCT vc.ID FROM Valid_Customers vc)
    GROUP BY w.Week_Start_Date, w.Week_End_Date
    ORDER BY w.Week_Start_Date, w.Week_End_Date
),
only_otp_orders AS (
    SELECT w.Week_Start_Date, w.Week_End_Date, count(DISTINCT woo.ID) as order_count
    FROM Weeks w
    JOIN WALDO_ORDERS."ORDER" woo ON TO_CHAR(woo.CREATEDAT, 'YYYY-MM-DD') BETWEEN w.Week_Start_Date AND w.Week_End_Date
    JOIN WALDO_ORDERS.ORDERCUSTOMER wooc ON woo.ID = wooc.ORDERID
    JOIN WALDO_ORDERS.CHARGE woc on wooc.ORDERID = woc.ORDERID
    WHERE woc.STATUS = 'SUCCESS' AND woo.STATUS IN ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING')
    AND LOWER(woo.TAGS) LIKE '%otp%'
      AND wooc.CUSTOMERID NOT IN (SELECT DISTINCT CUSTOMERID FROM WALDO_RENEWALS.CUSTOMERSUBSCRIPTION)
      AND wooc.CUSTOMERID IN (SELECT DISTINCT vc.ID FROM Valid_Customers vc)
    GROUP BY w.Week_Start_Date, w.Week_End_Date
    ORDER BY w.Week_Start_Date, w.Week_End_Date
),
customer_sub_new AS (
    SELECT w.Week_Start_Date, w.Week_End_Date,
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 13 THEN wrcs.CUSTOMERID END ) as "NEW SUBSCRIPTION - Hydra Boost Monthly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 14 THEN wrcs.CUSTOMERID END ) as "NEW SUBSCRIPTION - Vitamin Monthly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 15 THEN wrcs.CUSTOMERID END ) as "NEW SUBSCRIPTION - Hydra Boost Quarterly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 16 THEN wrcs.CUSTOMERID END ) as "NEW SUBSCRIPTION - Vitamin Quarterly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 17 THEN wrcs.CUSTOMERID END ) as "NEW SUBSCRIPTION - Hydra Boost Bi-annual",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 18 THEN wrcs.CUSTOMERID END ) as "NEW SUBSCRIPTION - Vitamin Bi-annual"
    FROM Weeks w
    JOIN WALDO_RENEWALS.CUSTOMERSUBSCRIPTION wrcs ON TO_CHAR(wrcs.CREATEDAT, 'YYYY-MM-DD') BETWEEN w.Week_Start_Date AND w.Week_End_Date
    WHERE wrcs.CUSTOMERID IN (SELECT DISTINCT vc.ID FROM Valid_Customers vc)
    GROUP BY w.Week_Start_Date, w.Week_End_Date
),
customer_sub_paused AS (
    SELECT w.Week_Start_Date, w.Week_End_Date,
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 13 THEN wrcs.CUSTOMERID END ) as "PAUSED - Hydra Boost Monthly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 14 THEN wrcs.CUSTOMERID END ) as "PAUSED - Vitamin Monthly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 15 THEN wrcs.CUSTOMERID END ) as "PAUSED - Hydra Boost Quarterly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 16 THEN wrcs.CUSTOMERID END ) as "PAUSED - Vitamin Quarterly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 17 THEN wrcs.CUSTOMERID END ) as "PAUSED - Hydra Boost Bi-annual",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 18 THEN wrcs.CUSTOMERID END ) as "PAUSED - Vitamin Bi-annual"
    FROM Weeks w
    JOIN WALDO_RENEWALS.CUSTOMERSUBSCRIPTION wrcs ON TO_CHAR(wrcs.CREATEDAT, 'YYYY-MM-DD') BETWEEN w.Week_Start_Date AND w.Week_End_Date
    JOIN WALDO_RENEWALS.PAUSE wrp on wrcs.ID = wrp.CUSTOMERSUBSCRIPTIONID
    LEFT JOIN WALDO_RENEWALS.CANCELLATION wrc on wrcs.ID = wrc.CUSTOMERSUBSCRIPTIONID
    WHERE wrcs.CUSTOMERID IN (SELECT DISTINCT vc.ID FROM Valid_Customers vc)
--       AND wrp.OUTCOME = 'IN_EFFECT'
    GROUP BY w.Week_Start_Date, w.Week_End_Date
),
customer_sub_cancelled AS (
    SELECT w.Week_Start_Date, w.Week_End_Date,
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 13 THEN wrcs.CUSTOMERID END ) as "CANCELLED - Hydra Boost Monthly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 14 THEN wrcs.CUSTOMERID END ) as "CANCELLED - Vitamin Monthly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 15 THEN wrcs.CUSTOMERID END ) as "CANCELLED - Hydra Boost Quarterly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 16 THEN wrcs.CUSTOMERID END ) as "CANCELLED - Vitamin Quarterly",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 17 THEN wrcs.CUSTOMERID END ) as "CANCELLED - Hydra Boost Bi-annual",
           COUNT(DISTINCT CASE WHEN wrcs.PLANID = 18 THEN wrcs.CUSTOMERID END ) as "CANCELLED - Vitamin Bi-annual"
    FROM Weeks w
    JOIN WALDO_RENEWALS.CUSTOMERSUBSCRIPTION wrcs ON TO_CHAR(wrcs.CREATEDAT, 'YYYY-MM-DD') BETWEEN w.Week_Start_Date AND w.Week_End_Date
    JOIN WALDO_RENEWALS.CANCELLATION wrc on wrcs.ID = wrc.CUSTOMERSUBSCRIPTIONID
    WHERE wrcs.CUSTOMERID IN (SELECT DISTINCT vc.ID FROM Valid_Customers vc)
    GROUP BY w.Week_Start_Date, w.Week_End_Date
)
SELECT w.Week_Start_Date as "Week Start",
       w.Week_End_Date as "Week End",
       COALESCE(coc."ACTIVE - Hydra Boost Monthly",0) as "ACTIVE - Hydra Boost Monthly",
       COALESCE(coc."ACTIVE - Vitamin Monthly",0) as "ACTIVE - Vitamin Monthly",
       COALESCE(coc."ACTIVE - Hydra Boost Quarterly",0) as "ACTIVE - Hydra Boost Quarterly",
       COALESCE(coc."ACTIVE - Vitamin Quarterly",0) as "ACTIVE - Vitamin Quarterly",
       COALESCE(coc."ACTIVE - Hydra Boost Bi-annual",0) as "ACTIVE - Hydra Boost Bi-annual",
       COALESCE(coc."ACTIVE - Vitamin Bi-annual",0) as "ACTIVE - Vitamin Bi-annual",
       COALESCE(csp."PAUSED - Hydra Boost Monthly",0) as "PAUSED - Hydra Boost Monthly",
       COALESCE(csp."PAUSED - Vitamin Monthly",0) as "PAUSED - Vitamin Monthly",
       COALESCE(csp."PAUSED - Hydra Boost Quarterly" ,0) as "PAUSED - Hydra Boost Quarterly",
       COALESCE(csp."PAUSED - Vitamin Quarterly",0) as "PAUSED - Vitamin Quarterly",
       COALESCE(csp."PAUSED - Hydra Boost Bi-annual",0) as "PAUSED - Hydra Boost Bi-annual",
       COALESCE(csp."PAUSED - Vitamin Bi-annual",0) as "PAUSED - Vitamin Bi-annual",
       COALESCE(csc."CANCELLED - Hydra Boost Monthly",0) as "CANCELLED - Hydra Boost Monthly",
       COALESCE(csc."CANCELLED - Vitamin Monthly",0) as "CANCELLED - Vitamin Monthly",
       COALESCE(csc."CANCELLED - Hydra Boost Quarterly",0) as "CANCELLED - Hydra Boost Quarterly",
       COALESCE(csc."CANCELLED - Vitamin Quarterly",0) as "CANCELLED - Vitamin Quarterly",
       COALESCE(csc."CANCELLED - Hydra Boost Bi-annual",0) as "CANCELLED - Hydra Boost Bi-annual",
       COALESCE(csc."CANCELLED - Vitamin Bi-annual",0) as "CANCELLED - Vitamin Bi-annual",
       COALESCE(csa."NEW SUBSCRIPTION - Hydra Boost Monthly",0) as "NEW SUBSCRIPTION - Hydra Boost Monthly",
       COALESCE(csa."NEW SUBSCRIPTION - Vitamin Monthly",0) as "NEW SUBSCRIPTION - Vitamin Monthly",
       COALESCE(csa."NEW SUBSCRIPTION - Hydra Boost Quarterly",0) as "NEW SUBSCRIPTION - Hydra Boost Quarterly",
       COALESCE(csa."NEW SUBSCRIPTION - Vitamin Quarterly",0) as "NEW SUBSCRIPTION - Vitamin Quarterly",
       COALESCE(csa."NEW SUBSCRIPTION - Hydra Boost Bi-annual",0) as "NEW SUBSCRIPTION - Hydra Boost Bi-annual",
       COALESCE(csa."NEW SUBSCRIPTION - Vitamin Bi-annual",0) as "NEW SUBSCRIPTION - Vitamin Bi-annual",
--        COALESCE(ooo.order_count,0) as "OTP Orders",
       COALESCE(co.order_count,0) as "Total Order Count",
       COALESCE(con.order_count,0) as "Total OTP Order Count",
       COALESCE(coc.active_customer_count,0) as "Total Active Subscribers",
       COALESCE(oo.order_count,0) as "Total OTP Customers"
FROM Weeks w
LEFT JOIN customer_sub_new csa ON csa.Week_Start_Date = w.Week_Start_Date AND csa.Week_End_Date = w.Week_End_Date
LEFT JOIN customer_order_sum co ON co.Week_Start_Date = w.Week_Start_Date AND co.Week_End_Date = w.Week_End_Date
LEFT JOIN customer_order_null con ON con.Week_Start_Date = w.Week_Start_Date AND con.Week_End_Date = w.Week_End_Date
LEFT JOIN customer_orders_customer coc ON coc.Week_Start_Date = w.Week_Start_Date AND coc.Week_End_Date = w.Week_End_Date
LEFT JOIN only_otp oo ON oo.Week_Start_Date = w.Week_Start_Date AND oo.Week_End_Date = w.Week_End_Date
LEFT JOIN only_otp_orders ooo ON ooo.Week_Start_Date = w.Week_Start_Date AND ooo.Week_End_Date = w.Week_End_Date
LEFT JOIN customer_sub_paused csp ON csp.Week_Start_Date = w.Week_Start_Date AND csp.Week_End_Date = w.Week_End_Date
LEFT JOIN customer_sub_cancelled csc ON csc.Week_Start_Date = w.Week_Start_Date AND csc.Week_End_Date = w.Week_End_Date
-- group by w.Week_Start_Date, w.Week_End_Date
ORDER BY w.Week_Start_Date desc, w.Week_End_Date desc;