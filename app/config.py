import os

DB_HOST = os.getenv("DB_HOST", "stock-postgres")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "stock_copilot")
DB_USER = os.getenv("DB_USER", "stock_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "stock_password_2026")

TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "8862702138:AAHEUnRXYNdmeSqe7kUQ9n6VMXiI9B_H828")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "6428436481")

AI_BRIDGE_URL = os.getenv("AI_BRIDGE_URL", "http://host.docker.internal:9998")

SCANNER_INTERVAL = int(os.getenv("SCANNER_INTERVAL", "60"))