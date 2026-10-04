def test_import(monkeypatch):
 monkeypatch.setenv("DATABASE_URL","postgresql://postgres:password@example.com:5432/postgres")
 monkeypatch.setenv("JWT_SECRET_KEY","x"*48)
 import main
 assert main.app.title=="RTCrackers Admin API"
