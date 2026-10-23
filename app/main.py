import time
import logging
import threading
from scanner import run_scanner_loop
from bot import run_bot_loop

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s'
)
logger = logging.getLogger("StockCopilotApp")

def main():
    logger.info("==========================================================")
    logger.info("       STOCK COPILOT CONTAINER ENGINE - INITIALIZED       ")
    logger.info("==========================================================")

    # 1. Luồng chạy Scanner ngầm
    t_scanner = threading.Thread(target=run_scanner_loop, name="ScannerThread", daemon=True)
    t_scanner.start()
    logger.info("Scanner thread đã khởi động thành công.")

    # 2. Luồng chạy Interactive Bot Telegram
    t_bot = threading.Thread(target=run_bot_loop, name="BotThread", daemon=True)
    t_bot.start()
    logger.info("Telegram Bot thread đã khởi động thành công.")

    logger.info("Hệ thống Stock Copilot đang lắng nghe và vận hành bình thường.")
    while True:
        time.sleep(1)

if __name__ == "__main__":
    main()