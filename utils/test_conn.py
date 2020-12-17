from conf.config import fareye_db as conn_string


def test():
	print(conn_string['host'])
	print(conn_string['port'])
	print(conn_string['dbname'])
	print(conn_string['username'])
	print(conn_string['password'])