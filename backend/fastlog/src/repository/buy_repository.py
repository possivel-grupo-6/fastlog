from src.entity.buy import Buy
from src.infra.db import get_db
from sqlalchemy import text
import logging

def save(buy: Buy):
    db = get_db()
    db.add(buy)
    db.commit()
    db.refresh(buy)
    return buy

def delete_data():
    db = get_db()
    table_name = "buy"
    drop_query = f"DELETE FROM {table_name};"
    db.execute(text(drop_query))
    db.commit()
    print(f"Tabela {table_name} limpa com sucesso.")


logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

def get_buy(code: str):
    db = get_db()
    
    # A consulta com bind parameters
    query = "SELECT * FROM buy WHERE code = :code;"
    params = {'code': code}
    
    # Logando a consulta e os parâmetros
    logger.debug("Executando consulta SQL: %s com parâmetros: %s", query, params)
    
    try:
        result = db.execute(text(query), params).fetchone()
        
        # Logando o resultado bruto
        logger.debug("Resultado da consulta: %s", result)
        
        if result:
            buy_data = {
                'code': result['code'], 
                'price': result['price'], 
                'cpf': result['cpf'], 
                'product': result['product'], 
                'status': result['status']
            }
            
            # Logando os dados formatados
            logger.debug("Dados formatados: %s", buy_data)
            
            return buy_data
        else:
            logger.info("Nenhum registro encontrado para code: %s", code)
            return None
    except Exception as e:
        # Logando a exceção com detalhes
        logger.error("Erro ao executar a consulta: %s", str(e), exc_info=True)
        raise