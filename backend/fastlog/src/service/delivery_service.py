from src.entity.buy import Buy
from src.entity.status import StatusEnum
from src.repository.buy_repository import save, get_buy
from src.service.generate import (
    generate_code,
    generate_price,
    generate_cpf,
    generate_product,
    generate_status
)
from datetime import datetime

def save_started_buys():
    test_buy = Buy()
    test_buy.code = 123,
    test_buy.price = 10.00,
    test_buy.cpf = "123.456.789-00",
    test_buy.product = "produto teste",
    test_buy.status = StatusEnum.a_caminho
    save(test_buy)
    print(f"save new buy (((code={test_buy.code} price={test_buy.price:.2f} cpf='{test_buy.cpf}' "
          f"product='{test_buy.product}' status={test_buy.status}))) at {datetime.now()}")

    for i in range(1, 10):        
        buy = Buy()
        buy.code = generate_code(),
        buy.price = generate_price(),
        buy.cpf = generate_cpf(),
        buy.product = generate_product(),
        buy.status = generate_status()
        save(buy)
        print(f"save new buy (((code={buy.code} price={buy.price:.2f} cpf='{buy.cpf}' "
          f"product='{buy.product}' status={buy.status}))) at {datetime.now()}")
        
def get_buy_by_code(code: str):
    return get_buy(code)