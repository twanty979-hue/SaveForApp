-- ==============================================================================
-- Migration: 005_add_destination_bank_and_transfer_type.sql
-- Description: เพิ่มคอลัมน์ destination_bank และปลดล็อก transactions_type_check
--              เพื่อรองรับการย้ายเงินระหว่างบัญชี (Internal Account Transfer)
--              และสร้าง Index เพื่อความรวดเร็วในการ Query
-- ==============================================================================

-- 1. เพิ่มคอลัมน์ destination_bank ในตาราง transactions
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS destination_bank text;

-- 2. ปลดล็อกและอัปเดต Check Constraint ของ type ให้รองรับ 'transfer' (ย้ายเงิน)
ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_type_check;

ALTER TABLE public.transactions
  ADD CONSTRAINT transactions_type_check
  CHECK (type IN ('expense', 'income', 'transfer'));

-- 3. สร้าง Index สำหรับการค้นหาและกรองตามธนาคารปลายทาง
CREATE INDEX IF NOT EXISTS idx_transactions_destination_bank
  ON public.transactions (destination_bank)
  WHERE destination_bank IS NOT NULL;

-- 4. อัปเดต Comment เอกสาร Schema
COMMENT ON COLUMN public.transactions.destination_bank IS 'รหัสธนาคารปลายทางสำหรับรายการย้ายเงิน (Transfer Destination Bank เช่น kbank, scb, truemoney)';

-- 5. ปรับปรุงรายการย้ายเงินที่มีอยู่เดิมให้เปลี่ยนเป็น type 'transfer' ไม่นับเป็นค่าใช้จ่าย
UPDATE public.transactions
SET
  type = 'transfer',
  source = 'transfer',
  destination_bank = CASE
    WHEN bank = 'scb' THEN 'kbank'
    WHEN bank = 'kbank' THEN 'scb'
    ELSE COALESCE(destination_bank, 'other')
  END
WHERE id IN (
  '3375646b-453b-4509-af2d-d129025c9b94',
  '99017ec2-6d04-4ccb-b9ce-40c69f89450e',
  '5978eb0a-132c-4f79-b85c-ad12dbf5c30a',
  'e860da11-b5c0-4425-a7f6-2da12c0c0392',
  '94b26550-74a5-4abc-8278-c308731dce75'
) OR note LIKE '%[ย้ายเงิน%' OR metadata->>'transfer_type' = 'own_account';
