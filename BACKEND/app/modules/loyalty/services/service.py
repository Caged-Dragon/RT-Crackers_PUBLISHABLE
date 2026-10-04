from sqlalchemy import select
from ....database.models import LoyaltyAccount,LoyaltyLedger
async def account(db,user_id):
 a=await db.get(LoyaltyAccount,user_id)
 if not a:a=LoyaltyAccount(user_id=user_id); db.add(a); await db.flush()
 return a
async def earn(db,user,b):
 a=await account(db,user['user_id']); a.points_balance+=b.points; a.lifetime_earned+=b.points; a.tier='GOLD' if a.lifetime_earned>=5000 else ('SILVER' if a.lifetime_earned>=1500 else 'BRONZE'); db.add(LoyaltyLedger(user_id=a.user_id,points=b.points,transaction_type=b.transaction_type,reference_type='order',reference_id=b.reference_id,description=b.description)); await db.commit(); return a
async def redeem(db,user,points):
 a=await account(db,user['user_id']);
 if a.points_balance<points: raise ValueError('Insufficient points')
 a.points_balance-=points; db.add(LoyaltyLedger(user_id=a.user_id,points=-points,transaction_type='redeem',description='Points redemption')); await db.commit(); return a
