insert into demo_system.fct_revenue_skuclass_agg_sampled_git
select * 
from demo_system.fct_revenue_skuclass_agg_sampled
where revcalday::date = CONVERT_TIMEZONE('Asia/Manila', SYSDATE)::date - INTERVAL '101 DAY'