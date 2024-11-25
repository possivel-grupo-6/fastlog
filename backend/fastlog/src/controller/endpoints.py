from fastapi import FastAPI, APIRouter
from src.service.delivery_service import get_buy_by_code
from fastapi.middleware.cors import CORSMiddleware

# Criação da instância do FastAPI
app = FastAPI()

# Configurar CORS para permitir acesso de qualquer origem
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite qualquer origem, você pode restringir para um domínio específico
    allow_credentials=True,
    allow_methods=["*"],  # Permite qualquer método (GET, POST, etc.)
    allow_headers=["*"],  # Permite qualquer cabeçalho
)

# Definição do Router
app_endpoint = APIRouter()

@app_endpoint.get("/buy/{code}")
async def get_buy(code: str):
    return get_buy_by_code(code)

# Incluindo o Router no FastAPI
app.include_router(app_endpoint)
