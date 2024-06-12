-- TOTAL_CUSTOMER_CREDITS
WITH Region_Currency AS (
    SELECT DISTINCT woc.REGION, woc.CURRENCY
    FROM WALDO_ORDERS.CHARGE woc
),
Customer_Credit AS (
    SELECT wcc.ID, wcc.EMAIL, wcc.FIRSTNAME, wcc.LASTNAME, wcc.REGION, COALESCE(wcc.CREDIT/100, 0) as CREDIT
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
      AND wcc.FIRSTNAME IS NOT NULL
),
Customer_Used_Credit AS (
    SELECT wcc.ID, COALESCE(SUM(woo.CREDITDEDUCTIONS/100), 0) as Deductions, COUNT(woo.ID) as Number_Orders
    FROM WALDO_CUSTOMERS.CUSTOMER wcc
    LEFT JOIN WALDO_ORDERS.ORDERCUSTOMER wooc on wcc.ID = wooc.CUSTOMERID
    LEFT JOIN WALDO_ORDERS."ORDER" woo on wooc.ORDERID = woo.ID
    LEFT JOIN WALDO_ORDERS.CHARGE woc on woo.ID = woc.ORDERID
    WHERE woo.STATUS in ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING')  and woc.STATUS = 'SUCCESS'
    GROUP BY wcc.ID
)
SELECT cc.ID, cc.EMAIL, cc.FIRSTNAME, cc.LASTNAME, cc.REGION, rc.CURRENCY,
       cc.CREDIT, COALESCE(cuc.Deductions, 0) as Deductions,
       cc.CREDIT + COALESCE(cuc.Deductions, 0) as TOTAL_CREDIT,
       COALESCE(cuc.Number_Orders, 0)
    FROM Customer_Credit cc
        LEFT JOIN Customer_Used_Credit cuc on cc.ID = cuc.ID
        JOIN Region_Currency rc on cc.REGION = rc.REGION
    WHERE TOTAL_CREDIT > 0
ORDER BY TOTAL_CREDIT DESC;