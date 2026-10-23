import json
import logging
import urllib.request
from config import AI_BRIDGE_URL

logger = logging.getLogger("AIClient")

def call_conversational_ai(user_message: str, portfolio_context: str, chat_history: list) -> str:
    payload = {
        "message": user_message,
        "portfolio_context": portfolio_context,
        "history": chat_history
    }
    data_bytes = json.dumps(payload, ensure_ascii=False).encode('utf-8')
    url = f"{AI_BRIDGE_URL}/chat"
    req = urllib.request.Request(
        url,
        data=data_bytes,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=40) as resp:
            resp_data = json.loads(resp.read().decode('utf-8'))
            reply = resp_data.get("reply", "")
            if reply:
                return reply
    except Exception as e:
        logger.error(f"Lỗi kết nối tới AI Host Bridge ({url}): {e}")
        return (
            "⚠️ <b>STOCK COPILOT AI THÔNG BÁO:</b>\n"
            "Chưa kết nối được với AI Host Bridge trên máy chủ Host.\n"
            "💡 <i>Vui lòng đảm bảo tiến trình `stock_ai_bridge.ps1` đang chạy trên cổng 9998!</i>"
        )
    return "Không nhận được phản hồi từ AI."