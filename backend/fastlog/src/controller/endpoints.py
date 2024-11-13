from fastapi import APIRouter
from src.service.delivery_service import get_buy_by_code

app_endpoint = APIRouter()

@app_endpoint.get("/")
async def get_buy(code: str):
    return get_buy_by_code(code)