#暫時用不到 沒有在維護
# llm.py
from fastapi import APIRouter
from pydantic import BaseModel
from app.services.openai_llm import ask_gpt4_1_nano

router = APIRouter()

# API request schema
class LLMRequest(BaseModel):
    conversation_history: list  # 每個元素：{"role": "user"/"assistant"/"system", "content": str}
    professor_type: str = "warm_industry_professor"

# API response schema
class LLMResponse(BaseModel):
    reply: str

@router.post("/chat", response_model=LLMResponse)
def chat(request: LLMRequest):
    # 呼叫 GPT，傳整段對話歷史
    reply = ask_gpt4_1_nano(request.conversation_history, request.professor_type)
    return {"reply": reply}