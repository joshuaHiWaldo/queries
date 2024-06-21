-- This query provides the difference between credit added/used
-- only shows customers who used more than they were given

WITH Valid_Customers AS (
    SELECT DISTINCT *
    FROM WALDO_CUSTOMERS.CUSTOMER wcc
    WHERE wcc.EMAIL LIKE '%@%'
    AND wcc.EMAIL NOT LIKE '%@hiwaldo%'
    AND LOWER(wcc.FIRSTNAME) NOT LIKE '%test%'
    AND LOWER(wcc.LASTNAME) NOT LIKE '%test%'
    AND wcc.REGION = 'UK'
),
Credit_Added AS (
    SELECT vc.ID as customer_id,
           SUM(CASE WHEN wccl.VALUEADDED > 0 THEN wccl.VALUEADDED/100 END) as added_credit
    FROM Valid_Customers vc
    LEFT JOIN WALDO_CUSTOMERS.CUSTOMERCREDITLOG wccl on vc.ID = wccl.CUSTOMERID
    WHERE TO_CHAR(wccl.CREATEDAT, 'YYYY-MM-DD') > '2022-03-11'
    AND wccl.ORDERID IS NULL
    GROUP BY vc.ID
),
Credit_Used AS (
    SELECT vc.ID as customer_id,
           SUM(woo.CREDITDEDUCTIONS/100) as used_credit
    FROM Valid_Customers vc
    LEFT JOIN WALDO_ORDERS.ORDERCUSTOMER wooc on vc.ID = wooc.CUSTOMERID
    LEFT JOIN WALDO_ORDERS."ORDER" woo on wooc.ORDERID = woo.ID
    LEFT JOIN WALDO_ORDERS.CHARGE woc on woo.ID = woc.ORDERID
    WHERE woc.STATUS = 'SUCCESS' AND woo.STATUS IN ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING')
    AND TO_CHAR(woo.CREATEDAT, 'YYYY-MM-DD') > '2022-03-11'
    GROUP BY vc.ID
),
Order_Count AS (
    SELECT vc.ID,
           COUNT(DISTINCT CASE WHEN woo.STATUS IN ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING') THEN woo.ID END) as successful_orders,
           COUNT(DISTINCT CASE WHEN woo.STATUS NOT IN ('APPROVED', 'SUCCESS', 'AUTHORISING', 'PENDING', 'DISPATCHING') THEN woo.ID END) as failed_orders,
           COUNT(DISTINCT CASE WHEN woc.STATUS IN ('SUCCESS', 'PENDING') THEN woc.ORDERID END) as successful_charge,
           COUNT(DISTINCT CASE WHEN woc.STATUS IN ('REFUNDED') THEN woc.ORDERID END) as refund_charge,
           COUNT(DISTINCT CASE WHEN woc.STATUS IN ('PARTIALLY_REFUNDED') THEN woc.ORDERID END) as partial_refund_charge,
           COUNT(DISTINCT CASE WHEN woc.STATUS IN ('FAILURE') THEN woc.ORDERID END) as failure_charge
    FROM Valid_Customers vc
    LEFT JOIN WALDO_ORDERS.ORDERCUSTOMER wooc on vc.ID = wooc.CUSTOMERID
    LEFT JOIN WALDO_ORDERS."ORDER" woo on wooc.ORDERID = woo.ID
    LEFT JOIN WALDO_ORDERS.CHARGE woc on woo.ID = woc.ORDERID
    WHERE TO_CHAR(woo.CREATEDAT, 'YYYY-MM-DD') > '2022-03-11' AND TO_CHAR(woc.CREATEDAT, 'YYYY-MM-DD') > '2022-03-11'
    GROUP BY vc.ID
)
SELECT vc.ID, vc.FIRSTNAME, vc.LASTNAME, vc.EMAIL, vc.CREDIT/100 as Current_Credit, ca.added_credit, cu.used_credit,
       ca.added_credit - cu.used_credit as Difference
       --oc.successful_orders, oc.failed_orders,
       --oc.successful_charge, oc.partial_refund_charge, oc.refund_charge, oc.failure_charge
FROM Valid_Customers vc
LEFT JOIN Credit_Added ca on vc.ID = ca.customer_id
LEFT JOIN Credit_Used cu on vc.ID = cu.customer_id
LEFT JOIN Order_Count oc on vc.ID = oc.ID
WHERE ca.added_credit < cu.used_credit;