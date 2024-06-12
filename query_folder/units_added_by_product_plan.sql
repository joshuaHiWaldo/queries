-- #######################################
-- Change '2024-06' [line 7] to required Year,Month
-- If you want only for a certain Year,Month, change ">=" to "=" [line 19] 
-- #######################################

WITH Given_Month AS (
    SELECT '2024-06' as given_month
)
SELECT
   wcc.REGION,
   cp.TITLE,
   SUM(opv.QUANTITY) as units_sold
   FROM WALDO_CUSTOMERS.CUSTOMER wcc
   JOIN WALDO_ORDERS.ORDERCUSTOMER wooc ON wcc.ID = wooc.CUSTOMERID
   JOIN WALDO_ORDERS."ORDER" woo ON wooc.ORDERID = woo.ID
   JOIN WALDO_ORDERS.CHARGE woc ON woo.ID = woc.ORDERID
   JOIN WALDO_CATALOG.CATALOGPLAN cp ON woo.PLANID = cp.ID
   JOIN WALDO_ORDERS.ORDERPRODUCTVARIANT opv ON woo.ID = opv.ORDERID
   WHERE TO_CHAR(CAST(woc.CREATEDAT AS DATE), 'YYYY-MM') >= (SELECT gm.given_month FROM Given_Month gm)
    AND woo.STATUS in ('SUCCESS','APPROVED','DISPATCHING', 'AUTHORISING', 'PENDING')
    AND woc.STATUS = 'SUCCESS'
    AND wcc.EMAIL LIKE '%@%'
    AND wcc.EMAIL NOT LIKE '%@hiwaldo%'
    AND LOWER(wcc.FIRSTNAME) NOT LIKE '%test%'
    AND LOWER(wcc.LASTNAME) NOT LIKE '%test%'
    AND wcc.ACTIVE = true
   GROUP BY wcc.REGION, cp.TITLE
   ORDER BY wcc.REGION, cp.TITLE;