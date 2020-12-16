from utils.reader import Reader
from utils.redshift_conn import RedshiftConn


class Writer:
	def __init__(self, sheet=None, view=None):
		self.sheet_table = None
		self.table_pri = None
		self.sheet = sheet
		self.view = view
		self.rc = RedshiftConn()
	
	def initialize_sheet(self):
		self.sheet_table = self.sheet['sheet_table']
		self.table_pri = self.sheet['pri_col']
	
	def exe(self, data):
		try:
			self.rc.get_cursor().execute(data)
			self.rc.get_conn().commit()
		except Exception as err:
			# self.rc.print_psycopg2_exception(err)
			pass

	def drop_create_temp_view(self, view_sql):
		sql = Reader(view_sql).read()
		self.exe(sql)
