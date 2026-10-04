from typing import Generator

import psycopg
from psycopg.rows import dict_row

from .config import get_settings


def get_db() -> Generator[psycopg.Connection, None, None]:
    settings = get_settings()
    with psycopg.connect(settings.database_url, row_factory=dict_row) as conn:
        yield conn
