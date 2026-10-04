import asyncio, sys
sys.path.insert(0, '/home/claude/backend')
from sqlalchemy import text
from core.database import Base, engine, import_all_models
import_all_models()
for extra in ("customers.checkout", ):
    pass
async def main():
    async with engine.connect() as c:
        rows = (await c.execute(text("""select table_name, column_name, is_nullable, data_type, is_generated, column_default
                                          from information_schema.columns where table_schema='public'"""))).all()
    db = {}
    for t, col, nul, dt, gen, d in rows:
        db.setdefault(t, {})[col] = (nul == 'YES', dt, gen == 'ALWAYS', d)
    problems = 0
    for tname, table in sorted(Base.metadata.tables.items()):
        if tname not in db:
            print(f"MISSING TABLE  {tname}"); problems += 1; continue
        for col in table.columns:
            if col.name not in db[tname]:
                print(f"MISSING COLUMN {tname}.{col.name}"); problems += 1
        mapped = {c.name for c in table.columns}
        extra = [c for c in db[tname] if c not in mapped]
        # NOT NULL columns without default that the model doesn't map would break INSERTs
        bad = [c for c in extra if not db[tname][c][0] and db[tname][c][3] is None and not db[tname][c][2]]
        if bad:
            print(f"UNMAPPED REQUIRED {tname}: {bad}"); problems += 1
    print("tables mapped:", len(Base.metadata.tables), "problems:", problems)
asyncio.run(main())
