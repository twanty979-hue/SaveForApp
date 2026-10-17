"use client";

import React, { useState } from "react";
import Link from "next/link";
import Image from "next/image";

export default function DeleteAccountPage() {
  const [email, setEmail] = useState("");
  const [reason, setReason] = useState("");
  const [isSubmitted, setIsSubmitted] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return;
    setIsSubmitted(true);
  };

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
      <main className="max-w-3xl mx-auto px-4 py-12">
        <div className="bg-white rounded-3xl p-6 sm:p-10 border border-[#E8E2CB] shadow-sm space-y-8">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-red-600 bg-red-50 px-3 py-1 rounded-full border border-red-200">
              Account Management
            </span>
            <h1 className="text-2xl sm:text-3xl font-extrabold text-[#1A2412] mt-3 mb-2">
              การขอลบบัญชีผู้ใช้ (Account Deletion)
            </h1>
            <p className="text-sm text-[#4A5568]">
              ตามข้อกำหนดของ Apple App Store และ Google Play Store คุณมีสิทธิในการขอลบบัญชีและข้อมูลส่วนบุคคลทั้งหมดของคุณอย่างถาวร
            </p>
          </div>

          {/* Option 1: In-App */}
          <div className="p-6 rounded-2xl bg-[#FAFDF5] border border-[#E2EFCF] space-y-3">
            <h2 className="text-base font-bold text-[#5A8238] flex items-center gap-2">
              <svg className="w-5 h-5 text-[#5A8238]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
              </svg>
              <span>วิธีที่ 1: ลบบัญชีได้ทันทีผ่านแอป เงินมานี่ (แนะนำ)</span>
            </h2>
            <ol className="list-decimal pl-5 text-sm text-[#2E451C] space-y-1.5">
              <li>เปิดแอปพลิเคชัน <strong>เงินมานี่</strong> บนโทรศัพท์มือถือของคุณ</li>
              <li>ไปที่แท็บ <strong>&ldquo;ตั้งค่า&rdquo; (Settings)</strong> ที่แถบเมนูด้านล่าง</li>
              <li>แตะที่หัวข้อ <strong>&ldquo;โปรไฟล์และการจัดการบัญชี&rdquo;</strong></li>
              <li>เลื่อนลงมาด้านล่างสุด แล้วแตะ <strong>&ldquo;ขอลบบัญชีผู้ใช้&rdquo;</strong></li>
              <li>ยืนยันการลบบัญชี ข้อมูลทั้งหมดจะถูกลบทันที</li>
            </ol>
          </div>

          {/* Option 2: Web Form */}
          <div className="p-6 rounded-2xl bg-white border border-[#E8E2CB] shadow-xs space-y-4">
            <h2 className="text-base font-bold text-[#1A2412] flex items-center gap-2">
              <svg className="w-5 h-5 text-[#1A2412]" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
              </svg>
              <span>วิธีที่ 2: ส่งคำร้องขอลบบัญชีผ่านแบบฟอร์มนี้</span>
            </h2>
            <p className="text-xs text-[#718096]">
              หากคุณได้ลบแอปไปแล้วหรือไม่สะดวกเข้าใช้งานแอป สามารถกรอกอีเมลที่ใช้ลงทะเบียนเพื่อให้ทีมงานดำเนินการลบบัญชีให้คุณ
            </p>

            {isSubmitted ? (
              <div className="p-6 rounded-2xl bg-[#E2EFCF] border border-[#C5DCAB] text-center space-y-2">
                <div className="w-12 h-12 rounded-full bg-[#5A8238] text-white flex items-center justify-center mx-auto">
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <h3 className="font-bold text-base text-[#1A2412]">
                  ได้รับคำร้องขอลบบัญชีของคุณเรียบร้อยแล้ว
                </h3>
                <p className="text-xs text-[#4A5568]">
                  ทีมงานจะดำเนินการตรวจสอบและลบข้อมูลของคุณออกจากระบบภายใน 48 ชั่วโมง และจะส่งอีเมลยืนยันไปยัง {email}
                </p>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-bold text-[#1A2412] mb-1.5">
                    อีเมลที่ใช้ลงทะเบียนใน เงินมานี่ <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="name@example.com"
                    className="w-full px-4 py-3 rounded-xl border border-[#CBD5E1] text-sm focus:outline-none focus:ring-2 focus:ring-[#7EA459] bg-[#FAF7E8]/40"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-[#1A2412] mb-1.5">
                    เหตุผลที่ต้องการลบบัญชี (ไม่บังคับ)
                  </label>
                  <textarea
                    rows={3}
                    value={reason}
                    onChange={(e) => setReason(e.target.value)}
                    placeholder="บอกเหตุผลหรือข้อเสนอแนะเพื่อให้เราพัฒนาแอปให้ดียิ่งขึ้น..."
                    className="w-full px-4 py-2.5 rounded-xl border border-[#CBD5E1] text-sm focus:outline-none focus:ring-2 focus:ring-[#7EA459] bg-[#FAF7E8]/40"
                  />
                </div>

                <div className="p-3 bg-red-50 rounded-xl border border-red-100 text-xs text-red-700 flex items-start gap-2">
                  <svg className="w-4 h-4 text-red-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                  <span>คำเตือน: เมื่อบัญชีถูกลบ ประวัติรายรับ-รายจ่าย เป้าหมายกระปุกเงิน และข้อมูลทั้งหมดจะไม่สามารถกู้คืนได้</span>
                </div>

                <button
                  type="submit"
                  className="w-full py-3 bg-red-600 hover:bg-red-700 text-white rounded-xl text-sm font-bold shadow-sm transition-all"
                >
                  ยืนยันการส่งคำร้องขอลบบัญชี
                </button>
              </form>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
