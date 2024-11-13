from sqlalchemy import Column, Integer, String, DECIMAL
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Buy(Base):
    __tablename__ = 'buy'
    
    code = Column(Integer, primary_key=True, autoincrement=True)
    price = Column(DECIMAL(10, 2), nullable=False)
    cpf = Column(String(14), nullable=False)
    product = Column(String(255), nullable=False)
    status = Column(String(255), nullable=False)