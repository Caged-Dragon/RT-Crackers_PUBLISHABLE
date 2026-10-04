from sqlalchemy import select
from ADMINS.cms.models import CMSPage,CMSHomeSection,CMSMenu,CMSMenuItem,CMSFooterLink,CMSFAQ,CMSPolicy
MODELS={'pages':CMSPage,'home-sections':CMSHomeSection,'menus':CMSMenu,'menu-items':CMSMenuItem,'footer-links':CMSFooterLink,'faqs':CMSFAQ,'policies':CMSPolicy}
