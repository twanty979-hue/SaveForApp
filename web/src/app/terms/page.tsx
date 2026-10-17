import React from "react";
import Link from "next/link";
import Image from "next/image";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "เงื่อนไขการใช้งาน (Terms of Use / EULA) • เงินมานี่ (NgenManee)",
  description:
    "ข้อกำหนดและเงื่อนไขการใช้งานแอปพลิเคชัน เงินมานี่ รวมถึงข้อตกลงใบอนุญาตใช้งาน (EULA) และรายละเอียดแพ็กเกจสมาชิก SaveFor PRO",
};

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-[#FAF7E8] text-[#2D3748]">
      {/* Header */}
      <header className="bg-white/80 backdrop-blur-md border-b border-[#E8E2CB] sticky top-0 z-40">
        <div className="max-w-4xl mx-auto px-4 h-16 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2.5">
            <Image
              src="/images/logo_blue.png"
              alt="เงินมานี่"
              width={32}
              height={32}
              className="rounded-lg border border-[#E2EFCF]"
            />
            <span className="font-bold text-[#1A2412] text-lg">เงินมานี่</span>
          </Link>
          <Link
            href="/"
            className="text-xs font-semibold text-[#5A8238] hover:text-[#7EA459] bg-[#E2EFCF] px-3 py-1.5 rounded-full transition-colors"
          >
            ← กลับหน้าหลัก
          </Link>
        </div>
      </header>

      {/* Content */}
      <main className="max-w-4xl mx-auto px-4 py-12">
        <div className="bg-white rounded-3xl p-6 sm:p-10 border border-[#E8E2CB] shadow-sm space-y-8">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-[#7EA459] bg-[#E2EFCF] px-3 py-1 rounded-full">
              Terms & Conditions
            </span>
            <h1 className="text-2xl sm:text-3xl font-extrabold text-[#1A2412] mt-3 mb-2">
              ข้อกำหนดและเงื่อนไขการใช้งาน (Terms of Use / EULA)
            </h1>
            <p className="text-xs text-[#718096]">
              มีผลบังคับใช้ตั้งแต่วันที่ 1 มกราคม 2569 • ปรับปรุงล่าสุดเดือนตุลาคม 2569
            </p>
          </div>

          <div className="space-y-6 text-sm leading-relaxed text-[#4A5568]">
            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                1. การยอมรับข้อกำหนด
              </h2>
              <p>
                การดาวน์โหลด ติดตั้ง หรือใช้งานแอปพลิเคชัน <strong>เงินมานี่ (NgenManee)</strong> หรือ <strong>SaveFor</strong> ถือว่าคุณได้อ่าน เข้าใจ และตกลงที่จะปฏิบัติตามข้อกำหนดและเงื่อนไขเหล่านี้
                หากคุณไม่เห็นด้วยกับข้อกำหนดใดๆ โปรดยุติการใช้งานและถอนการติดตั้งแอปพลิเคชัน
              </p>
            </section>

            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                2. ขอบเขตการให้บริการ
              </h2>
              <p>
                เงินมานี่ ให้บริการเครื่องมือช่วยบันทึกรายรับ-รายจ่าย สแกนสลิปโอนเงิน และจัดระเบียบเป้าหมายการเงินส่วนบุคคล
                ข้อมูลและรายงานสรุปผลทั้งหมดที่ปรากฏในแอปเป็นเพียงเครื่องมือช่วยอำนวยความสะดวกในการจัดสรรเงินเท่านั้น
                <strong>ไม่ใช่คำแนะนำทางการเงิน กฎหมาย หรือการลงทุนเฉพาะบุคคล</strong>
              </p>
            </section>

            {/* In-App Purchase & EULA Section */}
            <section className="space-y-3 bg-[#FAFDF5] border border-[#E2EFCF] p-5 rounded-2xl">
              <h2 className="text-base font-bold text-[#5A8238] flex items-center gap-2">
                <svg className="w-5 h-5 text-[#5A8238]" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
                <span>3. แพ็กเกจสมาชิกแบบต่ออายุอัตโนมัติ (Auto-Renewable Subscriptions)</span>
              </h2>
              <p>
                แอปพลิเคชัน เงินมานี่ มีการให้บริการสมาชิกพรีเมียมในชื่อ <strong>SaveFor PRO</strong> โดยมีเงื่อนไขดังต่อไปนี้:
              </p>
              <ul className="list-disc pl-5 space-y-2 text-xs sm:text-sm text-[#2E451C]">
                <li>
                  <strong>แพ็กเกจรายเดือน (Monthly):</strong> ค่าบริการ ฿35 ต่อเดือน
                </li>
                <li>
                  <strong>แพ็กเกจรายปี (Yearly):</strong> ค่าบริการ ฿350 ต่อปี (เฉลี่ยเพียงเดือนละ ฿29.17)
                </li>
                <li>
                  <strong>การเรียกเก็บเงิน:</strong> การชำระเงินจะถูกเรียกเก็บผ่านบัญชี Apple ID หรือ Google Play Store ของคุณเมื่อยืนยันการสั่งซื้อ
                </li>
                <li>
                  <strong>การต่ออายุอัตโนมัติ:</strong> การสมัครสมาชิกจะต่ออายุโดยอัตโนมัติเว้นแต่คุณจะปิดการต่ออายุอัตโนมัติอย่างน้อย 24 ชั่วโมงก่อนสิ้นสุดรอบระยะเวลาปัจจุบัน
                </li>
                <li>
                  <strong>การยกเลิกการสมัครสมาชิก:</strong> คุณสามารถจัดการหรือยกเลิกการต่ออายุสมาชิกได้ตลอดเวลาผ่านการตั้งค่าบัญชี Apple ID (Settings &gt; Apple ID &gt; Subscriptions) หรือ Google Play (Play Store &gt; Subscriptions)
                </li>
              </ul>
              <div className="pt-2 border-t border-[#D5E8BC] text-xs">
                <span>สำหรับผู้ใช้งานบนระบบปฏิบัติการ iOS ข้อตกลงนี้อ้างอิงตาม </span>
                <a
                  href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-[#7EA459] font-bold underline"
                >
                  Apple Standard End User License Agreement (EULA)
                </a>
              </div>
            </section>

            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                4. หน้าที่และความรับผิดชอบของผู้ใช้
              </h2>
              <ul className="list-disc pl-5 space-y-1">
                <li>คุณมีหน้าที่รักษาความปลอดภัยของบัญชีผู้ใช้และรหัสผ่านของคุณ</li>
                <li>ห้ามใช้งานแอปพลิเคชันเพื่อกิจกรรมที่ผิดกฎหมาย หรือส่งผลกระทบต่อความมั่นคงของระบบ</li>
                <li>คุณเป็นผู้รับผิดชอบต่อความถูกต้องของข้อมูลรายรับ-รายจ่ายที่ป้อนเข้าสู่ระบบ</li>
              </ul>
            </section>

            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                5. การจำกัดความรับผิด
              </h2>
              <p>
                เรามุ่งมั่นพัฒนาแอปให้ทำงานอย่างมีเสถียรภาพและแม่นยำสูงสุด อย่างไรก็ตาม เราไม่รับประกันว่าการให้บริการจะปราศจากข้อผิดพลาด 100%
                และเราจะไม่รับผิดชอบต่อความเสียหายใดๆ ที่เกิดขึ้นจากการตีความข้อมูล หรือการตัดสินใจทางการเงินส่วนบุคคลของคุณ
              </p>
            </section>

            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                6. การติดต่อฝ่ายสนับสนุน
              </h2>
              <p>
                หากมีข้อสงสัยเกี่ยวกับเงื่อนไขการใช้งานหรือต้องการความช่วยเหลือ กรุณาติดต่อทีมงานได้ที่{" "}
                <a href="mailto:support@ngenmoney.com" className="text-[#7EA459] font-semibold underline">
                  support@ngenmoney.com
                </a>
              </p>
            </section>
          </div>
        </div>
      </main>
    </div>
  );
}
