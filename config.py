# Configuration for Stock Copilot
import os

# PostgreSQL Isolated Instance (Cổng 5434 độc lập)
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5434")),
    "dbname": os.getenv("DB_NAME", "stock_copilot"),
    "user": os.getenv("DB_USER", "stock_user"),
    "password": os.getenv("DB_PASSWORD", "stock_password_2026")
}

# Local AGY Isolated CLI
AGY_CONFIG = {
    "cli_path": os.getenv("AGY_CLI_PATH", r"C:\Users\hieu.pt\AppData\Local\agy\bin\agy.exe"),
    "project": "stock-copilot",   # Tách biệt phiên làm việc
    "effort": "medium",           # Cân bằng tốc độ (10-15s) và chiều sâu lập luận
    "model": "gemini-2.5-flash"   # Phản hồi siêu tốc
}

# Telegram Notifier
TELEGRAM_CONFIG = {
    "bot_token": os.getenv("TELEGRAM_BOT_TOKEN", "8862702138:AAHEUnRXYNdmeSqe7kUQ9n6VMXiI9B_H828"),
    "chat_id": os.getenv("TELEGRAM_CHAT_ID", "6428436481")
}
