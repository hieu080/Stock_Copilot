import time
import json
import logging
import urllib.request
from typing import Dict, Any, Optional

logger = logging.getLogger("MarketData")

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}

def get_live_price(ticker: str) -> float:
    ticker = ticker.upper()
    now_ts = int(time.time())
    start_daily = now_ts - (15 * 86400)
    url = f"https://services.entrade.com.vn/chart-api/v2/ohlcs/stock?from={start_daily}&to={now_ts}&symbol={ticker}&resolution=1D"
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            if data and "c" in data and len(data["c"]) > 0:
                raw_c = float(data["c"][-1])
                return (raw_c * 1000) if raw_c < 1000 else raw_c
    except Exception as e:
        logger.warning(f"Lỗi lấy giá {ticker}: {e}")
    return 0.0

def get_intraday_data(ticker: str) -> Optional[Dict[str, Any]]:
    ticker = ticker.upper()
    now_ts = int(time.time())
    past_intraday = now_ts - (4 * 3600)
    past_daily = now_ts - (40 * 86400)

    # 1. Fetch Daily to get prev_open, prev_close and ma20
    url_daily = f"https://services.entrade.com.vn/chart-api/v2/ohlcs/stock?from={past_daily}&to={now_ts}&symbol={ticker}&resolution=1D"
    try:
        req_d = urllib.request.Request(url_daily, headers=HEADERS)
        with urllib.request.urlopen(req_d, timeout=8) as resp:
            data_d = json.loads(resp.read().decode('utf-8'))
    except Exception as e:
        logger.warning(f"Lỗi daily {ticker}: {e}")
        return None

    if not data_d or "c" not in data_d or len(data_d["c"]) < 3:
        return None

    cnt = len(data_d["c"])
    prev_close = float(data_d["c"][-2]) * 1000 if float(data_d["c"][-2]) < 1000 else float(data_d["c"][-2])
    prev_open = float(data_d["o"][-2]) * 1000 if float(data_d["o"][-2]) < 1000 else float(data_d["o"][-2])

    v_slice = data_d["v"][max(0, cnt-22):cnt-1]
    ma20_vol = int(sum(v_slice) / len(v_slice)) if v_slice else 1000000

    # 2. Fetch Live Intraday
    url_live = f"https://services.entrade.com.vn/chart-api/v2/ohlcs/stock?from={past_intraday}&to={now_ts}&symbol={ticker}&resolution=1"
    try:
        req_l = urllib.request.Request(url_live, headers=HEADERS)
        with urllib.request.urlopen(req_l, timeout=8) as resp:
            data_l = json.loads(resp.read().decode('utf-8'))
    except Exception as e:
        logger.warning(f"Lỗi live intraday {ticker}: {e}")
        return None

    if not data_l or "c" not in data_l or len(data_l["c"]) == 0:
        return None

    closes = [float(x) * 1000 if float(x) < 1000 else float(x) for x in data_l["c"]]
    opens = [float(x) * 1000 if float(x) < 1000 else float(x) for x in data_l.get("o", closes)]
    highs = [float(x) * 1000 if float(x) < 1000 else float(x) for x in data_l.get("h", closes)]
    lows = [float(x) * 1000 if float(x) < 1000 else float(x) for x in data_l.get("l", closes)]
    vols = [int(x) for x in data_l.get("v", [0] * len(closes))]

    day_open = opens[0]
    day_close = closes[-1]
    day_high = max(highs)
    day_low = min(lows)
    total_vol = sum(vols)

    return {
        "day_open": day_open,
        "day_close": day_close,
        "day_high": day_high,
        "day_low": day_low,
        "total_vol": total_vol,
        "prev_open": prev_open,
        "prev_close": prev_close,
        "ma20_vol": ma20_vol
    }