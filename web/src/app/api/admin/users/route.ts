import { NextResponse } from "next/server";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://nqgmimfkxgkkofaoddre.supabase.co";
const SERVICE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xZ21pbWZreGdra29mYW9kZHJlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MzA4MzQwMSwiZXhwIjoyMDk4NjU5NDAxfQ.n5sv4EyzAfV0zd9kIetUZQB1DDXibtqvhwUPgvjJCnY";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const headers = {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    };

    // 1. Fetch Auth Users
    const authRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users?per_page=1000`, {
      headers,
      cache: "no-store",
    });

    let authUsers: any[] = [];
    if (authRes.ok) {
      const authData = await authRes.json();
      authUsers = Array.isArray(authData) ? authData : authData.users || [];
    } else {
      console.error("[Admin API] Failed to fetch auth users:", authRes.status, await authRes.text());
    }

    // 2. Fetch Profiles table
    const profileRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?select=*`, {
      headers,
      cache: "no-store",
    });

    let profiles: any[] = [];
    if (profileRes.ok) {
      profiles = await profileRes.json();
    } else {
      console.error("[Admin API] Failed to fetch profiles:", profileRes.status, await profileRes.text());
    }

    // 3. Create Profile Map by ID
    const profileMap = new Map<string, any>();
    for (const p of profiles) {
      if (p.id) profileMap.set(p.id, p);
    }

    // 4. Combine and normalize
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).getTime();

    let proCount = 0;
    let freeCount = 0;
    let newTodayCount = 0;
    let newMonthCount = 0;

    const mergedUsers: any[] = [];
    const seenUserIds = new Set<string>();

    // Process Auth users first
    for (const u of authUsers) {
      const p = profileMap.get(u.id) || {};
      seenUserIds.add(u.id);

      const tier = (p.tier || "free").toLowerCase() === "pro" ? "pro" : "free";
      if (tier === "pro") proCount++;
      else freeCount++;

      const createdAtStr = u.created_at || p.created_at || "";
      const createdAtMs = createdAtStr ? new Date(createdAtStr).getTime() : 0;
      if (createdAtMs >= startOfToday) newTodayCount++;
      if (createdAtMs >= startOfMonth) newMonthCount++;

      let provider = "email";
      if (u.app_metadata?.provider) {
        provider = u.app_metadata.provider;
      } else if (Array.isArray(u.app_metadata?.providers) && u.app_metadata.providers.length > 0) {
        provider = u.app_metadata.providers[0];
      }

      mergedUsers.push({
        id: u.id,
        email: u.email || p.display_name?.includes("@") ? p.display_name : "ไม่มีอีเมล",
        displayName:
          p.display_name ||
          u.user_metadata?.full_name ||
          u.user_metadata?.name ||
          (u.email ? u.email.split("@")[0] : "ผู้ใช้งาน SaveFor"),
        avatarUrl: p.avatar_url || u.user_metadata?.avatar_url || u.user_metadata?.picture || null,
        tier,
        provider,
        createdAt: createdAtStr,
        lastSignInAt: u.last_sign_in_at || null,
        hasCompletedTutorial: p.has_completed_tutorial ?? false,
        subscriptionExpiresAt: p.subscription_expires_at || null,
        subscriptionPlan: p.subscription_plan || (tier === "pro" ? "monthly" : "free"),
        subscriptionStore: p.subscription_store || null,
      });
    }

    // Process any orphaned profiles not in auth list
    for (const p of profiles) {
      if (!seenUserIds.has(p.id)) {
        const tier = (p.tier || "free").toLowerCase() === "pro" ? "pro" : "free";
        if (tier === "pro") proCount++;
        else freeCount++;

        const createdAtStr = p.created_at || "";
        const createdAtMs = createdAtStr ? new Date(createdAtStr).getTime() : 0;
        if (createdAtMs >= startOfToday) newTodayCount++;
        if (createdAtMs >= startOfMonth) newMonthCount++;

        mergedUsers.push({
          id: p.id,
          email: p.display_name?.includes("@") ? p.display_name : "ไม่มีอีเมล",
          displayName: p.display_name || "ผู้ใช้งาน SaveFor",
          avatarUrl: p.avatar_url || null,
          tier,
          provider: "unknown",
          createdAt: createdAtStr,
          lastSignInAt: null,
          hasCompletedTutorial: p.has_completed_tutorial ?? false,
          subscriptionExpiresAt: p.subscription_expires_at || null,
          subscriptionPlan: p.subscription_plan || (tier === "pro" ? "monthly" : "free"),
          subscriptionStore: p.subscription_store || null,
        });
      }
    }

    // Sort by latest created first
    mergedUsers.sort((a, b) => {
      const timeA = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const timeB = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return timeB - timeA;
    });

    return NextResponse.json({
      success: true,
      stats: {
        total: mergedUsers.length,
        pro: proCount,
        free: freeCount,
        newToday: newTodayCount,
        newThisMonth: newMonthCount,
      },
      users: mergedUsers,
    });
  } catch (error: any) {
    console.error("[Admin Users API] Error:", error);
    return NextResponse.json(
      { success: false, error: error.message || "Failed to fetch users" },
      { status: 500 }
    );
  }
}
