DROP TABLE IF EXISTS temp_revheu_staging;
CREATE TEMPORARY TABLE temp_revheu_staging AS (
WITH fzb_cte AS(
       SELECT 
         reference_no,
         reference_no AS reference_no_clean,
         NULL AS client_name,
         CASE WHEN LOWER(job_master) IN ('rtc_delivery','s_delivery') THEN TRUE ELSE FALSE END as for_is_rtc,
         coalesce(updated_time,transaction_date) AS "time_stamp",
         package_type,
         CASE WHEN REGEXP_COUNT(package_value,'[a-zA-Z-]') > 0 THEN '0' ELSE package_value END AS package_value,
         package_size,
         CASE WHEN REGEXP_COUNT(actual_weight,'[a-zA-Z-]') > 0 THEN '0' ELSE actual_weight END AS actual_weight,
         CASE WHEN REGEXP_COUNT(volumetric_weight,'[a-zA-Z-]') > 0 THEN '0' ELSE volumetric_weight END AS volumetric_weight,
         CASE WHEN REGEXP_COUNT(actual_amount,'[a-zA-Z-]') > 0 THEN '0' ELSE actual_amount END AS actual_amount,
         money_transaction_type,
         hub,
         delivery_city,
         delivery_province,
         CASE WHEN LOWER(job_master) IN ('express delivery','express_delivery') THEN TRUE ELSE FALSE END as for_is_express,
         job_master,
         status,
         TRUE AS is_delivered,
         erp_push_time,
         longitude,
         latitude,
         coalesce(updated_time,transaction_date) AS start_date
      FROM fareye_zalora_backup fzb  
      WHERE reference_no IN (
                              SELECT DISTINCT reference_no 
                              FROM fareye_zalora_backup
                              WHERE LOWER(status)='success'
                              AND left(reference_no,4) NOT IN ('PICK','RTLP','TEST','ZPHE','RETL','9999')
                              AND COALESCE(updated_time,transaction_date) between '2020-10-01 00:00:00' and '2020-11-20 23:59:59'
                              -- AND COALESCE(updated_time,transaction_date) >= CONVERT_TIMEZONE('Asia/Manila', SYSDATE)::date - INTERVAL '1 MONTH'
                              -- AND COALESCE(updated_time,transaction_date) >= CONVERT_TIMEZONE('Asia/Manila', SYSDATE)::date - INTERVAL '1 DAY'
                              -- AND COALESCE(updated_time,transaction_date) >= CONVERT_TIMEZONE('Asia/Manila', SYSDATE)::date - INTERVAL '2 DAY'
                              -- AND COALESCE(updated_time,transaction_date) < CONVERT_TIMEZONE('Asia/Manila', SYSDATE)::date - INTERVAL '1 DAY'
                              AND LOWER(job_master) IN ('delivery','express delivery','rtc_delivery','s_delivery')
                              
                            )

)
, lms_cte as (
SELECT s.tracking_number,
       p.material as package_type_lms,
       s.package_value as package_value_lms,
       p.size as package_size_lms,
       s.collect_amount as actual_amount_lms,
       r.city as delivery_city_lms,
       pr.name as delivery_province_lms,
       d.weight as actual_weight_dim,
       (d.height*d.length*d.width) / (CASE WHEN left(s.tracking_number,4) = '0031' THEN 6000 ELSE 3500 END) as volumetric_weight_dim

FROM lms_db.sales_order s
LEFT JOIN lms_db.recipient r
ON s.recipient_id = r.id
LEFT JOIN lms_db.province pr
ON r.province_id = pr.id
LEFT JOIN lms_db.package_type p
ON s.package_type_id = p.id
LEFT JOIN dimweights d
ON s.tracking_number = d.tracking_number
WHERE s.tracking_number in (SELECT DISTINCT reference_no FROM fzb_cte)
)


SELECT fzb_cte.reference_no,
       fzb_cte.reference_no_clean,
       NULL as client_name,
       BOOL_OR(fzb_cte.for_is_rtc) as "is_rtc",
       MAX(CASE WHEN LOWER(fzb_cte.job_master) IN ('delivery','express delivery','rtc_delivery','s_delivery') THEN fzb_cte.time_stamp ELSE NULL END) as "timestamp",
       MAX(COALESCE(lms_cte.package_type_lms,fzb_cte.package_type)) as "package_type",
       MAX(GREATEST(lms_cte.package_value_lms::varchar,fzb_cte.package_value)) as "package_value",
       MAX(COALESCE(fzb_cte.package_size,lms_cte.package_size_lms)) as "package_size",
       MAX(GREATEST(lms_cte.actual_weight_dim::varchar,fzb_cte.actual_weight)) as "actual_weight",
       MAX(GREATEST(lms_cte.volumetric_weight_dim::varchar,fzb_cte.volumetric_weight)) as "volumetric_weight",
       MAX(GREATEST(lms_cte.actual_amount_lms::varchar,fzb_cte.actual_amount)) as "actual_amount",
       MAX(fzb_cte.money_transaction_type) as "money_transaction_type",
       MAX(CASE WHEN lower(fzb_cte.status) = 'success' THEN fzb_cte.hub ELSE NULL END) as "hub",
       MAX(COALESCE(lms_cte.delivery_city_lms,fzb_cte.delivery_city)) as "delivery_city",
       MAX(COALESCE(lms_cte.delivery_province_lms,fzb_cte.delivery_province)) as "delivery_province",
       BOOL_OR(fzb_cte.for_is_express) as "is_express",
       MAX(CASE WHEN fzb_cte.job_master in ('delivery','express delivery','rtc_delivery','s_delivery') THEN fzb_cte.job_master ELSE NULL END) as "job_master_first",
       TRUE as "is_delivered",
       MAX(fzb_cte.erp_push_time) as "erp_push_time",
       MAX(fzb_cte.longitude) as "longitude",
       MAX(fzb_cte.latitude) as "latitude",
       MIN(fzb_cte.start_date) as "start_date"

FROM  fzb_cte
LEFT JOIN lms_cte
ON fzb_cte.reference_no = lms_cte.tracking_number           
GROUP BY fzb_cte.reference_no, fzb_cte.reference_no_clean
);

BEGIN TRANSACTION;

DELETE FROM finance.revheu_v2
USING temp_revheu_staging
where finance.revheu_v2.reference_no = temp_revheu_staging.reference_no;

INSERT INTO finance.revheu_v2
SELECT * FROM temp_revheu_staging;

END TRANSACTION;

DROP TABLE temp_revheu_staging;

