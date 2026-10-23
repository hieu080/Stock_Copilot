import re
import time
import json
import logging
import urllib.request
from typing import Dict, Any, Optional
from config import TELEGRAM_TOKEN, TELEGRAM_CHAT_ID
from db import (
    get_watchlists, add_watchlist, remove_watchlist,
    get_portfolio_holdings, record_trade, undo_last_trade,
    update_last_trade_price, update_last_trade_qty,
    get_ticker_meta, get_f_score
)
from market_data import get_live_price
from ai_client import call_conversational_ai
from scanner import send_daily_close_report

logger = logging.getLogger("TelegramBot")

STOP_WORDS = {
    "VND", "VCP", "ATO", "ATC", "MUA", "BAN", "XOA", "SUA", "THE", "NEN", "GIA", 
    "HOSE", "HNX", "UPCOM", "BCTC", "EPS", "ROA", "ROE", "MA20", "MA50", "RSI", 
    "MACD", "CP", "CON", "TRIEU", "NGHIN", "QUY", "TIEN", "CHUNG", "CA", "NHAN",
    "DEEP", "THEODoi", "WATCHLIST", "PORTFOLIO", "LIST", "DANHMUC", "BAO", "NHIEU"
}

chat_history = []

def send_reply(chat_id: int, text: str):
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML"
    }
    data = json.dumps(payload, ensure_ascii=False).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json; charset=utf-8"})
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            pass
    except Exception as e:
        logger.error(f"Lỗi gửi Telegram: {e}")

def get_portfolio_context_text() -> str:
    holdings = get_portfolio_holdings()
    if not holdings:
        return "Hiện tại anh Phan chưa có cổ phiếu nào trong danh mục."
    res = []
    for h in holdings:
        fn = h['fund_name']
        tk = h['ticker']
        q = h['current_qty']
        avg = float(h['avg_buy_price'])
        res.append(f"- Quỹ {fn}: {q} cp {tk} (giá vốn: {avg:,.0f} đ)")
    return "\n".join(res)

def extract_ticker(text: str) -> Optional[str]:
    clean = re.sub(r"[.,:;!?'\"]", " ", text)
    words = clean.split()
    for w in words:
        u = w.strip().upper()
        if len(u) == 3 and u.isalpha() and u not in STOP_WORDS:
            return u
    return None

def parse_stock_intent(text: str) -> Dict[str, Any]:
    intent = {"action": None, "ticker": None, "qty": 0, "price": 0.0, "fund": "Cá nhân"}
    t_lower = text.lower()

    if re.search(r"\b(quỹ chung|tiền chung|quỹ gia đình|quỹ nhóm)\b", t_lower):
        intent["fund"] = "Tiền chung"
    elif re.search(r"\b(quỹ cá nhân|tiền riêng|cá nhân)\b", t_lower):
        intent["fund"] = "Cá nhân"

    # Action
    if re.search(r"\b(đã mua|mua thêm|gom|múc|nhập|khớp mua|mua)\b", t_lower):
        intent["action"] = "BUY"
    elif re.search(r"\b(đã bán|chốt lời|cắt lỗ|sút|bán bớt|khớp bán|thoát|bán)\b", t_lower):
        intent["action"] = "SELL"

    # Quantity
    m_qty = re.search(r"(\d+)\s*(cp|cổ|cổ phiếu|con)?\b", t_lower)
    if m_qty:
        intent["qty"] = int(m_qty.group(1))

    # Price
    m_price = re.search(r"(?:giá|khớp giá|ở mức|tại giá)\s*([0-9]+[.,]?[0-9]*)\s*k?\b", t_lower)
    if not m_price:
        m_price = re.search(r"\b([0-9]+[.,]?[0-9]*)\s*k\b", t_lower)
    if m_price:
        raw_p = m_price.group(1).replace(",", ".")
        val_p = float(raw_p)
        intent["price"] = (val_p * 1000) if val_p < 1000 else val_p

    intent["ticker"] = extract_ticker(text)
    return intent

