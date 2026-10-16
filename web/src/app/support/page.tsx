import React from "react";
import Link from "next/link";
import Image from "next/image";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "ศูนย์ช่วยเหลือและติดต่อเรา (Support) • เงินมานี่ (NgenManee)",
  description:
    "ศูนย์ช่วยเหลือและบริการลูกค้าสำหรับผู้ใช้งานแอป เงินมานี่ ติดต่อแจ้งปัญหา แนะนำฟีเจอร์ หรือสอบถามข้อมูลเพิ่มเติม",
};

export default function SupportPage() {
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

      {/* Main Container */}
      <main className="max-w-4xl mx-auto px-4 py-12">
        <div className="bg-white rounded-3xl p-6 sm:p-10 border border-[#E8E2CB] shadow-sm space-y-8">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-[#7EA459] bg-[#E2EFCF] px-3 py-1 rounded-full">
              Customer Support
            </span>
            <h1 className="text-2xl sm:text-3xl font-extrabold text-[#1A2412] mt-3 mb-2">
              ศูนย์ช่วยเหลือและติดต่อทีมงาน
            </h1>
            <p className="text-sm text-[#4A5568]">
              ทีมงาน เงินมานี่ พร้อมช่วยเหลือและดูแลคุณในทุกปัญหาการใช้งาน
            </p>
          </div>

          {/* Quick Contact Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
            <div className="p-6 rounded-2xl bg-[#FAFDF5] border border-[#E2EFCF] space-y-3">
              <div className="w-12 h-12 rounded-xl bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
              </div>
              <h3 className="font-bold text-base text-[#1A2412]">
                ติดต่อผ่านอีเมล
              </h3>
              <p className="text-xs text-[#4A5568] leading-relaxed">
                ส่งรายละเอียดปัญหา พร้อมภาพหน้าจอ (ถ้ามี) มาที่อีเมลฝ่ายบริการลูกค้า
              </p>
              <a
                href="mailto:support@ngenmoney.com"
                className="inline-block text-sm font-bold text-[#7EA459] hover:underline"
              >
                support@ngenmoney.com
              </a>
              <div className="text-[11px] text-[#718096]">
                ตอบกลับภายใน 24 ชั่วโมง (วันทำการ จันทร์-ศุกร์)
              </div>
            </div>

            <div className="p-6 rounded-2xl bg-[#FAFDF5] border border-[#E2EFCF] space-y-3">
              <div className="w-12 h-12 rounded-xl bg-[#FFE6CE] text-[#D9652B] flex items-center justify-center">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </div>
              <h3 className="font-bold text-base text-[#1A2412]">
                การจัดการบัญชี / ขอลบบัญชี
              </h3>
              <p className="text-xs text-[#4A5568] leading-relaxed">
                หากคุณต้องการลบบัญชีและข้อมูลทั้งหมดออกจากระบบ สามารถทำรายการด้วยตนเองได้ทันที
              </p>
              <Link
                href="/delete-account"
                className="inline-block text-sm font-bold text-[#D9652B] hover:underline"
              >
                ไปยังหน้าขอลบบัญชี →
              </Link>
              <div className="text-[11px] text-[#718096]">
                ข้อมูลจะถูกลบออกจากเซิร์ฟเวอร์ทันที
              </div>
            </div>
          </div>

          {/* Tips for fast resolution */}
          <div className="p-5 rounded-2xl bg-[#FAF7E8] border border-[#E8E2CB] space-y-3">
            <h3 className="font-bold text-sm text-[#1A2412] flex items-center gap-2">
              <svg className="w-4 h-4 text-[#7EA459]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>ข้อมูลที่ควรเตรียมเพื่อให้ตรวจสอบได้รวดเร็วยิ่งขึ้น</span>
            </h3>
            <ul className="list-disc pl-5 text-xs text-[#4A5568] space-y-1.5">
              <li>อีเมลที่คุณใช้เข้าสู่ระบบในแอป เงินมานี่</li>
              <li>รุ่นของโทรศัพท์มือถือและเวอร์ชันของระบบปฏิบัติการ (เช่น iPhone 15, iOS 18 หรือ Samsung Galaxy S24, Android 14)</li>
              <li>เวอร์ชันของแอป เงินมานี่ ที่กำลังใช้งาน (ดูได้ที่หน้า ตั้งค่า &gt; เกี่ยวกับแอป)</li>
              <li>ภาพถ่ายหน้าจอ (Screenshot) หรือข้อความแจ้งเตือนข้อผิดพลาดที่พบ</li>
            </ul>
          </div>
        </div>
      </main>
    </div>
  );
}
