DROP TABLE IF EXISTS temp_epod_staging;
CREATE TEMPORARY TABLE temp_epod_staging as (
WITH epod_cte as(
      SELECT reference_no,
             COALESCE(updated_time,transaction_date) as updated_time,
             field_signature,
             phone2,
             client_phone,
             field_receipt_name,
             field_image,
             field_relation_with_customer,
             field_other_relation,
             deliver_address,
             customer_name,
             job_master,
             status
      FROM fareye_zalora_backup
      WHERE reference_no in (
                              SELECT DISTINCT reference_no 
                              FROM fareye_zalora_backup
                              WHERE LOWER(status)='success'
                              AND left(reference_no,4) NOT IN ('PICK','RTLP','TEST','ZPHE','RETL','9999')
                              AND COALESCE(updated_time,transaction_date) >= CONVERT_TIMEZONE('Asia/Manila', SYSDATE)::date - INTERVAL '1 DAY'
                              AND LOWER(job_master) IN ('delivery','express delivery','rtc_delivery','s_delivery')

                            )
)
SELECT e1.reference_no AS "tracking_number",
       MAX(CASE WHEN lower(e1.job_master) = 's_delivery'
                THEN 'secondary_delivery'
                ELSE 'delivery'  
           END) AS "direction",
       MAX(e1.updated_time) AS "updated_time",
       NULL AS customer_id, --join on customer table
       max(e2.customer_name) as "customer_name", 
       MAX(e1.field_receipt_name) AS "recipient_name",
       MAX(e1.field_signature) AS "recipient_signature",
       MAX(COALESCE(e1.phone2,e1.client_phone)) AS "customer_phone_no",
       MAX(e1.field_image),
       MAX(e1.field_relation_with_customer) AS "relation_with_customer",
       MAX(e1.field_other_relation) AS "other_relation",
       MAX(e2.delivery_address) AS "delivery_address"
FROM  epod_cte e1
LEFT JOIN (
            SELECT 
               reference_no,
               deliver_address AS "delivery_address",
               customer_name
            FROM 
                 (
                   SELECT 
                       ROW_NUMBER() OVER (PARTITION BY reference_no ORDER BY LEN(deliver_address) DESC, LEN(customer_name) DESC) AS "rn",
                       reference_no,
                       deliver_address,
                       customer_name
                   FROM epod_cte)
                   WHERE rn = 1
                 ) e2
ON e1.reference_no = e2.reference_no             
GROUP BY e1.reference_no
);

BEGIN TRANSACTION;

DELETE FROM staging.ft_fwd_pod
USING temp_epod_staging
where staging.ft_fwd_pod.tracking_number = temp_epod_staging.tracking_number;

INSERT INTO staging.ft_fwd_pod
SELECT * FROM temp_epod_staging;

END TRANSACTION;

DROP TABLE temp_epod_staging;

