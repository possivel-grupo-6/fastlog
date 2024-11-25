from src.entity.buy import Buy
from src.infra.db import get_db
from sqlalchemy import text

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

from sqlalchemy.sql import text

def get_buy(code: str):
    try:
        # Obtém a conexão com o banco
        db = get_db()
        
        # Exibe a connection string para debugging
        connection_string = str(db.engine.url)
        print(f"Connection string: {connection_string}")
        
        # Define a query
        query = "SELECT * FROM buy WHERE code = :code;"
        params = {'code': code}
        
        # Executa a consulta
        result = db.execute(text(query), params).fetchone()
        
        # Retorna os dados, se encontrados
        if result:
            return {
                'code': result['code'], 
                'price': result['price'], 
                'cpf': result['cpf'], 
                'product': result['product'], 
                'status': result['status']
            }
        else:
            return None
    except Exception as e:
        # Exibe o erro e retorna a connection string
        print(f"Erro ao executar a consulta: {str(e)}")
        return {"error": str(e), "connection_string": connection_string}
