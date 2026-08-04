# carolina/backend/utilidades/tiempo.py
from datetime import datetime, timezone, timedelta

BOLIVIA_TZ = timezone(timedelta(hours=-4))


def ahora_bolivia():
    """Hora actual en Bolivia (UTC-4, sin horario de verano) como
    datetime naive, lista para guardar en columnas DateTime."""
    return datetime.now(BOLIVIA_TZ).replace(tzinfo=None)


def hoy_bolivia():
    return ahora_bolivia().date()
