WITH all_info AS (
WITH only_otp AS (
SELECT wcc.ID, woo.SHIPPINGCOUNTRY, woo.BILLINGCOUNTRY
FROM WALDO_CUSTOMERS.CUSTOMER wcc
LEFT JOIN WALDO_ORDERS.ORDERCUSTOMER wooc on wcc.ID = wooc.CUSTOMERID
LEFT JOIN WALDO_ORDERS."ORDER" woo on wooc.ORDERID = woo.ID
WHERE wcc.ID NOT IN (SELECT DISTINCT wrcs.CUSTOMERID as cid FROM WALDO_RENEWALS.CUSTOMERSUBSCRIPTION wrcs)
AND LOWER(woo.TAGS) LIKE '%otp%'
),
Customer_Info AS (
SELECT
wcc.ID,
wcc.FIRSTNAME,
wcc.LASTNAME,
wcc.EMAIL,
woo.BILLINGCOUNTRY as B_COUNTRY,
CASE
    WHEN woo.SHIPPINGCOUNTRY = 'FR' THEN 'France'
    WHEN woo.SHIPPINGCOUNTRY = 'FI' THEN 'Finland'
    WHEN woo.SHIPPINGCOUNTRY = 'ES' THEN 'Spain'
    WHEN woo.SHIPPINGCOUNTRY = 'DE' THEN 'Germany'
    WHEN woo.SHIPPINGCOUNTRY = 'NL' THEN 'Netherlands'
    WHEN woo.SHIPPINGCOUNTRY = 'BE' THEN 'Belgium'
    WHEN woo.SHIPPINGCOUNTRY = 'IT' THEN 'Italy'
    WHEN woo.SHIPPINGCOUNTRY = 'IE' THEN 'Ireland'
    ELSE woo.SHIPPINGCOUNTRY END as S_COUNTRY,
woo.REGION,
woo.TAGS,
wrcs.STATUS sub_status
FROM WALDO_CUSTOMERS.CUSTOMER wcc
LEFT JOIN WALDO_ORDERS.ORDERCUSTOMER wooc on wcc.ID = wooc.CUSTOMERID
LEFT JOIN WALDO_ORDERS."ORDER" woo on wooc.ORDERID = woo.ID
LEFT JOIN WALDO_RENEWALS.CUSTOMERSUBSCRIPTION wrcs on woo.ID = wrcs.ORDERID
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
      AND wcc.REGION != 'US'
      AND wcc.FIRSTNAME IS NOT NULL
)
SELECT
DISTINCT ci.S_COUNTRY as SHIPPING_COUNTRY,
COUNT(DISTINCT CASE WHEN sub_status = 'ACTIVE' THEN ci.ID END) as ACTIVE_SUBSCRIPTIONS,
COUNT(DISTINCT CASE WHEN sub_status = 'PAUSED' THEN ci.ID END) as PAUSED_SUBSCRIPTIONS,
COUNT(DISTINCT CASE WHEN sub_status = 'CANCELLED' THEN ci.ID END) as CANCELLED_SUBSCRIPTIONS,
-- COUNT(DISTINCT CASE WHEN LOWER(ci.TAGS) LIKE '%otp%' THEN ci.ID END) as OTP_ORDERS,
COUNT(DISTINCT oo.ID) as ONLY_OTP,
COUNT(DISTINCT CASE WHEN sub_status IN ('ACTIVE', 'PAUSED', 'CANCELLED') THEN ci.ID
                ELSE oo.ID END) as TOTAL_CUSTOMERS
FROM Customer_Info ci
LEFT JOIN only_otp oo on ci.ID = oo.ID-- ci.B_COUNTRY = oo.BILLINGCOUNTRY AND ci.S_COUNTRY = oo.SHIPPINGCOUNTRY -- ci.ID = oo.ID
-- WHERE ci.B_COUNTRY IS NOT NULL AND ci.B_COUNTRY != '' AND ci.B_COUNTRY != 'unknown'
WHERE ci.S_COUNTRY IS NOT NULL AND ci.S_COUNTRY != '' AND ci.S_COUNTRY != 'unknown' and ci.S_COUNTRY != 'United States'
GROUP BY ci.S_COUNTRY
ORDER BY ci.S_COUNTRY DESC
)
SELECT *
FROM all_info ai
WHERE ai.PAUSED_SUBSCRIPTIONS > 0 or ai.ACTIVE_SUBSCRIPTIONS > 0 or ai.CANCELLED_SUBSCRIPTIONS > 0 or ai.ONLY_OTP > 0 or ai.TOTAL_CUSTOMERS > 0;