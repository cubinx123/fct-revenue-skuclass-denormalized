import logging
import os
from os.path import join, dirname
from dotenv import load_dotenv

dotenv_path = join(dirname(__file__), '.env')
load_dotenv(dotenv_path)

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
ch = logging.FileHandler(os.environ.get("LOG_PATH"))
ch.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(name)s - '
                              'p%(process)s {%(pathname)s:%(lineno)d} - %(message)s',
                              datefmt='%Y-%b-%d %H:%M:%S')
#print("something")
ch.setFormatter(formatter)
logger.addHandler(ch)
