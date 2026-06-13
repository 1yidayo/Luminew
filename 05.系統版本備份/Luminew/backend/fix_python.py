import codecs
import re

f1 = r'c:\xampp\htdocs\Luminew\Luminew\backend\app\services\InterviewManager.py'
with codecs.open(f1, 'r', 'utf-8') as f:
    text = f.read()

text = re.sub(r'(def submit_did_ice_candidate[^)]*session_id)(\):)', r'\1=None\2', text, flags=re.DOTALL)
text = text.replace('"session_id": session_id', '"session_id": session_id or self.did_session_id')

with codecs.open(f1, 'w', 'utf-8') as f:
    f.write(text)

f2 = r'c:\xampp\htdocs\Luminew\Luminew\backend\app\api\emotion.py'
with codecs.open(f2, 'r', 'utf-8') as f:
    text2 = f.read()

text2 = text2.replace(
    'status = 400 if "No face" in result.get("error", "") else 500', 
    'status = 200 if "No face" in result.get("error", "") else 500'
)

with codecs.open(f2, 'w', 'utf-8') as f:
    f.write(text2)
