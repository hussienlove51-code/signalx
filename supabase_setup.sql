-- ======================================
-- SignalX - إعداد قاعدة بيانات Supabase
-- نفّذ هذا الكود في Supabase SQL Editor
-- ======================================

-- 1. جدول الباقات
CREATE TABLE packages (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  speed_mbps    INT  NOT NULL,
  price         INT  NOT NULL,
  duration_days INT  NOT NULL DEFAULT 30,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- 2. جدول الأبراج
CREATE TABLE towers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  location          TEXT,
  signal_strength   INT  DEFAULT 100,
  status            TEXT DEFAULT 'online', -- online | warning | offline
  temperature       FLOAT DEFAULT 40.0,
  subscriber_count  INT  DEFAULT 0,
  current_bandwidth FLOAT DEFAULT 0.0,
  created_at        TIMESTAMPTZ DEFAULT now()
);

-- 3. جدول المشتركين
CREATE TABLE subscribers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  phone       TEXT,
  area        TEXT,
  tower_id    UUID REFERENCES towers(id),
  package_id  UUID REFERENCES packages(id),
  expires_at  DATE NOT NULL,
  status      TEXT DEFAULT 'active', -- active | expiring | offline
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 4. جدول الدفعات
CREATE TABLE payments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscriber_id UUID REFERENCES subscribers(id) ON DELETE CASCADE,
  amount        INT  NOT NULL,
  method        TEXT DEFAULT 'cash', -- cash | app | zain_cash
  paid_at       TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- بيانات تجريبية للبدء
-- ======================================

-- باقات
INSERT INTO packages (name, speed_mbps, price, duration_days) VALUES
  ('باقة 5 ميغا',  5,  8000,  30),
  ('باقة 10 ميغا', 10, 15000, 30),
  ('باقة 20 ميغا', 20, 25000, 30),
  ('باقة 50 ميغا', 50, 45000, 30);

-- أبراج
INSERT INTO towers (name, location, signal_strength, status, temperature, subscriber_count, current_bandwidth) VALUES
  ('برج زنبور الرئيسي', 'قرية زنبور — ديالى', 97, 'online',  42, 142, 18.5),
  ('برج الخالص 2',      'الخالص — ديالى',     71, 'warning', 61, 105, 7.2),
  ('برج الخالص 3',      'الخالص الشرقي',       0,  'offline',  0,   0,  0.0);

-- ======================================
-- صلاحيات RLS (Row Level Security)
-- ======================================
ALTER TABLE subscribers ENABLE ROW LEVEL SECURITY;
ALTER TABLE towers       ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages     ENABLE ROW LEVEL SECURITY;

-- سماح للمستخدمين المسجلين بكل العمليات
CREATE POLICY "allow_all" ON subscribers FOR ALL USING (true);
CREATE POLICY "allow_all" ON towers       FOR ALL USING (true);
CREATE POLICY "allow_all" ON payments     FOR ALL USING (true);
CREATE POLICY "allow_all" ON packages     FOR ALL USING (true);

-- ═══════════════════════════════════════════
--  Migration: إضافة sas4_username للمشتركين
--  شغّل هذا إذا كانت جداولك موجودة مسبقاً
-- ═══════════════════════════════════════════
ALTER TABLE subscribers
  ADD COLUMN IF NOT EXISTS sas4_username TEXT UNIQUE;

-- إنشاء Index للبحث السريع بـ SAS4 username
CREATE INDEX IF NOT EXISTS idx_subscribers_sas4
  ON subscribers(sas4_username)
  WHERE sas4_username IS NOT NULL;
