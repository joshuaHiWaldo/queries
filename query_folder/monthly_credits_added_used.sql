-- #######################################
-- Change '2024-05' [line 6] to required Year,Month
-- #######################################

WITH Given_Month AS (
    SELECT '2024-05' as given_month
),
region_currency AS (
    SELECT DISTINCT REGION, CURRENCY FROM WALDO_ORDERS.CHARGE
),
Credit_Used AS (
    SELECT wcc.REGION,
           SUM(woo.CREDITDEDUCTIONS/100) as "CREDIT_USED",
           SUM(woo.DISCOUNTDEDUCTIONS/100) as "DISCOUNT_USED"
    FROM WALDO_ORDERS."ORDER" woo
    JOIN WALDO_ORDERS.ORDERCUSTOMER wooc ON woo.ID = wooc.ORDERID
    JOIN WALDO_CUSTOMERS.CUSTOMER wcc ON wooc.CUSTOMERID = wcc.ID
    LEFT JOIN WALDO_ORDERS.CHARGE woc on woo.ID = woc.ORDERID
    WHERE woo.STATUS in ('SUCCESS','APPROVED','DISPATCHING', 'AUTHORISING', 'PENDING')
    AND woc.STATUS = 'SUCCESS'
    AND EMAIL LIKE '%@%'
    AND EMAIL NOT LIKE '%@hiwaldo%'
    AND LOWER(FIRSTNAME) NOT LIKE '%test%'
    AND LOWER(LASTNAME) NOT LIKE '%test%'
    AND wcc.ACTIVE = true
    AND TO_CHAR(CAST(woc.CREATEDAT AS DATE), 'YYYY-MM') = (SELECT gm.given_month FROM Given_Month gm)
    GROUP BY wcc.REGION
),
Credit_Added AS (
    SELECT wcc.REGION,
           SUM(CASE WHEN VALUEADDED > 0 THEN VALUEADDED/100 END) as "CREDIT_ADDED"
FROM WALDO_CUSTOMERS.CUSTOMERCREDITLOG wccl
    JOIN WALDO_CUSTOMERS.CUSTOMER wcc ON wccl.CUSTOMERID = wcc.ID
    WHERE TO_CHAR(CAST(wccl.CREATEDAT AS DATE), 'YYYY-MM') = (SELECT gm.given_month FROM Given_Month gm)
    AND wcc.EMAIL LIKE '%@%'
    AND wcc.EMAIL NOT LIKE '%@hiwaldo%'
    AND LOWER(wcc.FIRSTNAME) NOT LIKE '%test%'
    AND LOWER(wcc.LASTNAME) NOT LIKE '%test%'
    GROUP BY wcc.REGION
)
SELECT cu.REGION, rc.CURRENCY,
       ROUND(cu.CREDIT_USED,2) as credit_used,
       ROUND(cu.DISCOUNT_USED,2) as discount_used,
       ROUND(ca.CREDIT_ADDED,2) as credit_added
FROM Credit_Used cu
JOIN Credit_Added ca on cu.REGION = ca.REGION
JOIN region_currency rc on ca.REGION = rc.REGION;