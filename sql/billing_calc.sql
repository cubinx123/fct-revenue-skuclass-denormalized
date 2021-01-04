DROP TABLE IF EXISTS temp_billing_calc;
CREATE TEMPORARY TABLE temp_billing_calc AS (
WITH revheu_cte AS (

       SELECT r.reference_no,
       r.delivery_city,
       r.delivery_province,

       CASE WHEN LEFT(r.reference_no,4) = '0031'
            THEN 'lazada_regular'
            WHEN LEFT(r.reference_no,4) = '0038'
            THEN 'shopee_regular2'
            WHEN LEFT(r.reference_no,4) = '0017'
            THEN 'bpi_cc'
            ELSE NULL
       END AS category,

       CAST(CASE WHEN LEFT(reference_no,4) = '0031'
            THEN
                --ROUND UP TO THE NEAREST 0.5 increment LAZADA ONLY
                CASE WHEN CEILING(
                              CAST(
                                  GREATEST(CASE WHEN r.actual_weight in (null,'-','0') THEN '0' ELSE r.actual_weight END,
                                           CASE WHEN r.actual_weight IN (null,'-','0') THEN '0' ELSE r.volumetric_weight END) AS FLOAT)/0.5)/2 = 0
                     THEN 1.000 --assumed weight for lazada
                     ELSE CEILING(
                              CAST(
                                  GREATEST(CASE WHEN r.actual_weight in (null,'-','0') THEN '0' ELSE r.actual_weight END,
                                           CASE WHEN r.actual_weight IN (null,'-','0') THEN '0' ELSE r.volumetric_weight END) AS FLOAT)/0.5)/2
                END 
            ELSE
                CASE WHEN CAST(
                                GREATEST(CASE WHEN r.actual_weight IN (null,'-','0') THEN '0' ELSE r.actual_weight END,
                                         CASE WHEN r.actual_weight IN (null,'-','') THEN '0' ELSE r.volumetric_weight END) AS FLOAT) = 0
                     THEN 1.000 -- assumed weight for shopee
                     ELSE CAST(
                                GREATEST(CASE WHEN r.actual_weight IN (null,'-','0') THEN '0' ELSE r.actual_weight END,
                                         CASE WHEN r.actual_weight IN (null,'-','') THEN '0' ELSE r.volumetric_weight END) AS FLOAT)
                END     

            END AS DECIMAL(8,3)) AS char_weight,

       CAST(r.package_value AS DECIMAL(20,2)) AS package_value,
       CAST(r.actual_amount AS DECIMAL(20,2)) AS actual_amount,

       LOWER(d.region) as "region",
       d.coverage,

       CASE
                  WHEN LEFT(r.reference_no,4) = '0038'
                  THEN 'none'
                  WHEN LEFT(r.reference_no,4) = '0018'
                  THEN package_type
                  WHEN char_weight > 3
                  THEN 'general_cargo'
                  ELSE 'pouch'
       END AS package_type,

       r.is_rtc,
       r."timestamp"


-- for assumed weight, criterias are 0 and null

        FROM finance.revheu_v2 r
        LEFT JOIN finance.dailybilling d
        ON d.client_code = left(r.reference_no,4)
        AND lower(concat(d.city_daily,d.province_daily)) = lower(concat(r.delivery_city,r.delivery_province))
        WHERE LEFT(reference_no,4) in ('0038','0031')
        AND r."timestamp" >= CONVERT_TIMEZONE('Asia/Manila', SYSDATE)::date - INTERVAL '1 DAY'
        -- AND r."timestamp" between '2020-10-01 00:00:00' and '2021-11-30 23:59:59'
        

                              
)

-- AGGREGATE/CALCULATE FOR FEES
SELECT  reference_no,
        delivery_city,
        delivery_province,
        category,
        char_weight,
        package_value,
        actual_amount,
        region,
        coverage,
        cod_fee,
        valuation_fee,
        base_rate,
        return_shipping,
        weight_surcharge,
        sra_surcharge,
        total_shipping_fee,
        total_billing_amount_vatex,
        vat,
        total_billing_amount_vatinc,
        "timestamp",
        is_rtc


FROM (
        SELECT rh.reference_no,
               rh.delivery_city,
               rh.delivery_province,
               rh.category,
               rh.char_weight,
               rh.package_value,
               rh.actual_amount,
               rh.region,
               rh.coverage,

               CASE WHEN rh.is_rtc
                    THEN 0 --NO COD FEE FOR RETURNING TRANSACTIONS
                    ELSE 
                        CASE WHEN rh.category in ('shopee_regular1','shopee_regular2')
                             THEN (rh.actual_amount * CAST(rc.cod AS DECIMAL(8,3)))/1.12 --REMOVING VAT FROM COD FEE CALCULATION FOR SHOPEE
                             ELSE rh.actual_amount * CAST(rc.cod AS DECIMAL(8,3))
                        END
               END AS "cod_fee",

               CASE WHEN rh.category in ('shopee_regular1','shopee_regular2') AND rh.package_value < 2501
                    THEN 0 --NO VALUATION FEE FOR SHOPPING FOR PACKAGE_VALUE LESS THAN 2501 PHP
                    ELSE 
                        CASE WHEN rh.category in ('shopee_regular1','shopee_regular2')
                             THEN (rh.package_value * CAST(rc.valuation AS DECIMAL(8,3))) / 1.12 --REMOVING VAT FROM VALUATION FEE CALCULATION FOR SHOPEE
                             ELSE rh.package_value * CAST(rc.valuation AS DECIMAL(8,3)) 
                        END
               END AS "valuation_fee",

               rc.base_rate,

               CASE WHEN rh.char_weight > CAST(rc.threshold AS DECIMAL(8,2))
                    THEN ((rh.char_weight - CAST(rc.threshold AS DECIMAL(8,3)))/0.5) * CAST(rc.excess AS DECIMAL(8,3)) --ONLY SHOPEE HAS WEIGHT SURCHARGE AND IT IS BY 0.5kgs
                    ELSE 0
               END AS "weight_surcharge",

               CASE WHEN rh.coverage not in ('SA-C')
                    THEN (CAST(rc.base_rate AS DECIMAL(8,3)) + "weight_surcharge") * CAST(rc.sar AS DECIMAL(8,2))
                    ELSE 0
               END AS "sra_surcharge",

               CASE WHEN rh.is_rtc
                    THEN
                         CASE WHEN rh.category = 'lazada_regular'
                              THEN ((CAST(rc.base_rate AS DECIMAL(8,3)) + "weight_surcharge") * 0.5) + "valuation_fee"
                              ELSE 0 --WE DONT CHARGE RETURN SHIPPING FOR SHOPEE
                         END
                    ELSE 0 
                END AS "return_shipping",

               CAST(rc.base_rate AS DECIMAL(8,3)) + "weight_surcharge" AS "total_shipping_fee",

               "total_shipping_fee" + "cod_fee" + "valuation_fee" + "sra_surcharge" + "return_shipping" AS "total_billing_amount_vatex",
 
               "total_billing_amount_vatex" * 0.12 AS "vat",

               "total_billing_amount_vatex" + "vat" AS "total_billing_amount_vatinc",

               rh."timestamp",
               rh.is_rtc,

               ROW_NUMBER() OVER (PARTITION BY rh.reference_no) AS "rn"

        FROM  revheu_cte rh
        LEFT JOIN finance.rate_card rc
        ON rh.region = rc.region
        AND rh.category = rc.category
        AND rh.package_type = rc.package_type
        AND rh.char_weight BETWEEN rc.weight_min AND rc.weight_max)

WHERE rn = 1

);

BEGIN TRANSACTION;

DELETE FROM finance.billing_calculated
USING temp_billing_calc
where finance.billing_calculated.reference_no = temp_billing_calc.reference_no;

INSERT INTO finance.billing_calculated
SELECT * FROM temp_billing_calc;

END TRANSACTION;

DROP TABLE temp_billing_calc;

