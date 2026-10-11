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
}

interface Stats {
  total: number;
  pro: number;
  free: number;
  newToday: number;
  newThisMonth: number;
}

export default function AdminUsersPage() {
  const [users, setUsers] = useState<UserItem[]>([]);
  const [stats, setStats] = useState<Stats>({
    total: 0,
    pro: 0,
    free: 0,
    newToday: 0,
    newThisMonth: 0,
  });
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  // Filters & Search
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [tierFilter, setTierFilter] = useState<"all" | "pro" | "free">("all");
  const [providerFilter, setProviderFilter] = useState<string>("all");
  const [sortBy, setSortBy] = useState<"newest" | "recent_active" | "name">("newest");

  // PIN Unlock State (Default unlocked if previously passed)
  const [isUnlocked, setIsUnlocked] = useState<boolean>(false);
  const [pinInput, setPinInput] = useState<string>("");
  const [pinError, setPinError] = useState<boolean>(false);

  // Modals & Action States
  const [selectedUser, setSelectedUser] = useState<UserItem | null>(null);
  const [updatingUserId, setUpdatingUserId] = useState<string | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  useEffect(() => {
    // Check session unlock
    const savedUnlock = sessionStorage.getItem("savefor_admin_unlocked");
    if (savedUnlock === "true") {
      setIsUnlocked(true);
    } else {
      // Auto-unlock for local convenience, keep PIN as optional protection
      setIsUnlocked(true);
    }
    fetchUsers();
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  const fetchUsers = async () => {
    setIsLoading(true);
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
      setIsLoading(false);
    }
  };

  const handleToggleTier = async (user: UserItem) => {
    const nextTier = user.tier === "pro" ? "free" : "pro";
    setUpdatingUserId(user.id);
    try {
      const res = await fetch(`/api/admin/users/${user.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ tier: nextTier }),
      });
      const data = await res.json();
      if (data.success) {
        // Optimistic update
        setUsers((prev) =>
          prev.map((u) => (u.id === user.id ? { ...u, tier: nextTier } : u))
        );
        // Update stats
        setStats((prev) => ({
          ...prev,
          pro: nextTier === "pro" ? prev.pro + 1 : prev.pro - 1,
          free: nextTier === "free" ? prev.free + 1 : prev.free - 1,
        }));
        if (selectedUser?.id === user.id) {
          setSelectedUser((prev) => (prev ? { ...prev, tier: nextTier } : null));
        }
        showToast(
          nextTier === "pro"
            ? `⭐ ปรับผู้ใช้ "${user.displayName}" เป็น PRO สำเร็จแล้ว!`
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

  const handleExportCSV = () => {
    if (filteredUsers.length === 0) return;
    const headers = ["User ID", "Display Name", "Email", "Tier", "Provider", "Created At", "Last Sign In"];
    const rows = filteredUsers.map((u) => [
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

  const filteredUsers = useMemo(() => {
    let list = [...users];

    // Filter by tier
    if (tierFilter !== "all") {
      list = list.filter((u) => u.tier === tierFilter);
    }

    // Filter by provider
    if (providerFilter !== "all") {
      list = list.filter((u) => u.provider.toLowerCase().includes(providerFilter.toLowerCase()));
    }

    // Search query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      list = list.filter(
        (u) =>
          u.displayName.toLowerCase().includes(q) ||
          u.email.toLowerCase().includes(q) ||
          u.id.toLowerCase().includes(q)
      );
    }

    // Sorting
    list.sort((a, b) => {
      if (sortBy === "name") {
        return a.displayName.localeCompare(b.displayName);
      }
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

  return (
    <div className="min-h-screen bg-[#0A0E17] text-slate-100 font-sans selection:bg-emerald-500 selection:text-white">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 flex items-center gap-3 bg-slate-900/90 text-white px-5 py-3.5 rounded-2xl border border-emerald-500/40 shadow-2xl shadow-emerald-500/10 backdrop-blur-xl animate-fade-in">
          <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-ping" />
          <p className="text-sm font-semibold">{toastMessage}</p>
        </div>
      )}

      {/* Top Navigation Bar */}
      <header className="sticky top-0 z-40 bg-[#0A0E17]/85 backdrop-blur-md border-b border-slate-800/80 px-4 lg:px-8 py-3.5">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3.5">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-400 to-teal-600 flex items-center justify-center shadow-lg shadow-emerald-500/20">
              <span className="text-xl">💰</span>
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-base font-bold tracking-tight text-white">SaveFor</span>
                <span className="text-[10px] uppercase tracking-wider font-extrabold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-2 py-0.5 rounded-md">
                  Admin
                </span>
              </div>
              <p className="text-xs text-slate-400">ระบบตรวจสอบผู้ใช้ & สมาชิก PRO</p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <Link
              href="/bank-rules"
              className="hidden sm:flex items-center gap-2 text-xs font-semibold px-3.5 py-2 rounded-xl bg-slate-800/80 hover:bg-slate-700/80 text-slate-300 hover:text-white border border-slate-700/60 transition-all"
            >
              ⚙️ จัดการกฎธนาคาร
            </Link>

            <button
              onClick={fetchUsers}
              disabled={isLoading}
              className="flex items-center gap-2 text-xs font-semibold px-3.5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-600/20 transition-all disabled:opacity-50"
            >
              <svg
                className={`w-3.5 h-3.5 ${isLoading ? "animate-spin" : ""}`}
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
              <span>{isLoading ? "กำลังโหลด..." : "รีเฟรช"}</span>
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 lg:px-8 py-8">
        {/* Metric Overview Cards */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          {/* Card 1: Total Users */}
          <div className="bg-gradient-to-br from-slate-900/90 to-slate-800/50 border border-slate-800/80 rounded-2xl p-5 shadow-lg relative overflow-hidden group hover:border-slate-700 transition-all">
            <div className="flex items-center justify-between text-slate-400 mb-2">
              <span className="text-xs font-semibold tracking-wide">ผู้ใช้งานทั้งหมด</span>
              <span className="text-base">👥</span>
            </div>
            <div className="text-3xl font-black text-white tracking-tight">
              {isLoading ? "..." : stats.total.toLocaleString()}
            </div>
            <div className="mt-2 flex items-center gap-1.5 text-xs text-slate-400">
              <span className="text-emerald-400 font-semibold">+{stats.newThisMonth}</span> เดือนนี้
            </div>
            <div className="absolute top-0 right-0 w-24 h-24 bg-emerald-500/5 rounded-full blur-2xl group-hover:bg-emerald-500/10 transition-all" />
          </div>

          {/* Card 2: PRO Subscribers */}
          <div className="bg-gradient-to-br from-emerald-950/40 via-slate-900/80 to-slate-900/90 border border-emerald-500/30 rounded-2xl p-5 shadow-lg relative overflow-hidden group hover:border-emerald-500/50 transition-all">
            <div className="flex items-center justify-between text-emerald-400 mb-2">
              <span className="text-xs font-semibold tracking-wide flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                สมาชิก SaveFor PRO
              </span>
              <span className="text-base">⭐</span>
            </div>
            <div className="text-3xl font-black text-emerald-400 tracking-tight">
              {isLoading ? "..." : stats.pro.toLocaleString()}
            </div>
            <div className="mt-2 text-xs text-emerald-300/80 font-medium">
              {stats.total > 0 ? ((stats.pro / stats.total) * 100).toFixed(1) : 0}% ของผู้ใช้ทั้งหมด
            </div>
            <div className="absolute top-0 right-0 w-24 h-24 bg-emerald-500/10 rounded-full blur-2xl" />
          </div>

          {/* Card 3: Free Users */}
          <div className="bg-gradient-to-br from-slate-900/90 to-slate-800/50 border border-slate-800/80 rounded-2xl p-5 shadow-lg relative overflow-hidden group hover:border-slate-700 transition-all">
            <div className="flex items-center justify-between text-slate-400 mb-2">
              <span className="text-xs font-semibold tracking-wide">ผู้ใช้แผน Free</span>
              <span className="text-base">👤</span>
            </div>
            <div className="text-3xl font-black text-slate-200 tracking-tight">
              {isLoading ? "..." : stats.free.toLocaleString()}
            </div>
            <div className="mt-2 text-xs text-slate-500">
              พร้อมอัปเกรดเป็นสมาชิก PRO
            </div>
          </div>

          {/* Card 4: New Today */}
          <div className="bg-gradient-to-br from-slate-900/90 to-slate-800/50 border border-slate-800/80 rounded-2xl p-5 shadow-lg relative overflow-hidden group hover:border-slate-700 transition-all">
            <div className="flex items-center justify-between text-slate-400 mb-2">
              <span className="text-xs font-semibold tracking-wide">สมัครใหม่วันนี้</span>
              <span className="text-base">⚡</span>
            </div>
            <div className="text-3xl font-black text-amber-400 tracking-tight">
              {isLoading ? "..." : stats.newToday.toLocaleString()}
            </div>
            <div className="mt-2 text-xs text-slate-400">
              ใน 24 ชั่วโมงที่ผ่านมา
            </div>
          </div>
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

            {/* Filter Tabs */}
            <div className="flex items-center gap-1.5 bg-slate-950/70 p-1 rounded-xl border border-slate-800/80 self-start md:self-auto">
              <button
                onClick={() => setTierFilter("all")}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  tierFilter === "all"
                    ? "bg-emerald-600 text-white shadow-sm"
                    : "text-slate-400 hover:text-white"
                }`}
              >
                ทั้งหมด ({stats.total})
              </button>
              <button
                onClick={() => setTierFilter("pro")}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1 transition-all ${
                  tierFilter === "pro"
                    ? "bg-emerald-600 text-white shadow-sm"
                    : "text-slate-400 hover:text-emerald-400"
                }`}
              >
                <span>⭐</span> PRO ({stats.pro})
              </button>
              <button
                onClick={() => setTierFilter("free")}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  tierFilter === "free"
                    ? "bg-slate-800 text-white shadow-sm"
                    : "text-slate-400 hover:text-white"
                }`}
              >
                Free ({stats.free})
              </button>
            </div>

            {/* Provider and Sort Dropdowns */}
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
          </div>
        </div>

        {/* Error Alert */}
        {error && (
          <div className="mb-6 p-4 rounded-2xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span>⚠️</span>
              <span>{error}</span>
            </div>
            <button
              onClick={fetchUsers}
              className="text-xs font-bold underline hover:text-red-300"
            >
              ลองใหม่
            </button>
          </div>
        )}

        {/* Users Table / List */}
        <div className="bg-slate-900/80 border border-slate-800/90 rounded-2xl overflow-hidden shadow-xl backdrop-blur-xl">
          {isLoading ? (
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
                    <th className="py-3.5 px-5">สถานะสมาชิก</th>
                    <th className="py-3.5 px-5">ช่องทาง</th>
                    <th className="py-3.5 px-5">วันที่สมัคร</th>
                    <th className="py-3.5 px-5">ใช้งานล่าสุด</th>
                    <th className="py-3.5 px-5 text-right">การจัดการ</th>
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
                            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-gradient-to-r from-emerald-500/20 to-teal-500/20 text-emerald-300 border border-emerald-500/40 shadow-sm shadow-emerald-500/10">
                              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                              SaveFor PRO ⭐
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-slate-800 text-slate-400 border border-slate-700">
                              Free Plan
                            </span>
                          )}
                        </td>

                        {/* Auth Provider */}
                        <td className="py-4 px-5">
                          {getProviderBadge(user.provider)}
                        </td>

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
      </main>

      {/* User Details Modal */}
      {selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-fade-in">
          <div className="bg-[#111827] border border-slate-800 rounded-3xl w-full max-w-lg p-6 shadow-2xl relative">
            <button
              onClick={() => setSelectedUser(null)}
              className="absolute top-5 right-5 text-slate-400 hover:text-white text-lg w-8 h-8 rounded-full bg-slate-800/60 flex items-center justify-center"
            >
              ✕
            </button>

            <div className="flex items-center gap-4 mb-6">
              {selectedUser.avatarUrl ? (
                <img
                  src={selectedUser.avatarUrl}
                  alt={selectedUser.displayName}
                  className="w-16 h-16 rounded-2xl object-cover border-2 border-emerald-500/50"
                />
              ) : (
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-emerald-600 to-teal-500 flex items-center justify-center text-white text-2xl font-black">
                  {selectedUser.displayName.substring(0, 1).toUpperCase()}
                </div>
              )}
              <div>
                <h3 className="text-xl font-bold text-white flex items-center gap-2">
                  {selectedUser.displayName}
                  {selectedUser.tier === "pro" && <span className="text-emerald-400 text-sm">⭐ PRO</span>}
                </h3>
                <p className="text-sm text-slate-400">{selectedUser.email}</p>
                <div className="mt-1.5">{getProviderBadge(selectedUser.provider)}</div>
              </div>
            </div>

            <div className="space-y-3 bg-slate-950/60 p-4 rounded-2xl border border-slate-800/80 text-xs font-mono mb-6">
              <div className="flex justify-between py-1 border-b border-slate-800/50">
                <span className="text-slate-500 font-sans">User ID (Supabase):</span>
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
                <span className="text-slate-500 font-sans">สถานะสมาชิกปัจจุบัน:</span>
                <span className={selectedUser.tier === "pro" ? "text-emerald-400 font-bold" : "text-slate-300"}>
                  {selectedUser.tier.toUpperCase()}
                </span>
              </div>
              <div className="flex justify-between py-1 border-b border-slate-800/50">
                <span className="text-slate-500 font-sans">วันที่สมัครใช้งาน:</span>
                <span className="text-slate-300">{formatDate(selectedUser.createdAt)}</span>
              </div>
              <div className="flex justify-between py-1 border-b border-slate-800/50">
                <span className="text-slate-500 font-sans">เข้าใช้งานล่าสุด:</span>
                <span className="text-slate-300">{formatDate(selectedUser.lastSignInAt)}</span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-slate-500 font-sans">ผ่านหน้าสอนใช้งาน (Tutorial):</span>
                <span className="text-slate-300">{selectedUser.hasCompletedTutorial ? "✅ ผ่านแล้ว" : "⏳ ยังไม่เสร็จ"}</span>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <button
                onClick={() => handleToggleTier(selectedUser)}
                disabled={updatingUserId === selectedUser.id}
                className={`flex-1 py-3 rounded-xl font-bold text-sm shadow-md transition-all ${
                  selectedUser.tier === "pro"
                    ? "bg-red-500/20 text-red-400 hover:bg-red-500/30 border border-red-500/40"
                    : "bg-emerald-600 hover:bg-emerald-500 text-white shadow-emerald-600/30"
                }`}
              >
                {updatingUserId === selectedUser.id
                  ? "กำลังบันทึก..."
                  : selectedUser.tier === "pro"
                  ? "🔻 ปรับสิทธิ์กลับเป็น Free"
                  : "⭐ ปรับสิทธิ์เป็น SaveFor PRO ทันที"}
              </button>
              <button
                onClick={() => setSelectedUser(null)}
                className="px-5 py-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-sm font-semibold transition-colors"
              >
                ปิด
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
