from alembic import op
import sqlalchemy as sa
revision='0002_admin_rbac_seed';down_revision='0001_cms';branch_labels=None;depends_on=None
ROLES=[('SUPER_ADMIN','Super Admin'),('INVENTORY_MANAGER','Inventory Manager'),('SALES_MANAGER','Sales Manager'),('CUSTOMER_SUPPORT','Customer Support'),('CONTENT_MANAGER','Content Manager')]
PERMS=['ADMIN_USERS.READ','ADMIN_USERS.WRITE','ROLES.READ','ROLES.WRITE','ROLES.DELETE','PERMISSIONS.READ','PERMISSIONS.WRITE','PERMISSIONS.DELETE','DASHBOARD.READ','PRODUCTS.READ','PRODUCTS.WRITE','PRODUCTS.DELETE','CATEGORIES.READ','CATEGORIES.WRITE','CATEGORIES.DELETE','INVENTORY.READ','INVENTORY.WRITE','INVENTORY.DELETE','ORDERS.READ','ORDERS.WRITE','ORDERS.DELETE','CUSTOMERS.READ','CUSTOMERS.WRITE','CUSTOMERS.DELETE','COUPONS.READ','COUPONS.WRITE','COUPONS.DELETE','BANNERS.READ','BANNERS.WRITE','BANNERS.DELETE','NEWSLETTERS.READ','NEWSLETTERS.WRITE','NEWSLETTERS.DELETE','SHIPPING.READ','SHIPPING.WRITE','SHIPPING.DELETE','DELIVERY.READ','DELIVERY.WRITE','DELIVERY.DELETE','CMS.READ','CMS.WRITE','CMS.DELETE','SETTINGS.READ','SETTINGS.WRITE','SETTINGS.DELETE','ANALYTICS.READ','REPORTS.READ','AUDIT.READ']
def upgrade():
 b=op.get_bind()
 for code,name in ROLES:b.execute(sa.text("INSERT INTO roles(role_code,role_name,role_scope,is_system,is_active) VALUES(:c,:n,'A',true,true) ON CONFLICT(role_code) DO NOTHING"),{'c':code,'n':name})
 for code in PERMS:b.execute(sa.text("INSERT INTO permissions(permission_code,module_name) VALUES(:c,:m) ON CONFLICT(permission_code) DO NOTHING"),{'c':code,'m':code.split('.')[0]})
 # Super Admin gets all current admin permissions.
 stmt=sa.text("INSERT INTO role_permissions(role_id,permission_id) SELECT r.role_id,p.permission_id FROM roles r CROSS JOIN permissions p WHERE r.role_code='SUPER_ADMIN' AND p.permission_code IN :codes ON CONFLICT DO NOTHING").bindparams(sa.bindparam('codes',expanding=True)); b.execute(stmt,{'codes':PERMS})
def downgrade():
 b=op.get_bind()
 b.execute(sa.text("DELETE FROM role_permissions WHERE role_id IN (SELECT role_id FROM roles WHERE role_code IN :codes)").bindparams(sa.bindparam('codes',expanding=True)),{'codes':[r[0] for r in ROLES]})
 b.execute(sa.text("DELETE FROM admin_permissions WHERE permission_id IN (SELECT permission_id FROM permissions WHERE permission_code IN :codes)").bindparams(sa.bindparam('codes',expanding=True)),{'codes':PERMS})
 b.execute(sa.text("DELETE FROM permissions WHERE permission_code IN :codes AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.permission_id=permissions.permission_id) AND NOT EXISTS (SELECT 1 FROM admin_permissions ap WHERE ap.permission_id=permissions.permission_id)").bindparams(sa.bindparam('codes',expanding=True)),{'codes':PERMS})
 b.execute(sa.text("DELETE FROM roles WHERE role_code IN :codes AND is_system=true AND NOT EXISTS (SELECT 1 FROM admin_roles ar WHERE ar.role_id=roles.role_id)").bindparams(sa.bindparam('codes',expanding=True)),{'codes':[r[0] for r in ROLES]})
