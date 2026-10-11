import { NextRequest, NextResponse } from "next/server";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://nqgmimfkxgkkofaoddre.supabase.co";
const SERVICE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xZ21pbWZreGdra29mYW9kZHJlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MzA4MzQwMSwiZXhwIjoyMDk4NjU5NDAxfQ.n5sv4EyzAfV0zd9kIetUZQB1DDXibtqvhwUPgvjJCnY";
const REVENUECAT_SECRET =
  process.env.REVENUECAT_SECRET_KEY || "sk_jTsXZnbJhWRcJOIrXGJTUTpVsPGbp";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const headers = {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    };

    // Fetch all profiles
    const res = await fetch(`${SUPABASE_URL}/rest/v1/profiles?select=*`, {
      headers,
      cache: "no-store",
    });

    if (!res.ok) {
      return NextResponse.json({ error: "Failed to fetch profiles" }, { status: 500 });
    }

    const profiles: any[] = await res.json();
    return NextResponse.json({ success: true, users: profiles });
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { userId, action, tier, plan, durationMinutes, customExpiry, store } = body;

    if (!userId) {
      return NextResponse.json({ error: "Missing userId" }, { status: 400 });
    }

    const headers = {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    };

    // ACTION: Apply Test Plan
    if (action === "apply_plan") {
      let expiresAt: string | null = null;

      if (customExpiry) {
        expiresAt = new Date(customExpiry).toISOString();
      } else if (durationMinutes && Number(durationMinutes) > 0) {
        expiresAt = new Date(Date.now() + Number(durationMinutes) * 60 * 1000).toISOString();
      } else if (plan === "lifetime") {
        expiresAt = new Date("2099-12-31T23:59:59Z").toISOString();
      } else if (plan === "yearly") {
        expiresAt = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString();
      } else if (plan === "monthly") {
        expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
      }

      const assignedTier = tier || (plan === "free" ? "free" : "pro");

      const updateRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          tier: assignedTier,
          subscription_expires_at: assignedTier === "pro" ? expiresAt : null,
          subscription_plan: plan || (assignedTier === "pro" ? "monthly" : "free"),
          subscription_store: assignedTier === "pro" ? store || "sandbox_test" : null,
          updated_at: new Date().toISOString(),
        }),
      });

      if (!updateRes.ok) {
        const err = await updateRes.text();
        return NextResponse.json({ error: `Failed to update profile: ${err}` }, { status: 500 });
      }

      return NextResponse.json({
        success: true,
        message: `จำลองแผน ${assignedTier.toUpperCase()} (${plan || "custom"}) สำเร็จ!`,
        expiresAt,
        tier: assignedTier,
      });
    }

    // ACTION: Simulate Immediate Expiration (5 minutes ago)
    if (action === "simulate_expire") {
      const expiredAt = new Date(Date.now() - 5 * 60 * 1000).toISOString();

      const updateRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          tier: "free",
          subscription_expires_at: expiredAt,
          subscription_plan: "free",
          subscription_store: null,
          updated_at: new Date().toISOString(),
        }),
      });

      if (!updateRes.ok) {
        return NextResponse.json({ error: "Failed to simulate expiration" }, { status: 500 });
      }

      return NextResponse.json({
        success: true,
        message: "จำลองการหมดอายุทันทีสำเร็จ! ปรับสถานะเป็น Free และกำหนดเวลาหมดอายุในอดีตเรียบร้อย",
        expiredAt,
      });
    }

    // ACTION: Reset User to Clean Slate (Delete RC Subscriber & Set Free)
    if (action === "reset_fresh") {
      try {
        await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`, {
          method: "DELETE",
          headers: {
            Authorization: `Bearer ${REVENUECAT_SECRET}`,
          },
        });
      } catch (e) {
        console.error("RC Delete error", e);
      }

      const updateRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          tier: "free",
          subscription_expires_at: null,
          subscription_plan: "free",
          subscription_store: null,
          updated_at: new Date().toISOString(),
        }),
      });

      if (!updateRes.ok) {
        return NextResponse.json({ error: "Failed to reset profile in DB" }, { status: 500 });
      }

      return NextResponse.json({
        success: true,
        message: "ล้างประวัติการทดสอบใน RevenueCat และรีเซ็ตบัญชีเป็น Free สะอาด 100% พร้อมทดสอบกดซื้อใหม่",
      });
    }

    // ACTION: Grant Real RevenueCat Promotional Entitlement
    if (action === "grant_rc_promo") {
      const duration = body.duration || "monthly";
      const promoRes = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}/entitlements/pro/promotional`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${REVENUECAT_SECRET}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ duration }),
        }
      );

      const promoExpiry = new Date();
      if (duration === "annual") {
        promoExpiry.setFullYear(promoExpiry.getFullYear() + 1);
      } else {
        promoExpiry.setMonth(promoExpiry.getMonth() + 1);
      }

      // Sync to Supabase DB
      await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          tier: "pro",
          subscription_expires_at: promoExpiry.toISOString(),
          subscription_plan: duration === "annual" ? "yearly" : "monthly",
          subscription_store: "promotional",
          updated_at: new Date().toISOString(),
        }),
      });

      return NextResponse.json({
        success: true,
        message: `ยิง API RevenueCat มอบสิทธิ์ PRO สำเร็จ (${duration}) พร้อมบันทึกลง Supabase DB แล้ว`,
      });
    }

    return NextResponse.json({ error: "Invalid action" }, { status: 400 });
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
