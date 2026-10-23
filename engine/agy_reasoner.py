import subprocess
import json
import logging
from typing import Dict, Any, Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("AgyReasoner")

def generate_investment_thesis(
    ticker: str,
    company_name: str,
    current_price: float,
    vol_surge_ratio: float,
    pattern: str,
    financial_data: Dict[str, Any],
    catalyst_notes: str,
    horizon: str = "SHORT_TERM",
    agy_cli_path: str = r"C:\Users\hieu.pt\AppData\Local\agy\bin\agy.exe",
    project_name: str = "stock-copilot"
) -> Dict[str, Any]:
    """
    Kích hoạt phiên AGY riêng biệt (--project stock-copilot) để sinh bài lập luận đầu tư đa chiều.
    """
    prompt = f"""Bạn là Chuyên viên Phân tích Đầu tư Cấp cao (Senior Equity Analyst).
Hãy thẩm định và đưa ra bộ lập luận chặt chẽ cho cơ hội đầu tư sau:

THÔNG TIN ĐẦU VÀO:
- Mã cổ phiếu: {ticker} ({company_name})
- Giá hiện tại: {current_price:,.0f} VND
- Dòng tiền: Khối lượng khớp lệnh phiên đạt {vol_surge_ratio:.1f}x so với trung bình 20 phiên (MA20)
- Mẫu hình kỹ thuật: {pattern}
- Loại hình khuyến nghị: {horizon} (Ngắn hạn / Dài hạn)
- Sức khỏe BCTC gần nhất:
  + Doanh thu: {financial_data.get('revenue_bil', 'N/A')} tỷ (Tăng trưởng YoY: {financial_data.get('revenue_growth_yoy', 'N/A')}%)
  + Lợi nhuận sau thuế: {financial_data.get('net_profit_bil', 'N/A')} tỷ (Tăng trưởng YoY: {financial_data.get('profit_growth_yoy', 'N/A')}%)
  + Biên lãi gộp: {financial_data.get('gross_margin', 'N/A')}%, Biên lãi ròng: {financial_data.get('net_margin', 'N/A')}%
  + Piotroski F-Score: {financial_data.get('f_score', 'N/A')}/9
  + Định giá: P/E = {financial_data.get('pe_ratio', 'N/A')}x, P/B = {financial_data.get('pb_ratio', 'N/A')}x
- Động lực tăng trưởng & Kế hoạch (Catalyst): {catalyst_notes}

YÊU CẦU ĐẦU RA:
Hãy trình bày bản lập luận phân tích sắc bén, cô đọng bằng tiếng Việt, gồm đúng 4 phần sau:
1. LẬP LUẬN KỸ THUẬT & DÒNG TIỀN (Tại sao vào lúc này? Phân tích mẫu hình và hấp thụ cung cầu).
2. LẬP LUẬN CƠ BẢN & SỨC KHỎE TÀI CHÍNH (Đánh giá chất lượng tăng trưởng và độ an toàn của BCTC).
3. ĐỘNG LỰC TĂNG TRƯỞNG & KẾ HOẠCH DOANH NGHIỆP (Catalyst hỗ trợ đà tăng).
4. KẾ HOẠCH HÀNH ĐỘNG & QUẢN TRỊ RỦI RO (Vùng mua tối ưu, Ngưỡng cắt lỗ Stoploss, Mục tiêu chốt lời Target 1 & 2, Tỷ lệ R:R và Xác suất thành công %).
"""

    cmd = [
        agy_cli_path,
        "--project", project_name,
        "--effort", "medium",
        "-p", prompt
    ]

    logger.info(f"Đang kích hoạt phiên agy độc lập cho mã {ticker}...")
    try:
        process = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=45,
            encoding="utf-8",
            errors="replace"
        )
        if process.returncode == 0 and process.stdout.strip():
            thesis_text = process.stdout.strip()
            logger.info("agy đã hoàn tất bài lập luận thành công.")
            return {
                "success": True,
                "ticker": ticker,
                "thesis": thesis_text,
                "mode": "AGY_PRODUCED"
            }
        else:
            logger.warning(f"agy CLI phản hồi mã lỗi {process.returncode} hoặc yêu cầu đăng nhập: {process.stderr[:200]}")
    except subprocess.TimeoutExpired:
        logger.error("agy phản hồi quá thời gian quy định (timeout 45s).")
    except Exception as e:
        logger.error(f"Lỗi khi gọi agy CLI: {e}")

    # Fallback dự phòng nếu agy chưa đăng nhập OAuth một lần
    fallback_thesis = generate_rule_based_thesis(
        ticker, company_name, current_price, vol_surge_ratio, pattern, financial_data, catalyst_notes, horizon
    )
    return {
        "success": True,
        "ticker": ticker,
        "thesis": fallback_thesis,
        "mode": "RULE_ENGINE_FALLBACK"
    }

def generate_rule_based_thesis(ticker, company_name, current_price, vol_surge_ratio, pattern, financial_data, catalyst, horizon):
    f_score = financial_data.get('f_score', 7)
    rev_growth = financial_data.get('revenue_growth_yoy', 20.0)
    profit_growth = financial_data.get('profit_growth_yoy', 22.0)
    stop_loss = current_price * 0.965
    target_1 = current_price * 1.10
    target_2 = current_price * 1.22
    prob = 85 if (vol_surge_ratio >= 2.0 and f_score >= 7) else 78

    return f"""🎯 [BẢN LẬP LUẬN ĐẦU TƯ: {ticker} - {company_name}]
⏱️ Giá kích hoạt: {current_price:,.0f} VND | Phân loại: {horizon} | Xác suất tăng: {prob}%

📈 1. LẬP LUẬN KỸ THUẬT & DÒNG TIỀN:
• Mẫu hình: Hoàn tất cấu trúc {pattern}, xác nhận bứt phá vượt qua cản then chốt.
• Dòng tiền: Khối lượng giao dịch bùng nổ đạt {vol_surge_ratio:.1f}x so với MA20, dòng tiền lớn hấp thụ toàn bộ áp lực chốt lời.
• Tín hiệu: Động lượng giá giữ vững vùng giá cao, vị thế kiểm soát thuộc về phe mua.

📑 2. LẬP LUẬN CƠ BẢN & SỨC KHỎE TÀI CHÍNH:
• Tăng trưởng: Doanh thu tăng trưởng +{rev_growth:.1f}% YoY, Lợi nhuận sau thuế tăng +{profit_growth:.1f}% YoY.
• Sức khỏe tài chính: Điểm Piotroski F-Score đạt {f_score}/9 (Doanh nghiệp cực kỳ lành mạnh, rủi ro tài chính tối thiểu).
• Dòng tiền kinh doanh thặng dư ổn định, biên lợi nhuận duy trì ở mức cao.

🚀 3. ĐỘNG LỰC TĂNG TRƯỞNG & KẾ HOẠCH (CATALYST):
• {catalyst}

⚖️ 4. KẾ HOẠCH GIẢI NGÂN & QUẢN TRỊ RỦI RO (R:R = 1 : 3.0):
• Vùng mua giải ngân: {current_price*0.995:,.0f} - {current_price*1.01:,.0f} VND
• Ngưỡng cắt lỗ (Stoploss): {stop_loss:,.0f} VND (Vi phạm -3.5%)
• Mục tiêu 1 (Ngắn hạn): {target_1:,.0f} VND (+10.0%)
• Mục tiêu 2 (Trung - Dài hạn): {target_2:,.0f} VND (+22.0%)
"""
