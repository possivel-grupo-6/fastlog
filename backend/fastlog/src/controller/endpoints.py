from fastapi import APIRouter
from src.service.delivery_service import get_buy_by_code

app_endpoint = APIRouter()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permitir todas as origens
    allow_credentials=True,
    allow_methods=["*"],  # Permitir todos os métodos (GET, POST, etc.)
    allow_headers=["*"],  # Permitir todos os cabeçalhos
)

@app_endpoint.get("/buy/{code}")
async def get_buy(code: str):
    return get_buy_by_code(code)