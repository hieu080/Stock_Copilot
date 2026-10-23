import time
import json
import logging
import datetime
import urllib.request
from config import TELEGRAM_TOKEN, TELEGRAM_CHAT_ID, SCANNER_INTERVAL
from db import get_watchlists, get_portfolio_holdings
from market_data import get_intraday_data, get_live_price

logger = logging.getLogger("Scanner")

alerted_today = {}
last_report_date = ""

def send_telegram(text: str):
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    payload = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": text,
        "parse_mode": "HTML"
    }
    data = json.dumps(payload, ensure_ascii=False).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json; charset=utf-8"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            pass
    except Exception as e:
        logger.error(f"Lỗi gửi Telegram từ scanner: {e}")

def detect_candle_pattern(day_open, day_high, day_low, day_close, prev_open, prev_close, vol_surge_ratio):
    body = abs(day_close - day_open)
    lower_shadow = min(day_open, day_close) - day_low
    upper_shadow = day_high - max(day_open, day_close)
    change_pct = round(((day_close - prev_close) / prev_close) * 100, 2) if prev_close > 0 else 0.0

    # 1. Bullish Signals
    if lower_shadow >= (1.8 * body) and upper_shadow <= (0.3 * body) and day_close >= day_open and vol_surge_ratio >= 1.2:
        return {
            "name": "Nến Búa Rút Chân (Bullish Hammer)",
            "trend": "TĂNG GIÁ",
            "icon": "🟢 🚀 TÍN HIỆU TĂNG GIÁ",
            "desc": "Lực cầu gom hàng quyết liệt ở vùng đáy, đạp rũ cung thành công và kéo giá đóng cửa sát mức cao nhất."
        }
    if day_close > day_open and prev_close < prev_open and day_close >= prev_open and day_open <= prev_close and vol_surge_ratio >= 1.3:
        return {
            "name": "Nến Nhấn Chìm Tăng (Bullish Engulfing)",
            "trend": "TĂNG GIÁ",
            "icon": "🟢 🚀 TÍN HIỆU TĂNG GIÁ",
            "desc": "Thân nến xanh hôm nay bao trùm hoàn toàn nến đỏ trước đó, phe Mua giành lại quyền kiểm soát tuyệt đối."
        }
    if change_pct >= 3.0 and vol_surge_ratio >= 2.0 and day_close >= (day_high * 0.985):
        return {
            "name": "Nến Marubozu Bùng Nổ Dòng Tiền (Breakout)",
            "trend": "TĂNG GIÁ",
            "icon": "🟢 🚀 TÍN HIỆU TĂNG GIÁ",
            "desc": f"Dòng tiền tổ chức đánh dứt khoát (+{change_pct}%), khớp lệnh gấp {vol_surge_ratio:.1f}x MA20, xác nhận vào sóng."
        }

    # 2. Bearish Signals
    if upper_shadow >= (1.8 * body) and lower_shadow <= (0.3 * body) and day_close <= day_open and vol_surge_ratio >= 1.2:
        return {
            "name": "Nến Sao Băng / Búa Ngược (Shooting Star)",
            "trend": "GIẢM GIÁ",
            "icon": "🔴 ⚠️ TÍN HIỆU GIẢM GIÁ (RỦI RO)",
            "desc": "Bị ép bán xả mạnh ở vùng giá cao, phe Mua thất bại trong việc giữ nền, nguy cơ điều chỉnh ngắn hạn."
        }
    if day_close < day_open and prev_close > prev_open and day_open >= prev_close and day_close <= prev_open and vol_surge_ratio >= 1.3:
        return {
            "name": "Nến Nhấn Chìm Giảm (Bearish Engulfing)",
            "trend": "GIẢM GIÁ",
            "icon": "🔴 ⚠️ TÍN HIỆU GIẢM GIÁ (RỦI RO)",
            "desc": "Thân nến đỏ bao trùm hoàn toàn nến xanh trước đó, phe Bán kiểm soát thế trận, rủi ro đảo chiều giảm."
        }
    if change_pct <= -2.8 and vol_surge_ratio >= 1.5:
        return {
            "name": "Nến Xả Lực Bán Đột Biến (Distribution)",
            "trend": "GIẢM GIÁ",
            "icon": "🔴 ⚠️ TÍN HIỆU GIẢM GIÁ (RỦI RO)",
            "desc": f"Áp lực bán tháo quyết liệt ({change_pct}%), thanh khoản tăng {vol_surge_ratio:.1f}x MA20, khuyến nghị thận trọng."
        }

    return None

