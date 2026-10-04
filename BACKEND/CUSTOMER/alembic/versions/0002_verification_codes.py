"""add server-side phone verification codes"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
revision='0002_verification_codes'; down_revision=None; branch_labels=None; depends_on=None

def upgrade():
    bind=op.get_bind()
    exists=bind.execute(sa.text("SELECT to_regclass('public.verification_codes')")).scalar()
    if exists is not None: return
    op.create_table('verification_codes',
        sa.Column('code_id',sa.BigInteger(),sa.Identity(always=True),primary_key=True),
        sa.Column('user_id',sa.BigInteger(),sa.ForeignKey('users.user_id',ondelete='CASCADE'),nullable=False),
        sa.Column('purpose',postgresql.CHAR(1),nullable=False,server_default='P'),
        sa.Column('target',sa.String(255),nullable=False),
        sa.Column('code_hash',sa.String(255),nullable=False),
        sa.Column('attempts',sa.SmallInteger(),nullable=False,server_default='0'),
        sa.Column('expires_at',sa.DateTime(),nullable=False),
        sa.Column('consumed_at',sa.DateTime()),
        sa.Column('created_at',sa.DateTime(),nullable=False,server_default=sa.func.now()),
        sa.CheckConstraint("purpose = 'P'",name='ck_verification_codes_purpose'),
        sa.CheckConstraint('attempts >= 0',name='ck_verification_codes_attempts'),
        sa.CheckConstraint('expires_at > created_at',name='ck_verification_codes_expiry'),
        sa.PrimaryKeyConstraint('code_id',name='pk_verification_codes'),
        sa.ForeignKeyConstraint(['user_id'],['users.user_id'],name='fk_verification_codes_user',ondelete='CASCADE'))
    op.create_index('ix_verification_codes_user_active','verification_codes',['user_id','expires_at'])

def downgrade():
    op.drop_index('ix_verification_codes_user_active',table_name='verification_codes'); op.drop_table('verification_codes')
