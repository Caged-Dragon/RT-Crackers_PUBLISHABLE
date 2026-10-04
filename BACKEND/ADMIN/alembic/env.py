from logging.config import fileConfig
from alembic import context
from sqlalchemy import engine_from_config,pool
from core.config import settings
config=context.config
if config.config_file_name:fileConfig(config.config_file_name)
from ADMINS.auth.models import *
from ADMINS.roles.models import *
from ADMINS.permissions.models import *
from ADMINS.cms.models import *
from ADMINS.settings.models import *
target_metadata=__import__('core.database',fromlist=['Base']).Base.metadata
def run_migrations_offline():
 context.configure(url=str(settings.sync_database_url),target_metadata=target_metadata,literal_binds=True,compare_type=True)
 with context.begin_transaction():context.run_migrations()
def run_migrations_online():
 e=engine_from_config({'sqlalchemy.url':str(settings.sync_database_url)},prefix='sqlalchemy.',poolclass=pool.NullPool)
 with e.connect() as c:
  context.configure(connection=c,target_metadata=target_metadata,compare_type=True)
  with context.begin_transaction():context.run_migrations()
if context.is_offline_mode():run_migrations_offline()
else:run_migrations_online()
