import { NextRequest, NextResponse } from "next/server";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://nqgmimfkxgkkofaoddre.supabase.co";
const SERVICE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xZ21pbWZreGdra29mYW9kZHJlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MzA4MzQwMSwiZXhwIjoyMDk4NjU5NDAxfQ.n5sv4EyzAfV0zd9kIetUZQB1DDXibtqvhwUPgvjJCnY";
const REVENUECAT_SECRET =
  process.env.REVENUECAT_SECRET_KEY || "sk_jTsXZnbJhWRcJOIrXGJTUTpVsPGbp";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { userId, action, targetTier } = body;

    if (!userId) {
      return NextResponse.json({ error: "Missing userId" }, { status: 400 });
    }

    const headers = {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    };

    // ACTION 1: Sync Database tier directly with RevenueCat status
    if (action === "sync_db_with_rc") {
      const rcRes = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`, {
        headers: {
          Authorization: `Bearer ${REVENUECAT_SECRET}`,
          "Content-Type": "application/json",
        },
      });

      let calculatedTier = "free";
      if (rcRes.ok) {
        const rcData = await rcRes.json();
        const sub = rcData?.subscriber;
        const entitlements = sub?.entitlements || {};
        const now = Date.now();
        for (const [, val] of Object.entries<any>(entitlements)) {
          const expiresAt = val?.expires_date ? new Date(val.expires_date).getTime() : null;
          if (expiresAt ? expiresAt > now : true) {
            calculatedTier = "pro";
            break;
          }
        }
      }

      // Update Supabase
      const updateRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          tier: calculatedTier,
          updated_at: new Date().toISOString(),
        }),
      });

      if (!updateRes.ok) {
        const errText = await updateRes.text();
        return NextResponse.json({ error: `Supabase sync failed: ${errText}` }, { status: 500 });
      }

      return NextResponse.json({
        success: true,
        message: `ซิงก์ข้อมูลสำเร็จ: ปรับ Database ของผู้ใช้เป็น ${calculatedTier.toUpperCase()} ตาม RevenueCat แล้ว`,
        syncedTier: calculatedTier,
      });
    }

    // ACTION 2: Grant Promotional Entitlement in RevenueCat (e.g. 1 month or 1 year)
    if (action === "grant_rc_promo") {
      const duration = body.duration || "monthly"; // "monthly", "annual", "lifetime"
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

      if (!promoRes.ok) {
        const err = await promoRes.text();
        return NextResponse.json({ error: `RevenueCat promo grant failed: ${err}` }, { status: promoRes.status });
      }

      // Also ensure Supabase DB is pro
      await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          tier: "pro",
          updated_at: new Date().toISOString(),
        }),
      });

      return NextResponse.json({
        success: true,
        message: `มอบสิทธิ์ PRO โปรโมชันใน RevenueCat สำเร็จแล้ว (${duration})`,
      });
    }

    // ACTION 3: Revoke Promotional Entitlement in RevenueCat
    if (action === "revoke_rc_entitlement") {
      const revokeRes = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}/entitlements/pro/revoke_promotionals`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${REVENUECAT_SECRET}`,
            "Content-Type": "application/json",
          },
        }
      );

      // Also set Supabase DB to free
      await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          tier: "free",
          updated_at: new Date().toISOString(),
        }),
      });

      return NextResponse.json({
        success: true,
        message: "ยกเลิกสิทธิ์โปรโมชันใน RevenueCat และปรับเป็น Free ใน Database เรียบร้อยแล้ว",
      });
    }

    // ACTION 4: Delete Subscriber in RevenueCat (Reset testing data)
    if (action === "delete_rc_subscriber") {
      const delRes = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`, {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${REVENUECAT_SECRET}`,
        },
      });

      // Also reset Supabase DB to free
      await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          tier: "free",
          updated_at: new Date().toISOString(),
        }),
      });

      return NextResponse.json({
        success: true,
        message: "ลบประวัติการทดสอบใน RevenueCat และปรับสถานะ Database เป็น Free สำเร็จ พร้อมทดสอบใหม่",
      });
    }

    // ACTION 5: Direct update DB tier
    if (action === "set_db_tier") {
      const tier = targetTier === "pro" ? "pro" : "free";
      const updateRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          tier,
          updated_at: new Date().toISOString(),
        }),
      });

      if (!updateRes.ok) {
        return NextResponse.json({ error: "Failed to update Supabase profile tier" }, { status: 500 });
      }

      return NextResponse.json({
        success: true,
        message: `ปรับสถานะ Database เป็น ${tier.toUpperCase()} เรียบร้อย`,
        tier,
      });
    }

    return NextResponse.json({ error: "Unknown action" }, { status: 400 });
  } catch (error: any) {
    return NextResponse.json({ error: error.message || "Failed to execute sync action" }, { status: 500 });
  }
}
