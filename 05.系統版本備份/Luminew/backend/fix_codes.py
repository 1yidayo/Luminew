import os
import sys
import random
import string
sys.path.append(os.getcwd())
from app.database.db import execute_read, execute_write

res = execute_read("SELECT UserID, TeacherCode FROM Users WHERE Role = 'teacher' AND TeacherCode IS NOT NULL")
for row in res:
    code = row.get("TeacherCode", "")
    if any(c.isalpha() for c in code):
        new_code = ''.join(random.choices(string.digits, k=6))
        execute_write(f"UPDATE Users SET TeacherCode = '{new_code}' WHERE UserID = {row['UserID']}")
        print(f"Updated Teacher {row['UserID']} code from {code} to {new_code}")
