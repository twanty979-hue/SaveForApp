-- ==============================================================================
-- Migration: 003_transactions_normalize_all_columns.sql
-- Description: แยกคอลัมน์มาตรฐานในตาราง transactions ให้สมบูรณ์แบบทั้งระบบ:
--              1. bank (รหัสธนาคาร เช่น kbank, scb, truemoney)
--              2. reference_no (เลขอ้างอิงสลิปโอนเงิน)
--              3. source (แหล่งที่มา: slip, manual, ai_chat, recurring_expense, recurring_income, dream_saving)
--              4. dream_id (เชื่อมกับตาราง dreams โดยตรง)
--              5. metadata (ข้อมูลเสริม JSONB)
-- ==============================================================================

-- 1. เพิ่มคอลัมน์ใหม่ในตาราง transactions
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS bank text,
  ADD COLUMN IF NOT EXISTS reference_no text,
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS dream_id uuid REFERENCES public.dreams(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- 2. สร้าง Indexes สำหรับเพิ่มความเร็วในการ Query และ Aggregation ระดับ 0.01ms
CREATE INDEX IF NOT EXISTS idx_transactions_bank
  ON public.transactions (bank)
  WHERE bank IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_reference_no
  ON public.transactions (reference_no)
  WHERE reference_no IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_source
  ON public.transactions (source);

CREATE INDEX IF NOT EXISTS idx_transactions_dream_id
  ON public.transactions (dream_id)
  WHERE dream_id IS NOT NULL;

-- 3. Backfill ข้อมูลเก่าทั้งหมดใน Database แยกเข้าสู่คอลัมน์ใหม่โดยอัตโนมัติ:

-- 3.1 กรณีสลิปโอนเงิน (ดึง bank, reference_no, source = 'slip')
UPDATE public.transactions
SET
  source = 'slip',
  bank = CASE
    WHEN note ILIKE '%กสิกร%' OR note ILIKE '%kbank%' THEN 'kbank'
    WHEN note ILIKE '%ไทยพาณิชย์%' OR note ILIKE '%scb%' THEN 'scb'
    WHEN note ILIKE '%กรุงศรี%' OR note ILIKE '%bay%' THEN 'krungsri'
    WHEN note ILIKE '%กรุงไทย%' OR note ILIKE '%ktb%' THEN 'ktb'
    WHEN note ILIKE '%กรุงเทพ%' OR note ILIKE '%bbl%' THEN 'bbl'
    WHEN note ILIKE '%ทหารไทย%' OR note ILIKE '%ttb%' OR note ILIKE '%tmb%' THEN 'ttb'
    WHEN note ILIKE '%ออมสิน%' OR note ILIKE '%gsb%' THEN 'gsb'
    WHEN note ILIKE '%truemoney%' OR note ILIKE '%ทรูมันนี่%' THEN 'truemoney'
    ELSE 'other'
  END,
  reference_no = substring(note from '\[Ref:([^\]]+)\]')
WHERE (note LIKE '%[สลิป%' OR note LIKE '%[Ref:%');

-- 3.2 กรณีรายจ่ายประจำ (source = 'recurring_expense')
UPDATE public.transactions
SET source = 'recurring_expense'
WHERE fixed_expense_id IS NOT NULL OR note LIKE '%[รายจ่ายประจำ]%';

-- 3.3 กรณีรายรับประจำ (source = 'recurring_income')
UPDATE public.transactions
SET source = 'recurring_income'
WHERE income_source_id IS NOT NULL OR note LIKE '%[รายรับประจำ]%';

-- 3.4 กรณีเงินออม/หยอดกระปุก (เชื่อมโยง dream_id จากตาราง dreams ให้โดยอัตโนมัติ)
UPDATE public.transactions t
SET
  source = 'dream_saving',
  dream_id = d.id
FROM public.dreams d
WHERE t.user_id = d.user_id
  AND (t.note LIKE '%[ออม]%' OR t.note LIKE '%หยอดกระปุก%')
  AND (
    t.note ILIKE '%' || d.title || '%'
    OR d.title ILIKE '%' || replace(replace(t.note, '[ออม] หยอดกระปุก: ', ''), '[ออม]', '') || '%'
  );

-- 4. บันทึก Schema Documentation ให้ชัดเจนใน Database (เพื่อให้ AI ทุกตัวอ่านเข้าใจทันที)
COMMENT ON COLUMN public.transactions.bank IS 'รหัสธนาคาร เช่น kbank, scb, truemoney, ktb, bbl, ttb, gsb, other';
COMMENT ON COLUMN public.transactions.reference_no IS 'เลขอ้างอิงสลิปธนาคาร (Slip Reference Number)';
COMMENT ON COLUMN public.transactions.source IS 'แหล่งที่มา: slip, manual, ai_chat, recurring_expense, recurring_income, dream_saving';
COMMENT ON COLUMN public.transactions.dream_id IS 'รหัสเป้าหมายเงินออม (Foreign Key to dreams.id)';
COMMENT ON COLUMN public.transactions.metadata IS 'ข้อมูลเสริมเพิ่มเติมในรูปแบบ JSONB';