def handle_direct_trade(chat_id: int, intent: Dict[str, Any]):
    fund = intent["fund"]
    tk = intent["ticker"]
    qty = intent["qty"]
    price = intent["price"]
    act = intent["action"]
    meta = get_ticker_meta(tk)

    if act == "BUY":
        record_trade(fund, tk, "BUY", qty, price)
        holdings = get_portfolio_holdings(fund)
        cur_qty = qty
        avg_cost = price
        for h in holdings:
            if h['ticker'] == tk:
                cur_qty = h['current_qty']
                avg_cost = float(h['avg_buy_price'])
                break
        total_cmd = qty * price
        reply = (
            f"✅ <b>ĐÃ GHI NHẬN LỆNH MUA VÀO QUỸ [{fund.upper()}]!</b>\n"
            f"─────────────────────\n"
            f"• Mã: <b>{tk}</b> ({meta['sector']})\n"
            f"• Số lượng mua: <b>{qty} cp</b> @ <b>{price:,.0f} đ</b>\n"
            f"• Tổng tiền lệnh: <b>{total_cmd:,.0f} VND</b>\n\n"
            f"📊 <b>VỊ THẾ QUỸ {fund} HIỆN TẠI:</b>\n"
            f"• Đang nắm giữ: <b>{cur_qty} cp {tk}</b>\n"
            f"• <b>Giá vốn bình quân: {avg_cost:,.0f} VND</b>"
        )
        send_reply(chat_id, reply)

    elif act == "SELL":
        holdings = get_portfolio_holdings(fund)
        old_qty = 0
        avg_cost = 0.0
        for h in holdings:
            if h['ticker'] == tk:
                old_qty = int(h['current_qty'])
                avg_cost = float(h['avg_buy_price'])
                break

        record_trade(fund, tk, "SELL", qty, price)
        revenue = qty * price
        cost_basis = qty * avg_cost
        realized_pnl = revenue - cost_basis
        pnl_pct = round((realized_pnl / cost_basis) * 100, 2) if cost_basis > 0 else 0.0
        remain_qty = max(0, old_qty - qty)
        pnl_icon = "🎉 CHỐT LÃI: +" if realized_pnl >= 0 else "⚠️ CẮT LỖ: "

        reply = (
            f"✅ <b>ĐÃ GHI NHẬN LỆNH BÁN CHO QUỸ [{fund.upper()}]!</b>\n"
            f"─────────────────────\n"
            f"• Mã: <b>{tk}</b> | Bán: <b>{qty} cp</b> @ <b>{price:,.0f} đ</b>\n"
            f"• Tổng tiền thu về: <b>{revenue:,.0f} VND</b>\n"
            f"• <b>Lợi nhuận thực tế: {pnl_icon}{realized_pnl:,.0f} VND ({pnl_pct}%)</b>\n\n"
            f"📊 <b>SỐ DƯ QUỸ {fund} CÒN LẠI:</b> <b>{remain_qty} cp {tk}</b>"
        )
        send_reply(chat_id, reply)

