import type { Metadata } from "next";
import { Prompt } from "next/font/google";
import "./globals.css";

const promptFont = Prompt({
  weight: ["300", "400", "500", "600", "700"],
  subsets: ["thai", "latin"],
  variable: "--font-prompt",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || "https://ngenmoney.com"),
  title: "เงินมานี่ (NgenManee) • แอปบันทึกรายรับรายจ่าย สแกนสลิปอัจฉริยะ & กระปุกเงินตามฝัน",
  description:
    "แอปบันทึกรายรับ-รายจ่ายที่อบอุ่นและฉลาดที่สุด สแกนสลิปโอนเงินบันทึกอัตโนมัติในพริบตา ตั้งเป้ากระปุกเงินตามฝัน วิเคราะห์สุขภาพการเงิน ปลอดภัยด้วย Face ID และไม่เข้าถึงบัญชีธนาคาร",
  keywords: [
    // Brand & App
    "เงินมานี่",
    "NgenManee",
    "ngenmoney",
    "ngenmoney.com",
    "SaveFor",
    "แอปเงินมานี่",
    "แอพเงินมานี่",
    "SaveFor App",

    // Core Expense Tracking (High Volume)
    "แอปรายรับรายจ่าย",
    "แอพรายรับรายจ่าย",
    "บันทึกรายรับรายจ่าย",
    "จดรายรับรายจ่าย",
    "แอพบันทึกรายรับรายจ่าย",
    "แอปทำบัญชีรายรับจ่าย",
    "แอปทำบัญชีส่วนตัว",
    "โปรแกรมบันทึกรายรับรายจ่าย",
    "จดบัญชีรายวัน",
    "แอปรายรับรายจ่าย 2569",
    "แอปรายรับรายจ่าย 2026",
    "แอปการเงิน",

    // Smart Bank Slip Scanner (Killer Feature / High Intent)
    "แอปสแกนสลิป",
    "แอพสแกนสลิป",
    "สแกนสลิป",
    "สแกนสลิปโอนเงิน",
    "อ่านสลิปธนาคาร",
    "แอปอ่านสลิปอัตโนมัติ",
    "สแกนสลิปย้อนหลัง",
    "สแกนสลิป 60 วัน",
    "OCR สลิปธนาคาร",
    "สแกนสลิปไม่ต้องพิมพ์",
    "สแกนสลิป กสิกร",
    "สแกนสลิป scb",
    "สแกนสลิป กรุงไทย",
    "สแกนสลิป กรุงเทพ",
    "สแกนสลิป กรุงศรี",
    "สแกนสลิป ttb",
    "สแกนสลิป ออมสิน",
    "สแกนสลิป พร้อมเพย์",

    // Chat Style Notebook
    "จดรายรับรายจ่ายแบบแชท",
    "จดบัญชีสไตล์แชท",
    "สมุดรายรับรายจ่าย",
    "สมุดบัญชีน่ารัก",
    "จดค่าใช้จ่ายเหมือนคุยกับเพื่อน",
    "บอลทาโร่",

    // Savings Goals & Piggy Bank
    "กระปุกเงินตามฝัน",
    "แอปออมเงิน",
    "แอพออมเงินตามเป้าหมาย",
    "วิธีเก็บเงินซื้อบ้าน",
    "วิธีเก็บเงินซื้อมอเตอร์ไซค์",
    "วางแผนการเงินส่วนบุคคล",
    "เก็บเงินสร้างอนาคต",

    // Financial Analytics & Privacy
    "คำนวณ Burn Rate",
    "อัตราการออมเงิน",
    "กราฟวิเคราะห์รายรับรายจ่าย",
    "แอปการเงิน Face ID",
    "แอปรายรับรายจ่ายปลอดภัยไม่ผูกธนาคาร",
  ],
  authors: [{ name: "NgenManee Team", url: "https://ngenmoney.com" }],
  creator: "NgenManee Team",
  publisher: "NgenManee",
  openGraph: {
    title: "เงินมานี่ (NgenManee) • จดง่าย สบายใจ ให้เงินไหลมาเทมา",
    description:
      "แอปบันทึกรายรับ-รายจ่ายสไตล์สมุดบันทึกอบอุ่น สแกนสลิปอัตโนมัติ ออมเงินตามฝัน ปลอดภัยและใช้งานง่าย รองรับทั้ง iOS และ Android",
    url: "https://ngenmoney.com",
    siteName: "เงินมานี่ (NgenManee)",
    images: [
      {
        url: "/images/splash_artwork.png",
        width: 1200,
        height: 630,
        alt: "เงินมานี่ (NgenManee) App Preview",
      },
    ],
    locale: "th_TH",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "เงินมานี่ (NgenManee) • จดง่าย สบายใจ ให้เงินไหลมาเทมา",
    description:
      "แอปบันทึกรายรับ-รายจ่ายสไตล์สมุดบันทึกอบอุ่น สแกนสลิปอัตโนมัติ ออมเงินตามฝัน",
    images: ["/images/splash_artwork.png"],
  },
  icons: {
    icon: "/images/logo_blue.png",
    apple: "/images/logo_blue.png",
  },
  alternates: {
    canonical: "https://ngenmoney.com",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="th" className={`${promptFont.variable} scroll-smooth`}>
      <head>
        <meta name="theme-color" content="#7EA459" />
      </head>
      <body className="min-h-screen flex flex-col font-sans bg-[#FAF7E8] text-[#2D3748]">
        {children}
      </body>
    </html>
  );
}
