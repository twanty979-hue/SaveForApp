import { NextResponse } from "next/server";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://nqgmimfkxgkkofaoddre.supabase.co";
const SERVICE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xZ21pbWZreGdra29mYW9kZHJlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MzA4MzQwMSwiZXhwIjoyMDk4NjU5NDAxfQ.n5sv4EyzAfV0zd9kIetUZQB1DDXibtqvhwUPgvjJCnY";
const REVENUECAT_SECRET =
  process.env.REVENUECAT_SECRET_KEY || "sk_jTsXZnbJhWRcJOIrXGJTUTpVsPGbp";

export const dynamic = "force-dynamic";

export async function POST() {
  try {
    const headers = {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    };

    // 1. Fetch profiles
    const profileRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?select=id,tier,subscription_expires_at`, {
      headers,
      cache: "no-store",
    });

    if (!profileRes.ok) {
      return NextResponse.json({ error: "Failed to fetch profiles" }, { status: 500 });
    }

    const profiles: Array<{ id: string; tier: string | null; subscription_expires_at: string | null }> = await profileRes.json();
    let syncedCount = 0;
    const now = Date.now();

    // 2. Query RevenueCat and sync each mismatched user
    for (const p of profiles) {
      try {
        const rcRes = await fetch(
          `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(p.id)}`,
          {
            headers: {
              Authorization: `Bearer ${REVENUECAT_SECRET}`,
              "Content-Type": "application/json",
            },
          }
        );

        let isRcPro = false;
        let rcExpiry: string | null = null;
        let rcPlan = "free";
        let rcStore: string | null = null;

        if (rcRes.ok) {
          const rcData = await rcRes.json();
          const sub = rcData?.subscriber;
          const entitlements = sub?.entitlements || {};
          const subscriptions = sub?.subscriptions || {};

          for (const [, val] of Object.entries<any>(entitlements)) {
            const exp = val?.expires_date ? new Date(val.expires_date).getTime() : null;
            if (exp ? exp > now : true) {
              isRcPro = true;
              rcExpiry = val?.expires_date || null;
              const pid = (val?.product_identifier || "").toLowerCase();
              rcPlan = pid.includes("year") || pid.includes("annual") ? "yearly" : "monthly";
              rcStore = subscriptions[val?.product_identifier]?.store || "app_store";
              break;
            }
          }

          if (!isRcPro) {
            for (const [productId, subVal] of Object.entries<any>(subscriptions)) {
              const exp = subVal?.expires_date ? new Date(subVal.expires_date).getTime() : null;
              const isSubActive = !subVal?.refunded_at && (exp ? exp > now : true);
              if (isSubActive) {
                isRcPro = true;
                rcExpiry = subVal?.expires_date || null;
                const pid = productId.toLowerCase();
                rcPlan = pid.includes("year") || pid.includes("annual") ? "yearly" : "monthly";
                rcStore = subVal?.store || "app_store";
                break;
              }
            }
          }
        }

        const expectedTier = isRcPro ? "pro" : "free";
        const currentTier = (p.tier || "free").toLowerCase() === "pro" ? "pro" : "free";

        if (expectedTier !== currentTier || (isRcPro && rcExpiry !== p.subscription_expires_at)) {
          // Update DB to match RevenueCat with exact online expiration
          await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(p.id)}`, {
            method: "PATCH",
            headers,
            body: JSON.stringify({
              tier: expectedTier,
              subscription_expires_at: rcExpiry,
              subscription_plan: rcPlan,
              subscription_store: isRcPro ? rcStore : null,
              updated_at: new Date().toISOString(),
            }),
          });
          syncedCount++;
        }
      } catch (err) {
        console.error(`Failed to sync user ${p.id}:`, err);
      }
    }

    return NextResponse.json({
      success: true,
      message: `ดำเนินการเทียบและซิงก์ข้อมูลสำเร็จ: ปรับฐานข้อมูลให้ตรงกับ RevenueCat ไปแล้ว ${syncedCount} คน`,
      syncedCount,
    });
  } catch (error: any) {
    return NextResponse.json({ error: error.message || "Failed to bulk sync" }, { status: 500 });
  }
}
