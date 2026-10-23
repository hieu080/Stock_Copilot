import requests
import logging

logger = logging.getLogger("TelegramNotifier")

def send_flash_alert(ticker: str, price: float, vol_ratio: float, f_score: int, bot_token: str = "", chat_id: str = ""):
    """
    TẦNG 1: Bắn cảnh báo chớp nhoáng dưới 1 giây.
    """
    message = (
        f"⚡ <b>[FLASH ALERT: {ticker}]</b>\n"
        f"Giá hiện tại: <b>{price:,.0f} VND</b>\n"
        f"Khối lượng nổ: <b>{vol_ratio:.1f}x MA20</b> | F-Score: <b>{f_score}/9</b>\n"
        f"⏳ <i>agy đang thẩm định và tạo bài lập luận chi tiết...</i>"
    )
    return _send_telegram(message, bot_token, chat_id)

def send_deep_thesis(thesis_content: str, bot_token: str = "", chat_id: str = ""):
    """
    TẦNG 2: Gửi bài lập luận chuyên sâu đa chiều.
    """
    # Thay đổi ký tự đặc biệt cho Telegram HTML
    clean_text = f"📋 <b>BẢN LẬP LUẬN ĐẦU TƯ TOÀN DIỆN</b>\n\n{thesis_content}"
    return _send_telegram(clean_text, bot_token, chat_id)

def _send_telegram(message: str, bot_token: str, chat_id: str):
    if not bot_token or not chat_id:
        print("\n" + "="*60)
        print("[MÔ PHỎNG TELEGRAM / CONSOLE OUTPUT]:")
        print(message)
        print("="*60 + "\n")
        return True

    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": message,
        "parse_mode": "HTML"
    }
    try:
        resp = requests.post(url, json=payload, timeout=10)
        return resp.status_code == 200
    except Exception as e:
        logger.error(f"Lỗi gửi Telegram: {e}")
        return False
