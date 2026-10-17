import { headers } from "next/headers";
import { notFound } from "next/navigation";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Admin Dashboard • เงินมานี่ (Internal)",
  robots: {
    index: false,
    follow: false,
  },
};

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const headersList = await headers();
  const forwardedHost = headersList.get("x-forwarded-host") || "";
  const rawHost = headersList.get("host") || "";
  const host = (forwardedHost || rawHost).toLowerCase();
  const hostname = host.split(":")[0];

  const isLocalhost =
    hostname === "localhost" ||
    hostname === "127.0.0.1" ||
    hostname === "::1" ||
    hostname.endsWith(".local") ||
    hostname.startsWith("192.168.") ||
    hostname.startsWith("10.") ||
    hostname.startsWith("172.");

  const isPublicProduction =
    hostname.includes("ngenmoney.com") ||
    hostname.includes("vercel.app") ||
    hostname.includes("render.com") ||
    !isLocalhost;

  if (isPublicProduction) {
    notFound();
  }

  return <>{children}</>;
}
