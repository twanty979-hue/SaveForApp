"use client";

import React, { useState, useEffect, useRef } from "react";
import Image from "next/image";
import Link from "next/link";
import { IPhone17ProMax } from "@/components/IPhone17ProMax";

interface ChatMessageItem {
  id: string;
  role: "user" | "bot" | "card" | "typing";
  text?: string;
  category?: "expense" | "income" | "savings";
  title?: string;
  amount?: string;
  date: string;
  subtitle?: string;
}

interface ScreenTab {
  id: string;
  label: string;
  title: string;
  desc: string;
}

const screenTabs: ScreenTab[] = [
  {
    id: "chat",
    label: "จดบันทึกสด (แชท)",
    title: "บันทึกง่ายสไตล์แชทสมุดโน้ต",
    desc: "พิมพ์รายการลงบัญชีง่ายเหมือนคุยแชท แสดงยอดใช้จ่ายวันนี้และเดือนนี้บนหัวบิลแบบเรียลไทม์",
  },
  {
    id: "slip",
    label: "สแกนสลิปอัจฉริยะ",
    title: "อ่านสลิปธนาคารอัตโนมัติ 16 ใบเสร็จในคลิกเดียว",
    desc: "ดึงยอดเงิน วันที่ และแยกธนาคาร (กสิกร, ไทยพาณิชย์, พร้อมเพย์) พร้อมบันทึกลงบัญชีทันที",
  },
  {
    id: "dreams",
    label: "กระปุกเงินตามฝัน",
    title: "รายการที่ตั้งไว้ & ออมเงินตามเป้าหมาย",
    desc: "สร้างเป้าหมายเก็บเงินสำหรับบ้านหรือมอเตอร์ไซค์ พร้อมแถบความคืบหน้าคำนวณระยะเวลาออมให้อัตโนมัติ",
  },
  {
    id: "dashboard",
    label: "แดชบอร์ดการเงิน",
    title: "แดชบอร์ดสรุปภาพรวมและกระแสเงินสด",
    desc: "กราฟวงแหวนวิเคราะห์รายรับ-รายจ่าย อัตราการออม และค่าใช้จ่ายเฉลี่ยต่อวัน รู้ทันทีว่าเงินรั่วไหลไปกับอะไร",
  },
];

const supportedBanks = [
  { name: "กสิกรไทย (K-Bank)", logo: "/images/banks/kbank.png" },
  { name: "ไทยพาณิชย์ (SCB)", logo: "/images/banks/scb.png" },
  { name: "กรุงไทย (KTB)", logo: "/images/banks/ktb.png" },
  { name: "กรุงเทพ (BBL)", logo: "/images/banks/bbl.png" },
  { name: "กรุงศรีอยุธยา (BAY)", logo: "/images/banks/bay.png" },
  { name: "ทีทีบี (ttb)", logo: "/images/banks/ttb.png" },
  { name: "ออมสิน (GSB)", logo: "/images/banks/gsb.png" },
  { name: "พร้อมเพย์ (PromptPay)", logo: "/images/banks/promptpay.png" },
];

const faqs = [
  {
    q: "แอป เงินมานี่ (NgenManee) ใช้งานฟรีไหม?",
    a: "ใช้งานฟรีได้ตลอดชีพครับ ฟีเจอร์หลักทั้งการจดบันทึกรายรับ-รายจ่ายสไตล์แชท, สแกนสลิปโอนเงินจากอัลบั้ม, และการสร้างเป้าหมายเงินออม สามารถใช้งานได้ฟรีครบถ้วน และมีแพ็กเกจ SaveFor PRO (เริ่มต้นเพียงเดือนละ ฿35 หรือรายปี ฿350) สำหรับผู้ที่ต้องการสแกนสลิปไม่จำกัดและปลดล็อกฟังก์ชันขั้นสูง",
  },
  {
    q: "แอปสามารถดึงเงินจากบัญชีธนาคารของผู้ใช้ได้หรือไม่?",
    a: "ไม่มีทางและทำไม่ได้แน่นอนครับ เงินมานี่ เป็นเพียงสมุดบันทึกรายรับ-รายจ่ายส่วนบุคคล ไม่มีการขอรหัสผ่านธนาคาร ไม่มีการเชื่อมต่อ API สั่งโอนเงิน ข้อมูลธุรกรรมเกิดขึ้นจากการสแกนภาพสลิปที่คุณโอนเงินเสร็จแล้ว หรือการพิมพ์ข้อความบันทึกเองเท่านั้น",
  },
  {
    q: "ระบบสแกนสลิปทำงานอย่างไร รองรับธนาคารใดบ้าง?",
    a: "ระบบใช้เทคโนโลยี Smart OCR สแกนตรวจจับสลิปจากอัลบั้มภาพย้อนหลังได้สูงสุด 60 วัน รองรับทุกธนาคารไทยชั้นนำ เช่น กสิกรไทย, ไทยพาณิชย์, กรุงไทย, กรุงเทพ, กรุงศรีอยุธยา, ออมสิน, ทีทีบี และ PromptPay ดึงยอดเงิน วันที่ และบันทึกให้อัตโนมัติ",
  },
  {
    q: "หากเปลี่ยนโทรศัพท์ ข้อมูลจะหายหรือไม่?",
    a: "ข้อมูลไม่หายครับ เมื่อคุณเข้าสู่ระบบด้วยอีเมล, Google หรือ Apple ID เดิม ข้อมูลรายรับ-รายจ่ายและเป้าหมายที่ตั้งไว้ทั้งหมดจะถูกซิงค์กลับมายังอุปกรณ์ใหม่อัตโนมัติทันที",
  },
  {
    q: "มีระบบล็อคเพื่อความเป็นส่วนตัวหรือไม่?",
    a: "มีครับ เงินมานี่ รองรับการล็อคด้วย Face ID, Touch ID หรือรหัส PIN พร้อมปุ่มโหมดความเป็นส่วนตัวสำหรับซ่อนตัวเลขยอดเงินในหน้าแรกได้ทันที ไม่ต้องกังวลว่าคนรอบข้างจะมองเห็นยอดเงินของคุณ",
  },
  {
    q: "หากต้องการลบบัญชีและข้อมูลทั้งหมด ทำได้หรือไม่?",
    a: "ทำได้อย่างง่ายดายครับ คุณสามารถกดลบบัญชีได้โดยตรงที่เมนูการตั้งค่าภายในแอป หรือทำรายการผ่านหน้าเว็บ /delete-account ข้อมูลทั้งหมดของคุณจะถูกลบออกจากเซิร์ฟเวอร์อย่างถาวรทันที",
  },
];

