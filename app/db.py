import time
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
from config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

logger = logging.getLogger("StockDB")

def get_db_connection():
    max_retries = 5
    for attempt in range(max_retries):
        try:
            conn = psycopg2.connect(
                host=DB_HOST,
                port=DB_PORT,
                dbname=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD,
                connect_timeout=10
            )
            conn.autocommit = True
            return conn
        except Exception as e:
            logger.warning(f"Chờ kết nối Database ({attempt+1}/{max_retries}): {e}")
            time.sleep(2)
    raise RuntimeError("Không thể kết nối đến PostgreSQL!")

def get_watchlists(active_only=False):
    sql = "SELECT ticker, company_name, sector, horizon, pivot_price, support_price, resistance_price, catalyst_notes, is_active FROM watchlists"
    if active_only:
        sql += " WHERE is_active = TRUE"
    sql += " ORDER BY ticker;"
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql)
            return cur.fetchall()

def add_watchlist(ticker: str, company_name: str, sector: str):
    ticker = ticker.upper()
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO watchlists (ticker, company_name, sector, is_active)
                VALUES (%s, %s, %s, TRUE)
                ON CONFLICT (ticker) DO UPDATE SET is_active = TRUE, sector = EXCLUDED.sector;
            """, (ticker, company_name, sector))

def remove_watchlist(ticker: str):
    ticker = ticker.upper()
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("UPDATE watchlists SET is_active = FALSE WHERE ticker = %s;", (ticker,))

def get_portfolio_holdings(fund_name: str = None):
    sql = "SELECT fund_name, ticker, company_name, sector, current_qty, avg_buy_price, total_invested, total_realized_sales FROM v_portfolio_holdings"
    params = []
    if fund_name:
        sql += " WHERE fund_name = %s"
        params.append(fund_name)
    sql += " ORDER BY fund_name, total_invested DESC;"
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, tuple(params))
            return cur.fetchall()

def record_trade(fund_name: str, ticker: str, action: str, qty: int, price: float, notes: str = "Telegram NLP"):
    ticker = ticker.upper()
    action = action.upper()
    meta = get_ticker_meta(ticker)
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO watchlists (ticker, company_name, sector)
                VALUES (%s, %s, %s)
                ON CONFLICT (ticker) DO NOTHING;
            """, (ticker, meta['company_name'], meta['sector']))

            cur.execute("""
                INSERT INTO portfolio_transactions (fund_name, ticker, action, quantity, price, notes)
                VALUES (%s, %s, %s, %s, %s, %s) RETURNING id;
            """, (fund_name, ticker, action, qty, price, notes))
            return cur.fetchone()[0]

def undo_last_trade():
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id, fund_name, ticker, action, quantity, price FROM portfolio_transactions ORDER BY id DESC LIMIT 1;")
            last = cur.fetchone()
            if not last:
                return None
            cur.execute("DELETE FROM portfolio_transactions WHERE id = %s;", (last['id'],))
            return last

def update_last_trade_price(new_price: float, ticker: str = None):
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            sql = "SELECT id, ticker, quantity, fund_name FROM portfolio_transactions"
            params = []
            if ticker:
                sql += " WHERE ticker = %s"
                params.append(ticker.upper())
            sql += " ORDER BY id DESC LIMIT 1;"
            cur.execute(sql, tuple(params))
            row = cur.fetchone()
            if not row:
                return None
            cur.execute("UPDATE portfolio_transactions SET price = %s WHERE id = %s;", (new_price, row['id']))
            return row

def update_last_trade_qty(new_qty: int, ticker: str = None):
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            sql = "SELECT id, ticker, price, fund_name FROM portfolio_transactions"
            params = []
            if ticker:
                sql += " WHERE ticker = %s"
                params.append(ticker.upper())
            sql += " ORDER BY id DESC LIMIT 1;"
            cur.execute(sql, tuple(params))
            row = cur.fetchone()
            if not row:
                return None
            cur.execute("UPDATE portfolio_transactions SET quantity = %s WHERE id = %s;", (new_qty, row['id']))
            return row

def get_ticker_meta(ticker: str):
    ticker = ticker.upper()
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT company_name, sector, pivot_price, support_price, resistance_price, catalyst_notes FROM watchlists WHERE ticker = %s;", (ticker,))
            row = cur.fetchone()
            if row:
                return row
    # Fallback sector dictionary
    sectors = {
        "FPT": ("Tập đoàn FPT", "Công nghệ"),
        "HPG": ("Thép Hòa Phát", "Thép"),
        "CTG": ("VietinBank", "Ngân hàng"),
        "MBB": ("Ngân hàng Quân Đội", "Ngân hàng"),
        "SSI": ("Chứng khoán SSI", "Chứng khoán"),
        "VCB": ("Vietcombank", "Ngân hàng"),
        "MWG": ("Thế Giới Di Động", "Bán lẻ"),
        "DGC": ("Hóa chất Đức Giang", "Hóa chất"),
        "TCB": ("Techcombank", "Ngân hàng"),
        "VNM": ("Vinamilk", "Thực phẩm"),
        "FRT": ("Bán lẻ FPT", "Bán lẻ"),
        "VND": ("Chứng khoán VNDIRECT", "Chứng khoán"),
        "VCI": ("Chứng khoán Vietcap", "Chứng khoán"),
        "ACB": ("Ngân hàng Á Châu", "Ngân hàng"),
        "VPB": ("VPBank", "Ngân hàng"),
        "STB": ("Sacombank", "Ngân hàng"),
        "PVS": ("Dịch vụ Dầu khí PVS", "Dầu khí"),
        "PVD": ("Khoan Dầu khí PVD", "Dầu khí"),
        "GAS": ("Tổng công ty Khí", "Dầu khí"),
        "DPM": ("Đạm Phú Mỹ", "Phân bón"),
        "DCM": ("Đạm Cà Mau", "Phân bón"),
        "VHM": ("Vinhomes", "Bất động sản"),
        "VIC": ("Vingroup", "Bất động sản"),
        "KDH": ("Nhà Khang Điền", "Bất động sản")
    }
    name, sec = sectors.get(ticker, (f"Công ty {ticker}", "Khác"))
    return {"company_name": name, "sector": sec, "pivot_price": 0, "support_price": 0, "resistance_price": 0, "catalyst_notes": ""}

def get_f_score(ticker: str) -> int:
    ticker = ticker.upper()
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT f_score FROM financial_reports WHERE ticker = %s ORDER BY year DESC, quarter DESC LIMIT 1;", (ticker,))
            r = cur.fetchone()
            return int(r[0]) if r and r[0] is not None else 8