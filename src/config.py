from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    """
    Configurações da aplicação carregadas a partir de variáveis de ambiente ou arquivo .env.
    NUNCA defina valores sensíveis diretamente aqui em produção.
    """
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # JWT
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_expiry_seconds: int = 3600

    # Rate Limiting
    rate_limit_requests_per_minute: int = 60

    # App
    app_title: str = "S.F.C.P.C - Systema de Gerenciamento"
    app_version: str = "0.1.0"
    environment: str = "development"  # development | staging | production


@lru_cache
def get_settings() -> Settings:
    return Settings()