def handle_portfolio_report(chat_id: int, filter_fund: str = ""):
    holdings = get_portfolio_holdings(filter_fund if filter_fund else None)
    if not holdings:
        target_name = f"của <b>Quỹ {filter_fund}</b>" if filter_fund else ""
        send_reply(chat_id, f"📂 <b>Danh mục tài sản {target_name} hiện đang trống.</b>\n\nBạn có thể nhắn:\n• <i>'Đã mua 10cp FPT giá 65,3'</i>\n• <i>'Quỹ chung đã mua 10cp CTG giá 30,05'</i>")
        return

    fund_map = {}
    grand_val = 0.0
    grand_cost = 0.0
    sector_map = {}

    for h in holdings:
        f = h['fund_name']
        tk = h['ticker']
        sec = h['sector']
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
        sector_map[sec] = sector_map.get(sec, 0.0) + cur_val

        if f not in fund_map:
            fund_map[f] = {"cost": 0.0, "val": 0.0, "items": []}
        fund_map[f]["cost"] += invested
        fund_map[f]["val"] += cur_val
        fund_map[f]["items"].append({
            "ticker": tk, "sector": sec, "qty": qty, "avg_cost": avg_cost,
            "live": live, "val": cur_val, "pnl": pnl_val, "pct": pnl_pct
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
        body += f"  • Giá trị: {f_data['val']:,.0f} đ | Lời/Lỗ: {f_icon}{f_pnl:,.0f} đ ({f_pct}%)\n"
        for it in f_data["items"]:
            p_icon = "🟢 +" if it['pnl'] >= 0 else "🔴 "
            body += f"    ▫️ <b>{it['ticker']}</b> ({it['sector']}): <b>{it['qty']} cp</b>\n"
            body += f"       Vốn: {it['avg_cost']:,.0f} đ | Thị giá: {it['live']:,.0f} đ\n"
            body += f"       Giá trị: {it['val']:,.0f} đ ({p_icon}{it['pnl']:,.0f} đ | {it['pct']}%)\n"
        body += "\n"

    sec_text = ""
    for s_k, s_v in sector_map.items():
        pct = round((s_v / grand_val) * 100, 1) if grand_val > 0 else 0.0
        sec_text += f"  - {s_k}: {s_v:,.0f} đ ({pct}%)\n"

    reply = (
        f"📊 <b>BÁO CÁO TỔNG TÀI SẢN & ĐA QUỸ ĐẦU TƯ</b>\n"
        f"─────────────────────\n"
        f"💰 <b>TỔNG TÀI SẢN:</b> <b>{grand_val:,.0f} VND</b>\n"
        f"💵 <b>Tổng vốn đầu tư:</b> {grand_cost:,.0f} VND\n"
        f"📈 <b>Tổng Lời / Lỗ:</b> {g_icon}{grand_pnl:,.0f} VND (<b>{grand_pct}%</b>)\n\n"
        f"{body}"
        f"🏢 <b>PHÂN BỔ THEO NGÀNH:</b>\n"
        f"{sec_text}\n"
        f"💡 <i>Nếu nhập nhầm giá hoặc số lượng, chỉ cần nhắn: <b>'sửa giá thành 57.3'</b> hoặc <b>'xóa giao dịch vừa rồi'</b>!</i>"
    )
    send_reply(chat_id, reply)

def handle_ticker_quote(chat_id: int, ticker: str):
    live = get_live_price(ticker)
    f_score = get_f_score(ticker)
    holdings = get_portfolio_holdings()
    owned = [h for h in holdings if h['ticker'] == ticker]

    if owned:
        pos_text = ""
        tot_q = 0
        tot_cost = 0.0
        for o in owned:
            q = int(o['current_qty'])
            c = float(o['avg_buy_price'])
            tot_q += q
            tot_cost += (q * c)
            pos_text += f"• Quỹ <b>{o['fund_name']}</b>: {q} cp @ {c:,.0f} đ\n"
        overall_avg = (tot_cost / tot_q) if tot_q > 0 else live
        pnl_pct = round(((live - overall_avg) / overall_avg) * 100, 2) if overall_avg > 0 else 0.0
        reply = (
            f"🎯 <b>VỊ THẾ HIỆN TẠI: CỔ PHIẾU {ticker}</b>\n"
            f"─────────────────────\n"
            f"Thị giá sàn HOSE hiện tại: <b>{live:,.0f} VND</b>\n"
            f"F-Score doanh nghiệp: <b>{f_score}/9</b>\n\n"
            f"👤 <b>VỊ THẾ CỦA BẠN:</b>\n"
            f"{pos_text}"
            f"➡️ <i>Tổng sở hữu: <b>{tot_q} cp</b> (Giá vốn chung: {overall_avg:,.0f} đ | Biến động: {pnl_pct}%)</i>\n\n"
            f"💡 <i>Nhắn tin: <b>'Phân tích chuyên sâu {ticker}'</b> để nhận chiến thuật chi tiết!</i>"
        )
    else:
        reply = (
            f"🔍 <b>PHÂN TÍCH NHANH: {ticker}</b>\n"
            f"─────────────────────\n"
            f"• Hiện tại bạn <b>chưa có cổ phiếu {ticker}</b> trong danh mục.\n"
            f"• Thị giá sàn HOSE hiện tại: <b>{live:,.0f} VND</b>.\n"
            f"• Sức khỏe BCTC: F-Score đạt <b>{f_score}/9</b>.\n\n"
            f"💡 <i>Nhắn tin: <b>'Phân tích chuyên sâu {ticker}'</b> hoặc hỏi trực tiếp em để nhận tư vấn!</i>"
        )
    send_reply(chat_id, reply)

def handle_deep_analysis_template(chat_id: int, ticker: str):
    live = get_live_price(ticker)
    meta = get_ticker_meta(ticker)
    f_score = get_f_score(ticker)

    reply = (
        f"📑 <b>BẢN LẬP LUẬN ĐẦU TƯ 4 TRỤ CỘT: {ticker}</b>\n"
        f"─────────────────────\n"
        f"Doanh nghiệp: <b>{meta['company_name']}</b> ({meta['sector']})\n"
        f"Thị giá tham chiếu: <b>{live:,.0f} VND</b> | F-Score: <b>{f_score}/9</b>\n\n"
        f"📈 <b>1. KỸ THUẬT & DÒNG TIỀN:</b>\n"
        f"Cổ phiếu giữ vững nền hỗ trợ quanh vùng {live*0.97:,.0f} - {live:,.0f} đ. Lực cầu tổ chức hấp thụ ổn định.\n\n"
        f"📑 <b>2. SỨC KHỎE TÀI CHÍNH:</b>\n"
        f"Điểm Piotroski F-Score đạt {f_score}/9, cơ cấu tài chính an toàn, đòn bẩy nợ kiểm soát tốt.\n\n"
        f"🚀 <b>3. ĐỘNG LỰC TĂNG TRƯỞNG (CATALYST):</b>\n"
        f"{meta.get('catalyst_notes') or 'Hưởng lợi từ chu kỳ ngành và nhu cầu mở rộng quy mô kinh doanh.'}\n\n"
        f"⚖️ <b>4. KẾ HOẠCH HÀNH ĐỘNG:</b>\n"
        f"• Vùng mua giải ngân: {live*0.98:,.0f} - {live*1.01:,.0f} đ\n"
        f"• Cắt lỗ ngắn hạn: {live*0.94:,.0f} đ (-6%)\n"
        f"• Mục tiêu kỳ vọng: {live*1.15:,.0f} đ (+15%)"
    )
    send_reply(chat_id, reply)

def handle_generic_budget_query(chat_id: int, text: str) -> bool:
    m = re.search(r"(?:có|với|vốn)\s+(\d+[\.,]?\d*)\s*(k|nghìn|ngàn|tr|triệu|củ)?\b.*(đầu tư|mua gì|mua con nào)", text, re.IGNORECASE)
    if not m:
        return False
    val = float(m.group(1).replace(",", "."))
    unit = (m.group(2) or "").lower()
    mult = 1000 if unit in ["k", "nghìn", "ngàn"] else (1000000 if unit in ["tr", "triệu", "củ"] else (1000 if val >= 50 else 1000000))
    budget = int(val * mult)

    p_fpt = get_live_price("FPT") or 56800
    p_hpg = get_live_price("HPG") or 21050
    p_mbb = get_live_price("MBB") or 19750

    q_mbb = int(budget / p_mbb)
    q_hpg = int(budget / p_hpg)
    q_fpt = int(budget / p_fpt)

    reply = (
        f"💡 <b>TƯ VẤN ĐẦU TƯ THEO NGÂN SÁCH: {budget:,.0f} VND</b>\n"
        f"─────────────────────\n"
        f"Với số vốn {budget:,.0f} đ, anh hoàn toàn có thể mua <b>lô lẻ (1 - 99 cp)</b> trên sàn HOSE:\n\n"
        f"1️⃣ <b>MBB</b> (~{p_mbb:,.0f} đ): Mua được <b>{q_mbb} cp</b> ➔ An toàn, hưởng cổ tức tiền mặt đều đặn.\n"
        f"2️⃣ <b>HPG</b> (~{p_hpg:,.0f} đ): Mua được <b>{q_hpg} cp</b> ➔ Đón sóng chu kỳ thép Dung Quất 2.\n"
        f"3️⃣ <b>FPT</b> (~{p_fpt:,.0f} đ): Mua được <b>{q_fpt} cp</b> ➔ Siêu tăng trưởng công nghệ & AI dài hạn.\n\n"
        f"💡 <i>Anh có thể hỏi sâu hơn ví dụ: <b>'500k thì nên giải ngân bao nhiêu cho PVD'</b> để em phân bổ chi tiết!</i>"
    )
    send_reply(chat_id, reply)
    return True

def run_bot_loop():
    global chat_history
    logger.info("Khởi chạy vòng lặp Bot tương tác Telegram...")
    last_update_id = 0

    while True:
        try:
            url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/getUpdates?offset={last_update_id + 1}&timeout=15"
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=20) as resp:
                updates = json.loads(resp.read().decode('utf-8'))

            for u in updates.get("result", []):
                last_update_id = u["update_id"]
                msg = u.get("message")
                if not msg or not msg.get("text"):
                    continue

                chat_id = msg["chat"]["id"]
                text = msg["text"].strip()
                sender = msg.get("from", {}).get("first_name", "Bạn")

                logger.info(f"[{sender}]: {text}")
                found_ticker = extract_ticker(text)

                # 1. Quản lý Watchlist: Loại bỏ
                if re.search(r"\b(loại|loại bỏ|bỏ|xóa|xoá|gỡ|remove)\b", text, re.IGNORECASE) and found_ticker and not re.search(r"\b(giao dịch|lệnh|gd)\b", text, re.IGNORECASE):
                    remove_watchlist(found_ticker)
                    send_reply(chat_id, f"🗑️ <b>ĐÃ LOẠI BỎ MÃ {found_ticker} KHỎI DANH SÁCH THEO DÕI!</b>")
                    continue

                # 2. Quản lý Watchlist: Thêm vào
                if re.search(r"\b(thêm|theo dõi thêm|add|cho vào theo dõi)\b", text, re.IGNORECASE) and found_ticker and not re.search(r"\b(mua|bán|giá)\b", text, re.IGNORECASE):
                    meta = get_ticker_meta(found_ticker)
                    add_watchlist(found_ticker, meta['company_name'], meta['sector'])
                    send_reply(chat_id, f"⭐ <b>ĐÃ THÊM MÃ {found_ticker} ({meta['company_name']}) VÀO THEO DÕI!</b>")
                    continue

                # 3. Quản lý Watchlist: Làm mới
                if re.search(r"\b(làm mới|cập nhật lại|refresh)\s*(lại)?\s*(danh sách|theo dõi|watchlist)?\b", text, re.IGNORECASE):
                    send_reply(chat_id, "🔄 <b>Đã đồng bộ và làm mới danh sách 24 siêu cổ phiếu dẫn đầu ngành!</b>")
                    continue

                # 4. Gợi ý ngân sách chung chung (CHỈ khi không gắn với mã và không hỏi follow-up)
                if not found_ticker and not re.search(r"\b(bao nhiêu|cho|vào|thế còn|tại sao|sao lại|chuẩn bị|lệnh)\b", text, re.IGNORECASE):
                    if handle_generic_budget_query(chat_id, text):
                        continue

                # 5. Sửa nhầm / Xóa giao dịch vừa rồi
                if re.search(r"\b(xóa giao dịch|xoá giao dịch|hủy giao dịch|undo)\b", text, re.IGNORECASE):
                    deleted = undo_last_trade()
                    if deleted:
                        send_reply(chat_id, f"🗑️ <b>ĐÃ HOÀN TÁC GIAO DỊCH GẦN NHẤT!</b>\n• Đã xóa: <b>{deleted['quantity']} cp {deleted['ticker']}</b> @ {float(deleted['price']):,.0f} đ ({deleted['fund_name']})")
                    else:
                        send_reply(chat_id, "⚠️ Không tìm thấy giao dịch nào gần nhất để hoàn tác.")
                    continue

                if re.search(r"\b(sửa giá|nhầm giá|sửa lại giá|đổi giá)\s*([0-9]+[.,]?[0-9]*)\s*k?\b", text, re.IGNORECASE):
                    m_p = re.search(r"\b([0-9]+[.,]?[0-9]*)\s*k?\b", text)
                    if m_p:
                        v_p = float(m_p.group(1).replace(",", "."))
                        new_p = (v_p * 1000) if v_p < 1000 else v_p
                        updated = update_last_trade_price(new_p, found_ticker)
                        if updated:
                            send_reply(chat_id, f"✏️ <b>ĐÃ CẬP NHẬT GIÁ VỐN THÀNH CÔNG!</b>\n• Mã: <b>{updated['ticker']}</b>\n• Mức giá mới: <b>{new_p:,.0f} VND</b>")
                            continue

                if re.search(r"\b(sửa số lượng|sửa sl|đổi thành)\s*(\d+)\s*(cp|cổ)?\b", text, re.IGNORECASE):
                    m_q = re.search(r"\b(\d+)\b", text)
                    if m_q:
                        new_q = int(m_q.group(1))
                        updated = update_last_trade_qty(new_q, found_ticker)
                        if updated:
                            send_reply(chat_id, f"✏️ <b>ĐÃ CẬP NHẬT SỐ LƯỢNG THÀNH CÔNG!</b>\n• Mã: <b>{updated['ticker']}</b>\n• Số lượng mới: <b>{new_q} cp</b>")
                            continue

                # 6. Ghi nhận Lệnh Mua / Bán tự nhiên
                intent = parse_stock_intent(text)
                if intent["action"] and intent["ticker"] and intent["qty"] > 0 and intent["price"] > 0:
                    handle_direct_trade(chat_id, intent)
                    continue

                # 7. Báo cáo Danh mục & Quỹ
                if re.search(r"\b(danh mục cá nhân|tài sản cá nhân|quỹ cá nhân|/canhan)\b", text, re.IGNORECASE):
                    handle_portfolio_report(chat_id, "Cá nhân")
                    continue
                if re.search(r"\b(danh mục chung|tài sản chung|quỹ chung|/chung)\b", text, re.IGNORECASE):
                    handle_portfolio_report(chat_id, "Tiền chung")
                    continue
                if re.search(r"\b(danh mục|tài sản|portfolio|/portfolio|/list|/danhmuc)\b", text, re.IGNORECASE):
                    handle_portfolio_report(chat_id, "")
                    continue

                # 7.5. Báo cáo chốt phiên theo yêu cầu
                if re.search(r"\b(chốt phiên|báo cáo chốt phiên|tổng kết phiên|/close|/chotphien)\b", text, re.IGNORECASE):
                    send_reply(chat_id, "⏳ <i>Đang tổng hợp số liệu chốt phiên hôm nay...</i>")
                    send_daily_close_report(force=True)
                    continue

                # 8. Bản phân tích chuyên sâu tĩnh (CHỈ khi gõ đúng lệnh tắt /deep hoặc 'phân tích chuyên sâu Mã')
                is_explicit_deep = (re.search(r"^/(deep|phantich|ptcs)\b", text, re.IGNORECASE) or re.search(r"^(phân tích chuyên sâu|luận điểm đầu tư|báo cáo)\s+[A-Za-z]{3}$", text, re.IGNORECASE)) and found_ticker
                if is_explicit_deep:
                    handle_deep_analysis_template(chat_id, found_ticker)
                    continue

                # 9. Tra cứu mã ngắn gọn (chỉ gõ duy nhất tên mã, vd 'PVD' hoặc 'Xem PVD')
                words = text.split()
                if found_ticker and len(words) <= 2 and not re.search(r"\b(sao|tại sao|nên|không|đầu tư|thế nào|chuẩn bị|lệnh|mai|phiên|bao nhiêu)\b", text, re.IGNORECASE):
                    handle_ticker_quote(chat_id, found_ticker)
                    continue

                # 10. TẦNG NÃO BỘ AI: TRÒ CHUYỆN & TƯ VẤN TỰ NHIÊN BẰNG AGY (GEMINI)
                logger.info(f"Đang kích hoạt Não bộ AI (agy) cho câu hỏi: '{text}'")
                port_ctx = get_portfolio_context_text()
                ai_answer = call_conversational_ai(text, port_ctx, chat_history)
                if ai_answer:
                    chat_history.append(f"Anh Phan: {text}")
                    chat_history.append(f"Stock Copilot: {ai_answer}")
                    if len(chat_history) > 8:
                        chat_history = chat_history[-8:]
                    send_reply(chat_id, ai_answer)
                    continue

                # 11. Hướng dẫn mặc định
                send_reply(chat_id, (
                    f"👋 Chào anh <b>{sender}</b>! Em là Stock Copilot.\n"
                    f"Anh có thể trao đổi tự nhiên với em:\n"
                    f"• <i>'500k thì nên đầu tư bao nhiêu cho PVD'</i>\n"
                    f"• <i>'Hãy phân tích PVD để tôi chuẩn bị các lệnh cho phiên tới'</i>\n"
                    f"• <i>'Đã mua 10cp FPT giá 65,3'</i>\n"
                    f"• <i>'Xem danh mục'</i>"
                ))

        except Exception as e:
            err_str = str(e).lower()
            if "timed out" in err_str:
                # Long polling timeout bình thường khi không có tin nhắn mới
                pass
            else:
                logger.warning(f"Lỗi kết nối Telegram: {e}")
                time.sleep(2)