import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "การขอลบบัญชีผู้ใช้ (Account Deletion) • เงินมานี่ (NgenManee)",
  description:
    "หน้าขอลบบัญชีผู้ใช้และข้อมูลส่วนบุคคลทั้งหมดตามข้อกำหนดของ Apple App Store และ Google Play Store",
};

export default function DeleteAccountLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
