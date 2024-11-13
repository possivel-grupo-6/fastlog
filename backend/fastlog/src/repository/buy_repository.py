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

def get_buy(code: str):
    db = get_db()
    query = f"SELECT * FROM buy WHERE code = {code};"
    result = db.execute(text(query), {'code': code}).fetchone()
    if result:
        return {
            'code': result[0], 
            'price': result[1], 
            'cpf': result[2], 
            'product': result[3], 
            'status': result[4]
        }
    else:
        return None