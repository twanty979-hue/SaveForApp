import { NextResponse } from "next/server";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://nqgmimfkxgkkofaoddre.supabase.co";
const SERVICE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xZ21pbWZreGdra29mYW9kZHJlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MzA4MzQwMSwiZXhwIjoyMDk4NjU5NDAxfQ.n5sv4EyzAfV0zd9kIetUZQB1DDXibtqvhwUPgvjJCnY";
const REVENUECAT_SECRET =
  process.env.REVENUECAT_SECRET_KEY || "sk_jTsXZnbJhWRcJOIrXGJTUTpVsPGbp";

export const dynamic = "force-dynamic";

interface RCSubInfo {
  status: "active" | "inactive" | "not_found" | "error";
  activeEntitlements: string[];
  subscriptions: Array<{
    productId: string;
    isActive: boolean;
    expiresDate: string | null;
    purchaseDate: string | null;
    store: string;
    willRenew: boolean;
  }>;
  managementUrl: string | null;
  lastSeen: string | null;
}

async function fetchRCSubscriber(appUserId: string): Promise<RCSubInfo> {
  try {
    const res = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`, {
      headers: {
        Authorization: `Bearer ${REVENUECAT_SECRET}`,
        "Content-Type": "application/json",
      },
      cache: "no-store",
    });

    if (res.status === 404) {
      return {
        status: "not_found",
        activeEntitlements: [],
        subscriptions: [],
        managementUrl: null,
        lastSeen: null,
      };
    }

    if (!res.ok) {
      return {
        status: "error",
        activeEntitlements: [],
        subscriptions: [],
        managementUrl: null,
        lastSeen: null,
      };
    }

    const data = await res.json();
    const sub = data?.subscriber;
    const entitlementsObj = sub?.entitlements || {};
    const subscriptionsObj = sub?.subscriptions || {};

    const now = Date.now();
    const activeEntitlements: string[] = [];

    for (const [key, val] of Object.entries<any>(entitlementsObj)) {
      const expiresAt = val?.expires_date ? new Date(val.expires_date).getTime() : null;
      const isActive = expiresAt ? expiresAt > now : true;
      if (isActive) {
        activeEntitlements.push(key);
      }
    }

    const subscriptions = Object.entries<any>(subscriptionsObj).map(([productId, val]) => {
      const expiresAt = val?.expires_date ? new Date(val.expires_date).getTime() : null;
      const isActive = expiresAt ? expiresAt > now : true;
      return {
        productId,
        isActive,
        expiresDate: val?.expires_date || null,
        purchaseDate: val?.purchase_date || null,
        store: val?.store || "unknown",
        willRenew: Boolean(val?.will_renew),
      };
    });

    const isRcActive = activeEntitlements.length > 0 || subscriptions.some((s) => s.isActive);

    return {
      status: isRcActive ? "active" : "inactive",
      activeEntitlements,
      subscriptions,
      managementUrl: sub?.management_url || null,
      lastSeen: sub?.last_seen || null,
    };
  } catch (e) {
    return {
      status: "error",
      activeEntitlements: [],
      subscriptions: [],
      managementUrl: null,
      lastSeen: null,
    };
  }
}

export async function GET() {
  try {
    const headers = {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    };

    // 1. Fetch Supabase Profiles
    const profileRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?select=*`, {
      headers,
      cache: "no-store",
    });

    const profiles: any[] = profileRes.ok ? await profileRes.json() : [];

    // 2. Fetch Supabase Auth Users for email and providers
    const authRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users?per_page=1000`, {
      headers,
      cache: "no-store",
    });

    let authUsers: any[] = [];
    if (authRes.ok) {
      const authData = await authRes.json();
      authUsers = Array.isArray(authData) ? authData : authData.users || [];
    }

    const authMap = new Map<string, any>();
    for (const u of authUsers) {
      if (u.id) authMap.set(u.id, u);
    }

    // 3. Batch query RevenueCat for each profile (concurrency: 5)
    const auditResults: any[] = [];
    let dbProCount = 0;
    let rcProCount = 0;
    let syncedCount = 0;
    let mismatchCount = 0;

    // Concurrency chunking
    const chunkSize = 5;
    for (let i = 0; i < profiles.length; i += chunkSize) {
      const chunk = profiles.slice(i, i + chunkSize);
      const chunkPromises = chunk.map(async (p) => {
        const u = authMap.get(p.id) || {};
        const rcData = await fetchRCSubscriber(p.id);

        const dbTier = (p.tier || "free").toLowerCase() === "pro" ? "pro" : "free";
        const isDbPro = dbTier === "pro";
        const isRcPro = rcData.status === "active";

        if (isDbPro) dbProCount++;
        if (isRcPro) rcProCount++;

        let syncStatus: "synced_pro" | "synced_free" | "mismatch_db_free_rc_pro" | "mismatch_db_pro_rc_inactive";
        if (isDbPro && isRcPro) {
          syncStatus = "synced_pro";
          syncedCount++;
        } else if (!isDbPro && !isRcPro) {
          syncStatus = "synced_free";
          syncedCount++;
        } else if (!isDbPro && isRcPro) {
          syncStatus = "mismatch_db_free_rc_pro";
          mismatchCount++;
        } else {
          syncStatus = "mismatch_db_pro_rc_inactive";
          mismatchCount++;
        }

        let provider = "email";
        if (u.app_metadata?.provider) {
          provider = u.app_metadata.provider;
        } else if (Array.isArray(u.app_metadata?.providers) && u.app_metadata.providers.length > 0) {
          provider = u.app_metadata.providers[0];
        }

        return {
          id: p.id,
          email: u.email || (p.display_name?.includes("@") ? p.display_name : "ไม่มีอีเมล"),
          displayName:
            p.display_name ||
            u.user_metadata?.full_name ||
            u.user_metadata?.name ||
            (u.email ? u.email.split("@")[0] : "ผู้ใช้งาน SaveFor"),
          avatarUrl: p.avatar_url || u.user_metadata?.avatar_url || null,
          provider,
          createdAt: p.created_at || u.created_at || "",
          dbTier,
          dbExpiresAt: p.subscription_expires_at || null,
          dbPlan: p.subscription_plan || (dbTier === "pro" ? "monthly" : "free"),
          dbStore: p.subscription_store || null,
          rcData,
          isDbPro,
          isRcPro,
          syncStatus,
        };
      });

      const chunkResults = await Promise.all(chunkPromises);
      auditResults.push(...chunkResults);
    }

    // Sort by mismatch first, then latest created
    auditResults.sort((a, b) => {
      const isMismatchA = a.syncStatus.startsWith("mismatch") ? 1 : 0;
      const isMismatchB = b.syncStatus.startsWith("mismatch") ? 1 : 0;
      if (isMismatchA !== isMismatchB) return isMismatchB - isMismatchA;
      const timeA = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const timeB = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return timeB - timeA;
    });

    return NextResponse.json({
      success: true,
      comparison: {
        totalUsers: profiles.length,
        dbProCount,
        rcProCount,
        syncedCount,
        mismatchCount,
        isFullyInSync: mismatchCount === 0,
      },
      users: auditResults,
    });
  } catch (error: any) {
    console.error("[RevenueCat Audit API] Error:", error);
    return NextResponse.json(
      { success: false, error: error.message || "Failed to audit RevenueCat comparison" },
      { status: 500 }
    );
  }
}
