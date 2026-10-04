from ADMINS.base import Schema
class AnalyticsQuery(Schema): start_date:str|None=None; end_date:str|None=None; group_by:str="day"
