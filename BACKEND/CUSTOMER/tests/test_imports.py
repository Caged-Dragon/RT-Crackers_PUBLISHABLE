def test_application_imports(monkeypatch):
    monkeypatch.setenv("DATABASE_URL","postgresql://postgres:password@example.com:5432/postgres")
    monkeypatch.setenv("JWT_SECRET_KEY","x"*48)
    import main
    assert main.app.title == "RTCrackers API"
