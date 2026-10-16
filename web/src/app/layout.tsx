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
    "เงินมานี่",
    "NgenManee",
    "ngenmoney",
    "บันทึกรายรับรายจ่าย",
    "สแกนสลิป",
    "จดรายรับรายจ่าย",
    "กระปุกเงินตามฝัน",
    "แอปการเงิน",
    "SaveFor",
    "ออมเงิน",
  ],
  authors: [{ name: "NgenManee Team" }],
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