export default function LandingPage() {
  const [activeTab, setActiveTab] = useState<number>(0);
  const [openFaq, setOpenFaq] = useState<number | null>(null);

  // Chat typing animation states for Tab 0
  const [typedText, setTypedText] = useState<string>("");
  const [isSending, setIsSending] = useState<boolean>(false);
  const chatContainerRef = useRef<HTMLDivElement>(null);

  const initialChatMessages: ChatMessageItem[] = [
    { id: "init-1", role: "user", text: "ขับไรเดอร์ 800", date: "6 ต.ค. • 13:01" },
    {
      id: "init-2",
      role: "card",
      category: "income",
      title: "เงินเดือน",
      amount: "+฿43",
      date: "10 ต.ค. • 13:49",
      subtitle: "ยอดรับสะสมเดือนนี้ ฿843",
    },
  ];

  const [chatMessages, setChatMessages] = useState<ChatMessageItem[]>(initialChatMessages);
  const [todayExpense, setTodayExpense] = useState<number>(0);

  // Smart Slip modal state & QR interactions
  const [slipModalOpen, setSlipModalOpen] = useState<boolean>(false);
  const [isScanning, setIsScanning] = useState<boolean>(false);
  const [showQrHint, setShowQrHint] = useState<boolean>(false);
  const [slipSaved, setSlipSaved] = useState<boolean>(false);
  const [slipBadgeCount, setSlipBadgeCount] = useState<number>(18);

  const handleOpenSlipModal = () => {
    setShowQrHint(false);
    setSlipSaved(false);
    setIsScanning(true);
    setSlipModalOpen(true);

    // Scanning completes after 1.2s
    setTimeout(() => {
      setIsScanning(false);
    }, 1200);
  };

  const handleSaveSlips = () => {
    setSlipSaved(true);
    setTimeout(() => {
      setSlipModalOpen(false);
      setSlipBadgeCount(2); // Reduced from 18 to 2
      setChatMessages((prev) => [
        ...prev,
        {
          id: `slip-batch-${Date.now()}`,
          role: "card",
          category: "expense",
          title: "สแกนสลิป 16 ใบ",
          amount: "-฿1,602.86",
          date: "เมื่อสักครู่",
          subtitle: "ตรวจจับครบทุกธนาคารไทย (กสิกร, SCB, กรุงไทย, BBL, BAY, ttb, ออมสิน, PromptPay) เรียบร้อย",
        },
      ]);
      setTodayExpense((prev) => prev + 1602);
    }, 600);
  };

  // When activeTab changes to 1 (Smart Slip), show hint then open modal over notebook
  useEffect(() => {
    if (activeTab === 1) {
      setShowQrHint(true);
      const hintTimer = setTimeout(() => {
        setShowQrHint(false);
        handleOpenSlipModal();
      }, 1200);
      return () => clearTimeout(hintTimer);
    } else if (activeTab === 0) {
      setShowQrHint(false);
      setSlipModalOpen(false);
    }
  }, [activeTab]);

  // Scroll ONLY the inner chat container, NEVER scroll the browser window
  useEffect(() => {
    if (chatContainerRef.current) {
      chatContainerRef.current.scrollTo({
        top: chatContainerRef.current.scrollHeight,
        behavior: "smooth",
      });
    }
  }, [chatMessages]);

  // Cycle simulation tabs: 28 seconds for Tab 0 (Live Chat) so the full conversation plays out comfortably, 10s for other tabs
  useEffect(() => {
    const duration = activeTab === 0 ? 28000 : 10000;
    const timer = setTimeout(() => {
      setActiveTab((prev) => (prev + 1) % screenTabs.length);
    }, duration);
    return () => clearTimeout(timer);
  }, [activeTab]);

  // Quick Action Handler for instant interaction
  const handleQuickAction = (
    text: string,
    category: "expense" | "income" | "savings",
    title: string,
    amount: string,
    botReply: string,
    subtitle: string,
    expenseVal?: number
  ) => {
    setTypedText("");
    setIsSending(true);

    setTimeout(() => {
      const userMsgId = `quick-user-${Date.now()}`;
      const typingMsgId = `quick-typing-${Date.now()}`;

      setChatMessages((prev) => [
        ...prev,
        { id: userMsgId, role: "user", text, date: "เมื่อสักครู่" },
      ]);
      setIsSending(false);

      // Typing indicator
      setTimeout(() => {
        setChatMessages((prev) => [
          ...prev,
          { id: typingMsgId, role: "typing", date: "" },
        ]);

        // Bot reply
        setTimeout(() => {
          setChatMessages((prev) => [
            ...prev.filter((m) => m.id !== typingMsgId),
            { id: `quick-bot-${Date.now()}`, role: "bot", text: botReply, date: "เมื่อสักครู่" },
            {
              id: `quick-card-${Date.now()}`,
              role: "card",
              category,
              title,
              amount,
              date: "เมื่อสักครู่",
              subtitle,
            },
          ]);
          if (expenseVal !== undefined && expenseVal > 0) {
            setTodayExpense((prev) => prev + expenseVal);
          }
        }, 900);
      }, 350);
    }, 200);
  };

  const handleManualSend = () => {
    if (!typedText.trim()) return;
    const text = typedText.trim();
    const num = parseInt(text.match(/\d+/)?.[0] || "100", 10);
    const isIncome = text.includes("เงินเดือน") || text.includes("รับ") || text.includes("ได้");
    const isSavings = text.includes("ออม") || text.includes("กระปุก") || text.includes("บ้าน") || text.includes("มอไซ");

    if (isSavings) {
      handleQuickAction(
        text,
        "savings",
        text,
        `+฿${num.toLocaleString()}`,
        `หยอดกระปุก '${text}' ฿${num.toLocaleString()} สำเร็จแล้วครับ`,
        "เป้าหมายเงินออมคืบหน้าอย่างต่อเนื่อง"
      );
    } else if (isIncome) {
      handleQuickAction(
        text,
        "income",
        text,
        `+฿${num.toLocaleString()}`,
        `บันทึกรายรับ '${text}' ฿${num.toLocaleString()} เข้ากระเป๋าเรียบร้อยครับ`,
        "ยอดรับสะสมเดือนนี้เพิ่มขึ้น"
      );
    } else {
      handleQuickAction(
        text,
        "expense",
        text,
        `-฿${num.toLocaleString()}`,
        `บันทึกรายจ่าย '${text}' ฿${num.toLocaleString()} เรียบร้อยครับ`,
        "หมวดหมู่ทั่วไป • บันทึกสำเร็จ",
        num
      );
    }
  };

  // Animate multi-step chat typing & bot responses when Tab 0 is active
  useEffect(() => {
    if (activeTab !== 0) return;

    setChatMessages(initialChatMessages);
    setTodayExpense(0);
    setTypedText("");
    setIsSending(false);

    const timeouts: NodeJS.Timeout[] = [];
    let currentInterval: NodeJS.Timeout | null = null;

    // Step 1: Type "กินชาบู 350" at t = 1200ms
    const phrase1 = "กินชาบู 350";
    timeouts.push(
      setTimeout(() => {
        let idx = 0;
        currentInterval = setInterval(() => {
          if (idx < phrase1.length) {
            setTypedText(phrase1.slice(0, idx + 1));
            idx++;
          } else {
            if (currentInterval) clearInterval(currentInterval);
            // Step 2: Send message
            timeouts.push(
              setTimeout(() => {
                setIsSending(true);
                timeouts.push(
                  setTimeout(() => {
                    setChatMessages((prev) => [
                      ...prev,
                      { id: "user-1", role: "user", text: "กินชาบู 350", date: "เมื่อสักครู่" },
                    ]);
                    setTypedText("");
                    setIsSending(false);

                    // Step 3: Bot typing indicator
                    timeouts.push(
                      setTimeout(() => {
                        setChatMessages((prev) => [
                          ...prev,
                          { id: "typing-1", role: "typing", date: "" },
                        ]);

                        // Step 4: Bot replies with text + expense card
                        timeouts.push(
                          setTimeout(() => {
                            setChatMessages((prev) => [
                              ...prev.filter((m) => m.id !== "typing-1"),
                              {
                                id: "bot-1",
                                role: "bot",
                                text: "บันทึกรายจ่าย 'กินชาบู' เรียบร้อยครับ",
                                date: "เมื่อสักครู่",
                              },
                              {
                                id: "card-1",
                                role: "card",
                                category: "expense",
                                title: "กินชาบู",
                                amount: "-฿350",
                                date: "เมื่อสักครู่",
                                subtitle: "หมวดอาหารและเครื่องดื่ม • วันนี้รวม ฿350",
                              },
                            ]);
                            setTodayExpense(350);

                            // Step 5: Pause to read, then start typing Message 2
                            timeouts.push(
                              setTimeout(() => {
                                const phrase2 = "ออมเงินมอไซ 500";
                                let idx2 = 0;
                                currentInterval = setInterval(() => {
                                  if (idx2 < phrase2.length) {
                                    setTypedText(phrase2.slice(0, idx2 + 1));
                                    idx2++;
                                  } else {
                                    if (currentInterval) clearInterval(currentInterval);
                                    // Send second message
                                    timeouts.push(
                                      setTimeout(() => {
                                        setIsSending(true);
                                        timeouts.push(
                                          setTimeout(() => {
                                            setChatMessages((prev) => [
                                              ...prev,
                                              { id: "user-2", role: "user", text: "ออมเงินมอไซ 500", date: "เมื่อสักครู่" },
                                            ]);
                                            setTypedText("");
                                            setIsSending(false);

                                            // Bot typing indicator 2
                                            timeouts.push(
                                              setTimeout(() => {
                                                setChatMessages((prev) => [
                                                  ...prev,
                                                  { id: "typing-2", role: "typing", date: "" },
                                                ]);

                                                // Bot reply 2: text + savings card
                                                timeouts.push(
                                                  setTimeout(() => {
                                                    setChatMessages((prev) => [
                                                      ...prev.filter((m) => m.id !== "typing-2"),
                                                      {
                                                        id: "bot-2",
                                                        role: "bot",
                                                        text: "หยอดกระปุก 'มอไซ' ฿500 สำเร็จ! เป้าหมายถึง 55% แล้วครับ",
                                                        date: "เมื่อสักครู่",
                                                      },
                                                      {
                                                        id: "card-2",
                                                        role: "card",
                                                        category: "savings",
                                                        title: "หยอดกระปุกมอไซ",
                                                        amount: "+฿500",
                                                        date: "เมื่อสักครู่",
                                                        subtitle: "กระปุกมอไซ: ฿27,709 / ฿50,000 (55%)",
                                                      },
                                                    ]);
                                                  }, 1100)
                                                );
                                              }, 450)
                                            );
                                          }, 350)
                                        );
                                      }, 350)
                                    );
                                  }
                                }, 110);
                              }, 3200) // Reading pause between message 1 and 2
                            );
                          }, 1100)
                        );
                      }, 450)
                    );
                  }, 350)
                );
              }, 350)
            );
          }
        }, 110);
      }, 1200)
    );

    return () => {
      timeouts.forEach((t) => clearTimeout(t));
      if (currentInterval) clearInterval(currentInterval);
    };
  }, [activeTab]);

  return (
    <div className="min-h-screen bg-[#FAF7E8] text-[#2D3748] selection:bg-[#E2EFCF] selection:text-[#5A8238]">
      {/* Schema.org Structured Data for SEO Rich Snippets */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@graph": [
              {
                "@type": "SoftwareApplication",
                "@id": "https://ngenmoney.com/#app",
                name: "เงินมานี่ (NgenManee)",
                alternateName: ["SaveFor", "เงินมานี่", "NgenManee"],
                applicationCategory: "FinanceApplication",
                applicationSubCategory: "PersonalFinanceApplication",
                operatingSystem: "iOS 15.0+, Android 8.0+",
                offers: {
                  "@type": "Offer",
                  price: "0",
                  priceCurrency: "THB",
                },
                aggregateRating: {
                  "@type": "AggregateRating",
                  ratingValue: "4.9",
                  reviewCount: "128",
                  bestRating: "5",
                  worstRating: "1",
                },
                featureList: [
                  "สแกนสลิปโอนเงินอัตโนมัติจากอัลบั้มย้อนหลัง 60 วัน",
                  "ตรวจจับครบทุกธนาคารไทย (กสิกร, SCB, กรุงไทย, BBL, BAY, ttb, ออมสิน, พร้อมเพย์)",
                  "บันทึกรายรับ-รายจ่ายสไตล์แชทสมุดโน้ต",
                  "กระปุกเงินตามฝันและคำนวณระยะเวลาออม",
                  "วิเคราะห์กระแสเงินสดและอัตราการออมด้วย Donut Chart",
                  "ล็อคความเป็นส่วนตัวด้วย Face ID / Touch ID",
                ],
                description:
                  "แอปบันทึกรายรับ-รายจ่ายที่อบอุ่นและฉลาดที่สุด สแกนสลิปโอนเงินบันทึกอัตโนมัติในพริบตา ตั้งเป้ากระปุกเงินตามฝัน วิเคราะห์สุขภาพการเงิน ปลอดภัยด้วย Face ID และไม่เข้าถึงบัญชีธนาคาร",
                url: "https://ngenmoney.com",
                image: "https://ngenmoney.com/images/logo_blue.png",
                screenshot: "https://ngenmoney.com/images/splash_artwork.png",
                author: {
                  "@type": "Person",
                  "name": "วรธน นำทอง (Worathon Namthong)",
                  "alternateName": ["Worathon Namthong", "วรธน นำทอง", "บอลทาโร่"],
                  "jobTitle": "Founder & CEO (ผู้ก่อตั้งและประธานเจ้าหน้าที่บริหาร)",
                  "url": "https://ngenmoney.com",
                },
                creator: {
                  "@type": "Person",
                  "name": "วรธน นำทอง (Worathon Namthong)",
                  "jobTitle": "Founder & CEO",
                  "url": "https://ngenmoney.com",
                },
                installUrl: [
                  "https://play.google.com/store/apps/details?id=com.savefor.app",
                  "https://apps.apple.com/app/savefor/id6809708026",
                ],
              },
              {
                "@type": "Person",
                "@id": "https://ngenmoney.com/#developer",
                name: "วรธน นำทอง (Worathon Namthong)",
                alternateName: ["Worathon Namthong", "วรธน นำทอง", "บอลทาโร่"],
                jobTitle: "Founder & CEO (ผู้ก่อตั้งและประธานเจ้าหน้าที่บริหาร)",
                url: "https://ngenmoney.com",
                sameAs: [
                  "https://suparpos.com",
                  "https://github.com/twanty979-hue",
                ],
              },
              {
                "@type": "WebSite",
                "@id": "https://ngenmoney.com/#website",
                name: "เงินมานี่ (NgenManee)",
                url: "https://ngenmoney.com",
                description: "เว็บไซต์ทางการของแอปบันทึกรายรับ-รายจ่าย เงินมานี่ (NgenManee) พัฒนาโดย วรธน นำทอง",
                inLanguage: "th-TH",
                publisher: {
                  "@id": "https://ngenmoney.com/#organization",
                },
              },
              {
                "@type": "Organization",
                "@id": "https://ngenmoney.com/#organization",
                name: "เงินมานี่ (NgenManee)",
                url: "https://ngenmoney.com",
                logo: "https://ngenmoney.com/images/logo_blue.png",
                founder: {
                  "@type": "Person",
                  "name": "วรธน นำทอง (Worathon Namthong)",
                  "url": "https://ngenmoney.com",
                },
                contactPoint: {
                  "@type": "ContactPoint",
                  email: "support@ngenmoney.com",
                  contactType: "customer support",
                },
              },
              {
                "@type": "FAQPage",
                "@id": "https://ngenmoney.com/#faq",
                mainEntity: faqs.map((faq) => ({
                  "@type": "Question",
                  name: faq.q,
                  acceptedAnswer: {
                    "@type": "Answer",
                    text: faq.a,
                  },
                })),
              },
            ],
          }),
        }}
      />

      {/* ─────────────────────────────────────────────────────────────
          1. HEADER / NAVBAR
      ───────────────────────────────────────────────────────────── */}
      <header className="sticky top-0 z-50 bg-[#FAF7E8]/90 backdrop-blur-md border-b border-[#E8E2CB]/80 transition-all">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-20 flex items-center justify-between">
          {/* Logo & Brand */}
          <Link href="/" className="flex items-center gap-3 group">
            <div className="w-12 h-12 rounded-2xl bg-white shadow-xs border border-[#E2EFCF] p-1.5 flex items-center justify-center transition-transform group-hover:scale-105">
              <Image
                src="/images/logo_blue.png"
                alt="เงินมานี่ โลโก้"
                width={40}
                height={40}
                className="object-contain rounded-xl"
                priority
              />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xl sm:text-2xl font-bold tracking-tight text-[#1A2412]">
                  เงินมานี่
                </span>
                <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-[#E2EFCF] text-[#5A8238] border border-[#C5DCAB]">
                  ngenmoney.com
                </span>
              </div>
              <p className="text-xs text-[#718096] hidden sm:block">
                สมุดบันทึกรายรับรายจ่าย & กระปุกเงินตามฝัน
              </p>
            </div>
          </Link>

          {/* Nav Links */}
          <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-[#4A5568]">
            <a href="#showcase" className="hover:text-[#7EA459] transition-colors">
              หน้าจอแอปจริง
            </a>
            <a href="#features" className="hover:text-[#7EA459] transition-colors">
              ฟีเจอร์เด่น
            </a>
            <a href="#banks" className="hover:text-[#7EA459] transition-colors">
              ธนาคารที่รองรับ
            </a>
            <a href="#faq" className="hover:text-[#7EA459] transition-colors">
              คำถามที่พบบ่อย
            </a>
          </nav>

          {/* CTA Download Button */}
          <div className="flex items-center gap-3">
            <a
              href="#download"
              className="inline-flex items-center gap-2 bg-[#7EA459] hover:bg-[#5A8238] text-white font-medium text-sm px-5 py-2.5 rounded-full shadow-xs hover:shadow-md transition-all transform hover:-translate-y-0.5 active:translate-y-0"
            >
              <span>ดาวน์โหลดฟรี</span>
              <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
              </svg>
            </a>
          </div>
        </div>
      </header>

      {/* ─────────────────────────────────────────────────────────────
          2. HERO SECTION WITH LIVING ANIMATED APP SIMULATOR
      ───────────────────────────────────────────────────────────── */}
      <section id="showcase" className="relative pt-10 pb-20 sm:pt-16 sm:pb-28 overflow-hidden">
        {/* Soft background aura */}
        <div className="absolute top-10 left-1/2 -translate-x-1/2 w-[700px] h-[350px] bg-gradient-to-r from-[#E2EFCF]/60 via-[#FAF7E8] to-[#FFF3CD]/40 blur-3xl -z-10 rounded-full pointer-events-none" />

        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-8 items-center">
            {/* Left Column: Headlines & Actions */}
            <div className="lg:col-span-7 text-center lg:text-left">
              {/* Badge */}
              <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#E2EFCF] text-[#5A8238] text-xs sm:text-sm font-semibold border border-[#BED7A1] mb-6 shadow-xs">
                <span className="flex h-2 w-2 rounded-full bg-[#7EA459] animate-pulse" />
                <span>แอปบันทึกการเงินสไตล์สมุดโน้ตอบอุ่น • เปิดให้ดาวน์โหลดแล้ว</span>
              </div>

              {/* Headline */}
              <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-[#1A2412] tracking-tight leading-[1.18] mb-6">
                จดง่าย สบายใจ... <br />
                <span className="text-[#7EA459] relative inline-block">
                  ให้เงินไหลมาเทมา
                  <svg
                    className="absolute -bottom-2 left-0 w-full text-[#F5B731]"
                    viewBox="0 0 250 12"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <path d="M3 9C55 3 195 2 247 9" stroke="currentColor" strokeWidth="5" strokeLinecap="round" />
                  </svg>
                </span>
              </h1>

              {/* Subtitle */}
              <p className="text-lg sm:text-xl text-[#4A5568] max-w-xl mx-auto lg:mx-0 leading-relaxed mb-8 font-light">
                บันทึกรายรับ-รายจ่ายผ่านช่องแชทง่ายๆ เหมือนคุยกับเพื่อน สแกนสลิปโอนเงินย้อนหลัง บันทึก 16 ใบเสร็จในคลิกเดียว พร้อมกระปุกเงินตามฝันและแดชบอร์ดการเงินที่ใช้งานง่ายที่สุด
              </p>

              {/* Store Download CTAs */}
              <div className="flex flex-col sm:flex-row items-center justify-center lg:justify-start gap-4 mb-8">
                {/* App Store Button */}
                <a
                  href="https://apps.apple.com/app/savefor/id6809708026"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="w-full sm:w-auto inline-flex items-center justify-center gap-3 bg-[#1A2412] hover:bg-black text-white px-6 py-3.5 rounded-2xl shadow-md hover:shadow-lg transition-all transform hover:-translate-y-0.5 active:translate-y-0"
                >
                  <svg className="w-7 h-7 fill-current" viewBox="0 0 24 24">
                    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.64-.78 1.08-1.86.96-2.95-1 .04-2.16.66-2.83 1.45-.58.68-1.1 1.77-.96 2.84 1.12.09 2.22-.56 2.83-1.34z" />
                  </svg>
                  <div className="text-left">
                    <div className="text-[10px] uppercase tracking-wider text-gray-300 leading-none">
                      Download on the
                    </div>
                    <div className="text-base font-semibold leading-tight">
                      App Store
                    </div>
                  </div>
                </a>

                {/* Google Play Button */}
                <a
                  href="https://play.google.com/store/apps/details?id=com.savefor.app"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="w-full sm:w-auto inline-flex items-center justify-center gap-3 bg-[#1A2412] hover:bg-black text-white px-6 py-3.5 rounded-2xl shadow-md hover:shadow-lg transition-all transform hover:-translate-y-0.5 active:translate-y-0"
                >
                  <svg className="w-7 h-7 fill-current" viewBox="0 0 24 24">
                    <path d="M3.609 1.814L13.793 12 3.61 22.186a2.38 2.38 0 01-.61-.715V2.53c.184-.286.39-.53.61-.716zm11.602 11.604L4.85 23.778c.376.14.796.177 1.229.074.453-.109.873-.34 1.229-.68l10.9-6.242-2.997-3.512zM21.5 10.366l-3.328-1.906-3.418 3.54 3.418 3.54 3.328-1.906c.928-.532 1.499-1.503 1.499-2.634 0-1.131-.571-2.102-1.499-2.634zm-6.289-1.574L7.308.848C6.952.508 6.532.277 6.079.168 5.646.065 5.226.102 4.85.242l10.361 10.36 2.997-1.81z" />
                  </svg>
                  <div className="text-left">
                    <div className="text-[10px] uppercase tracking-wider text-gray-300 leading-none">
                      GET IT ON
                    </div>
                    <div className="text-base font-semibold leading-tight">
                      Google Play
                    </div>
                  </div>
                </a>
              </div>


              {/* Trust Badges */}
              <div className="flex flex-wrap items-center justify-center lg:justify-start gap-6 text-xs text-[#718096]">
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center">
                    <svg className="w-3 h-3" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                  </div>
                  <span>สแกนสลิปทุกธนาคารไทย</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center">
                    <svg className="w-3 h-3" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                  </div>
                  <span>ไม่ขอรหัสผ่านธนาคาร 100%</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center">
                    <svg className="w-3 h-3" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                  </div>
                  <span>ไม่มีโฆษณาคั่นกวนใจ</span>
                </div>
              </div>
            </div>

            {/* Right Column: LIVING ANIMATED APP SIMULATION */}
            <div className="lg:col-span-5 flex flex-col items-center">
              {/* iPhone 17 Pro Max Frame with EXACT Real App UI & Animations */}
              <IPhone17ProMax className="w-[315px] sm:w-[335px]" variant="black">
                {/* Inner Screen Container */}
                <div className="w-full h-full bg-[#FAF7E8] overflow-hidden relative flex flex-col font-sans select-none bg-[linear-gradient(to_right,#EFE9D2_1px,transparent_1px),linear-gradient(to_bottom,#EFE9D2_1px,transparent_1px)] bg-[size:16px_16px]">
                  {/* Status Bar */}
                  <div className="pt-2.5 px-6 pb-1.5 flex items-center justify-between text-[11px] font-semibold text-[#1A2412] z-30">
                    <span>01:08</span>
                    {/* Dynamic Island spacer so text and battery do not collide with the real Dynamic Island */}
                    <div className="w-24 h-4.5" />
                    {/* Signal & Battery */}
                    <div className="flex items-center gap-1 text-[#1A2412]">
                      <svg className="w-3.5 h-3.5 fill-current" viewBox="0 0 24 24">
                        <path d="M12 3c-4.97 0-9 4.03-9 9 0 2.12.74 4.07 1.97 5.61L12 22l7.03-4.39C20.26 16.07 21 14.12 21 12c0-4.97-4.03-9-9-9z" />
                      </svg>
                      <div className="w-5 h-2.5 border border-[#1A2412] rounded-xs p-0.5 flex items-center">
                        <div className="w-2/3 h-full bg-[#1A2412] rounded-2xs" />
                      </div>
                      <span className="text-[9px] font-bold">13</span>
                    </div>
                  </div>

                  {/* ════════════════════════════════════════════════════════════
                      SIMULATED APP SCREENS (EXACT MATCH TO USER SCREENSHOTS)
                  ════════════════════════════════════════════════════════════ */}
                  
                  {/* ──── SCREEN 0 & 1: NOTEBOOK & SMART SLIP SCANNER (UNIFIED) ──── */}
                  {(activeTab === 0 || activeTab === 1) && (
                    <div className="flex-1 flex flex-col justify-between overflow-hidden relative animate-fadeIn">
                      {/* Top Header Card (Exact match to screenshot 1) */}
                      <div className="px-3 pt-1 z-20">
                        <div className="bg-white rounded-2xl p-2.5 border border-[#E8E2CB] shadow-xs flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <div className="w-9 h-9 rounded-full overflow-hidden bg-white border border-[#E2EFCF] p-1 flex items-center justify-center shadow-xs">
                              <Image
                                src="/images/logo_blue.png"
                                alt="เงินมานี่"
                                width={32}
                                height={32}
                                className="w-full h-full object-contain rounded-full"
                              />
                            </div>
                            <div>
                              <div className="text-xs font-bold text-[#1A2412] leading-tight">บอลทาโร่</div>
                              <div className="text-[9px] flex items-center gap-1 text-gray-500 mt-0.5">
                                <span className={`font-semibold ${todayExpense > 0 ? "text-red-500" : "text-red-500"}`}>
                                  วันนี้ ฿{todayExpense}
                                </span>
                                <span>•</span>
                                <span>เดือนนี้ ฿4372</span>
                              </div>
                            </div>
                          </div>

                          {/* Quick Header Actions */}
                          <div className="flex items-center gap-1.5">
                            {/* QR Scanner button with glowing RED badge & guide hint */}
                            <div className="relative">
                              <button
                                onClick={() => {
                                  if (slipModalOpen) {
                                    setSlipModalOpen(false);
                                  } else {
                                    handleOpenSlipModal();
                                  }
                                }}
                                className={`w-8 h-8 rounded-xl bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center relative shadow-2xs hover:scale-105 active:scale-95 transition-all cursor-pointer ${
                                  showQrHint || activeTab === 1
                                    ? "ring-4 ring-[#7EA459]/50 animate-pulse scale-105"
                                    : ""
                                }`}
                                title="แตะเพื่อสแกนสลิป"
                              >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
                                </svg>
                                {slipBadgeCount > 0 && (
                                  <span className="absolute -top-1.5 -right-1.5 bg-red-500 text-white text-[8px] font-black px-1 py-0.2 rounded-full border border-white animate-pulse">
                                    {slipBadgeCount}
                                  </span>
                                )}
                              </button>

                              {/* Pointer Tooltip Hint */}
                              {showQrHint && (
                                <div className="absolute top-10 -right-6 z-30 animate-bounce pointer-events-none">
                                  <div className="bg-[#1A2412] text-white text-[9px] font-bold px-2 py-1 rounded-xl shadow-xl flex items-center gap-1 whitespace-nowrap">
                                    <span className="w-1.5 h-1.5 bg-[#7EA459] rounded-full animate-ping" />
                                    <span>แตะปุ่มนี้เพื่อสแกนสลิป</span>
                                    <svg className="w-2.5 h-2.5 text-[#7EA459]" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 10l7-7m0 0l7 7" />
                                    </svg>
                                  </div>
                                </div>
                              )}
                            </div>

                            <div className="w-8 h-8 rounded-xl bg-gray-50 border border-gray-200 text-gray-600 flex items-center justify-center">
                              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                              </svg>
                            </div>

                            <div className="w-8 h-8 rounded-xl bg-gray-50 border border-gray-200 text-gray-600 flex items-center justify-center relative">
                              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                              </svg>
                              <span className="absolute top-1 right-1 w-1.5 h-1.5 bg-red-500 rounded-full" />
                            </div>

                            <div className="w-8 h-8 rounded-xl bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center">
                              <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                              </svg>
                            </div>
                          </div>
                        </div>
                      </div>

                      {/* Chat Messages Stream */}
                      <div ref={chatContainerRef} className="flex-1 overflow-y-auto px-3 py-2 flex flex-col gap-2.5">
                        {chatMessages.map((msg) => (
                          <React.Fragment key={msg.id}>
                            {/* 1. User Message (Right Green Bubble) */}
                            {msg.role === "user" && (
                              <div className="flex justify-end animate-slide-up flex-shrink-0">
                                <div className="bg-[#6F9745] text-white px-3.5 py-2 rounded-2xl rounded-tr-xs shadow-xs text-right max-w-[210px]">
                                  <div className="text-xs font-bold">{msg.text}</div>
                                  <div className="text-[8px] text-white/80 mt-0.5">{msg.date}</div>
                                </div>
                              </div>
                            )}

                            {/* 2. Bot Message (Left White Bubble with Avatar) */}
                            {msg.role === "bot" && (
                              <div className="flex items-start gap-1.5 animate-slide-up max-w-[240px] flex-shrink-0">
                                <div className="w-6 h-6 rounded-lg bg-white border border-[#E2EFCF] p-0.5 shadow-2xs flex-shrink-0 mt-0.5">
                                  <Image
                                    src="/images/logo_blue.png"
                                    alt="เงินมานี่"
                                    width={20}
                                    height={20}
                                    className="object-contain rounded-md"
                                  />
                                </div>
                                <div className="bg-white border border-[#E8E2CB] text-[#1A2412] px-3 py-2 rounded-2xl rounded-tl-xs shadow-xs text-left">
                                  <div className="text-[11px] font-semibold leading-relaxed text-[#1A2412]">
                                    {msg.text}
                                  </div>
                                  <div className="text-[8px] text-gray-400 mt-0.5">{msg.date}</div>
                                </div>
                              </div>
                            )}

                            {/* 3. Bot Typing Indicator */}
                            {msg.role === "typing" && (
                              <div className="flex items-center gap-1.5 animate-slide-up flex-shrink-0">
                                <div className="w-6 h-6 rounded-lg bg-white border border-[#E2EFCF] p-0.5 shadow-2xs flex-shrink-0">
                                  <Image
                                    src="/images/logo_blue.png"
                                    alt="เงินมานี่"
                                    width={20}
                                    height={20}
                                    className="object-contain rounded-md"
                                  />
                                </div>
                                <div className="bg-white border border-[#E8E2CB] px-3 py-2 rounded-2xl rounded-tl-xs shadow-xs flex items-center gap-1">
                                  <span className="w-1.5 h-1.5 bg-[#7EA459] rounded-full animate-bounce [animation-delay:-0.3s]" />
                                  <span className="w-1.5 h-1.5 bg-[#7EA459] rounded-full animate-bounce [animation-delay:-0.15s]" />
                                  <span className="w-1.5 h-1.5 bg-[#7EA459] rounded-full animate-bounce" />
                                </div>
                              </div>
                            )}

                            {/* 4. Structured Transaction Card */}
                            {msg.role === "card" && (
                              <div className="w-[210px] bg-white rounded-2xl border border-[#D5E3DF] overflow-hidden shadow-xs animate-slide-up flex-shrink-0">
                                <div
                                  className={`p-2 flex items-center justify-between ${
                                    msg.category === "income"
                                      ? "bg-[#E6F5F3]"
                                      : msg.category === "savings"
                                      ? "bg-[#EDE8FD]"
                                      : "bg-[#FEE2E2]"
                                  }`}
                                >
                                  <span
                                    className={`text-[8px] font-bold px-1.5 py-0.5 rounded-full border ${
                                      msg.category === "income"
                                        ? "text-[#10B981] bg-white border-[#A7F3D0]"
                                        : msg.category === "savings"
                                        ? "text-[#7A5AF8] bg-white border-[#DCD2F9]"
                                        : "text-[#EF4444] bg-white border-[#FCA5A5]"
                                    }`}
                                  >
                                    {msg.category === "income"
                                      ? "รายรับ"
                                      : msg.category === "savings"
                                      ? "เงินออม"
                                      : "รายจ่าย"}
                                  </span>
                                  <div className="w-5 h-5 rounded-full bg-white flex items-center justify-center text-gray-500 shadow-2xs">
                                    <svg className="w-2.5 h-2.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                                      <path strokeLinecap="round" strokeLinejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                                    </svg>
                                  </div>
                                </div>
                                <div className="p-2.5">
                                  <div className="flex items-center gap-1.5 mb-1">
                                    <div
                                      className={`w-6 h-6 rounded-lg flex items-center justify-center ${
                                        msg.category === "income"
                                          ? "bg-[#E6F5F3] text-[#10B981]"
                                          : msg.category === "savings"
                                          ? "bg-[#EDE8FD] text-[#7A5AF8]"
                                          : "bg-[#FEE2E2] text-[#EF4444]"
                                      }`}
                                    >
                                      {msg.category === "income" ? (
                                        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                                          <path strokeLinecap="round" strokeLinejoin="round" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
                                        </svg>
                                      ) : msg.category === "savings" ? (
                                        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                                          <path strokeLinecap="round" strokeLinejoin="round" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                        </svg>
                                      ) : (
                                        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                                          <path strokeLinecap="round" strokeLinejoin="round" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" />
                                        </svg>
                                      )}
                                    </div>
                                    <div className="text-[8px] text-gray-400">{msg.date}</div>
                                  </div>
                                  <div className="flex items-center justify-between">
                                    <div className="text-xs font-bold text-[#1A2412] truncate max-w-[110px]">{msg.title}</div>
                                    <div
                                      className={`text-xs font-black ${
                                        msg.category === "income"
                                          ? "text-[#10B981]"
                                          : msg.category === "savings"
                                          ? "text-[#7A5AF8]"
                                          : "text-[#EF4444]"
                                      }`}
                                    >
                                      {msg.amount}
                                    </div>
                                  </div>
                                  {msg.subtitle && (
                                    <div className="text-[8px] text-gray-400 mt-0.5 leading-tight">{msg.subtitle}</div>
                                  )}
                                </div>
                              </div>
                            )}
                          </React.Fragment>
                        ))}
                      </div>

                      {/* Bottom Quick Category Pills */}
                      <div className="px-3 py-1 flex items-center gap-1.5 z-20">
                        <button
                          onClick={() =>
                            handleQuickAction(
                              "ค่าห้อง 3500",
                              "expense",
                              "ค่าห้อง",
                              "-฿3,500",
                              "บันทึกค่าใช้จ่าย 'ค่าห้อง' ฿3,500 เรียบร้อยครับ",
                              "หมวดที่พักอาศัย • บันทึกสำเร็จ",
                              3500
                            )
                          }
                          className="px-2.5 py-1 rounded-xl bg-[#FDE8E8] text-[#E05252] border border-[#FBD5D5] text-[9px] font-bold flex items-center gap-1 shadow-2xs active:scale-95 transition-transform cursor-pointer"
                        >
                          <svg className="w-2.5 h-2.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                          </svg>
                          <span>ค่าห้อง</span>
                        </button>
                        <button
                          onClick={() =>
                            handleQuickAction(
                              "เงินเดือน 25000",
                              "income",
                              "เงินเดือน",
                              "+฿25,000",
                              "ยินดีด้วยครับ! บันทึกรายรับ 'เงินเดือน' ฿25,000 เข้ากระเป๋าแล้วครับ",
                              "ยอดรับสะสมเดือนนี้ ฿25,843",
                              0
                            )
                          }
                          className="px-2.5 py-1 rounded-xl bg-[#E3F5EC] text-[#2E9E66] border border-[#BCF0DA] text-[9px] font-bold flex items-center gap-1 shadow-2xs active:scale-95 transition-transform cursor-pointer"
                        >
                          <svg className="w-2.5 h-2.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                          </svg>
                          <span>เงินเดือน</span>
                        </button>
                        <button
                          onClick={() =>
                            handleQuickAction(
                              "บ้าน 500",
                              "savings",
                              "หยอดกระปุกบ้าน",
                              "+฿500",
                              "หยอดกระปุก 'บ้าน' ฿500 สำเร็จแล้วครับ",
                              "สะสมแล้ว ฿146,165 / ฿5,500,000",
                              0
                            )
                          }
                          className="px-2.5 py-1 rounded-xl bg-[#EDE8FD] text-[#7A5AF8] border border-[#DCD2F9] text-[9px] font-bold flex items-center gap-1 shadow-2xs active:scale-95 transition-transform cursor-pointer"
                        >
                          <svg className="w-2.5 h-2.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                          </svg>
                          <span>บ้าน</span>
                        </button>
                        <button
                          onClick={() =>
                            handleQuickAction(
                              "มอไซ 300",
                              "savings",
                              "หยอดกระปุกมอไซ",
                              "+฿300",
                              "หยอดกระปุก 'มอไซ' ฿300 สำเร็จแล้วครับ",
                              "สะสมแล้ว ฿27,509 / ฿50,000 (55%)",
                              0
                            )
                          }
                          className="px-2.5 py-1 rounded-xl bg-[#E8EDFD] text-[#4E6BF2] border border-[#D1DBFB] text-[9px] font-bold flex items-center gap-1 shadow-2xs active:scale-95 transition-transform cursor-pointer"
                        >
                          <svg className="w-2.5 h-2.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
                          </svg>
                          <span>มอไซ</span>
                        </button>
                      </div>

                      {/* Bottom Input Bar with Typing Simulation & Interactive Input */}
                      <div className="p-3 pt-1 z-20">
                        <div className="bg-white rounded-2xl px-3 py-2 border border-[#E8E2CB] shadow-sm flex items-center justify-between gap-2">
                          <div className="w-5 h-5 text-[#7EA459]">
                            <svg className="w-full h-full" fill="currentColor" viewBox="0 0 24 24">
                              <path d="M4 4h4v4H4V4zm6 0h4v4h-4V4zm6 0h4v4h-4V4zM4 10h4v4H4v-4zm6 0h4v4h-4v-4zm6 0h4v4h-4v-4zM4 16h4v4H4v-4zm6 0h4v4h-4v-4zm6 0h4v4h-4v-4z" />
                            </svg>
                          </div>
                          <div className="flex-1 text-xs text-gray-700 font-medium">
                            <input
                              type="text"
                              value={typedText}
                              onChange={(e) => setTypedText(e.target.value)}
                              onKeyDown={(e) => {
                                if (e.key === "Enter") handleManualSend();
                              }}
                              placeholder="พิมพ์รายการและจำนวนเงิน..."
                              className="w-full bg-transparent text-xs text-[#1A2412] font-medium placeholder-gray-400 focus:outline-none"
                            />
                          </div>
                          <button
                            onClick={handleManualSend}
                            className={`w-7 h-7 rounded-full flex items-center justify-center transition-all ${
                              typedText || isSending
                                ? "bg-[#7EA459] text-white shadow-xs scale-105 cursor-pointer"
                                : "bg-gray-100 text-gray-400 cursor-default"
                            }`}
                          >
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M5 10l7-7m0 0l7 7m-7-7v18" />
                            </svg>
                          </button>
                        </div>
                      </div>

                      {/* OVERLAY: SMART SLIP OCR MODAL (Overlays on top of the notebook) */}
                      {slipModalOpen && (
                        <div className="absolute inset-0 z-40 flex flex-col justify-end p-3 animate-fadeIn">
                          {/* Darkened backdrop */}
                          <div
                            onClick={() => setSlipModalOpen(false)}
                            className="absolute inset-0 bg-black/45 backdrop-blur-2xs transition-opacity cursor-pointer"
                          />

                          {/* Modal Sheet from Screenshot 3 */}
                          <div className="relative z-10 w-full bg-[#FAF5E6] rounded-3xl p-4 border border-[#E8E2CB] shadow-2xl space-y-3 animate-slide-up">
                            {isScanning ? (
                              /* Live Scanning Progress */
                              <div className="py-5 px-3 space-y-3 text-center">
                                <div className="relative w-44 h-20 mx-auto bg-white rounded-xl border border-gray-200 p-2 shadow-inner overflow-hidden flex items-center justify-center gap-1.5 flex-wrap">
                                  <Image src="/images/banks/kbank.png" alt="KBank" width={18} height={18} className="rounded-full shadow-xs" />
                                  <Image src="/images/banks/scb.png" alt="SCB" width={18} height={18} className="rounded-full shadow-xs" />
                                  <Image src="/images/banks/ktb.png" alt="KTB" width={18} height={18} className="rounded-full shadow-xs" />
                                  <Image src="/images/banks/bbl.png" alt="BBL" width={18} height={18} className="rounded-full shadow-xs" />
                                  <Image src="/images/banks/bay.png" alt="BAY" width={18} height={18} className="rounded-full shadow-xs" />
                                  <Image src="/images/banks/ttb.png" alt="TTB" width={18} height={18} className="rounded-full shadow-xs" />
                                  <Image src="/images/banks/gsb.png" alt="GSB" width={18} height={18} className="rounded-full shadow-xs" />
                                  <Image src="/images/banks/promptpay.png" alt="PromptPay" width={18} height={18} className="rounded-full shadow-xs" />
                                  <div className="absolute left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-[#7EA459] to-transparent shadow-[0_0_8px_#7EA459] animate-laser" />
                                </div>

                                <div>
                                  <div className="text-xs font-bold text-[#1A2412] flex items-center justify-center gap-1.5">
                                    <span className="w-2 h-2 rounded-full bg-[#7EA459] animate-ping" />
                                    <span>กำลังตรวจจับและอ่านสลิป 16 ใบ...</span>
                                  </div>
                                  <div className="text-[10px] text-gray-500 mt-1">
                                    ตรวจจับครบทุกธนาคารไทย (กสิกร, SCB, กรุงไทย, BBL, BAY, ttb, ออมสิน, พร้อมเพย์)
                                  </div>
                                </div>

                                <div className="w-48 mx-auto h-1.5 bg-gray-200 rounded-full overflow-hidden">
                                  <div className="h-full bg-[#7EA459] rounded-full animate-pulse w-full" />
                                </div>
                              </div>
                            ) : (
                              /* Result Sheet (Exact match to Screenshot 3 with ALL BANKS) */
                              <>
                                <div className="flex items-start justify-between">
                                  <div className="flex items-center gap-2">
                                    <Image
                                      src="/images/logo_blue.png"
                                      alt="Logo"
                                      width={28}
                                      height={28}
                                      className="rounded-lg"
                                    />
                                    <div>
                                      <div className="text-xs font-bold text-[#1A2412]">SaveFor</div>
                                      <div className="text-[9px] text-gray-500">สรุปยอดสแกนทั้งหมด</div>
                                    </div>
                                  </div>
                                  <div className="flex items-center gap-1.5">
                                    <span className="text-[10px] font-bold bg-[#FDF0D5] text-[#9A6700] px-2.5 py-0.5 rounded-full border border-[#F3DBA7]">
                                      16/16 ใบ
                                    </span>
                                    <button
                                      onClick={() => setSlipModalOpen(false)}
                                      className="w-5 h-5 rounded-full bg-black/5 hover:bg-black/15 text-gray-500 flex items-center justify-center transition-colors cursor-pointer"
                                    >
                                      <svg className="w-3 h-3" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                                      </svg>
                                    </button>
                                  </div>
                                </div>

                                <div className="text-center py-0.5">
                                  <div className="text-[10px] text-gray-500">ยอดเงินรวมทั้งสิ้น</div>
                                  <div className="text-2xl font-black text-[#1A2412] tracking-tight mt-0.5">
                                    ฿1602.86
                                  </div>
                                </div>

                                {/* Bank Breakdown: ALL BANKS */}
                                <div className="bg-[#F6EED8] p-2 rounded-2xl border border-[#E8E0C5]">
                                  <div className="grid grid-cols-4 gap-1.5">
                                    {[
                                      { name: "กสิกร", logo: "/images/banks/kbank.png", count: 3 },
                                      { name: "ไทยพาณิชย์", logo: "/images/banks/scb.png", count: 3 },
                                      { name: "กรุงไทย", logo: "/images/banks/ktb.png", count: 2 },
                                      { name: "กรุงเทพ", logo: "/images/banks/bbl.png", count: 2 },
                                      { name: "กรุงศรี", logo: "/images/banks/bay.png", count: 2 },
                                      { name: "ทีทีบี", logo: "/images/banks/ttb.png", count: 2 },
                                      { name: "ออมสิน", logo: "/images/banks/gsb.png", count: 1 },
                                      { name: "พร้อมเพย์", logo: "/images/banks/promptpay.png", count: 1 },
                                    ].map((b, i) => (
                                      <div
                                        key={i}
                                        className="bg-white/90 rounded-lg py-1 px-1 flex items-center justify-center gap-1 border border-black/5 shadow-2xs"
                                      >
                                        <Image
                                          src={b.logo}
                                          alt={b.name}
                                          width={13}
                                          height={13}
                                          className="rounded-full shrink-0"
                                        />
                                        <span className="text-[9px] font-black text-[#1A2412]">
                                          x{b.count}
                                        </span>
                                      </div>
                                    ))}
                                  </div>
                                </div>

                                <div className="bg-[#EBF7EE] border border-[#BDE8C6] p-2 rounded-xl flex items-center justify-center gap-1.5 text-[10px] font-bold text-[#2E9E66]">
                                  <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                                  </svg>
                                  <span>พร้อมบันทึกสลิปทั้งหมด 16 รายการ</span>
                                </div>

                                <div className="text-center text-[9px] text-gray-400">
                                  ปัดซ้ายเพื่อดูสลิปทีละใบ
                                </div>

                                <div className="space-y-1.5 pt-1">
                                  <div className="w-full py-1.5 bg-[#4B4B4B] text-white text-[10px] font-bold rounded-xl text-center shadow-xs">
                                    สรุปยอดรวม (16 ใบ)
                                  </div>
                                  <button
                                    onClick={handleSaveSlips}
                                    className="w-full py-2.5 bg-[#6F9745] hover:bg-[#5E8238] text-white text-xs font-bold rounded-xl text-center shadow-md active:scale-98 transition-all flex items-center justify-center gap-1.5 cursor-pointer"
                                  >
                                    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                                      <path strokeLinecap="round" strokeLinejoin="round" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
                                    </svg>
                                    <span>{slipSaved ? "บันทึกสำเร็จ 16 ใบเรียบร้อยแล้ว!" : "บันทึกทั้งหมด (16 ใบ • ฿1602.86)"}</span>
                                  </button>
                                </div>
                              </>
                            )}
                          </div>
                        </div>
                      )}
                    </div>
                  )}

                  {/* ──── SCREEN 2: DREAMS / PLANS (EXACT MATCH TO SCREENSHOT 4) ──── */}
                  {activeTab === 2 && (
                    <div className="flex-1 p-3 space-y-3 overflow-y-auto animate-fadeIn">
                      {/* Top Bar from Screenshot 4 */}
                      <div className="flex items-center justify-between pt-1">
                        <div className="flex items-center gap-2">
                          <div className="w-7 h-7 rounded-full bg-white border border-gray-200 flex items-center justify-center text-xs">
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                            </svg>
                          </div>
                          <span className="text-sm font-bold text-[#1A2412]">รายการที่ตั้งไว้</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="text-[10px] font-bold bg-[#FFF7ED] text-[#D97706] px-2 py-0.5 rounded-full border border-[#FDBA74]">
                            5/10 PRO
                          </span>
                          <div className="w-7 h-7 rounded-lg bg-[#1E293B] text-white flex items-center justify-center">
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                            </svg>
                          </div>
                        </div>
                      </div>

                      {/* Segment Filter Capsules */}
                      <div className="flex items-center gap-2 text-[10px] font-bold">
                        <span className="px-3 py-1 bg-white border border-gray-200 rounded-full text-gray-500">รายรับ</span>
                        <span className="px-3 py-1 bg-[#EDE8FD] text-[#7A5AF8] rounded-full">เงินออม</span>
                        <span className="px-3 py-1 bg-white border border-gray-200 rounded-full text-gray-500">รายจ่าย</span>
                      </div>

                      {/* Goal Card 1: บ้าน (Gold border) */}
                      <div className="bg-white rounded-2xl p-3 border-2 border-[#F59E0B] shadow-xs space-y-2 relative overflow-hidden">
                        <div className="flex items-start justify-between">
                          <div className="flex items-center gap-2">
                            <div className="w-10 h-10 rounded-xl bg-orange-50 text-orange-500 flex items-center justify-center">
                              <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                              </svg>
                            </div>
                            <div>
                              <div className="text-xs font-bold text-[#1A2412]">บ้าน</div>
                              <span className="text-[8px] text-orange-600 bg-orange-100 px-1.5 py-0.2 rounded-full font-semibold">
                                หยอดแล้ว 0 ครั้ง
                              </span>
                            </div>
                          </div>
                          <span className="text-[10px] font-bold text-orange-500 bg-orange-50 px-1.5 py-0.5 rounded">
                            3%
                          </span>
                        </div>

                        <div className="flex items-baseline justify-between text-xs">
                          <span className="font-bold text-[#1A2412]">฿145,665</span>
                          <span className="text-[10px] text-gray-400">/ ฿5,500,000</span>
                        </div>

                        {/* Animated Progress Bar */}
                        <div className="w-full h-1.5 bg-gray-100 rounded-full overflow-hidden">
                          <div className="h-full bg-gradient-to-r from-orange-400 to-orange-500 rounded-full w-[3%] transition-all duration-1000" />
                        </div>
                        <div className="text-[8px] text-gray-400">เดือนละ ฿5 • อีก 1070867 เดือน</div>
                      </div>

                      {/* Goal Card 2: มอไซ (Mint border) */}
                      <div className="bg-white rounded-2xl p-3 border-2 border-[#10B981]/50 shadow-xs space-y-2 relative overflow-hidden">
                        <div className="flex items-start justify-between">
                          <div className="flex items-center gap-2">
                            <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
                              <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
                              </svg>
                            </div>
                            <div>
                              <div className="text-xs font-bold text-[#1A2412]">มอไซ</div>
                              <span className="text-[8px] text-emerald-600 bg-emerald-100 px-1.5 py-0.2 rounded-full font-semibold">
                                หยอดแล้ว 0 ครั้ง
                              </span>
                            </div>
                          </div>
                          <span className="text-[10px] font-bold text-emerald-600 bg-emerald-50 px-1.5 py-0.5 rounded">
                            54%
                          </span>
                        </div>

                        <div className="flex items-baseline justify-between text-xs">
                          <span className="font-bold text-[#1A2412]">฿27,209</span>
                          <span className="text-[10px] text-gray-400">/ ฿50,000</span>
                        </div>

                        {/* Animated Progress Bar */}
                        <div className="w-full h-1.5 bg-gray-100 rounded-full overflow-hidden">
                          <div className="h-full bg-gradient-to-r from-emerald-400 to-[#10B981] rounded-full w-[54%] transition-all duration-1000" />
                        </div>
                        <div className="text-[8px] text-gray-400">เดือนละ ฿3,000 • อีก 8 เดือน</div>
                      </div>
                    </div>
                  )}

                  {/* ──── SCREEN 3: DASHBOARD (EXACT MATCH TO SCREENSHOT 5) ──── */}
                  {activeTab === 3 && (
                    <div className="flex-1 p-3 space-y-2.5 overflow-y-auto animate-fadeIn">
                      {/* Top Bar from Screenshot 5 */}
                      <div className="flex items-center justify-between pt-1">
                        <div className="flex items-center gap-2">
                          <div className="w-7 h-7 rounded-full bg-white border border-gray-200 flex items-center justify-center text-xs">
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                            </svg>
                          </div>
                          <div>
                            <div className="text-xs font-bold text-[#1A2412] flex items-center gap-1">
                              แดชบอร์ดการเงิน <span className="text-[8px] bg-[#E2EFCF] text-[#5A8238] px-1 rounded">PRO</span>
                            </div>
                            <div className="text-[8px] text-gray-400">ภาพรวมกระแสเงินสดและการตัดสินใจ</div>
                          </div>
                        </div>
                        <div className="flex items-center gap-1">
                          <div className="w-7 h-7 rounded-lg bg-white border border-gray-200 text-gray-600 flex items-center justify-center text-xs">
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                              <path strokeLinecap="round" strokeLinejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                          </div>
                          <div className="w-7 h-7 rounded-lg bg-white border border-gray-200 text-gray-600 flex items-center justify-center text-xs">
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                            </svg>
                          </div>
                        </div>
                      </div>

                      {/* Period Capsules */}
                      <div className="flex items-center gap-1.5 text-[10px] font-bold">
                        <span className="px-3 py-1 bg-white border border-gray-200 rounded-full text-[#1A2412]">เดือนนี้</span>
                        <span className="px-3 py-1 bg-white border border-gray-200 rounded-full text-gray-400">เดือนก่อน</span>
                        <span className="px-3 py-1 bg-white border border-gray-200 rounded-full text-gray-400">30 วัน</span>
                        <span className="px-3 py-1 bg-white border border-gray-200 rounded-full text-gray-400">ทั้งหมด</span>
                      </div>

                      {/* Donut Card from Screenshot 5 */}
                      <div className="bg-white rounded-2xl p-3 border border-[#E8E2CB] shadow-xs space-y-2">
                        <div className="flex items-center justify-between text-[10px]">
                          <span className="font-bold text-[#1A2412] flex items-center gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-red-500" /> ภาพรวมเดือนนี้
                          </span>
                          <span className="text-[8px] bg-red-100 text-red-600 px-1.5 py-0.2 rounded-full font-bold">
                            รายจ่ายเกิน
                          </span>
                        </div>

                        {/* Interactive Ring & Numbers */}
                        <div className="flex items-center justify-between pt-1">
                          {/* Animated SVG Donut */}
                          <div className="relative w-20 h-20 flex items-center justify-center">
                            <svg className="w-full h-full -rotate-90" viewBox="0 0 36 36">
                              <path
                                className="text-gray-100"
                                strokeWidth="3.8"
                                stroke="currentColor"
                                fill="none"
                                d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                              />
                              <path
                                className="text-[#10B981] transition-all duration-1000"
                                strokeDasharray="16, 100"
                                strokeWidth="3.8"
                                strokeLinecap="round"
                                stroke="currentColor"
                                fill="none"
                                d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                              />
                              <path
                                className="text-[#EF4444] transition-all duration-1000"
                                strokeDasharray="84, 100"
                                strokeDashoffset="-16"
                                strokeWidth="3.8"
                                strokeLinecap="round"
                                stroke="currentColor"
                                fill="none"
                                d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                              />
                            </svg>
                            <div className="absolute text-center">
                              <div className="text-[7px] text-gray-400">คงเหลือสุทธิ</div>
                              <div className="text-[10px] font-black text-red-500">-฿3.5k</div>
                            </div>
                          </div>

                          {/* Metric Rows */}
                          <div className="space-y-1.5 text-[9px] flex-1 pl-3">
                            <div className="flex items-center justify-between bg-emerald-50/50 p-1 rounded-lg">
                              <span className="text-[#10B981] font-bold">↗ รายรับ</span>
                              <span className="font-black text-[#10B981]">฿843</span>
                            </div>
                            <div className="flex items-center justify-between bg-red-50/50 p-1 rounded-lg">
                              <span className="text-red-500 font-bold">↘ รายจ่าย</span>
                              <span className="font-black text-red-500">฿4,372</span>
                            </div>
                            <div className="flex items-center justify-between bg-purple-50/50 p-1 rounded-lg">
                              <span className="text-purple-600 font-bold">เงินออม</span>
                              <span className="font-black text-purple-600">฿0</span>
                            </div>
                          </div>
                        </div>
                      </div>

                      {/* 4 KPI Cards Grid from Screenshot 5 */}
                      <div className="grid grid-cols-2 gap-2 text-[9px]">
                        <div className="bg-white p-2.5 rounded-xl border border-gray-200">
                          <span className="text-gray-400">อัตราการออม</span>
                          <div className="text-sm font-black text-[#1A2412] mt-0.5">0%</div>
                          <span className="text-[8px] text-orange-500">แนะนำ 20%+</span>
                        </div>
                        <div className="bg-white p-2.5 rounded-xl border border-gray-200">
                          <span className="text-gray-400">ใช้จ่ายต่อรายรับ</span>
                          <div className="text-sm font-black text-red-500 mt-0.5">519%</div>
                          <span className="text-[8px] text-red-500">ระวังใช้เกินตัว</span>
                        </div>
                        <div className="bg-white p-2.5 rounded-xl border border-gray-200">
                          <span className="text-gray-400">เฉลี่ยจ่ายต่อวัน</span>
                          <div className="text-sm font-black text-[#1A2412] mt-0.5">฿257</div>
                          <span className="text-[8px] text-gray-400">ความเร็วการใช้เงิน</span>
                        </div>
                        <div className="bg-white p-2.5 rounded-xl border border-gray-200">
                          <span className="text-gray-400">จำนวนรายการ</span>
                          <div className="text-sm font-black text-[#1A2412] mt-0.5">10</div>
                          <span className="text-[8px] text-blue-500">รายการบันทึก</span>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Home Bar Indicator */}
                  <div className="h-3.5 flex items-center justify-center pb-1 bg-white border-t border-gray-100">
                    <div className="w-24 h-1 bg-gray-400 rounded-full" />
                  </div>
                </div>
              </IPhone17ProMax>

              {/* Active Screen Caption Box */}
              <div className="mt-4 text-center max-w-xs">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#7EA459] bg-[#E2EFCF] px-2.5 py-0.5 rounded-full border border-[#BED7A1]">
                  Interactive Demo
                </span>
                <h3 className="text-sm font-bold text-[#1A2412] mt-1.5">
                  {screenTabs[activeTab].title}
                </h3>
                <p className="text-xs text-[#718096] mt-0.5 leading-relaxed">
                  {screenTabs[activeTab].desc}
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ─────────────────────────────────────────────────────────────
          3. SUPPORTED BANKS SHOWCASE
      ───────────────────────────────────────────────────────────── */}
      <section id="banks" className="py-16 bg-white border-y border-[#E8E2CB]">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="text-center max-w-2xl mx-auto mb-10">
            <span className="text-xs font-bold uppercase tracking-wider text-[#7EA459] bg-[#E2EFCF] px-3 py-1 rounded-full border border-[#C5DCAB]">
              Smart Bank OCR
            </span>
            <h2 className="text-2xl sm:text-3xl font-extrabold text-[#1A2412] mt-3 mb-2 tracking-tight">
              สแกนสลิปได้ทุกธนาคารไทยชั้นนำ
            </h2>
            <p className="text-sm text-[#4A5568]">
              ระบบดึงยอด วันที่ เวลา และผู้รับเงินได้จากสลิปของทุกธนาคารในประเทศไทยอย่างแม่นยำ
            </p>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-8 gap-4">
            {supportedBanks.map((bank, index) => (
              <div
                key={index}
                className="bg-[#FAF7E8] p-3.5 rounded-2xl border border-[#E8E2CB] flex flex-col items-center justify-center text-center hover:border-[#7EA459] hover:shadow-xs transition-all"
              >
                <div className="w-12 h-12 rounded-xl bg-white p-1.5 border border-gray-100 flex items-center justify-center mb-2 shadow-2xs">
                  <Image
                    src={bank.logo}
                    alt={bank.name}
                    width={40}
                    height={40}
                    className="object-contain"
                  />
                </div>
                <span className="text-[11px] font-bold text-[#1A2412] leading-tight">
                  {bank.name}
                </span>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─────────────────────────────────────────────────────────────
          4. DETAILED FEATURES WITH REAL SCREENSHOTS
      ───────────────────────────────────────────────────────────── */}
      <section id="features" className="py-20 bg-[#FAF7E8] space-y-20">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="text-center max-w-2xl mx-auto mb-16">
            <span className="text-xs font-bold uppercase tracking-wider text-[#7EA459] bg-[#E2EFCF] px-3 py-1 rounded-full border border-[#C5DCAB]">
              เจาะลึกฟีเจอร์เด่น
            </span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-[#1A2412] mt-4 mb-3 tracking-tight">
              สัมผัสความง่ายที่คิดมาเพื่อการใช้งานจริง
            </h2>
            <p className="text-[#4A5568] text-base leading-relaxed">
              ภาพหน้าจอจริงจากแอป เงินมานี่ ที่พร้อมให้คุณดาวน์โหลดและใช้งานแล้ววันนี้
            </p>
          </div>

          {/* Feature 1: Slip OCR */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center bg-white rounded-3xl p-6 sm:p-10 border border-[#E8E2CB] shadow-xs mb-12">
            <div className="lg:col-span-6 space-y-4">
              <span className="text-xs font-bold uppercase tracking-wider text-[#7EA459] bg-[#E2EFCF] px-3 py-1 rounded-full">
                ฟีเจอร์ไฮไลท์ 01
              </span>
              <h3 className="text-2xl sm:text-3xl font-extrabold text-[#1A2412]">
                สแกนสลิปจากอัลบั้ม ย้อนหลังได้สูงสุด 60 วัน
              </h3>
              <p className="text-sm sm:text-base text-[#4A5568] leading-relaxed font-light">
                ไม่ต้องมานั่งกรอกเองทีละรายการ! เพียงเลือกช่วงวันที่ต้องการสแกน ระบบ Smart OCR จะตรวจจับสลิปโอนเงินจากอัลบั้มรูปภาพ อ่านยอดเงิน วันที่ และจัดหมวดหมู่อัตโนมัติ สรุปยอดรวมและกดบันทึกทั้งหมด 16 รายการได้ในคลิกเดียว
              </p>
              <div className="space-y-2 pt-2 text-xs sm:text-sm text-[#2D3748]">
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center font-bold">✓</div>
                  <span>เลือกสแกนย้อนหลังได้ 1 วัน, 3 วัน, 7 วัน, 15 วัน, 30 วัน หรือ 60 วัน</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center font-bold">✓</div>
                  <span>สรุปยอดเงินรวมทั้งสิ้น และจำแนกครบทุกธนาคาร (กสิกร, ไทยพาณิชย์, กรุงไทย, กรุงเทพ, กรุงศรี, ทีทีบี, ออมสิน, พร้อมเพย์)</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center font-bold">✓</div>
                  <span>ปัดซ้าย-ขวาเพื่อตรวจสอบรายละเอียดสลิปทีละใบได้อย่างอิสระ</span>
                </div>
              </div>
            </div>
            <div className="lg:col-span-6 flex items-center justify-center gap-4 sm:gap-6">
              <IPhone17ProMax
                src="/images/mockups/mockup_slip_picker.png"
                alt="สแกนสลิปจากอัลบั้ม ย้อนหลังได้สูงสุด 60 วัน"
                className="w-44 sm:w-56"
                variant="black"
              />
              <IPhone17ProMax
                src="/images/mockups/mockup_slip_result.png"
                alt="สรุปยอดสแกนสลิป แยกธนาคารอัตโนมัติ"
                className="w-44 sm:w-56"
                variant="black"
              />
            </div>
          </div>

          {/* Feature 2: Chat Style Home & Dreams */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center bg-white rounded-3xl p-6 sm:p-10 border border-[#E8E2CB] shadow-xs mb-12">
            <div className="lg:col-span-6 order-2 lg:order-1 flex items-center justify-center gap-4 sm:gap-6">
              <IPhone17ProMax
                src="/images/mockups/mockup_home.png"
                alt="หน้าแรกสไตล์แชทสมุดโน้ต"
                className="w-44 sm:w-56"
                variant="black"
              />
              <IPhone17ProMax
                src="/images/mockups/mockup_dreams.png"
                alt="รายการที่ตั้งไว้ & กระปุกเงินตามฝัน"
                className="w-44 sm:w-56"
                variant="black"
              />
            </div>

            <div className="lg:col-span-6 order-1 lg:order-2 space-y-4">
              <span className="text-xs font-bold uppercase tracking-wider text-[#7EA459] bg-[#E2EFCF] px-3 py-1 rounded-full">
                ฟีเจอร์ไฮไลท์ 02
              </span>
              <h3 className="text-2xl sm:text-3xl font-extrabold text-[#1A2412]">
                จดง่ายสไตล์แชท & กระปุกเงินตามฝัน
              </h3>
              <p className="text-sm sm:text-base text-[#4A5568] leading-relaxed font-light">
                จดบัญชีได้สนุกเหมือนคุยกับเพื่อน เพียงพิมพ์รายการในกล่องแชทด้านล่าง ระบบจะบันทึกพร้อมแสดงเวลาและยอดเงินทันที พร้อมตั้งเป้าหมายเงินออมสำหรับสิ่งที่อยากได้ เช่น บ้าน, มอเตอร์ไซค์ พร้อมคำนวณจำนวนเดือนที่ต้องออมให้อัตโนมัติ
              </p>
              <div className="space-y-2 pt-2 text-xs sm:text-sm text-[#2D3748]">
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center font-bold">✓</div>
                  <span>ปุ่มลัดพิมพ์ด่วนสำหรับหมวดหมู่ประจำ เช่น ค่าห้อง, เงินเดือน, บ้าน, มอไซ</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center font-bold">✓</div>
                  <span>เห็นยอดสะสมรวมของทั้งวันและทั้งเดือนบนหัวบิลเสมอ</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center font-bold">✓</div>
                  <span>หลอดเปอร์เซ็นต์แสดงความคืบหน้าการออม ให้คุณมีกำลังใจทุกวัน</span>
                </div>
              </div>
            </div>
          </div>

          {/* Feature 3: Financial Dashboard */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center bg-white rounded-3xl p-6 sm:p-10 border border-[#E8E2CB] shadow-xs">
            <div className="lg:col-span-6 space-y-4">
              <span className="text-xs font-bold uppercase tracking-wider text-[#7EA459] bg-[#E2EFCF] px-3 py-1 rounded-full">
                ฟีเจอร์ไฮไลท์ 03
              </span>
              <h3 className="text-2xl sm:text-3xl font-extrabold text-[#1A2412]">
                แดชบอร์ดสรุปภาพรวมและศูนย์วิเคราะห์การเงิน
              </h3>
              <p className="text-sm sm:text-base text-[#4A5568] leading-relaxed font-light">
                รู้ทันสุขภาพการเงินของตนเองด้วยแดชบอร์ดที่วิเคราะห์กระแสเงินสดให้แบบ Real-time พร้อมกราฟวงแหวน Donut Chart เปรียบเทียบรายรับ รายจ่าย และเงินออม พร้อมเตือนเมื่อใช้จ่ายเกินตัว
              </p>
              <div className="space-y-2 pt-2 text-xs sm:text-sm text-[#2D3748]">
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center font-bold">✓</div>
                  <span>คำนวณอัตราการออม (%) และสัดส่วนค่าใช้จ่ายต่อรายรับให้อัตโนมัติ</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center font-bold">✓</div>
                  <span>แสดงค่าใช้จ่ายเฉลี่ยต่อวัน (Burn Rate) เพื่อการวางแผนงบประมาณที่แม่นยำ</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-5 h-5 rounded-full bg-[#E2EFCF] text-[#5A8238] flex items-center justify-center font-bold">✓</div>
                  <span>โหมดความเป็นส่วนตัว แตะซ่อนตัวเลขได้ทันทีเมื่อเปิดดูในที่สาธารณะ</span>
                </div>
              </div>
            </div>

            <div className="lg:col-span-6 flex items-center justify-center">
              <IPhone17ProMax
                src="/images/mockups/mockup_dashboard.png"
                alt="แดชบอร์ดการเงิน เงินมานี่"
                className="w-56 sm:w-68"
                variant="black"
              />
            </div>
          </div>

        </div>
      </section>

      {/* ─────────────────────────────────────────────────────────────
          5. FAQ ACCORDION
      ───────────────────────────────────────────────────────────── */}
      <section id="faq" className="py-20 bg-white border-t border-[#E8E2CB]">
        <div className="max-w-4xl mx-auto px-4 sm:px-6">
          <div className="text-center max-w-2xl mx-auto mb-16">
            <span className="text-xs font-bold uppercase tracking-wider text-[#7EA459] bg-[#E2EFCF] px-3 py-1 rounded-full border border-[#C5DCAB]">
              FAQ
            </span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-[#1A2412] mt-4 mb-3 tracking-tight">
              คำถามที่พบบ่อย
            </h2>
            <p className="text-[#4A5568] text-base">
              ข้อสงสัยเกี่ยวกับการใช้งานและระบบความปลอดภัยของ เงินมานี่
            </p>
          </div>

          <div className="space-y-4">
            {faqs.map((faq, index) => {
              const isOpen = openFaq === index;
              return (
                <div
                  key={index}
                  className="bg-[#FAF7E8] rounded-2xl border border-[#E8E2CB] overflow-hidden transition-all shadow-2xs"
                >
                  <button
                    onClick={() => setOpenFaq(isOpen ? null : index)}
                    className="w-full px-6 py-5 text-left flex items-center justify-between gap-4 font-semibold text-base text-[#1A2412] hover:text-[#7EA459] transition-colors"
                  >
                    <span>{faq.q}</span>
                    <span
                      className={`transform transition-transform text-[#7EA459] text-xl font-bold ${
                        isOpen ? "rotate-45" : "rotate-0"
                      }`}
                    >
                      +
                    </span>
                  </button>
                  {isOpen && (
                    <div className="px-6 pb-5 text-sm text-[#4A5568] leading-relaxed border-t border-[#E8E2CB]/50 pt-3">
                      {faq.a}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* ─────────────────────────────────────────────────────────────
          6. BOTTOM DOWNLOAD CTA BANNER
      ───────────────────────────────────────────────────────────── */}
      <section id="download" className="py-20 bg-[#FAF7E8]">
        <div className="max-w-5xl mx-auto px-4 sm:px-6">
          <div className="relative bg-gradient-to-br from-[#7EA459] via-[#6B9346] to-[#4F732E] rounded-[40px] p-8 sm:p-14 text-white shadow-xl overflow-hidden">
            <div className="relative z-10 max-w-2xl text-center sm:text-left">
              <span className="inline-block text-xs font-bold uppercase tracking-wider bg-white/20 px-3.5 py-1 rounded-full text-white mb-4 backdrop-blur-xs">
                เริ่มต้นสร้างสุขภาพการเงินที่ดีตั้งแต่วันนี้
              </span>
              <h2 className="text-3xl sm:text-5xl font-extrabold tracking-tight leading-tight mb-4">
                ดาวน์โหลด เงินมานี่ <br />
                <span className="text-[#F5B731]">ฟรีทั้ง iOS & Android</span>
              </h2>
              <p className="text-white/90 text-base sm:text-lg mb-8 leading-relaxed max-w-xl font-light">
                สัมผัสประสบการณ์บันทึกการเงินที่เข้าใจง่าย สแกนสลิปโอนเงินเสร็จในพริบตา พร้อมกระปุกเงินตามฝันที่จะพาคุณไปถึงทุกเป้าหมาย
              </p>

              {/* Dual Store Download Buttons */}
              <div className="flex flex-col sm:flex-row items-center gap-4">
                <a
                  href="https://apps.apple.com/app/savefor/id6809708026"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="w-full sm:w-auto inline-flex items-center justify-center gap-3 bg-white hover:bg-gray-100 text-[#1A2412] px-6 py-3.5 rounded-2xl shadow-md transition-transform hover:-translate-y-0.5 active:translate-y-0 font-medium"
                >
                  <svg className="w-6 h-6 fill-current" viewBox="0 0 24 24">
                    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.64-.78 1.08-1.86.96-2.95-1 .04-2.16.66-2.83 1.45-.58.68-1.1 1.77-.96 2.84 1.12.09 2.22-.56 2.83-1.34z" />
                  </svg>
                  <div className="text-left">
                    <div className="text-[9px] uppercase tracking-wider text-gray-500 leading-none">
                      Download on the
                    </div>
                    <div className="text-sm font-bold leading-tight">
                      App Store
                    </div>
                  </div>
                </a>

                <a
                  href="https://play.google.com/store/apps/details?id=com.savefor.app"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="w-full sm:w-auto inline-flex items-center justify-center gap-3 bg-white hover:bg-gray-100 text-[#1A2412] px-6 py-3.5 rounded-2xl shadow-md transition-transform hover:-translate-y-0.5 active:translate-y-0 font-medium"
                >
                  <svg className="w-6 h-6 fill-current" viewBox="0 0 24 24">
                    <path d="M3.609 1.814L13.793 12 3.61 22.186a2.38 2.38 0 01-.61-.715V2.53c.184-.286.39-.53.61-.716zm11.602 11.604L4.85 23.778c.376.14.796.177 1.229.074.453-.109.873-.34 1.229-.68l10.9-6.242-2.997-3.512zM21.5 10.366l-3.328-1.906-3.418 3.54 3.418 3.54 3.328-1.906c.928-.532 1.499-1.503 1.499-2.634 0-1.131-.571-2.102-1.499-2.634zm-6.289-1.574L7.308.848C6.952.508 6.532.277 6.079.168 5.646.065 5.226.102 4.85.242l10.361 10.36 2.997-1.81z" />
                  </svg>
                  <div className="text-left">
                    <div className="text-[9px] uppercase tracking-wider text-gray-500 leading-none">
                      GET IT ON
                    </div>
                    <div className="text-sm font-bold leading-tight">
                      Google Play
                    </div>
                  </div>
                </a>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ─────────────────────────────────────────────────────────────
          7. FOOTER
      ───────────────────────────────────────────────────────────── */}
      <footer className="bg-white border-t border-[#E8E2CB] pt-14 pb-10">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8 mb-12">
            {/* Col 1: Brand Info */}
            <div className="md:col-span-2 space-y-4">
              <div className="flex items-center gap-3">
                <Image
                  src="/images/logo_blue.png"
                  alt="เงินมานี่"
                  width={36}
                  height={36}
                  className="rounded-xl border border-[#E2EFCF]"
                />
                <span className="text-xl font-bold text-[#1A2412]">
                  เงินมานี่ (NgenManee)
                </span>
              </div>
              <p className="text-sm text-[#718096] max-w-sm leading-relaxed font-light">
                แอปพลิเคชันบันทึกรายรับ-รายจ่าย สแกนสลิปอัจฉริยะ และวางแผนกระปุกเงินตามฝัน ในสไตล์สมุดบันทึกอบอุ่น ปลอดภัย ไม่เข้าถึงบัญชีธนาคาร
              </p>
              <div className="text-xs text-[#718096]">
                ก่อตั้งและสร้างสรรค์โดย <strong className="text-[#1A2412]">วรธน นำทอง (Worathon Namthong)</strong> • Founder & CEO (วัยรุ่นไฟแรงผู้สร้าง SuparPOS & เงินมานี่)
              </div>
              <div className="text-xs text-[#A0AEC0]">
                เว็บไซต์ทางการ: <span className="text-[#7EA459] font-semibold">ngenmoney.com</span>
              </div>
            </div>

            {/* Col 2: Legal & Compliance */}
            <div>
              <h4 className="text-xs font-bold uppercase tracking-wider text-[#1A2412] mb-4">
                ข้อมูลทางกฎหมาย
              </h4>
              <ul className="space-y-2.5 text-sm text-[#4A5568]">
                <li>
                  <Link href="/privacy" className="hover:text-[#7EA459] transition-colors">
                    นโยบายความเป็นส่วนตัว (Privacy Policy)
                  </Link>
                </li>
                <li>
                  <Link href="/terms" className="hover:text-[#7EA459] transition-colors">
                    เงื่อนไขการใช้งาน (Terms of Use / EULA)
                  </Link>
                </li>
                <li>
                  <Link href="/delete-account" className="hover:text-[#7EA459] transition-colors">
                    การขอลบบัญชีผู้ใช้ (Account Deletion)
                  </Link>
                </li>
              </ul>
            </div>

            {/* Col 3: Support & Contact */}
            <div>
              <h4 className="text-xs font-bold uppercase tracking-wider text-[#1A2412] mb-4">
                ช่วยเหลือและบริการ
              </h4>
              <ul className="space-y-2.5 text-sm text-[#4A5568]">
                <li>
                  <Link href="/support" className="hover:text-[#7EA459] transition-colors">
                    ศูนย์ช่วยเหลือและติดต่อเรา
                  </Link>
                </li>
                <li>
                  <a href="mailto:support@ngenmoney.com" className="hover:text-[#7EA459] transition-colors">
                    support@ngenmoney.com
                  </a>
                </li>
              </ul>
            </div>
          </div>

          {/* Bottom Copyright */}
          <div className="pt-8 border-t border-[#F0EEDC] flex flex-col sm:flex-row items-center justify-between text-xs text-[#718096] gap-4">
            <p>© {new Date().getFullYear()} เงินมานี่ (NgenManee) • ngenmoney.com - สงวนลิขสิทธิ์</p>
            <p>ขับเคลื่อนด้วยไฟวัยรุ่นสตาร์ทอัพโดย <span className="font-semibold text-[#1A2412]">วรธน นำทอง (Worathon Namthong) • Founder & CEO</span></p>
          </div>
        </div>
      </footer>
    </div>
  );
}
