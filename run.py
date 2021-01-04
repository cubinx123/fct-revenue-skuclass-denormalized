import os
import re
import time

from conf.config import views
from utils.writer import Writer
from conf.logging_conf import logger


def run():
	for view in views:
		w = Writer()
		w.drop_create_temp_view(view['view_sql'])


if __name__ == '__main__':
	logger.info("Billing Calculated Table ETL has Started")
	run()
	logger.info("Billing Calculated Table ETL has Ended")
