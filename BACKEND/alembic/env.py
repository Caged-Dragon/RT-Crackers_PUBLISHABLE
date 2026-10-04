from alembic import context
from sqlalchemy import engine_from_config,pool
from PLATFORM.core.config import settings
from PLATFORM.database.models import Base
config=context.config
config.set_main_option('sqlalchemy.url',settings.DATABASE_URL.replace('%','%%').replace('+asyncpg',''))
target_metadata=Base.metadata
def run_migrations_offline():
    context.configure(url=settings.DATABASE_URL.replace('+asyncpg',''),target_metadata=target_metadata,literal_binds=True,compare_type=True)
    with context.begin_transaction(): context.run_migrations()
def run_migrations_online():
    connectable=engine_from_config(config.get_section(config.config_ini_section),prefix='sqlalchemy.',poolclass=pool.NullPool)
    with connectable.connect() as connection:
        context.configure(connection=connection,target_metadata=target_metadata,compare_type=True)
        with context.begin_transaction(): context.run_migrations()
if context.is_offline_mode(): run_migrations_offline()
else: run_migrations_online()
