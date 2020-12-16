import os
import pandas as pd

filename = 'lester'
filepath='/sql/'
absFilePath = os.path.abspath(__file__)
fileDir = os.path.dirname(os.path.abspath(__file__))
parentDir = os.path.dirname(fileDir)
path = parentDir + filepath + filename
print("absFilePath = os.path.abspath(__file__) :" + absFilePath  )
print("fileDir = os.path.dirname(os.path.abspath(__file__)) :" + fileDir )
print("parentDir = os.path.dirname(fileDir) :" + parentDir)
print("path = parentDir + filepath + filename :" + path)

df = pd.DataFrame({'A':[1,2,3]})
df.to_csv(parentDir+filepath+"test.csv",index=False)
print("DF successfully created")