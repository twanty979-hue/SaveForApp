"use client";

import React, { useState, useEffect, useMemo } from "react";
import Link from "next/link";

interface UserItem {
  id: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
  tier: "free" | "pro";
  provider: string;
  createdAt: string;
  lastSignInAt: string | null;
  hasCompletedTutorial: boolean;
  subscriptionExpiresAt?: string | null;
  subscriptionPlan?: string | null;
  subscriptionStore?: string | null;
}

interface Stats {
  total: number;
  pro: number;
  free: number;
  newToday: number;
  newThisMonth: number;
}

interface RCSubscriberData {
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

interface AuditUserItem {
  id: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
  provider: string;
  createdAt: string;
  dbTier: "free" | "pro";
  dbExpiresAt?: string | null;
  dbPlan?: string | null;
  dbStore?: string | null;
  rcData: RCSubscriberData;
  isDbPro: boolean;
  isRcPro: boolean;
  syncStatus:
    | "synced_pro"
    | "synced_free"
    | "mismatch_db_free_rc_pro"
    | "mismatch_db_pro_rc_inactive";
}

interface ComparisonStats {
  totalUsers: number;
  dbProCount: number;
  rcProCount: number;
  syncedCount: number;
  mismatchCount: number;
  isFullyInSync: boolean;
}

export default function AdminDashboardPage() {
  // Navigation Tabs
  const [activeTab, setActiveTab] = useState<"users" | "rc_audit" | "mismatch">("users");

  // Users State
  const [users, setUsers] = useState<UserItem[]>([]);
  const [stats, setStats] = useState<Stats>({
    total: 0,
    pro: 0,
    free: 0,
    newToday: 0,
    newThisMonth: 0,
  });
  const [isLoadingUsers, setIsLoadingUsers] = useState<boolean>(true);

  // RevenueCat Audit State
  const [auditUsers, setAuditUsers] = useState<AuditUserItem[]>([]);
  const [comparisonStats, setComparisonStats] = useState<ComparisonStats>({
    totalUsers: 0,
    dbProCount: 0,
    rcProCount: 0,
    syncedCount: 0,
    mismatchCount: 0,
    isFullyInSync: true,
  });
  const [isLoadingAudit, setIsLoadingAudit] = useState<boolean>(false);
  const [lastAuditTime, setLastAuditTime] = useState<string | null>(null);

  // Action Loading States
  const [updatingUserId, setUpdatingUserId] = useState<string | null>(null);
  const [isBulkSyncing, setIsBulkSyncing] = useState<boolean>(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [selectedUser, setSelectedUser] = useState<UserItem | AuditUserItem | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Filter & Search
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [tierFilter, setTierFilter] = useState<"all" | "pro" | "free">("all");
  const [providerFilter, setProviderFilter] = useState<string>("all");
  const [sortBy, setSortBy] = useState<"newest" | "recent_active" | "name">("newest");

  useEffect(() => {
    fetchUsers();
    fetchRevenueCatAudit();
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3800);
  };

  const fetchUsers = async () => {
    setIsLoadingUsers(true);
    setError(null);
    try {
      const res = await fetch("/api/admin/users");
      const data = await res.json();
      if (data.success) {
        setUsers(data.users || []);
        if (data.stats) setStats(data.stats);
      } else {
        setError(data.error || "เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้งาน");
      }
    } catch (err: any) {
      setError(err.message || "ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้");
    } finally {
      setIsLoadingUsers(false);
    }
  };

  const fetchRevenueCatAudit = async () => {
    setIsLoadingAudit(true);
    try {
      const res = await fetch("/api/admin/revenuecat/audit");
      const data = await res.json();
      if (data.success) {
        setAuditUsers(data.users || []);
        if (data.comparison) setComparisonStats(data.comparison);
        setLastAuditTime(
          new Date().toLocaleTimeString("th-TH", { hour: "2-digit", minute: "2-digit", second: "2-digit" })
        );
      }
    } catch (err: any) {
      console.error("RC Audit failed", err);
    } finally {
      setIsLoadingAudit(false);
    }
  };

  // Toggle tier in DB
  const handleToggleTier = async (user: { id: string; tier?: string; dbTier?: string; displayName: string }) => {
    const currentTier = user.tier || user.dbTier || "free";
    const nextTier = currentTier === "pro" ? "free" : "pro";
    setUpdatingUserId(user.id);
    try {
      const res = await fetch(`/api/admin/users/${user.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ tier: nextTier }),
      });
      const data = await res.json();
      if (data.success) {
        // Optimistic update users
        setUsers((prev) =>
          prev.map((u) => (u.id === user.id ? { ...u, tier: nextTier } : u))
        );
        // Optimistic update audit users
        setAuditUsers((prev) =>
          prev.map((u) => {
            if (u.id !== user.id) return u;
            const isDbPro = nextTier === "pro";
            let syncStatus: any = "synced_free";
            if (isDbPro && u.isRcPro) syncStatus = "synced_pro";
            else if (!isDbPro && !u.isRcPro) syncStatus = "synced_free";
            else if (!isDbPro && u.isRcPro) syncStatus = "mismatch_db_free_rc_pro";
            else syncStatus = "mismatch_db_pro_rc_inactive";

            return { ...u, dbTier: nextTier, isDbPro, syncStatus };
          })
        );
        // Update stats
        setStats((prev) => ({
          ...prev,
          pro: nextTier === "pro" ? prev.pro + 1 : prev.pro - 1,
          free: nextTier === "free" ? prev.free + 1 : prev.free - 1,
        }));
        showToast(
          nextTier === "pro"
            ? `⭐ ปรับผู้ใช้ "${user.displayName}" เป็น PRO สำเร็จ!`
            : `👤 ปรับผู้ใช้ "${user.displayName}" กลับเป็น Free เรียบร้อย`
        );
      } else {
        alert("ไม่สามารถปรับสถานะได้: " + (data.error || "Unknown error"));
      }
    } catch (err: any) {
      alert("Error: " + err.message);
    } finally {
      setUpdatingUserId(null);
    }
  };

  // Sync individual user DB tier directly from RevenueCat
  const handleSyncUserWithRC = async (userId: string, userName: string) => {
    setUpdatingUserId(userId);
    try {
      const res = await fetch("/api/admin/revenuecat/sync-user", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, action: "sync_db_with_rc" }),
      });
      const data = await res.json();
      if (data.success) {
        showToast(`⚡ ซิงก์ "${userName}" ให้ตรงกับ RevenueCat สำเร็จ! (${data.syncedTier?.toUpperCase()})`);
        // Refresh both lists
        fetchRevenueCatAudit();
        fetchUsers();
      } else {
        alert("ซิงก์ไม่สำเร็จ: " + (data.error || "Unknown error"));
      }
    } catch (err: any) {
      alert("Error: " + err.message);
    } finally {
      setUpdatingUserId(null);
    }
  };

  // Grant promotional entitlement in RevenueCat
  const handleGrantPromoRC = async (userId: string, userName: string) => {
    if (!confirm(`ต้องการมอบสิทธิ์ PRO โปรโมชันใน RevenueCat ให้กับ "${userName}" หรือไม่?`)) return;
    setUpdatingUserId(userId);
    try {
      const res = await fetch("/api/admin/revenuecat/sync-user", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, action: "grant_rc_promo", duration: "monthly" }),
      });
      const data = await res.json();
      if (data.success) {
        showToast(`🎁 มอบสิทธิ์ PRO โปรโมชันให้ "${userName}" ใน RevenueCat สำเร็จ!`);
        fetchRevenueCatAudit();
        fetchUsers();
      } else {
        alert("ไม่สำเร็จ: " + (data.error || "Unknown error"));
      }
    } catch (err: any) {
      alert("Error: " + err.message);
    } finally {
      setUpdatingUserId(null);
    }
  };

  // Delete subscriber in RevenueCat Sandbox (Reset)
  const handleDeleteRCSubscriber = async (userId: string, userName: string) => {
    if (
      !confirm(
        `⚠️ คุณแน่ใจหรือไม่ว่าต้องการลบประวัติการทดสอบใน RevenueCat ของ "${userName}"?\n(ข้อมูลใบเสร็จใน RC Sandbox จะถูกล้าง เพื่อให้ทดสอบกดซื้อใหม่ได้)`
      )
    )
      return;

    setUpdatingUserId(userId);
    try {
      const res = await fetch("/api/admin/revenuecat/sync-user", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, action: "delete_rc_subscriber" }),
      });
      const data = await res.json();
      if (data.success) {
        showToast(`🗑️ ล้างประวัติใน RevenueCat ของ "${userName}" สำเร็จ พร้อมทดสอบใหม่`);
        fetchRevenueCatAudit();
        fetchUsers();
      } else {
        alert("ลบไม่สำเร็จ: " + (data.error || "Unknown error"));
      }
    } catch (err: any) {
      alert("Error: " + err.message);
    } finally {
      setUpdatingUserId(null);
    }
  };

  // Bulk reconcile all mismatched users
  const handleBulkSyncAll = async () => {
    if (!confirm("คุณต้องการซิงก์ฐานข้อมูล Supabase ให้ตรงกับสถานะจริงใน RevenueCat ของทุกคนหรือไม่?")) return;
    setIsBulkSyncing(true);
    try {
      const res = await fetch("/api/admin/revenuecat/sync-all", { method: "POST" });
      const data = await res.json();
      if (data.success) {
        showToast(`🎉 ${data.message}`);
        await Promise.all([fetchRevenueCatAudit(), fetchUsers()]);
      } else {
        alert("Bulk sync failed: " + (data.error || "Unknown error"));
      }
    } catch (err: any) {
      alert("Error: " + err.message);
    } finally {
      setIsBulkSyncing(false);
    }
  };

  // Export CSV
  const handleExportCSV = () => {
    const listToExport = filteredUsers;
    if (listToExport.length === 0) return;
    const headers = ["User ID", "Display Name", "Email", "Tier", "Provider", "Created At", "Last Sign In"];
    const rows = listToExport.map((u) => [
      `"${u.id}"`,
      `"${u.displayName.replace(/"/g, '""')}"`,
      `"${u.email}"`,
      `"${u.tier.toUpperCase()}"`,
      `"${u.provider}"`,
      `"${u.createdAt ? new Date(u.createdAt).toLocaleString("th-TH") : "-"}"`,
      `"${u.lastSignInAt ? new Date(u.lastSignInAt).toLocaleString("th-TH") : "-"}"`,
    ]);

    const csvContent = "\uFEFF" + [headers.join(","), ...rows.map((r) => r.join(","))].join("\n");
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.setAttribute("download", `savefor_users_${new Date().toISOString().split("T")[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showToast("📥 ส่งออกรายงาน CSV เรียบร้อยแล้ว");
  };

  // Filtered Supabase Users
  const filteredUsers = useMemo(() => {
    let list = [...users];
    if (tierFilter !== "all") list = list.filter((u) => u.tier === tierFilter);
    if (providerFilter !== "all") list = list.filter((u) => u.provider.toLowerCase().includes(providerFilter.toLowerCase()));
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      list = list.filter(
        (u) =>
          u.displayName.toLowerCase().includes(q) ||
          u.email.toLowerCase().includes(q) ||
          u.id.toLowerCase().includes(q)
      );
    }
    list.sort((a, b) => {
      if (sortBy === "name") return a.displayName.localeCompare(b.displayName);
      if (sortBy === "recent_active") {
        const timeA = a.lastSignInAt ? new Date(a.lastSignInAt).getTime() : 0;
        const timeB = b.lastSignInAt ? new Date(b.lastSignInAt).getTime() : 0;
        return timeB - timeA;
      }
      const timeA = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const timeB = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return timeB - timeA;
    });
    return list;
  }, [users, tierFilter, providerFilter, searchQuery, sortBy]);

  // Filtered RevenueCat Audit Users
  const filteredAuditUsers = useMemo(() => {
    let list = [...auditUsers];
    if (activeTab === "mismatch") {
      list = list.filter((u) => u.syncStatus.startsWith("mismatch"));
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      list = list.filter(
        (u) =>
          u.displayName.toLowerCase().includes(q) ||
          u.email.toLowerCase().includes(q) ||
          u.id.toLowerCase().includes(q)
      );
    }
    return list;
  }, [auditUsers, activeTab, searchQuery]);

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return "-";
    try {
      const d = new Date(dateStr);
      return d.toLocaleDateString("th-TH", {
        year: "numeric",
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      });
    } catch {
      return dateStr;
    }
  };

  const getProviderBadge = (provider: string) => {
    const p = provider.toLowerCase();
    if (p.includes("google")) {
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-500/10 text-red-400 border border-red-500/20">
          <svg className="w-3.5 h-3.5" viewBox="0 0 24 24">
            <path
              fill="currentColor"
              d="M12.24 10.285V13.4h6.887C18.2 16.14 15.645 18 12.24 18c-3.323 0-6.01-2.697-6.01-6s2.687-6 6.01-6c1.488 0 2.85.545 3.9 1.45l2.42-2.42C16.945 3.52 14.73 2.6 12.24 2.6 6.945 2.6 2.6 6.945 2.6 12.24s4.345 9.64 9.64 9.64c5.54 0 9.215-3.9 9.215-9.38 0-.63-.065-1.22-.185-1.785H12.24z"
            />
          </svg>
          Google
        </span>
      );
    }
    if (p.includes("apple")) {
      return (
        <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-zinc-700/50 text-zinc-300 border border-zinc-600/30">
          <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.63-.77 1.06-1.84.94-2.91-.91.04-2.02.61-2.67 1.38-.58.67-1.09 1.76-.95 2.81 1.02.08 2.05-.51 2.68-1.28" />
          </svg>
          Apple
        </span>
      );
    }
    return (
      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-500/10 text-blue-400 border border-blue-500/20">
        ✉️ อีเมล
      </span>
    );
  };

  const renderSyncBadge = (status: AuditUserItem["syncStatus"]) => {
    switch (status) {
      case "synced_pro":
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
            <span className="w-2 h-2 rounded-full bg-emerald-400" />
            🟢 ตรงกัน (PRO)
          </span>
        );
      case "synced_free":
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-800 text-slate-400 border border-slate-700/80">
            <span className="w-2 h-2 rounded-full bg-slate-500" />
            🟢 ตรงกัน (Free)
          </span>
        );
      case "mismatch_db_free_rc_pro":
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-extrabold bg-amber-500/20 text-amber-300 border border-amber-500/40 animate-pulse">
            <span>⚠️</span>
            DB Free แต่ RevenueCat มี PRO!
          </span>
        );
      case "mismatch_db_pro_rc_inactive":
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-extrabold bg-rose-500/20 text-rose-300 border border-rose-500/40">
            <span>⚠️</span>
            DB PRO แต่ RevenueCat หมดอายุ/ไม่มีสิทธิ์
          </span>
        );
    }
  };

  return (
    <div className="min-h-screen bg-[#0A0E17] text-slate-100 font-sans selection:bg-emerald-500 selection:text-white pb-20">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 flex items-center gap-3 bg-slate-900/95 text-white px-5 py-3.5 rounded-2xl border border-emerald-500/50 shadow-2xl shadow-emerald-500/20 backdrop-blur-xl animate-fade-in">
          <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-ping" />
          <p className="text-sm font-semibold">{toastMessage}</p>
        </div>
      )}

      {/* Top Navigation Bar */}
      <header className="sticky top-0 z-40 bg-[#0A0E17]/90 backdrop-blur-md border-b border-slate-800/80 px-4 lg:px-8 py-3.5">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3.5">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-400 to-teal-600 flex items-center justify-center shadow-lg shadow-emerald-500/20">
              <span className="text-xl">💰</span>
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-base font-bold tracking-tight text-white">SaveFor</span>
                <span className="text-[10px] uppercase tracking-wider font-extrabold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-2 py-0.5 rounded-md">
                  Admin & Subscriptions
                </span>
              </div>
              <p className="text-xs text-slate-400">
                ระบบจัดการผู้ใช้ & เปรียบเทียบข้อมูล RevenueCat กับ Supabase Database
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            <Link
              href="/bank-rules"
              className="hidden md:flex items-center gap-1.5 text-xs font-semibold px-3 py-2 rounded-xl bg-slate-800/80 hover:bg-slate-700/80 text-slate-300 hover:text-white border border-slate-700/60 transition-all"
            >
              ⚙️ กฎธนาคาร
            </Link>

            <button
              onClick={() => {
                fetchUsers();
                fetchRevenueCatAudit();
              }}
              disabled={isLoadingUsers || isLoadingAudit}
              className="flex items-center gap-2 text-xs font-semibold px-3.5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-600/20 transition-all disabled:opacity-50"
            >
              <svg
                className={`w-3.5 h-3.5 ${isLoadingUsers || isLoadingAudit ? "animate-spin" : ""}`}
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2.5"
                  d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                />
              </svg>
              <span>รีเฟรชข้อมูล</span>
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 lg:px-8 py-8">
        {/* ========================================================================= */}
        {/* REVENUECAT VS SUPABASE DATABASE COMPARISON BANNER */}
        {/* ========================================================================= */}
        <section className="mb-8">
          <div className="bg-gradient-to-r from-slate-900 via-indigo-950/40 to-slate-900 border border-indigo-500/30 rounded-3xl p-6 shadow-2xl relative overflow-hidden">
            <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-6 relative z-10">
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <span className="text-xl">⚡</span>
                  <h2 className="text-lg font-black text-white tracking-tight">
                    ผลการเปรียบเทียบ: Supabase Database vs RevenueCat
                  </h2>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30">
                    Live API Verified
                  </span>
                </div>
                <p className="text-xs text-slate-300">
                  ตรวจสอบความถูกต้องระหว่างฐานข้อมูลหลัก Supabase กับยอดผู้สมัครจริงในระบบ RevenueCat
                  {lastAuditTime && ` • ตรวจสอบล่าสุดเมื่อ ${lastAuditTime}`}
                </p>
              </div>

              {/* Status pill & Sync button */}
              <div className="flex flex-wrap items-center gap-3">
                {comparisonStats.isFullyInSync ? (
                  <div className="flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 text-xs font-bold">
                    <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                    <span>🟢 ข้อมูลตรงกัน 100% (In Sync)</span>
                  </div>
                ) : (
                  <div className="flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-amber-500/20 text-amber-300 border border-amber-500/40 text-xs font-bold animate-pulse">
                    <span>⚠️</span>
                    <span>พบข้อมูลไม่ตรงกัน {comparisonStats.mismatchCount} รายการ!</span>
                  </div>
                )}

                {!comparisonStats.isFullyInSync && (
                  <button
                    onClick={handleBulkSyncAll}
                    disabled={isBulkSyncing}
                    className="flex items-center gap-2 text-xs font-bold px-4 py-2 rounded-xl bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-400 hover:to-orange-400 text-slate-950 shadow-lg shadow-amber-500/20 transition-all disabled:opacity-50"
                  >
                    <span>⚡</span>
                    <span>{isBulkSyncing ? "กำลังซิงก์..." : "ซิงก์ทุกคนให้ตรงกับ RevenueCat"}</span>
                  </button>
                )}
              </div>
            </div>

            {/* Comparison Metrics Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6">
              {/* Total Users */}
              <div className="bg-slate-950/60 border border-slate-800/80 rounded-2xl p-4">
                <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider block">
                  ผู้ใช้ทั้งหมดในระบบ
                </span>
                <div className="text-2xl font-black text-white mt-1">
                  {isLoadingAudit ? "..." : comparisonStats.totalUsers} <span className="text-xs font-normal text-slate-400">บัญชี</span>
                </div>
                <span className="text-[10px] text-slate-500 mt-0.5 block">Supabase Auth & Profiles</span>
              </div>

              {/* Supabase PRO Count */}
              <div className="bg-slate-950/60 border border-slate-800/80 rounded-2xl p-4">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] font-semibold text-emerald-400 uppercase tracking-wider block">
                    PRO ใน Database
                  </span>
                  <span className="text-xs">🗄️</span>
                </div>
                <div className="text-2xl font-black text-emerald-400 mt-1">
                  {isLoadingAudit ? "..." : comparisonStats.dbProCount} <span className="text-xs font-normal text-slate-400">คน</span>
                </div>
                <span className="text-[10px] text-emerald-400/70 mt-0.5 block">ตาราง profiles (tier = 'pro')</span>
              </div>

              {/* RevenueCat PRO Count */}
              <div className="bg-slate-950/60 border border-slate-800/80 rounded-2xl p-4">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] font-semibold text-indigo-400 uppercase tracking-wider block">
                    PRO ใน RevenueCat
                  </span>
                  <span className="text-xs">⚡</span>
                </div>
                <div className="text-2xl font-black text-indigo-400 mt-1">
                  {isLoadingAudit ? "..." : comparisonStats.rcProCount} <span className="text-xs font-normal text-slate-400">คน</span>
                </div>
                <span className="text-[10px] text-indigo-400/70 mt-0.5 block">Active Entitlements ใน RC</span>
              </div>

              {/* Mismatch Count */}
              <div
                className={`bg-slate-950/60 rounded-2xl p-4 border ${
                  comparisonStats.mismatchCount > 0
                    ? "border-amber-500/40 bg-amber-500/5"
                    : "border-slate-800/80"
                }`}
              >
                <div className="flex items-center justify-between">
                  <span
                    className={`text-[11px] font-semibold uppercase tracking-wider block ${
                      comparisonStats.mismatchCount > 0 ? "text-amber-400" : "text-slate-400"
                    }`}
                  >
                    ความคลาดเคลื่อน
                  </span>
                  <span className="text-xs">{comparisonStats.mismatchCount > 0 ? "⚠️" : "✅"}</span>
                </div>
                <div
                  className={`text-2xl font-black mt-1 ${
                    comparisonStats.mismatchCount > 0 ? "text-amber-400" : "text-emerald-400"
                  }`}
                >
                  {isLoadingAudit ? "..." : comparisonStats.mismatchCount} <span className="text-xs font-normal text-slate-400">คน</span>
                </div>
                <span className="text-[10px] text-slate-500 mt-0.5 block">
                  {comparisonStats.mismatchCount > 0 ? "กดดูที่แท็บด้านล่างเพื่อซิงก์" : "ตรงกันสมบูรณ์"}
                </span>
              </div>
            </div>

            <div className="absolute top-0 right-0 w-80 h-80 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none" />
          </div>
        </section>

        {/* ========================================================================= */}
        {/* TABS NAVIGATION */}
        {/* ========================================================================= */}
        <div className="flex items-center gap-2 mb-6 border-b border-slate-800/80 pb-3">
          <button
            onClick={() => setActiveTab("users")}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-bold transition-all ${
              activeTab === "users"
                ? "bg-emerald-600 text-white shadow-lg shadow-emerald-600/20"
                : "bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800/60 border border-slate-800/80"
            }`}
          >
            <span>👥</span>
            <span>รายชื่อผู้ใช้งาน Supabase ({stats.total})</span>
          </button>

          <button
            onClick={() => setActiveTab("rc_audit")}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-bold transition-all ${
              activeTab === "rc_audit"
                ? "bg-indigo-600 text-white shadow-lg shadow-indigo-600/20"
                : "bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800/60 border border-slate-800/80"
            }`}
          >
            <span>⚡</span>
            <span>ตารางเปรียบเทียบ RevenueCat ({auditUsers.length})</span>
          </button>

          <button
            onClick={() => setActiveTab("mismatch")}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-bold transition-all relative ${
              activeTab === "mismatch"
                ? "bg-amber-600 text-white shadow-lg shadow-amber-600/20"
                : "bg-slate-900/60 text-slate-400 hover:text-white hover:bg-slate-800/60 border border-slate-800/80"
            }`}
          >
            <span>⚠️</span>
            <span>รายการที่ไม่ตรงกัน</span>
            {comparisonStats.mismatchCount > 0 && (
              <span className="w-5 h-5 rounded-full bg-red-500 text-white text-[10px] font-black flex items-center justify-center">
                {comparisonStats.mismatchCount}
              </span>
            )}
          </button>
        </div>

