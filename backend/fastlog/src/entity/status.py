from enum import Enum

class StatusEnum(str, Enum):
    aguardando_envio = "aguardando envio"
    preparacao = "preparacao"
    coletada_pela_transportadora = "coletada pela transportadora"
    a_caminho = "a caminho"
    rota_de_entrega = "rota de entrega"
    entregue = "entregue"   