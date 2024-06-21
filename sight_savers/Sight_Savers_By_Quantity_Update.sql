WITH Valid_Customers AS (
    SELECT wcc.ID, wcc.FIRSTNAME, wcc.LASTNAME, wcc.EMAIL, wrcs.PLANID, wrcs.CREATEDAT
    FROM WALDO_CUSTOMERS.CUSTOMER wcc
    JOIN WALDO_RENEWALS.CUSTOMERSUBSCRIPTION wrcs ON wcc.ID = wrcs.CUSTOMERID
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
      AND wcc.FIRSTNAME IS NOT NULL
),
filter_order AS (
SELECT wooc.CUSTOMERID, woo.ID, woo.PLANID, opv.NAME, opv.QUANTITY, cp.TITLE,
       ROW_NUMBER() OVER (PARTITION BY woo.ID ORDER BY woo.CREATEDAT DESC) AS rn
FROM WALDO_ORDERS."ORDER" woo
JOIN WALDO_ORDERS.CHARGE woc on woo.ID = woc.ORDERID
JOIN WALDO_ORDERS.ORDERCUSTOMER wooc on woc.ORDERID = wooc.ORDERID
JOIN WALDO_ORDERS.ORDERPRODUCTVARIANT opv on wooc.ORDERID = opv.ORDERID
JOIN WALDO_CATALOG.CATALOGPLAN cp on woo.PLANID = cp.ID

WHERE (lower(opv.NAME) LIKE '%vitamin%' OR lower(opv.NAME) LIKE '%hydra boost%')
    AND lower(opv.NAME) NOT LIKE '%trial%'
    AND wooc.CUSTOMERID IN (SELECT DISTINCT vc.ID FROM Valid_Customers vc)
    AND woc.STATUS = 'SUCCESS'
    AND woo.STATUS IN ('SUCCESS','APPROVED','DISPATCHING', 'AUTHORISING', 'PENDING')
    AND TO_CHAR(woc.CREATEDAT, 'YYYY-MM-DD') >= '2021-06-22'
),
filter_order_2 AS (
    SELECT *,
           CASE
               WHEN LOWER(fo.TITLE) LIKE '%monthly%' AND fo.QUANTITY = 1 AND rn <= 2 THEN 1
               WHEN LOWER(fo.TITLE) LIKE '%monthly%' AND fo.QUANTITY > 1 AND rn = 1 THEN 1
--                WHEN LOWER(fo.TITLE) LIKE '%monthly%' AND fo.QUANTITY = 2 AND rn = 1 THEN 1

               WHEN LOWER(fo.TITLE) LIKE '%quarterly%' AND fo.QUANTITY = 3 AND rn <= 2 THEN 1
               WHEN LOWER(fo.TITLE) LIKE '%quarterly%' AND fo.QUANTITY > 3 AND rn = 1 THEN 1
--                WHEN LOWER(fo.TITLE) LIKE '%quarterly%' AND fo.QUANTITY = 6 AND rn = 1 THEN 1

               WHEN LOWER(fo.TITLE) LIKE '%bi-annual%' AND fo.QUANTITY = 6 AND rn <= 2 THEN 1
               WHEN LOWER(fo.TITLE) LIKE '%bi-annual%' AND fo.QUANTITY > 6 AND rn = 1 THEN 1
--                WHEN LOWER(fo.TITLE) LIKE '%bi-annual%' AND fo.QUANTITY = 12 AND rn = 1 THEN 1
               
           END as keep_row
    FROM filter_order fo
)
SELECT DISTINCT
    cp.CUSTOMERID,
   COUNT(DISTINCT CASE WHEN LOWER(cp.TITLE) LIKE '%monthly%' THEN cp.ID END) as "Monthly",
   SUM(CASE WHEN LOWER(cp.TITLE) LIKE '%monthly%' THEN cp.QUANTITY ELSE 0 END) as "Monthly Count",

   COUNT(DISTINCT CASE WHEN LOWER(cp.TITLE) LIKE '%quarterly%' THEN cp.ID END) as "Quarterly",
   SUM(CASE WHEN LOWER(cp.TITLE) LIKE '%quarterly%' THEN cp.QUANTITY ELSE 0 END) as "Quaterly Count",
   COUNT(DISTINCT CASE WHEN LOWER(cp.TITLE) LIKE '%bi-annual%' THEN cp.ID END) as "Bi-annual",
   SUM(CASE WHEN LOWER(cp.TITLE) LIKE '%bi-annual%' THEN cp.QUANTITY ELSE 0 END) as "Bi-annual Count",

   "Monthly Count" + "Quaterly Count" + "Bi-annual Count" as total_packs,
   FLOOR(("Monthly Count" + "Quaterly Count" + "Bi-annual Count") / 24) as donation_count

FROM filter_order_2 cp
WHERE cp.keep_row = 1
GROUP BY cp.CUSTOMERID
ORDER BY total_packs desc;