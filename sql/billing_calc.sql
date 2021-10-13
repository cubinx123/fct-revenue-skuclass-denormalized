DROP TABLE IF EXISTS temp_billing_with_barangay;
CREATE TEMPORARY TABLE temp_billing_with_barangay AS (
WITH revheu_cte AS (

       --JOINING REVHEU AND COVERAGE CLASS

       SELECT r.reference_no,
       f_billing_clean_city(d.region,r.delivery_city) AS "delivery_city_r",
       f_billing_clean_province(d.region,r.delivery_province) AS "delivery_province",
       r.barangay,
       CASE WHEN LEFT(r.reference_no,4) = '0031'
            THEN 'lazada_regular'
            WHEN LEFT(r.reference_no,4) = '0038'
            THEN 'shopee_regular2'
            WHEN LEFT(r.reference_no,4) = '0017'
            THEN 'bpi_cc'
            ELSE LEFT(r.reference_no,4) -- this is for category
       END AS category,

       CAST(CASE WHEN LEFT(reference_no,4) = '0031'
                 THEN
                    --ROUND UP TO THE NEAREST 0.5 increment LAZADA ONLY
                      CASE WHEN CEILING(
                                    CAST(
                                        GREATEST(CAST(CASE WHEN r.actual_weight in (null,'-','0','') THEN '0' ELSE r.actual_weight END AS FLOAT),
                                                 CAST(CASE WHEN r.volumetric_weight IN (null,'-','0','') THEN '0' ELSE r.volumetric_weight END AS FLOAT)) AS FLOAT)/0.5)/2 = 0
                           THEN 1.000 --assumed weight for lazada
                           ELSE CEILING(
                                    CAST(
                                        GREATEST(CAST(CASE WHEN r.actual_weight in (null,'-','0','') THEN '0' ELSE r.actual_weight END AS FLOAT),
                                                 CAST(CASE WHEN r.volumetric_weight IN (null,'-','0','') THEN '0' ELSE r.volumetric_weight END AS FLOAT)) AS FLOAT)/0.5)/2
                      END

                 WHEN LEFT(reference_no,4) = '0038'
                 THEN
                      CASE WHEN CAST(
                                      GREATEST(CAST(CASE WHEN r.actual_weight IN (null,'-','0','') THEN '0' ELSE r.actual_weight END AS FLOAT),
                                               CAST(CASE WHEN r.volumetric_weight IN (null,'-','') THEN '0' ELSE r.volumetric_weight END AS FLOAT)) AS FLOAT) = 0
                           THEN 0.500 -- assumed weight for shopee
                           ELSE CAST(
                                      GREATEST(CAST(CASE WHEN r.actual_weight IN (null,'-','0','') THEN '0' ELSE r.actual_weight END AS FLOAT),
                                               CAST(CASE WHEN r.volumetric_weight IN (null,'-','') THEN '0' ELSE r.volumetric_weight END AS FLOAT)) AS FLOAT)
                      END

                 ELSE   CAST(GREATEST(CAST(CASE WHEN r.actual_weight IN (null,'-','0','') THEN '0' ELSE r.actual_weight END AS FLOAT),
                                       CAST(CASE WHEN r.volumetric_weight IN (null,'-','') THEN '0' ELSE r.volumetric_weight END AS FLOAT)) AS FLOAT)

            END AS DECIMAL(12,3)) AS char_weight,


       CAST(CASE WHEN LEFT(reference_no,4) = '0031'
                 THEN CEILING(CAST(CASE WHEN r.actual_weight in (null,'-','0','') THEN '0' ELSE r.actual_weight END AS FLOAT)/0.5)/2
                 ELSE CAST(CASE WHEN r.actual_weight IN (null,'-','0','') THEN '0' ELSE r.actual_weight END AS FLOAT)
            END AS FLOAT) AS actual_weight_r,


       CAST(CASE WHEN LEFT(reference_no,4) = '0031'
                 THEN CEILING(CAST(CASE WHEN r.volumetric_weight in (null,'-','0','') THEN '0' ELSE r.volumetric_weight END AS FLOAT)/0.5)/2
                 ELSE CAST(CASE WHEN r.volumetric_weight IN (null,'-','0','') THEN '0' ELSE r.volumetric_weight END AS FLOAT)
            END AS FLOAT) AS volumetric_weight_r,

       r.job_master_first,

       CAST(r.package_value AS DECIMAL(20,2)) AS package_value,
       CAST(r.actual_amount AS DECIMAL(20,2)) AS actual_amount,

       CASE WHEN LOWER(d.region) IS NULL 
            THEN 'ncr' 
            WHEN LEFT(r.reference_no,4) = '0038' AND LOWER(f_billing_clean_city(d.region,r.delivery_city)) = 'davao'
            THEN 'davao' -- this is for shopee EX Vizmin
            ELSE LOWER(d.region) 
      END AS "region",

       CASE WHEN d.coverage IS NULL THEN 'SA-C' ELSE d.coverage END AS "coverage",


       CASE WHEN LEFT(r.reference_no,4) not in ('0031','0038','0018','0280','0017')
            THEN
                 CASE WHEN actual_weight_r > 3
                      THEN 'general_cargo'
                      WHEN r.package_size in ('-','envelope','small','0','envelope size','envelopes') -- DASH (-) and base rate is only tentative
                      THEN 'small'
                      WHEN r.package_size in ('general_cargo','regular')
                      THEN 'general_cargo'
                      WHEN r.package_size in ('box','base rate')
                      THEN 'box'
                      WHEN r.package_size in ('extra_large','x-large','xl','extra large')
                      THEN 'extra_large'
                      WHEN r.package_size in ('large')
                      THEN 'large'
                      WHEN r.package_size in ('medium')
                      THEN 'medium'
                      WHEN r.package_size in ('bulky')
                      THEN 'bulky'
                      ELSE 'small' -- This also is tentative
                  END

            ELSE
                 CASE WHEN LEFT(r.reference_no,4) = '0038'
                      THEN 'none'
                      WHEN LEFT(r.reference_no,4) = '0018' or LEFT(r.reference_no,4) = '0280'
                      THEN 
                            CASE WHEN regexp_count(lower(r.reference_no),'mp') > 0
                                 THEN 'medium'
                                 ELSE
                                      CASE WHEN package_type IN ('-')
                                           THEN 'large'
                                           ELSE lower(package_type)
                                      END
                            END
                      WHEN char_weight > 3
                      THEN 'general_cargo'
                      ELSE 'pouch'
                 END
       END AS package_type,

       CASE WHEN LEFT(r.reference_no,4) in ('0219','0278','0237','0248','0234','0284','0266') --update this one if there are parcel or documents in rate card
            THEN 
                 CASE WHEN regexp_count(lower(package_type),'freight') > 0
                      THEN 'parcel'
                      WHEN regexp_count(lower(package_type),'mail') > 0
                      THEN 'document'
                      ELSE 'parcel' --usually parcel
                  END
            ELSE 'none'
       END AS package_category,

       CASE WHEN REGEXP_COUNT(lower(r.reference_no),'-pr') > 0 and (left(r.reference_no,4) = '0018' or left(r.reference_no,4) = '0280')
            THEN TRUE
            ELSE r.is_rtc
       END as is_rtc,
       r.is_express,
       r."timestamp",
       d.distance

       -- row_number() over (partition by r.reference_no) as "rn"


        FROM finance.revheu_test r
        LEFT JOIN finance.dailybilling_v2 d
        ON d.client_code = case when left(r.reference_no,4) in ('0031','0038','0017') 
                                then left(r.reference_no,4) 
                                when left(r.reference_no,4) in ('0010','0011','0012','0013','0014','0015','0016','0211','0282','0270','0011','0195','0289','0172','0287','0259','0260','0320','0314','0297') --globe codes
                                then 'globe'
                                when left(r.reference_no,4) in ('0018','0280')
                                then 'zalora'
                                else 'all' end
        AND replace(lower(concat(concat(d.city_daily,d.province_daily),d.barangay)),' ','') = replace(lower(concat(concat(replace(r.delivery_city,'ñ','n'),r.delivery_province),r.barangay)),' ','')
        -- WHERE LEFT(reference_no,4) in ('0223','0312','0265')
        -- WHERE LEFT(reference_no,4) not in ('0031','0038','0280','0018')
        -- WHERE LEFT(reference_no,4) in ('0211','0282','0270','0011','0195','0289','0172','0287','0259','0260','0320','0314','0297')
        -- WHERE LEFT(reference_no,4) in ('0038')
        -- WHERE LEFT(reference_no,4) in ('0031','0038','0018','0280','0117','0029','0192','0058','0163','0226','0242','0116','0180','0206','0141','0134','0140','0106','0199','0235','0228','0233','0185','0198','0173','0186','0092','0210','0217','0232','0214','0202','0230','0197','0216','0030','0219','0105','0122','0077','0160','0246','0150','0269','0171','0132','0137','0244','0209','0149','0167','0170','0265','0168','0144','0188','0268','0292','0278','0252','0294','0237','0245','0281','0241','0248','0234','0283','0215','0293')
        WHERE (LEFT(reference_no,4) in ('0031','0038','0018','0280','0117','0029','0192','0058','0163','0226','0242','0116','0180','0206','0141','0134','0140','0106','0199','0235','0228','0233','0185','0198','0173','0186','0092','0210','0217','0232','0214','0202','0230','0197','0216','0030','0219','0105','0122','0077','0160','0246','0150','0269','0171','0132','0137','0244','0209','0149','0167','0170','0265','0168','0144','0188','0268','0292','0278','0252','0294','0237','0245','0281','0241','0248','0234','0283','0215','0293')
              OR LEFT(reference_no,4) in ('0128','0196','0250','0304','0310','0315','0319','0323','0335','0337','0306','0332','0338','0309','0318','0343','0125','0347','0348','0324','0284','0349','0254','0345','0331','0340','0325','0311','0299','0308','0193','0298','0225','0267','0263','0187','0312','0223','0317','0266','0033','0339','0342','0258','0136','0211','0282','0270','0011','0195','0289','0172','0287','0259','0260','0320','0314','0297'))
        -- WHERE LEFT(reference_no,4) in ('0018','0280')
        AND r."timestamp" >= CONVERT_TIMEZONE('Asia/Manila', SYSDATE)::date - INTERVAL '7 DAY'
        -- AND r."timestamp" between '2021-02-01 00:00:00' and '2021-02-28 23:59:59'
        
        -- AND r."timestamp" between '2021-08-16 00:00:00' and '2021-08-30 23:59:59'




)

-- AGGREGATE/CALCULATE FOR FEES
SELECT  reference_no,
        delivery_city_r as delivery_city,
        delivery_province,
        category,
        char_weight,
        package_value,
        actual_amount,
        region,
        coverage,
        cod_fee,
        valuation_fee,
        base_rate_r as base_rate,
        return_shipping,
        weight_surcharge,
        sra_surcharge,
        total_shipping_fee,
        total_billing_amount_vatex,
        vat,
        total_billing_amount_vatinc,
        "timestamp",
        is_rtc,
        package_type as package_size,
        redelivery_fee,
        package_category,
        actual_weight_r as actual_weight,
        volumetric_weight_r as volumetric_weight,
        LOWER(job_master_first) as job_master,
        barangay,
        pickup_surcharge,
        express_surcharge,
        express_weight_surcharge


FROM (
        SELECT rh.reference_no,
               rh.delivery_city_r,
               rh.delivery_province,
               rh.barangay,
               rh.category,
               rh.char_weight,
               rh.package_value,
               rh.actual_amount,
               rh.region,
               rh.coverage,

               CASE WHEN rh.is_rtc
                    THEN 0 --NO COD FEE FOR RETURNING TRANSACTIONS
                    ELSE
                         CASE WHEN rh.actual_amount = 0
                              THEN 0
                              ELSE
                                    CASE WHEN rh.category in ('shopee_regular1','shopee_regular2')
                                         THEN GREATEST((rh.actual_amount * CAST(rc.cod AS float))/1.12, CAST(rc.cod_fix AS DECIMAL(8,3))) --REMOVING VAT FROM COD FEE CALCULATION FOR SHOPEE
                                         ELSE GREATEST(rh.actual_amount * CAST(rc.cod AS float), CAST(rc.cod_fix AS DECIMAL(8,3)))
                                    END
                         END           
               END AS "cod_fee",

               CASE WHEN rh.category in ('shopee_regular1','shopee_regular2') AND rh.package_value < 2501
                    THEN 0 --NO VALUATION FEE FOR SHOPPING FOR PACKAGE_VALUE LESS THAN 2501 PHP
                    ELSE
                        CASE WHEN rh.category in ('shopee_regular1','shopee_regular2')
                             THEN (rh.package_value * CAST(rc.valuation AS float)) / 1.12 --REMOVING VAT FROM VALUATION FEE CALCULATION FOR SHOPEE
                             WHEN LEFT(rh.reference_no,4) = '0248'
                             THEN (rh.package_value - 500) * CAST(rc.valuation AS float) --PINGCON first 500 pesos free of valuation fee
                             ELSE rh.package_value * CAST(rc.valuation AS float)
                        END
               END AS "valuation_fee",

               CASE WHEN rh.is_rtc AND rh.category in ('lazada_regular')
                    THEN '0'
                    WHEN rh.is_rtc and regexp_count(lower(rh.reference_no),'-pr') > 0 and (rh.category = '0018' or rh.category = '0280')
                    THEN '0'
                    ELSE rc.base_rate
              END AS "base_rate_r",

               CASE WHEN rh.char_weight > CAST(rc.threshold AS DECIMAL(8,2)) -- regardless of package size, as long as it exceeds the threshold weight, excess weight will be charged
               -- CASE WHEN rh.char_weight > CAST(rc.threshold AS DECIMAL(8,2)) and rh.package_type in ('general_cargo','bulky')
                    THEN
                         CASE WHEN rc.weight_roundup
                              THEN CEIL(rh.char_weight - CAST(rc.threshold AS DECIMAL(8,3))) * CAST(rc.excess AS DECIMAL(8,3))
                              ELSE (rh.char_weight - CAST(rc.threshold AS DECIMAL(8,3))) * CAST(rc.excess AS DECIMAL(8,3))
                         END
                    ELSE 0
               END AS "weight_surcharge",

               CASE WHEN rh.coverage not in ('SA-C')
                    THEN 
                          CASE WHEN left(rh.reference_no,4) in ('0018','0280','0283') -- when zalora and other clients, use fixed rate SAR in rate card
                               THEN CAST(rc.sar AS DECIMAL(8,2))
                               WHEN left(rh.reference_no,4) in ('0211','0282','0270','0011','0195','0289','0172','0287','0259','0260','0320','0314','0297') --globe project codes
                               THEN CAST(rh.distance as INT) * 5
                               ELSE (CAST(rc.base_rate AS float) + "weight_surcharge") * CAST(rc.sar AS DECIMAL(8,2))
                          END
                    ELSE 0
               END AS "sra_surcharge",

               CASE WHEN rh.is_rtc
                    THEN
                         CASE WHEN rh.category = 'lazada_regular'
                              THEN ((CAST(rc.base_rate AS float) + "weight_surcharge") * CAST(rc.return_rate AS DECIMAL(8,3))) -- no SRA surcharge since this a not a new client
                              WHEN rh.category in ('shopee_regular1','shopee_regular2')
                              THEN 0 --WE DONT CHARGE RETURN SHIPPING FOR SHOPEE
                              -- WHEN rh.category in ('0058','0163','0226','0116','0141','0134','0106','0092','0210','0217','0232','0214','0202','0230','0197','0216') --return shipping formula for these clients (base+weight) x 50% 
                              WHEN left(rh.reference_no,4) in ('0018','0280') -- Zalora RTC is pure 50% of base rate
                              THEN CAST(rc.base_rate AS float) * CAST(rc.return_rate AS DECIMAL(8,3))
                              WHEN rc.is_base_rate
                              THEN (CAST(rc.base_rate AS float) + "weight_surcharge") * CAST(rc.return_rate AS DECIMAL(8,3))
                              ELSE (CAST(rc.base_rate AS float) + "weight_surcharge" + "sra_surcharge") * CAST(rc.return_rate AS DECIMAL(8,3)) --other clients sra included
                         END
                    ELSE 0
                END AS "return_shipping",

               CASE WHEN REGEXP_COUNT(rh.reference_no,'RDEL') > 0 
                    THEN (CAST(rc.base_rate AS float) + "sra_surcharge" + "weight_surcharge") * CAST(rc.rdel AS DECIMAL(8,3)) 
                    ELSE 0
                    END AS "redelivery_fee",

                CASE WHEN regexp_count(lower(rh.reference_no),'-pr') > 0 and (rh.category = '0018' or rh.category = '0280')
                     THEN 10
                     ELSE 0
                END as "pickup_surcharge",    

                CASE WHEN rh.is_express
                     THEN CAST(rc.express_sur AS float)
                     ELSE 0
                END AS "express_surcharge",

                CASE WHEN rh.is_express AND rh.char_weight > CAST(rc.threshold AS DECIMAL(8,2))
                     THEN CAST(rc.express_weight_sur AS float)
                     ELSE 0
                END AS "express_weight_surcharge",



               CAST("base_rate_r" AS float) + "weight_surcharge" + "redelivery_fee" AS "total_shipping_fee",

               "total_shipping_fee" + "cod_fee" + "valuation_fee" + "sra_surcharge" + "return_shipping" + "pickup_surcharge" + "express_surcharge" + "express_weight_surcharge" AS "total_billing_amount_vatex",

               "total_billing_amount_vatex" * 0.12 AS "vat",

               "total_billing_amount_vatex" + "vat" AS "total_billing_amount_vatinc",

               rh."timestamp",

               rh.is_rtc,

               rh.package_type,

               rh.package_category,

               rh.actual_weight_r,
               rh.volumetric_weight_r,
               rh.job_master_first,

               ROW_NUMBER() OVER (PARTITION BY rh.reference_no) AS "rn"

        FROM  revheu_cte rh
        LEFT JOIN finance.rate_card_v2 rc
        ON rh.region = rc.region
        AND rh.category = rc.category
        AND rh.package_type = rc.package_type
        AND rh.package_category = rc.package_category
        AND rh.char_weight BETWEEN rc.weight_min AND rc.weight_max
        AND rh.package_value BETWEEN rc.value_min AND rc.value_max)

WHERE rn = 1

);

-- BEGIN TRANSACTION;

DELETE FROM finance.billing_all_clients
USING temp_billing_with_barangay
where finance.billing_all_clients.reference_no = temp_billing_with_barangay.reference_no;

INSERT INTO finance.billing_all_clients
SELECT * FROM temp_billing_with_barangay;

-- END TRANSACTION;

DROP TABLE temp_billing_with_barangay;