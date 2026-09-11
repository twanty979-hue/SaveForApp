-- ==============================================================================
-- Migration: 006_fix_auth_profile_trigger.sql
-- Description: ป้องกัน Duplicate Key Error ตอนล็อกอินด้วย Social Auth (Apple / Google)
--              เมื่อผู้ใช้มีโปรไฟล์อยู่แล้ว โดยใช้ ON CONFLICT DO UPDATE
--              และจำกัด Trigger ให้ทำงานเฉพาะตอน INSERT เท่านั้น
-- ==============================================================================

-- 1. ปรับปรุงฟังก์ชัน handle_new_user ให้รองรับกรณีมี Profile อยู่แล้ว (Upsert)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', 'ผู้ใช้งาน SaveFor'),
    new.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO UPDATE SET
    display_name = COALESCE(EXCLUDED.display_name, public.profiles.display_name),
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
    updated_at = now();
  RETURN NEW;
END;
$$;

-- 2. ตั้งค่า Trigger on_auth_user_created ให้ทำงานเฉพาะตอนสร้างบัญชีใหม่ (INSERT) เท่านั้น ไม่รันซ้ำตอน UPDATE
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