def send_daily_close_report():
    global last_report_date
    today_str = datetime.date.today().strftime("%Y-%m-%d")
    if last_report_date == today_str:
        return
    last_report_date = today_str

    holdings = get_portfolio_holdings()
    if not holdings:
        return

    fund_map = {}
    grand_val = 0.0
    grand_cost = 0.0

    for h in holdings:
        f = h['fund_name']
        tk = h['ticker']
        qty = int(h['current_qty'])
        avg_cost = float(h['avg_buy_price'])
        invested = float(h['total_invested'])

        live = get_live_price(tk)
        if live <= 0: live = avg_cost
        cur_val = qty * live
        pnl_val = cur_val - invested
        pnl_pct = round((pnl_val / invested) * 100, 2) if invested > 0 else 0.0

        grand_cost += invested
        grand_val += cur_val

        if f not in fund_map:
            fund_map[f] = {"cost": 0.0, "val": 0.0, "items": []}
        fund_map[f]["cost"] += invested
        fund_map[f]["val"] += cur_val
        fund_map[f]["items"].append({
            "ticker": tk,
            "qty": qty,
            "avg_cost": avg_cost,
            "live": live,
            "val": cur_val,
            "pnl": pnl_val,
            "pct": pnl_pct
        })

    grand_pnl = grand_val - grand_cost
    grand_pct = round((grand_pnl / grand_cost) * 100, 2) if grand_cost > 0 else 0.0
    g_icon = "🟢 +" if grand_pnl >= 0 else "🔴 "

    body = ""
    for f_name, f_data in fund_map.items():
        f_pnl = f_data["val"] - f_data["cost"]
        f_pct = round((f_pnl / f_data["cost"]) * 100, 2) if f_data["cost"] > 0 else 0.0
        f_icon = "🟢 +" if f_pnl >= 0 else "🔴 "
        body += f"🏛️ <b>QUỸ {f_name.upper()}:</b>\n"
        body += f"  • Tổng giá trị: <b>{f_data['val']:,.0f} đ</b> | Lời/Lỗ: <b>{f_icon}{f_pnl:,.0f} đ ({f_pct}%)</b>\n"
        for it in f_data["items"]:
            p_icon = "🟢 +" if it['pnl'] >= 0 else "🔴 "
            body += f"    ▫️ <b>{it['ticker']}</b>: {it['qty']} cp @ {it['live']:,.0f} đ (Vốn: {it['avg_cost']:,.0f} đ)\n"
            body += f"       ➔ {it['val']:,.0f} đ ({p_icon}{it['pnl']:,.0f} đ | {it['pct']}%)\n"
        body += "\n"

    report_msg = (
        f"📊 <b>BÁO CÁO TỔNG KẾT TÀI SẢN CHỐT PHIÊN ({today_str})</b>\n"
        f"─────────────────────\n"
        f"💰 <b>TỔNG TÀI SẢN:</b> <b>{grand_val:,.0f} VND</b>\n"
        f"💵 <b>Tổng vốn đầu tư:</b> {grand_cost:,.0f} VND\n"
        f"📈 <b>Tổng Lời / Lỗ:</b> {g_icon}{grand_pnl:,.0f} VND (<b>{grand_pct}%</b>)\n\n"
        f"{body}"
        f"💡 <i>Báo cáo định kỳ lúc 15:00 sau giờ chốt phiên sàn HOSE!</i>"
    )
    send_telegram(report_msg)

def run_scanner_loop():
    logger.info("Khởi chạy vòng lặp Scanner thị trường...")
    while True:
        try:
            now = datetime.datetime.now()
            today_str = now.strftime("%Y-%m-%d")

            # Check 15:00 close report (chỉ chạy từ 15:00 đến 15:05 vào ngày trong tuần)
            if now.weekday() < 5 and now.hour == 15 and now.minute <= 5:
                send_daily_close_report()

            # Quét danh sách 24 mã
            watchlists = get_watchlists(active_only=True)
            for item in watchlists:
                tk = item['ticker']
                c_name = item['company_name']
                data = get_intraday_data(tk)
                if not data:
                    continue

                ma20_vol = data.get('ma20_vol', 1000000)
                vol_surge = round(data['total_vol'] / ma20_vol, 2) if ma20_vol > 0 else 1.0

                pattern = detect_candle_pattern(
                    data['day_open'], data['day_high'], data['day_low'], data['day_close'],
                    data['prev_open'], data['prev_close'], vol_surge
                )

                if pattern:
                    alert_key = f"{today_str}_{tk}_{pattern['name']}"
                    if alert_key not in alerted_today:
                        alerted_today[alert_key] = True
                        chg_pct = round(((data['day_close'] - data['prev_close']) / data['prev_close']) * 100, 2) if data['prev_close'] > 0 else 0.0
                        msg = (
                            f"{pattern['icon']}: <b>{tk}</b> ({c_name})\n"
                            f"─────────────────────\n"
                            f"• Mẫu hình nến: <b>{pattern['name']}</b>\n"
                            f"• Xu hướng dự báo: <b>{pattern['trend']}</b>\n"
                            f"• Thị giá realtime: <b>{data['day_close']:,.0f} VND</b> ({'+' if chg_pct>=0 else ''}{chg_pct}%)\n"
                            f"• Khối lượng phiên: <b>{data['total_vol']:,} cp</b> (Đạt <b>{vol_surge:.1f}x MA20</b>)\n"
                            f"• Ý nghĩa kỹ thuật: {pattern['desc']}\n\n"
                            f"💡 <i>Nhắn tin: <b>'Phân tích chuyên sâu {tk}'</b> để lập chiến thuật chi tiết!</i>"
                        )
                        send_telegram(msg)
                        logger.info(f"Đã phát tín hiệu nến cho {tk}: {pattern['name']}")

        except Exception as e:
            logger.error(f"Lỗi trong vòng quét: {e}")

        time.sleep(SCANNER_INTERVAL)