import re
def pincode(v:str)->str:
 if not re.fullmatch(r'\d{6}',v): raise ValueError('Pincode must contain six digits')
 return v
def gstin(v:str)->str:
 if not re.fullmatch(r'\d{2}[A-Z0-9]{13}',v): raise ValueError('Invalid GSTIN')
 return v
