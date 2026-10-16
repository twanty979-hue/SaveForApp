import React from "react";
import Link from "next/link";
import Image from "next/image";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "นโยบายความเป็นส่วนตัว (Privacy Policy) • เงินมานี่ (NgenManee)",
  description:
    "นโยบายความเป็นส่วนตัวของแอปพลิเคชัน เงินมานี่ อธิบายถึงการเก็บรวบรวม ใช้ และปกป้องข้อมูลส่วนบุคคลของคุณอย่างปลอดภัย",
};

export default function PrivacyPolicyPage() {
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
              Legal & Privacy
            </span>
            <h1 className="text-2xl sm:text-3xl font-extrabold text-[#1A2412] mt-3 mb-2">
              นโยบายความเป็นส่วนตัว (Privacy Policy)
            </h1>
            <p className="text-xs text-[#718096]">
              มีผลบังคับใช้ตั้งแต่วันที่ 1 มกราคม 2569 • ปรับปรุงล่าสุดเดือนตุลาคม 2569
            </p>
          </div>

          <div className="space-y-6 text-sm leading-relaxed text-[#4A5568]">
            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                1. บทนำและความมุ่งมั่นของเรา
              </h2>
              <p>
                แอปพลิเคชัน <strong>เงินมานี่ (NgenManee)</strong> หรือ <strong>SaveFor</strong> (ต่อไปนี้จะเรียกว่า &ldquo;เรา&rdquo;)
                ให้ความสำคัญสูงสุดกับการคุ้มครองข้อมูลส่วนบุคคลและความเป็นส่วนตัวของคุณ
                นโยบายนี้จัดทำขึ้นเพื่อให้คุณเข้าใจถึงลักษณะข้อมูลที่เราเก็บรวบรวม วัตถุประสงค์ในการนำไปใช้
                และการรักษาความปลอดภัยของข้อมูลตามพระราชบัญญัติคุ้มครองข้อมูลส่วนบุคคล พ.ศ. 2562 (PDPA)
              </p>
            </section>

            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                2. ข้อมูลที่เราเก็บรวบรวม
              </h2>
              <ul className="list-disc pl-5 space-y-1.5">
                <li>
                  <strong>ข้อมูลบัญชีผู้ใช้:</strong> เช่น ชื่อที่แสดง (Display Name), อีเมลแอดเดรส (Email), รูปโปรไฟล์ หรือรหัสผู้ใช้ที่สร้างขึ้นเมื่อคุณลงทะเบียนผ่านระบบอีเมล, Google Sign-In หรือ Apple ID
                </li>
                <li>
                  <strong>ข้อมูลบันทึกทางการเงินส่วนบุคคล:</strong> เช่น รายการรายรับ, รายจ่าย, หมวดหมู่, บันทึกช่วยจำ, และเป้าหมายกระปุกเงินตามฝันที่คุณบันทึกในแอป
                </li>
                <li>
                  <strong>รูปภาพสลิปสำหรับการประมวลผล (Slip OCR):</strong> เมื่อคุณใช้ฟังก์ชันสแกนสลิป รูปภาพสลิปจะถูกส่งไปประมวลผลการอ่านข้อความ (OCR) อย่างปลอดภัย และจะไม่มีการนำภาพสลิปไปเผยแพร่หรือส่งต่อให้บุคคลภายนอก
                </li>
                <li>
                  <strong>ข้อมูลทางเทคนิคและการใช้งาน:</strong> เช่น รุ่นของอุปกรณ์, ระบบปฏิบัติการ (iOS / Android), ข้อมูลบันทึกข้อผิดพลาด (Crash Logs) เพื่อใช้ในการปรับปรุงเสถียรภาพของแอป
                </li>
              </ul>
            </section>

            <section className="space-y-2 bg-[#FAFDF5] border border-[#E2EFCF] p-4 rounded-2xl">
              <h2 className="text-base font-bold text-[#5A8238] flex items-center gap-2">
                <span>🛡️</span> ข้อสำคัญ: สิ่งที่เรา &ldquo;ไม่เก็บรวบรวมอย่างเด็ดขาด&rdquo;
              </h2>
              <p className="text-[#2E451C]">
                เราไม่มีการเข้าถึงบัญชีธนาคารของคุณ ไม่มีการขอชื่อผู้ใช้งานหรือรหัสผ่านธนาคาร (Internet Banking / Mobile Banking PIN)
                และไม่มีการเชื่อมต่อ API เพื่อทำธุรกรรมการเงินใดๆ เงินมานี่ เป็นเพียงเครื่องมือสมุดบันทึกรายรับ-รายจ่ายส่วนบุคคลเท่านั้น
              </p>
            </section>

            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                3. วัตถุประสงค์ในการใช้ข้อมูล
              </h2>
              <p>เรานำข้อมูลของคุณไปใช้เพื่อวัตถุประสงค์ดังต่อไปนี้เท่านั้น:</p>
              <ul className="list-disc pl-5 space-y-1">
                <li>เพื่อแสดงผลยอดเงิน รายรับ-รายจ่าย และสถิติทางการเงินภายในบัญชีของคุณ</li>
                <li>เพื่อซิงค์ข้อมูลข้ามอุปกรณ์เมื่อคุณเข้าสู่ระบบด้วยบัญชีเดียวกัน</li>
                <li>เพื่อตรวจสอบสถานะการสมัครสมาชิก SaveFor PRO ผ่านระบบของ Apple App Store, Google Play Store และ RevenueCat</li>
                <li>เพื่อแก้ไขปัญหาและพัฒนาระบบให้ดียิ่งขึ้น</li>
              </ul>
            </section>

            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                4. การรักษาความมั่นคงปลอดภัยของข้อมูล
              </h2>
              <p>
                ข้อมูลของคุณได้รับการปกป้องด้วยมาตรฐานความปลอดภัยระดับสูง การสื่อสารทั้งหมดระหว่างแอปพลิเคชันกับเซิร์ฟเวอร์
                ถูกเข้ารหัสด้วยโปรโตคอล TLS/SSL (HTTPS) และข้อมูลในฐานข้อมูลได้รับการปกป้องด้วยสิทธิ์การเข้าถึงอย่างเข้มงวด
                นอกจากนี้ แอปยังรองรับการเข้ารหัสข้อมูลในเครื่องด้วยระบบชีวมิติ (Face ID / Touch ID / PIN)
              </p>
            </section>

            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                5. สิทธิของคุณในฐานะเจ้าของข้อมูล (Data Subject Rights)
              </h2>
              <p>คุณมีสิทธิในการควบคุมข้อมูลของคุณอย่างเต็มที่ ได้แก่:</p>
              <ul className="list-disc pl-5 space-y-1">
                <li>สิทธิในการเข้าถึงและขอรับสำเนาข้อมูลส่วนบุคคลของคุณ</li>
                <li>สิทธิในการแก้ไขข้อมูลให้ถูกต้องและเป็นปัจจุบัน</li>
                <li>
                  สิทธิในการขอลบข้อมูลและบัญชีของคุณอย่างถาวร โดยสามารถดำเนินการได้ทันทีผ่านเมนูในแอป หรือผ่านหน้าเว็บไซต์{" "}
                  <Link href="/delete-account" className="text-[#7EA459] underline font-semibold">
                    /delete-account
                  </Link>
                </li>
              </ul>
            </section>

            <section className="space-y-2">
              <h2 className="text-base font-bold text-[#1A2412]">
                6. การติดต่อเรา
              </h2>
              <p>
                หากคุณมีข้อสงสัย ข้อเสนอแนะ หรือต้องการใช้สิทธิเกี่ยวกับข้อมูลส่วนบุคคลของคุณ
                สามารถติดต่อเราได้ที่:
              </p>
              <div className="p-3 bg-[#FAF7E8] rounded-xl text-xs space-y-1 text-[#4A5568]">
                <p><strong>ทีมพัฒนา เงินมานี่ (NgenManee)</strong></p>
                <p>อีเมล: support@ngenmanee.com</p>
                <p>เว็บไซต์: https://ngenmanee.com</p>
              </div>
            </section>
          </div>
        </div>
      </main>
    </div>
  );
}
