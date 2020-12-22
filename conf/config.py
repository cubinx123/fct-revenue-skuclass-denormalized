import os
from os.path import join, dirname
from dotenv import load_dotenv

dotenv_path = join(dirname(__file__), '.env')
load_dotenv(dotenv_path)

fareye_db = {'username': os.environ.get("DB_USER"),
                  'password': os.environ.get("DB_PASSWORD"),
                  'host': os.environ.get("DB_HOST"),
                  'port': os.environ.get("DB_PORT"),
                  'dbname': os.environ.get("DB_DBNAME")}

views = [{'view_name': 'revheu_table',# Change in .sql
          'view_sql': 'revheu-table.sql'
          }
         ]

aws_config = {
    'aws_access_key' : os.environ.get("AWS_ACCESS_KEY"),
    'aws_secret_key' : os.environ.get("AWS_SECRET_KEY")
    }

