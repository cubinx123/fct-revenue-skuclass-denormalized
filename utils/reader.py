import os


class Reader:
	def __init__(self, filename, filepath='/sql/'):
		absFilePath = os.path.abspath(__file__)
		fileDir = os.path.dirname(os.path.abspath(__file__))
		parentDir = os.path.dirname(fileDir)
		self.path = parentDir + filepath + filename
	
	def read(self):
		if os.path.exists(self.path):
			with open(self.path, 'r') as f:
				return f.read()
		return None