        {/* Filter and Search Bar */}
        <div className="bg-slate-900/80 border border-slate-800/90 rounded-2xl p-4 mb-6 backdrop-blur-xl shadow-lg">
          <div className="flex flex-col md:flex-row gap-3.5 items-stretch md:items-center justify-between">
            {/* Search Input */}
            <div className="relative flex-1">
              <span className="absolute inset-y-0 left-3.5 flex items-center pointer-events-none text-slate-400">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </span>
              <input
                type="text"
                placeholder="ค้นหาชื่อผู้ใช้, อีเมล, หรือ User ID..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-slate-950/70 border border-slate-800 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500/80 transition-all"
              />
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery("")}
                  className="absolute inset-y-0 right-3 flex items-center text-slate-500 hover:text-white"
                >
                  ✕
                </button>
              )}
            </div>

            {activeTab === "users" && (
              <>
                {/* Filter Tabs for users */}
                <div className="flex items-center gap-1.5 bg-slate-950/70 p-1 rounded-xl border border-slate-800/80">
                  <button
                    onClick={() => setTierFilter("all")}
                    className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                      tierFilter === "all" ? "bg-emerald-600 text-white shadow-sm" : "text-slate-400 hover:text-white"
                    }`}
                  >
                    ทั้งหมด ({stats.total})
                  </button>
                  <button
                    onClick={() => setTierFilter("pro")}
                    className={`px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1 transition-all ${
                      tierFilter === "pro" ? "bg-emerald-600 text-white shadow-sm" : "text-slate-400 hover:text-emerald-400"
                    }`}
                  >
                    <span>⭐</span> PRO ({stats.pro})
                  </button>
                  <button
                    onClick={() => setTierFilter("free")}
                    className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                      tierFilter === "free" ? "bg-slate-800 text-white shadow-sm" : "text-slate-400 hover:text-white"
                    }`}
                  >
                    Free ({stats.free})
                  </button>
                </div>

                <div className="flex items-center gap-2">
                  <select
                    value={providerFilter}
                    onChange={(e) => setProviderFilter(e.target.value)}
                    className="bg-slate-950/70 border border-slate-800 text-xs text-slate-300 rounded-xl px-3 py-2.5 focus:outline-none focus:border-emerald-500"
                  >
                    <option value="all">ช่องทาง: ทั้งหมด</option>
                    <option value="google">Google</option>
                    <option value="apple">Apple</option>
                    <option value="email">อีเมล</option>
                  </select>

                  <select
                    value={sortBy}
                    onChange={(e) => setSortBy(e.target.value as any)}
                    className="bg-slate-950/70 border border-slate-800 text-xs text-slate-300 rounded-xl px-3 py-2.5 focus:outline-none focus:border-emerald-500"
                  >
                    <option value="newest">สมัครล่าสุด</option>
                    <option value="recent_active">ใช้งานล่าสุด</option>
                    <option value="name">ชื่อ A-Z</option>
                  </select>

                  <button
                    onClick={handleExportCSV}
                    title="ดาวน์โหลดเป็นไฟล์ CSV"
                    className="flex items-center gap-1.5 px-3 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold border border-slate-700/80 transition-all"
                  >
                    <span>📥</span>
                    <span className="hidden sm:inline">CSV</span>
                  </button>
                </div>
              </>
            )}
          </div>
        </div>

        {/* Error Alert */}
        {error && (
          <div className="mb-6 p-4 rounded-2xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span>⚠️</span>
              <span>{error}</span>
            </div>
            <button onClick={fetchUsers} className="text-xs font-bold underline hover:text-red-300">
              ลองใหม่
            </button>
          </div>
        )}

        {/* ========================================================================= */}
        {/* VIEW 1: SUPABASE USERS LIST */}
        {/* ========================================================================= */}
        {activeTab === "users" && (
          <div className="bg-slate-900/80 border border-slate-800/90 rounded-2xl overflow-hidden shadow-xl backdrop-blur-xl">
            {isLoadingUsers ? (
              <div className="py-24 text-center">
                <div className="w-10 h-10 border-3 border-emerald-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
                <p className="text-sm text-slate-400">กำลังเชื่อมต่อ Supabase เพื่อดึงรายชื่อผู้ใช้...</p>
              </div>
            ) : filteredUsers.length === 0 ? (
              <div className="py-24 text-center">
                <span className="text-4xl block mb-3">🔍</span>
                <p className="text-base font-semibold text-white mb-1">ไม่พบข้อมูลผู้ใช้ที่ตรงกับเงื่อนไข</p>
                <p className="text-xs text-slate-400">ลองล้างการค้นหาหรือเปลี่ยนตัวกรองใหม่</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="border-b border-slate-800/80 bg-slate-950/40 text-[11px] font-bold uppercase tracking-wider text-slate-400">
                      <th className="py-3.5 px-5">ผู้ใช้งาน</th>
                      <th className="py-3.5 px-5">สถานะใน DB</th>
                      <th className="py-3.5 px-5">ช่องทาง</th>
                      <th className="py-3.5 px-5">วันที่สมัคร</th>
                      <th className="py-3.5 px-5">ใช้งานล่าสุด</th>
                      <th className="py-3.5 px-5 text-right">ปรับสิทธิ์ด่วน</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/50 text-sm">
                    {filteredUsers.map((user) => {
                      const isPro = user.tier === "pro";
                      const isUpdating = updatingUserId === user.id;

                      return (
                        <tr
                          key={user.id}
                          className="hover:bg-slate-800/40 transition-colors group cursor-pointer"
                          onClick={() => setSelectedUser(user)}
                        >
                          {/* User Profile */}
                          <td className="py-4 px-5">
                            <div className="flex items-center gap-3">
                              {user.avatarUrl ? (
                                <img
                                  src={user.avatarUrl}
                                  alt={user.displayName}
                                  className="w-10 h-10 rounded-full object-cover border border-slate-700/80 shadow-sm"
                                />
                              ) : (
                                <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-slate-700 to-slate-600 flex items-center justify-center font-bold text-white text-sm shadow-sm border border-slate-700">
                                  {user.displayName.substring(0, 1).toUpperCase()}
                                </div>
                              )}
                              <div>
                                <div className="flex items-center gap-2">
                                  <span className="font-semibold text-white group-hover:text-emerald-400 transition-colors">
                                    {user.displayName}
                                  </span>
                                  {isPro && (
                                    <span className="text-[10px] bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 px-1.5 py-0.2 rounded font-extrabold">
                                      PRO
                                    </span>
                                  )}
                                </div>
                                <p className="text-xs text-slate-400 font-mono tracking-tight">{user.email}</p>
                              </div>
                            </div>
                          </td>

                          {/* Tier Status Badge */}
                          <td className="py-4 px-5">
                            {isPro ? (
                              <div>
                                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-gradient-to-r from-emerald-500/20 to-teal-500/20 text-emerald-300 border border-emerald-500/40 shadow-sm shadow-emerald-500/10">
                                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                                  SaveFor PRO ⭐
                                </span>
                                {user.subscriptionExpiresAt && (
                                  <p className="text-[10px] text-emerald-400/80 mt-1 font-mono">
                                    หมดอายุ: {formatDate(user.subscriptionExpiresAt)}
                                  </p>
                                )}
                              </div>
                            ) : (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-slate-800 text-slate-400 border border-slate-700">
                                Free Plan
                              </span>
                            )}
                          </td>

                          {/* Auth Provider */}
                          <td className="py-4 px-5">{getProviderBadge(user.provider)}</td>

                          {/* Created At */}
                          <td className="py-4 px-5 text-xs text-slate-400 font-mono">
                            {formatDate(user.createdAt)}
                          </td>

                          {/* Last Sign In */}
                          <td className="py-4 px-5 text-xs text-slate-400 font-mono">
                            {formatDate(user.lastSignInAt)}
                          </td>

                          {/* Actions */}
                          <td className="py-4 px-5 text-right" onClick={(e) => e.stopPropagation()}>
                            <div className="flex items-center justify-end gap-2">
                              <button
                                onClick={() => handleToggleTier(user)}
                                disabled={isUpdating}
                                className={`text-xs font-bold px-3 py-1.5 rounded-xl border transition-all ${
                                  isPro
                                    ? "bg-slate-800/80 hover:bg-red-500/20 text-slate-300 hover:text-red-400 border-slate-700 hover:border-red-500/30"
                                    : "bg-emerald-600/20 hover:bg-emerald-600 text-emerald-400 hover:text-white border-emerald-500/40"
                                } disabled:opacity-50`}
                              >
                                {isUpdating ? "..." : isPro ? "ปรับเป็น Free" : "⚡ อัปเป็น PRO"}
                              </button>
                              <button
                                onClick={() => setSelectedUser(user)}
                                className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
                                title="ดูรายละเอียดผู้ใช้"
                              >
                                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" />
                                </svg>
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* ========================================================================= */}
        {/* VIEW 2 & 3: REVENUECAT VS SUPABASE COMPARISON AUDIT TABLE */}
        {/* ========================================================================= */}
        {(activeTab === "rc_audit" || activeTab === "mismatch") && (
          <div className="bg-slate-900/80 border border-slate-800/90 rounded-2xl overflow-hidden shadow-xl backdrop-blur-xl">
            {isLoadingAudit ? (
              <div className="py-24 text-center">
                <div className="w-10 h-10 border-3 border-indigo-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
                <p className="text-sm text-slate-400">กำลังยิงตรวจเทียบกับ RevenueCat v1 REST API...</p>
                <p className="text-xs text-slate-500 mt-1">Bearer sk_jTsXZnbJhWRcJOIrXGJTUTpVsPGbp</p>
              </div>
            ) : filteredAuditUsers.length === 0 ? (
              <div className="py-24 text-center">
                <span className="text-4xl block mb-3">
                  {activeTab === "mismatch" ? "🎉" : "🔍"}
                </span>
                <p className="text-base font-semibold text-white mb-1">
                  {activeTab === "mismatch"
                    ? "ยอดเยี่ยม! ไม่มีข้อมูลไม่ตรงกันเลย ทุกบัญชีถูกต้องตรงกัน 100%"
                    : "ไม่พบข้อมูลผู้ใช้ที่ตรงกับเงื่อนไข"}
                </p>
                <p className="text-xs text-slate-400">
                  {activeTab === "mismatch"
                    ? "ฐานข้อมูล Supabase และ RevenueCat สอดคล้องกันทั้งหมด"
                    : "ลองรีเฟรชข้อมูลหรือล้างการค้นหา"}
                </p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="border-b border-slate-800/80 bg-slate-950/40 text-[11px] font-bold uppercase tracking-wider text-slate-400">
                      <th className="py-3.5 px-5">ผู้ใช้งาน</th>
                      <th className="py-3.5 px-5">สถานะใน DB (Supabase)</th>
                      <th className="py-3.5 px-5">สถานะใน RevenueCat</th>
                      <th className="py-3.5 px-5">ผลการเทียบเคียง</th>
                      <th className="py-3.5 px-5 text-right">เครื่องมือซิงก์ & จัดการ</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/50 text-sm">
                    {filteredAuditUsers.map((item) => {
                      const isUpdating = updatingUserId === item.id;
                      const hasActiveEntitlement = item.rcData.activeEntitlements.length > 0;

                      return (
                        <tr
                          key={item.id}
                          className="hover:bg-slate-800/40 transition-colors group cursor-pointer"
                          onClick={() => setSelectedUser(item)}
                        >
                          {/* User info */}
                          <td className="py-4 px-5">
                            <div className="flex items-center gap-3">
                              {item.avatarUrl ? (
                                <img
                                  src={item.avatarUrl}
                                  alt={item.displayName}
                                  className="w-10 h-10 rounded-full object-cover border border-slate-700/80 shadow-sm"
                                />
                              ) : (
                                <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-indigo-700 to-indigo-600 flex items-center justify-center font-bold text-white text-sm shadow-sm border border-slate-700">
                                  {item.displayName.substring(0, 1).toUpperCase()}
                                </div>
                              )}
                              <div>
                                <span className="font-semibold text-white group-hover:text-indigo-400 transition-colors">
                                  {item.displayName}
                                </span>
                                <p className="text-xs text-slate-400 font-mono tracking-tight">{item.email}</p>
                                <p className="text-[10px] text-slate-500 font-mono tracking-tight">ID: {item.id.substring(0, 8)}...</p>
                              </div>
                            </div>
                          </td>

                          {/* Supabase DB Tier */}
                          <td className="py-4 px-5">
                            {item.isDbPro ? (
                              <div>
                                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">
                                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                                  PRO ⭐
                                </span>
                                {item.dbExpiresAt && (
                                  <p className="text-[10px] text-emerald-400/80 mt-1 font-mono">
                                    หมดอายุ: {formatDate(item.dbExpiresAt)}
                                  </p>
                                )}
                              </div>
                            ) : (
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-slate-800 text-slate-400 border border-slate-700">
                                Free 👤
                              </span>
                            )}
                          </td>

                          {/* RevenueCat Status */}
                          <td className="py-4 px-5">
                            {item.isRcPro ? (
                              <div>
                                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-indigo-500/20 text-indigo-300 border border-indigo-500/40">
                                  <span className="w-1.5 h-1.5 rounded-full bg-indigo-400 animate-pulse" />
                                  Active ({item.rcData.activeEntitlements.join(", ") || "pro"})
                                </span>
                                {item.rcData.subscriptions.length > 0 && (
                                  <p className="text-[10px] text-indigo-300/70 mt-1 font-mono">
                                    {item.rcData.subscriptions[0].store} • {item.rcData.subscriptions[0].productId}
                                  </p>
                                )}
                              </div>
                            ) : (
                              <div>
                                <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-slate-800/80 text-slate-400 border border-slate-700/80">
                                  {item.rcData.status === "not_found" ? "ยังไม่เคยเข้าแอป" : "ไม่มีสมาชิกที่ใช้งาน"}
                                </span>
                                {item.rcData.lastSeen && (
                                  <p className="text-[10px] text-slate-500 mt-1">
                                    เข้าแอปล่าสุด: {formatDate(item.rcData.lastSeen)}
                                  </p>
                                )}
                              </div>
                            )}
                          </td>

                          {/* Comparison Sync Status */}
                          <td className="py-4 px-5">
                            {renderSyncBadge(item.syncStatus)}
                          </td>

                          {/* Reconcile & Action Buttons */}
                          <td className="py-4 px-5 text-right" onClick={(e) => e.stopPropagation()}>
                            <div className="flex items-center justify-end gap-2 flex-wrap">
                              {/* 1-Click Sync Button */}
                              <button
                                onClick={() => handleSyncUserWithRC(item.id, item.displayName)}
                                disabled={isUpdating}
                                title="ปรับสถานะใน DB ให้ตรงกับ RevenueCat ทันที"
                                className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-xl bg-indigo-600/30 hover:bg-indigo-600 text-indigo-300 hover:text-white border border-indigo-500/40 transition-all disabled:opacity-50"
                              >
                                <span>🔄</span>
                                <span>{isUpdating ? "..." : "ซิงก์ DB"}</span>
                              </button>

                              {/* Grant Promo */}
                              <button
                                onClick={() => handleGrantPromoRC(item.id, item.displayName)}
                                disabled={isUpdating}
                                title="มอบสิทธิ์ PRO โปรโมชันใน RevenueCat (1 เดือน)"
                                className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-xl bg-emerald-600/20 hover:bg-emerald-600 text-emerald-400 hover:text-white border border-emerald-500/30 transition-all disabled:opacity-50"
                              >
                                <span>🎁</span>
                                <span>แจก PRO</span>
                              </button>

                              {/* Reset RC sandbox */}
                              <button
                                onClick={() => handleDeleteRCSubscriber(item.id, item.displayName)}
                                disabled={isUpdating}
                                title="ล้างประวัติการทดสอบใน RevenueCat เพื่อทดสอบซื้อใหม่"
                                className="p-1.5 rounded-xl text-slate-500 hover:text-rose-400 hover:bg-rose-500/10 border border-transparent hover:border-rose-500/30 transition-all disabled:opacity-50"
                              >
                                <span>🗑️</span>
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </main>

      {/* ========================================================================= */}
      {/* USER & REVENUECAT DETAILS MODAL */}
      {/* ========================================================================= */}
      {selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-fade-in">
          <div className="bg-[#111827] border border-slate-800 rounded-3xl w-full max-w-xl p-6 shadow-2xl relative max-h-[90vh] overflow-y-auto">
            <button
              onClick={() => setSelectedUser(null)}
              className="absolute top-5 right-5 text-slate-400 hover:text-white text-lg w-8 h-8 rounded-full bg-slate-800/60 flex items-center justify-center"
            >
              ✕
            </button>

            {/* Profile Header */}
            <div className="flex items-center gap-4 mb-6">
              {selectedUser.avatarUrl ? (
                <img
                  src={selectedUser.avatarUrl}
                  alt={selectedUser.displayName}
                  className="w-16 h-16 rounded-2xl object-cover border-2 border-emerald-500/50"
                />
              ) : (
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-emerald-600 to-indigo-600 flex items-center justify-center text-white text-2xl font-black">
                  {selectedUser.displayName.substring(0, 1).toUpperCase()}
                </div>
              )}
              <div>
                <h3 className="text-xl font-bold text-white flex items-center gap-2">
                  {selectedUser.displayName}
                  {((selectedUser as any).tier === "pro" || (selectedUser as any).dbTier === "pro") && (
                    <span className="text-emerald-400 text-sm">⭐ PRO</span>
                  )}
                </h3>
                <p className="text-sm text-slate-400">{selectedUser.email}</p>
                <div className="mt-1.5">{getProviderBadge(selectedUser.provider)}</div>
              </div>
            </div>

            {/* Supabase DB Details Box */}
            <div className="space-y-2 bg-slate-950/70 p-4 rounded-2xl border border-slate-800/80 text-xs font-mono mb-4">
              <div className="text-[11px] font-bold text-emerald-400 uppercase tracking-wider mb-2 font-sans flex items-center gap-1.5">
                <span>🗄️</span> ข้อมูลใน Supabase Database
              </div>
              <div className="flex justify-between py-1 border-b border-slate-800/50">
                <span className="text-slate-500 font-sans">User ID (UUID):</span>
                <span
                  onClick={() => {
                    navigator.clipboard.writeText(selectedUser.id);
                    showToast("📋 คัดลอก User ID เรียบร้อยแล้ว");
                  }}
                  className="text-emerald-400 hover:underline cursor-pointer"
                  title="คลิกเพื่อคัดลอก"
                >
                  {selectedUser.id}
                </span>
              </div>
              <div className="flex justify-between py-1 border-b border-slate-800/50">
                <span className="text-slate-500 font-sans">สถานะ DB Tier:</span>
                <span
                  className={
                    ((selectedUser as any).tier === "pro" || (selectedUser as any).dbTier === "pro")
                      ? "text-emerald-400 font-bold"
                      : "text-slate-300"
                  }
                >
                  {((selectedUser as any).tier || (selectedUser as any).dbTier || "free").toUpperCase()}
                </span>
              </div>
              <div className="flex justify-between py-1 border-b border-slate-800/50">
                <span className="text-slate-500 font-sans">วันหมดอายุใน DB:</span>
                <span className="text-slate-300">
                  {formatDate((selectedUser as any).subscriptionExpiresAt || (selectedUser as any).dbExpiresAt)}
                </span>
              </div>
              <div className="flex justify-between py-1 border-b border-slate-800/50">
                <span className="text-slate-500 font-sans">แผนการสมัครใน DB:</span>
                <span className="text-slate-300">
                  {((selectedUser as any).subscriptionPlan || (selectedUser as any).dbPlan || "free").toUpperCase()}
                </span>
              </div>
              <div className="flex justify-between py-1 border-b border-slate-800/50">
                <span className="text-slate-500 font-sans">ช่องทางชำระเงิน (Store):</span>
                <span className="text-slate-300">
                  {(selectedUser as any).subscriptionStore || (selectedUser as any).dbStore || "-"}
                </span>
              </div>
              <div className="flex justify-between py-1 border-b border-slate-800/50">
                <span className="text-slate-500 font-sans">วันที่สมัคร:</span>
                <span className="text-slate-300">{formatDate(selectedUser.createdAt)}</span>
              </div>
              {"lastSignInAt" in selectedUser && (
                <div className="flex justify-between py-1">
                  <span className="text-slate-500 font-sans">เข้าใช้งานล่าสุด:</span>
                  <span className="text-slate-300">{formatDate((selectedUser as any).lastSignInAt)}</span>
                </div>
              )}
            </div>

            {/* RevenueCat Subscriber Details Box */}
            {"rcData" in selectedUser && (
              <div className="space-y-2 bg-indigo-950/20 p-4 rounded-2xl border border-indigo-500/30 text-xs font-mono mb-6">
                <div className="text-[11px] font-bold text-indigo-400 uppercase tracking-wider mb-2 font-sans flex items-center gap-1.5">
                  <span>⚡</span> ข้อมูลใน RevenueCat (API Verified)
                </div>
                <div className="flex justify-between py-1 border-b border-indigo-500/20">
                  <span className="text-slate-400 font-sans">สถานะใน RevenueCat:</span>
                  <span className={(selectedUser as AuditUserItem).isRcPro ? "text-indigo-400 font-bold" : "text-slate-400"}>
                    {(selectedUser as AuditUserItem).rcData.status.toUpperCase()}
                  </span>
                </div>
                <div className="flex justify-between py-1 border-b border-indigo-500/20">
                  <span className="text-slate-400 font-sans">Active Entitlements:</span>
                  <span className="text-indigo-300">
                    {(selectedUser as AuditUserItem).rcData.activeEntitlements.length > 0
                      ? (selectedUser as AuditUserItem).rcData.activeEntitlements.join(", ")
                      : "ไม่มี"}
                  </span>
                </div>
                {(selectedUser as AuditUserItem).rcData.subscriptions.length > 0 && (
                  <>
                    <div className="flex justify-between py-1 border-b border-indigo-500/20">
                      <span className="text-slate-400 font-sans">Store / Product:</span>
                      <span className="text-slate-300">
                        {(selectedUser as AuditUserItem).rcData.subscriptions[0].store} / {(selectedUser as AuditUserItem).rcData.subscriptions[0].productId}
                      </span>
                    </div>
                    <div className="flex justify-between py-1 border-b border-indigo-500/20">
                      <span className="text-slate-400 font-sans">วันหมดอายุสิทธิ์:</span>
                      <span className="text-slate-300">
                        {formatDate((selectedUser as AuditUserItem).rcData.subscriptions[0].expiresDate)}
                      </span>
                    </div>
                  </>
                )}
                <div className="flex justify-between py-1">
                  <span className="text-slate-400 font-sans">ผลการเทียบเคียง:</span>
                  <div>{renderSyncBadge((selectedUser as AuditUserItem).syncStatus)}</div>
                </div>
              </div>
            )}

            {/* Actions Footer */}
            <div className="space-y-2">
              <div className="flex items-center gap-3">
                <button
                  onClick={() => handleToggleTier(selectedUser as any)}
                  disabled={updatingUserId === selectedUser.id}
                  className={`flex-1 py-3 rounded-xl font-bold text-xs shadow-md transition-all ${
                    ((selectedUser as any).tier === "pro" || (selectedUser as any).dbTier === "pro")
                      ? "bg-slate-800 text-slate-300 hover:bg-red-500/20 hover:text-red-400 border border-slate-700"
                      : "bg-emerald-600 hover:bg-emerald-500 text-white shadow-emerald-600/30"
                  }`}
                >
                  {updatingUserId === selectedUser.id
                    ? "กำลังบันทึก..."
                    : ((selectedUser as any).tier === "pro" || (selectedUser as any).dbTier === "pro")
                    ? "🔻 ปรับสถานะ DB เป็น Free"
                    : "⭐ ปรับสถานะ DB เป็น PRO"}
                </button>

                <button
                  onClick={() => handleSyncUserWithRC(selectedUser.id, selectedUser.displayName)}
                  disabled={updatingUserId === selectedUser.id}
                  className="px-4 py-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition-all shadow-md shadow-indigo-600/20"
                >
                  🔄 ซิงก์ตาม RC
                </button>

                <button
                  onClick={() => handleGrantPromoRC(selectedUser.id, selectedUser.displayName)}
                  disabled={updatingUserId === selectedUser.id}
                  className="px-4 py-3 rounded-xl bg-purple-600/30 hover:bg-purple-600 text-purple-300 hover:text-white border border-purple-500/40 text-xs font-bold transition-all"
                >
                  🎁 แจก Promo
                </button>
              </div>

              <div className="flex items-center justify-between pt-2">
                <button
                  onClick={() => handleDeleteRCSubscriber(selectedUser.id, selectedUser.displayName)}
                  disabled={updatingUserId === selectedUser.id}
                  className="text-xs text-rose-400 hover:underline flex items-center gap-1"
                >
                  <span>🗑️ ลบประวัติเทสใน RevenueCat (Reset Subscriber)</span>
                </button>

                <button
                  onClick={() => setSelectedUser(null)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold"
                >
                  ปิด
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
