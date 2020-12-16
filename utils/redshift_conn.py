import psycopg2 as p
import sys
from conf.config import fareye_db as conn_string
from psycopg2 import OperationalError, errorcodes, errors
from conf.logging_conf import logger


class RedshiftConn:
	def __init__(self):
		self.conn = None
		self.cur = None
		self.set_conn()
		self.set_cursor()
	
	def set_conn(self):
		# self.conn = p.connect(host=conn_string['host'], port=conn_string['port'], database=conn_string['dbname'], user=conn_string['username'], password=conn_string['password'])

		try:
			self.conn = p.connect("host='fareye-cluster.c1um01vbpg6h.ap-southeast-1.redshift.amazonaws.com' dbname='fareye' user='lester_paja' password='5oSqOXLp' port ='5439'")
			# self.conn = p.connect(host=conn_string['host'], port=conn_string['port'], database=conn_string['dbname'],
			# 				  user=conn_string['username'], password=conn_string['password'])
		except OperationalError as err:
			# self.print_psycopg2_exception(err)
			# self.conn = None
			return print('conn failed')
		
	def get_conn(self):
		return self.conn
	
	def set_cursor(self):
		self.cur = self.conn.cursor()
	
	def get_cursor(self):
		return self.cur

	# def print_psycopg2_exception(self,err):
	# 	# get details about the exception
	# 	err_type, err_obj, traceback = sys.exc_info()

	# 	# get the line number when exception occured
	# 	line_num = traceback.tb_lineno

	# 	# print the connect() error
	# 	logger.info("psycopg2 ERROR: {0} on line number: {1}".format(err,line_num))
	# 	logger.info("psycopg2 traceback: {0} --type: {1}".format(traceback,err_type))

	# 	# print the pgcode and pgerror exceptions
	# 	logger.info("pgerror: {0}".format(err.pgerror))
	# 	logger.info("pgcode: {0}".format(err.pgcode))

	# 	message = """orders-daily-etl
	# 				 psycopg2 ERROR: {0} on line number: {1}
	# 				 psycopg2 traceback: {2} --type: {3}
	# 				 pgerror: {4}
	# 				 pgcode: {5}
	# 	""".format(err,line_num,traceback,err_type,err.pgerror,err.pgcode)

	# 	notification = Notification()

	# 	sns_response = notification.send(message)
	# 	logger.info("SNS Response: {0}".format(sns_response))
