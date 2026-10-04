from app.utils.money import money

def test_money():
    assert str(money('10.005')) == '10.01'
