from sqlalchemy import create_engine
import os

DATABASE_URL = "mysql+pymysql://fastlog-user:fastlog-passwd@23.20.132.252:3306/fastlog"

engine = create_engine(DATABASE_URL)
connection = engine.connect()
print("Conexão bem-sucedida!")

