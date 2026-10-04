import pytest

@pytest.mark.asyncio
async def test_health_function_exists(monkeypatch):
    monkeypatch.setenv("DATABASE_URL","postgresql://postgres:password@example.com:5432/postgres")
    monkeypatch.setenv("JWT_SECRET_KEY","x"*48)
    import main
    assert callable(main.health)
