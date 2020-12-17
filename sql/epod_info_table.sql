DROP TABLE IF EXISTS finance.test_oop;

CREATE TABLE finance.test_oop as (
select *
from finance.revheu_v1
where left(reference_no,4) = '0018
limit 3000
);
