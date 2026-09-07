-- ==============================================================================
-- Migration 004: Clean Legacy Prefix Tags from transactions.note
-- วันที่สร้าง: 2026-09-08
-- วัตถุประสงค์: 
--   ลบ Tag นำหน้าเก่าๆ เช่น [รายจ่ายประจำ], [รายรับประจำ], [ออม] หยอดกระปุก:, [สลิป ...], [Ref:...] ออกจากคอลัมน์ note
--   เพื่อให้ note เก็บเฉพาะชื่อรายการจริงที่สะอาดบริสุทธิ์ (Clean Title) เช่น "ข้าว", "ขนม", "ค่าห้อง"
--   เนื่องจากประเภท/แหล่งที่มา (source), ธนาคาร (bank), เลขอ้างอิง (reference_no) 
--   และ ID เชื่อมโยง (fixed_expense_id, dream_id) ถูกแยกไปเก็บในคอลัมน์มาตรฐานจาก Migration 003 เรียบร้อยแล้ว
-- ==============================================================================

-- 1. ตัด [รายจ่ายประจำ] ออกจาก note และตัดช่องว่างส่วนเกิน
UPDATE public.transactions
SET note = TRIM(REPLACE(note, '[รายจ่ายประจำ]', ''))
WHERE note LIKE '%[รายจ่ายประจำ]%';

-- 2. ตัด [รายรับประจำ] ออกจาก note และตัดช่องว่างส่วนเกิน
UPDATE public.transactions
SET note = TRIM(REPLACE(note, '[รายรับประจำ]', ''))
WHERE note LIKE '%[รายรับประจำ]%';

-- 3. ตัด [ออม] หยอดกระปุก: และ [ออม] ออกจาก note
UPDATE public.transactions
SET note = TRIM(REPLACE(REPLACE(note, '[ออม] หยอดกระปุก:', ''), '[ออม]', ''))
WHERE note LIKE '%[ออม]%';

-- 4. ตัด [สลิป ...] และ [Ref:...] ออกจาก note สำหรับรายการสลิปที่แยก bank และ reference_no ไปแล้ว
UPDATE public.transactions
SET note = TRIM(REGEXP_REPLACE(REGEXP_REPLACE(note, '\[สลิป\s+[^\]]+\]', '', 'g'), '\[Ref:[^\]]+\]', '', 'g'))
WHERE note LIKE '%[สลิป%' OR note LIKE '%[Ref:%';

-- 5. หากมีรายการใดที่ note ว่างเปล่าหลังตัด Tag ให้ตั้งชื่อมาตรฐานตามประเภท
UPDATE public.transactions
SET note = CASE
    WHEN type = 'income' THEN 'รายรับ'
    WHEN source = 'dream_saving' THEN 'เงินออม'
    ELSE 'รายจ่าย'
END
WHERE note IS NULL OR TRIM(note) = '';
