-- Schema for Stock Copilot (PostgreSQL 16)
CREATE TABLE IF NOT EXISTS watchlists (
    ticker VARCHAR(10) PRIMARY KEY,
    company_name VARCHAR(255) NOT NULL,
    exchange VARCHAR(10) DEFAULT 'HOSE',
    horizon VARCHAR(20) DEFAULT 'BOTH', -- 'SHORT_TERM', 'LONG_TERM', 'BOTH'
    pivot_price NUMERIC(12, 2),
    support_price NUMERIC(12, 2),
    resistance_price NUMERIC(12, 2),
    catalyst_notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS financial_reports (
    id SERIAL PRIMARY KEY,
    ticker VARCHAR(10) REFERENCES watchlists(ticker) ON DELETE CASCADE,
    year INT NOT NULL,
    quarter INT NOT NULL,
    revenue_bil NUMERIC(12, 2),           -- Doanh thu (tỷ đồng)
    net_profit_bil NUMERIC(12, 2),        -- Lợi nhuận sau thuế (tỷ đồng)
    revenue_growth_yoy NUMERIC(8, 2),     -- Tăng trưởng doanh thu cùng kỳ (%)
    profit_growth_yoy NUMERIC(8, 2),      -- Tăng trưởng LN cùng kỳ (%)
    gross_margin NUMERIC(8, 2),           -- Biên lãi gộp (%)
    net_margin NUMERIC(8, 2),             -- Biên lãi ròng (%)
    debt_to_equity NUMERIC(8, 2),         -- Nợ vay / Vốn CSH
    cfo_bil NUMERIC(12, 2),               -- Dòng tiền kinh doanh (tỷ đồng)
    pe_ratio NUMERIC(8, 2),
    pb_ratio NUMERIC(8, 2),
    f_score INT CHECK (f_score BETWEEN 0 AND 9), -- Piotroski F-Score (0-9)
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ticker, year, quarter)
);

CREATE TABLE IF NOT EXISTS market_snapshots (
    id BIGSERIAL PRIMARY KEY,
    ticker VARCHAR(10) REFERENCES watchlists(ticker) ON DELETE CASCADE,
    snapshot_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    current_price NUMERIC(12, 2) NOT NULL,
    change_pct NUMERIC(6, 2),
    volume BIGINT NOT NULL,
    ma20_volume BIGINT,
    vol_surge_ratio NUMERIC(6, 2),        -- Vol / MA20 Vol (vd: 2.2x)
    rsi_14 NUMERIC(6, 2),
    ma20_price NUMERIC(12, 2),
    ma50_price NUMERIC(12, 2),
    is_breakout BOOLEAN DEFAULT FALSE,
    pattern_detected VARCHAR(100)         -- 'VCP', 'Double Bottom', 'Cup & Handle', etc.
);

CREATE TABLE IF NOT EXISTS investment_theses (
    id SERIAL PRIMARY KEY,
    ticker VARCHAR(10) REFERENCES watchlists(ticker) ON DELETE CASCADE,
    alert_level VARCHAR(20) NOT NULL,     -- 'FLASH', 'DEEP_THESIS'
    horizon VARCHAR(20) NOT NULL,         -- 'SHORT_TERM', 'LONG_TERM'
    trigger_price NUMERIC(12, 2) NOT NULL,
    confluence_score INT,                 -- Thang điểm hợp lưu 0-100%
    probability_pct INT,                  -- Xác suất tăng %
    tech_thesis TEXT,                     -- Lập luận kỹ thuật & dòng tiền
    fund_thesis TEXT,                     -- Lập luận BCTC & sức khỏe DN
    catalyst_thesis TEXT,                 -- Động lực tăng trưởng & kế hoạch
    action_plan TEXT,                     -- Kế hoạch giải ngân & R:R
    entry_zone VARCHAR(100),
    stop_loss NUMERIC(12, 2),
    target_1 NUMERIC(12, 2),
    target_2 NUMERIC(12, 2),
    agy_raw_response TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_snapshots_ticker_time ON market_snapshots(ticker, snapshot_time DESC);
CREATE INDEX IF NOT EXISTS idx_theses_ticker_created ON investment_theses(ticker, created_at DESC);

-- Seed Initial Watchlist
INSERT INTO watchlists (ticker, company_name, exchange, horizon, pivot_price, support_price, resistance_price, catalyst_notes)
VALUES 
    ('FPT', 'CTCP FPT', 'HOSE', 'BOTH', 137000, 133000, 145000, 'Hợp tác nhà máy AI Nvidia, mảng xuất khẩu phần mềm Nhật Bản tăng trưởng >28%'),
    ('HPG', 'CTCP Tập đoàn Hòa Phát', 'HOSE', 'BOTH', 29000, 27500, 32000, 'Đại dự án Dung Quất 2 chạy thử giai đoạn 1, sản lượng HRC mở rộng'),
    ('MWG', 'CTCP Đầu tư Thế Giới Di Động', 'HOSE', 'BOTH', 68000, 64000, 75000, 'Chuỗi Bách Hóa Xanh bắt đầu đóng góp lợi nhuận, tái cấu trúc chuỗi ICT'),
    ('VCB', 'NHTM Cổ phần Ngoại thương Việt Nam', 'HOSE', 'LONG_TERM', 92000, 89000, 102000, 'Chất lượng tài sản hàng đầu hệ thống, kế hoạch phát hành riêng lẻ cho nhà đầu tư ngoại'),
    ('SSI', 'CTCP Chứng khoán SSI', 'HOSE', 'SHORT_TERM', 34500, 32000, 38000, 'Hưởng lợi hệ thống KRX vận hành và câu chuyện nâng hạng thị trường FTSE')
ON CONFLICT (ticker) DO NOTHING;

-- Seed Sample Financial Data for FPT
INSERT INTO financial_reports (ticker, year, quarter, revenue_bil, net_profit_bil, revenue_growth_yoy, profit_growth_yoy, gross_margin, net_margin, debt_to_equity, cfo_bil, pe_ratio, pb_ratio, f_score)
VALUES 
    ('FPT', 2026, 2, 16800, 2350, 21.4, 22.8, 38.5, 14.0, 0.28, 3100, 23.5, 5.2, 8),
    ('HPG', 2026, 2, 39500, 3320, 25.1, 127.0, 13.8, 8.4, 0.65, 4200, 12.8, 1.5, 7),
    ('MWG', 2026, 2, 34200, 1180, 15.6, 680.0, 21.2, 3.4, 0.42, 2800, 18.2, 2.9, 7)
ON CONFLICT (ticker, year, quarter) DO NOTHING;
