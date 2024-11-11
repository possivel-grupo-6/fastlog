from src.entity.status import StatusEnum

import random

def generate_code():
    return random.randint(0000, 9999)

def generate_price():
    return random.uniform(10.00, 299.99)

def generate_cpf():
    a = random.randint(000, 999)
    b = random.randint(000, 999)
    c = random.randint(000, 999)
    d = random.randint(00, 99)
    return f"{a}.{b}.{c}-{d}"

def generate_product():
    product_list = [
        "Produto 1",
        "Produto 2",
        "Produto 3",
        "Produto 4",
        "Produto 5"
    ]
    return random.choice(product_list)

def generate_status():
    return random.choice(list(StatusEnum))