"use client";

import React, { useState, useEffect, useMemo } from "react";
import Link from "next/link";

interface UserProfile {
  id: string;
  email: string;
  displayName: string;
  display_name: string;
  tier: "free" | "pro";
  subscription_expires_at: string | null;
  subscription_plan: string | null;
  subscription_store: string | null;
  created_at: string;
  avatar_url: string | null;
}

export default function AdminTestPlanPage() {
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [selectedUserId, setSelectedUserId] = useState<string>("");
  const [userSearch, setUserSearch] = useState<string>("");
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  const [isSyncingRC, setIsSyncingRC] = useState<boolean>(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Custom Form State
  const [customTier, setCustomTier] = useState<"free" | "pro">("pro");
  const [customPlan, setCustomPlan] = useState<string>("monthly");
  const [customDurationMinutes, setCustomDurationMinutes] = useState<string>("30");
  const [customDateTime, setCustomDateTime] = useState<string>("");
  const [customStore, setCustomStore] = useState<string>("app_store");
  const [useExactDateTime, setUseExactDateTime] = useState<boolean>(false);

  // Countdown timer ticker
  const [currentTime, setCurrentTime] = useState<number>(Date.now());

  useEffect(() => {
    fetchUsers();
    const interval = setInterval(() => setCurrentTime(Date.now()), 1000);
    return () => clearInterval(interval);
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3800);
  };

  const fetchUsers = async () => {
    setIsLoading(true);
    try {
      const res = await fetch("/api/admin/test-plan");
      const data = await res.json();
      if (data.success && Array.isArray(data.users)) {
        setUsers(data.users);
        if (data.users.length > 0 && !selectedUserId) {
          // Default to the first PRO or first user
          setSelectedUserId(data.users[0].id);
        }
      }
    } catch (e: any) {
      showToast("❌ ไม่สามารถโหลดรายชื่อผู้ใช้ได้: " + e.message);
    } finally {
      setIsLoading(false);
    }
  };

  const filteredUsers = useMemo(() => {
    if (!userSearch.trim()) return users;
    const q = userSearch.toLowerCase().trim();
    return users.filter(
      (u) =>
        (u.displayName || "").toLowerCase().includes(q) ||
        (u.email || "").toLowerCase().includes(q) ||
        u.id.toLowerCase().includes(q)
    );
  }, [users, userSearch]);

  const selectedUser = useMemo(() => {
    return users.find((u) => u.id === selectedUserId) || null;
  }, [users, selectedUserId]);

  // Sync selected user directly with RevenueCat API
  const handleSyncWithRC = async () => {
    if (!selectedUserId) return;
    setIsSyncingRC(true);
    try {
      const res = await fetch("/api/admin/revenuecat/sync-user", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId: selectedUserId, action: "sync_db_with_rc" }),
      });
      const data = await res.json();
      if (data.success) {
        showToast(`⚡ ซิงก์กับ RevenueCat สำเร็จ! สถานะใน DB คือ: ${data.syncedTier?.toUpperCase()}`);
        await fetchUsers();
      } else {
        alert("ซิงก์ไม่สำเร็จ: " + (data.error || "Unknown error"));
      }
    } catch (e: any) {
      alert("Error: " + e.message);
    } finally {
      setIsSyncingRC(false);
    }
  };

  const handleApplyPreset = async (presetType: string) => {
    if (!selectedUserId) {
      alert("กรุณาเลือกผู้ใช้งานก่อนครับ");
      return;
    }

    setIsSubmitting(true);
    try {
      let body: any = { userId: selectedUserId, action: "apply_plan" };

      if (presetType === "expire_now") {
        body = { userId: selectedUserId, action: "simulate_expire" };
      } else if (presetType === "2_minutes") {
        body = {
          userId: selectedUserId,
          action: "apply_plan",
          tier: "pro",
          plan: "trial",
          durationMinutes: 2,
          store: "app_store",
        };
      } else if (presetType === "1_hour") {
        body = {
          userId: selectedUserId,
          action: "apply_plan",
          tier: "pro",
          plan: "trial",
          durationMinutes: 60,
          store: "app_store",
        };
      } else if (presetType === "3_days") {
        body = {
          userId: selectedUserId,
          action: "apply_plan",
          tier: "pro",
          plan: "trial",
          durationMinutes: 3 * 24 * 60,
          store: "app_store",
        };
      } else if (presetType === "monthly") {
        body = {
          userId: selectedUserId,
          action: "apply_plan",
          tier: "pro",
          plan: "monthly",
          durationMinutes: 30 * 24 * 60,
          store: "app_store",
        };
      } else if (presetType === "yearly") {
        body = {
          userId: selectedUserId,
          action: "apply_plan",
          tier: "pro",
          plan: "yearly",
          durationMinutes: 365 * 24 * 60,
          store: "app_store",
        };
      } else if (presetType === "lifetime") {
        body = {
          userId: selectedUserId,
          action: "apply_plan",
          tier: "pro",
          plan: "lifetime",
          store: "promotional",
        };
      } else if (presetType === "reset_fresh") {
        body = { userId: selectedUserId, action: "reset_fresh" };
      }

      const res = await fetch("/api/admin/test-plan", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      const data = await res.json();
      if (data.success) {
        showToast(`🎉 ${data.message}`);
        await fetchUsers();
      } else {
        alert("ทำรายการไม่สำเร็จ: " + (data.error || "Unknown error"));
      }
    } catch (e: any) {
      alert("Error: " + e.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleApplyCustom = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUserId) {
      alert("กรุณาเลือกผู้ใช้งานก่อนครับ");
      return;
    }

    setIsSubmitting(true);
    try {
      const body: any = {
        userId: selectedUserId,
        action: "apply_plan",
        tier: customTier,
        plan: customPlan,
        store: customStore,
      };

      if (customTier === "pro") {
        if (useExactDateTime && customDateTime) {
          body.customExpiry = new Date(customDateTime).toISOString();
        } else {
          body.durationMinutes = Number(customDurationMinutes) || 30;
        }
      }

      const res = await fetch("/api/admin/test-plan", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      const data = await res.json();
      if (data.success) {
        showToast(`🚀 ${data.message}`);
        await fetchUsers();
      } else {
        alert("ไม่สำเร็จ: " + (data.error || "Unknown error"));
      }
    } catch (e: any) {
      alert("Error: " + e.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const formatCountdown = (expiresAtStr: string | null) => {
    if (!expiresAtStr) return null;
    const exp = new Date(expiresAtStr).getTime();
    const diff = exp - currentTime;

    if (diff <= 0) {
      const agoSec = Math.floor(Math.abs(diff) / 1000);
      if (agoSec < 60) return `หมดอายุแล้วเมื่อ ${agoSec} วินาทีก่อน`;
      const agoMin = Math.floor(agoSec / 60);
      if (agoMin < 60) return `หมดอายุแล้วเมื่อ ${agoMin} นาทีที่แล้ว`;
      const agoHr = Math.floor(agoMin / 60);
      return `หมดอายุแล้วเมื่อ ${agoHr} ชั่วโมงที่แล้ว`;
    }

    const sec = Math.floor(diff / 1000) % 60;
    const min = Math.floor(diff / (1000 * 60)) % 60;
    const hr = Math.floor(diff / (1000 * 60 * 60)) % 24;
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days > 0) {
      return `เหลือเวลาอีก ${days} วัน ${hr} ชม. ${min} นาที`;
    }
    if (hr > 0) {
      return `เหลือเวลาอีก ${hr} ชม. ${min} นาที ${sec} วิ`;
    }
    return `เหลือเวลาอีก ${min} นาที ${sec} วินาที ⏳`;
  };

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return "-";
    try {
      return new Date(dateStr).toLocaleString("th-TH", {
        year: "numeric",
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      });
    } catch {
      return dateStr;
    }
  };

  const isExpired = selectedUser?.subscription_expires_at
    ? new Date(selectedUser.subscription_expires_at).getTime() < currentTime
    : false;

  const isProActive = selectedUser?.tier === "pro" && !isExpired;

  return (
    <div className="min-h-screen bg-[#0A0E17] text-slate-100 font-sans selection:bg-purple-500 selection:text-white pb-24">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 flex items-center gap-3 bg-slate-900/95 text-white px-5 py-3.5 rounded-2xl border border-purple-500/50 shadow-2xl shadow-purple-500/20 backdrop-blur-xl animate-fade-in">
          <span className="w-2.5 h-2.5 rounded-full bg-purple-400 animate-ping" />
          <p className="text-sm font-semibold">{toastMessage}</p>
        </div>
      )}

      {/* Top Header */}
      <header className="sticky top-0 z-40 bg-[#0A0E17]/90 backdrop-blur-md border-b border-slate-800/80 px-4 lg:px-8 py-3.5">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3.5">
            <Link
              href="/"
              className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-indigo-600 flex items-center justify-center shadow-lg shadow-purple-500/20 hover:opacity-90 transition-opacity"
            >
              <span className="text-xl">🧪</span>
            </Link>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-base font-bold tracking-tight text-white">SaveFor</span>
                <span className="text-[10px] uppercase tracking-wider font-extrabold bg-purple-500/20 text-purple-300 border border-purple-500/30 px-2 py-0.5 rounded-md">
                  Test Plan Studio
                </span>
              </div>
              <p className="text-xs text-slate-400">
                ระบบจำลองแผนสมาชิก วันหมดอายุ และทดสอบสิทธิ์ PRO แบบออนไลน์
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            <Link
              href="/"
              className="flex items-center gap-1.5 text-xs font-semibold px-3.5 py-2 rounded-xl bg-slate-800/80 hover:bg-slate-700/80 text-slate-300 hover:text-white border border-slate-700/60 transition-all"
            >
              <span>📊</span>
              <span>แดชบอร์ดหลัก</span>
            </Link>
            <Link
              href="/bank-rules"
              className="hidden sm:flex items-center gap-1.5 text-xs font-semibold px-3.5 py-2 rounded-xl bg-slate-800/80 hover:bg-slate-700/80 text-slate-300 hover:text-white border border-slate-700/60 transition-all"
            >
              <span>⚙️</span>
              <span>กฎธนาคาร</span>
            </Link>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 lg:px-8 py-8 space-y-8">
        {/* Banner Section */}
        <section className="bg-gradient-to-r from-purple-950/40 via-slate-900 to-indigo-950/40 border border-purple-500/30 rounded-3xl p-6 shadow-2xl relative overflow-hidden">
          <div className="relative z-10 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
            <div>
              <div className="flex items-center gap-2">
                <span className="text-2xl">⚡</span>
                <h1 className="text-xl font-black text-white tracking-tight">
                  เครื่องมือทดสอบแผนสมาชิก (Subscription Test Plan Studio)
                </h1>
              </div>
              <p className="text-xs text-slate-300 mt-1 max-w-2xl">
                ใช้สำหรับทดสอบพฤติกรรมของแอปพลิเคชันมือถือในสถานการณ์จริง เช่น: สิทธิ์หมดอายุทันที, กำหนดให้หมดอายุในอีก 2 นาที, จำลองแผนรายเดือน/รายปี หรือล้างประวัติการทดสอบเพื่อกดซื้อใหม่ใน TestFlight
              </p>
            </div>

            <div className="flex items-center gap-2 bg-slate-950/80 px-3.5 py-2 rounded-2xl border border-slate-800">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse" />
              <span className="text-xs font-mono text-emerald-300">Live Supabase Synced</span>
            </div>
          </div>
          <div className="absolute top-0 right-0 w-80 h-80 bg-purple-500/10 rounded-full blur-3xl pointer-events-none" />
        </section>

        {/* User Picker & Live Inspector Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Col 1: Account Selector */}
          <div className="bg-slate-900/80 border border-slate-800/90 rounded-3xl p-6 backdrop-blur-xl shadow-xl flex flex-col justify-between">
            <div>
              <label className="text-xs font-bold text-slate-400 uppercase tracking-wider block mb-2">
                1. เลือกบัญชีผู้ใช้งานที่ต้องการทดสอบ
              </label>

              {/* Search Box */}
              <div className="mb-3">
                <input
                  type="text"
                  placeholder="พิมพ์ค้นหาชื่อ หรืออีเมล..."
                  value={userSearch}
                  onChange={(e) => setUserSearch(e.target.value)}
                  className="w-full bg-slate-950/80 border border-slate-800 rounded-xl px-3.5 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-purple-500"
                />
              </div>

              {/* User Dropdown */}
              <select
                value={selectedUserId}
                onChange={(e) => setSelectedUserId(e.target.value)}
                disabled={isLoading}
                className="w-full bg-slate-950 border border-slate-700 text-white rounded-2xl p-3.5 text-xs focus:outline-none focus:border-purple-500 transition-all font-sans"
              >
                {filteredUsers.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.displayName} ({u.email}) • {u.tier === "pro" ? "⭐ PRO" : "👤 Free"}
                  </option>
                ))}
              </select>

              {/* Quick user selector chips */}
              <div className="mt-4">
                <span className="text-[11px] text-slate-500 block mb-2 font-semibold">
                  เลือกด่วนจากบัญชีทดสอบ:
                </span>
                <div className="flex flex-wrap gap-1.5 max-h-40 overflow-y-auto pr-1">
                  {users.slice(0, 8).map((u) => (
                    <button
                      key={u.id}
                      onClick={() => setSelectedUserId(u.id)}
                      className={`text-[11px] px-2.5 py-1.5 rounded-xl border transition-all text-left flex items-center gap-1.5 ${
                        selectedUserId === u.id
                          ? "bg-purple-600 text-white border-purple-500 font-bold shadow-md shadow-purple-600/30"
                          : "bg-slate-950 text-slate-300 border-slate-800 hover:text-white hover:border-slate-700"
                      }`}
                    >
                      <span>{u.tier === "pro" ? "⭐" : "👤"}</span>
                      <span className="font-medium truncate max-w-[120px]">{u.displayName}</span>
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="mt-6 pt-4 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
              <span>พบผู้ใช้ในระบบทั้งหมด:</span>
              <span className="font-bold text-white">{users.length} คน</span>
            </div>
          </div>

          {/* Col 2 & 3: Live Inspector Card */}
          <div className="lg:col-span-2 bg-gradient-to-br from-slate-900/90 to-slate-950 border border-slate-800 rounded-3xl p-6 shadow-xl relative overflow-hidden flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between mb-4 flex-wrap gap-3">
                <div className="flex items-center gap-3">
                  {selectedUser?.avatar_url ? (
                    <img
                      src={selectedUser.avatar_url}
                      alt={selectedUser.displayName}
                      className="w-12 h-12 rounded-2xl object-cover border border-slate-700"
                    />
                  ) : (
                    <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-purple-600 to-indigo-600 flex items-center justify-center text-white text-lg font-black">
                      {selectedUser?.displayName?.substring(0, 1).toUpperCase() || "?"}
                    </div>
                  )}
                  <div>
                    <h3 className="text-lg font-bold text-white flex items-center gap-2">
                      {selectedUser?.displayName || "กำลังโหลด..."}
                    </h3>
                    <p className="text-xs text-purple-300 font-mono">{selectedUser?.email}</p>
                    <p className="text-[10px] text-slate-500 font-mono">User ID: {selectedUser?.id}</p>
                  </div>
                </div>

                {/* Big Live Badge & Sync Button */}
                <div className="flex items-center gap-2">
                  <button
                    onClick={handleSyncWithRC}
                    disabled={isSyncingRC}
                    title="ดึงสถานะการซื้อสดๆ จาก RevenueCat มาอัปเดตลง DB เดี๋ยวนี้"
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold bg-indigo-600/30 hover:bg-indigo-600 text-indigo-300 hover:text-white border border-indigo-500/40 transition-all disabled:opacity-50"
                  >
                    <span>🔄</span>
                    <span>{isSyncingRC ? "กำลังซิงก์..." : "ซิงก์กับ RevenueCat สดๆ"}</span>
                  </button>

                  {isProActive ? (
                    <span className="inline-flex items-center gap-1.5 px-4 py-2 rounded-2xl text-xs font-black bg-gradient-to-r from-emerald-500/20 to-teal-500/20 text-emerald-300 border border-emerald-500/40 shadow-lg shadow-emerald-500/10">
                      <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                      PRO ACTIVE ⭐
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-2xl text-xs font-semibold bg-slate-800 text-slate-400 border border-slate-700">
                      <span>👤</span>
                      <span>FREE PLAN</span>
                    </span>
                  )}
                </div>
              </div>

              {/* Status details grid */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 bg-slate-950/70 p-4 rounded-2xl border border-slate-800/80 text-xs">
                <div>
                  <span className="text-slate-500 block text-[11px]">สถานะใน Supabase DB:</span>
                  <span className={`font-bold mt-0.5 block ${isProActive ? "text-emerald-400" : "text-slate-300"}`}>
                    {selectedUser?.tier?.toUpperCase()}
                  </span>
                </div>
                <div>
                  <span className="text-slate-500 block text-[11px]">แผนที่ใช้งาน:</span>
                  <span className="font-bold text-white mt-0.5 block">
                    {(selectedUser?.subscription_plan || "free").toUpperCase()}
                  </span>
                </div>
                <div>
                  <span className="text-slate-500 block text-[11px]">ช่องทาง (Store):</span>
                  <span className="font-bold text-slate-300 mt-0.5 block">
                    {selectedUser?.subscription_store || "-"}
                  </span>
                </div>
                <div>
                  <span className="text-slate-500 block text-[11px]">วันหมดอายุ:</span>
                  <span className={`font-mono text-[11px] mt-0.5 block ${isExpired ? "text-rose-400" : "text-indigo-300"}`}>
                    {selectedUser?.subscription_expires_at
                      ? formatDate(selectedUser.subscription_expires_at)
                      : "ไม่มี"}
                  </span>
                </div>
              </div>

              {/* Live Countdown ticker alert */}
              {selectedUser?.subscription_expires_at && (
                <div
                  className={`mt-4 p-3.5 rounded-2xl border flex items-center justify-between text-xs font-semibold ${
                    isExpired
                      ? "bg-rose-500/10 border-rose-500/30 text-rose-300"
                      : "bg-purple-500/10 border-purple-500/30 text-purple-300"
                  }`}
                >
                  <div className="flex items-center gap-2">
                    <span className="text-base">{isExpired ? "⛔" : "⏳"}</span>
                    <span>{formatCountdown(selectedUser.subscription_expires_at)}</span>
                  </div>
                  <span className="text-[11px] font-mono text-slate-400">
                    UTC: {selectedUser.subscription_expires_at}
                  </span>
                </div>
              )}
            </div>

            <div className="mt-4 pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-500">
              <span>* แอปพลิเคชันมือถือจะอ่านค่าจาก Supabase ทันทีเมื่อเปิดแอปหรือรีเฟรช</span>
              <button
                onClick={fetchUsers}
                disabled={isLoading}
                className="text-purple-400 hover:underline font-semibold"
              >
                🔄 รีเฟรชสถานะ
              </button>
            </div>
          </div>
        </div>

        {/* Preset Test Scenarios Grid */}
        <section className="bg-slate-900/80 border border-slate-800/90 rounded-3xl p-6 backdrop-blur-xl shadow-xl">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-base font-bold text-white flex items-center gap-2">
                <span>⚡</span>
                <span>ชุดทดสอบสำเร็จรูป (1-Click Test Scenarios)</span>
              </h2>
              <p className="text-xs text-slate-400">
                กดคลิกเดียวเพื่อจำลองสถานการณ์ให้ผู้ใช้ที่เลือกทันที
              </p>
            </div>
            {isSubmitting && (
              <span className="text-xs text-purple-400 font-bold animate-pulse">
                กำลังบันทึกลงระบบ...
              </span>
            )}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5">
            {/* Scenario 1: Expire Now */}
            <button
              onClick={() => handleApplyPreset("expire_now")}
              disabled={isSubmitting}
              className="bg-slate-950/70 hover:bg-rose-500/10 border border-slate-800 hover:border-rose-500/40 p-4 rounded-2xl text-left transition-all group disabled:opacity-50"
            >
              <div className="flex items-center justify-between text-rose-400 mb-1.5">
                <span className="font-bold text-sm">⛔ หมดอายุทันที</span>
                <span className="text-base group-hover:scale-125 transition-transform">🔒</span>
              </div>
              <p className="text-xs text-slate-400">
                ตั้งให้หมดอายุไปแล้ว 5 นาที เพื่อทดสอบว่าฟังก์ชัน PRO ถูกล็อกกลับเป็นหน้า Paywall ทันทีหรือไม่
              </p>
            </button>

            {/* Scenario 2: 2 Minutes */}
            <button
              onClick={() => handleApplyPreset("2_minutes")}
              disabled={isSubmitting}
              className="bg-slate-950/70 hover:bg-amber-500/10 border border-slate-800 hover:border-amber-500/40 p-4 rounded-2xl text-left transition-all group disabled:opacity-50"
            >
              <div className="flex items-center justify-between text-amber-400 mb-1.5">
                <span className="font-bold text-sm">⏱️ หมดอายุใน 2 นาที</span>
                <span className="text-base group-hover:scale-125 transition-transform">⏳</span>
              </div>
              <p className="text-xs text-slate-400">
                ทดสอบการนับถอยหลังและการหลุดของสิทธิ์ PRO แบบต่อหน้าต่อตา
              </p>
            </button>

            {/* Scenario 3: 1 Hour */}
            <button
              onClick={() => handleApplyPreset("1_hour")}
              disabled={isSubmitting}
              className="bg-slate-950/70 hover:bg-purple-500/10 border border-slate-800 hover:border-purple-500/40 p-4 rounded-2xl text-left transition-all group disabled:opacity-50"
            >
              <div className="flex items-center justify-between text-purple-400 mb-1.5">
                <span className="font-bold text-sm">⏳ ทดลองใช้ 1 ชั่วโมง</span>
                <span className="text-base group-hover:scale-125 transition-transform">⭐</span>
              </div>
              <p className="text-xs text-slate-400">
                จำลองสิทธิ์ระยะสั้นสำหรับทดสอบฟีเจอร์สแกนสลิปย้อนหลังเกิน 30 วัน
              </p>
            </button>

            {/* Scenario 4: 3-Day Trial */}
            <button
              onClick={() => handleApplyPreset("3_days")}
              disabled={isSubmitting}
              className="bg-slate-950/70 hover:bg-blue-500/10 border border-slate-800 hover:border-blue-500/40 p-4 rounded-2xl text-left transition-all group disabled:opacity-50"
            >
              <div className="flex items-center justify-between text-blue-400 mb-1.5">
                <span className="font-bold text-sm">🎁 Free Trial 3 วัน</span>
                <span className="text-base group-hover:scale-125 transition-transform">📅</span>
              </div>
              <p className="text-xs text-slate-400">
                จำลองช่วงทดลองใช้ฟรี ก่อนเริ่มคิดเงินรอบแรก
              </p>
            </button>

            {/* Scenario 5: Monthly */}
            <button
              onClick={() => handleApplyPreset("monthly")}
              disabled={isSubmitting}
              className="bg-slate-950/70 hover:bg-emerald-500/10 border border-slate-800 hover:border-emerald-500/40 p-4 rounded-2xl text-left transition-all group disabled:opacity-50"
            >
              <div className="flex items-center justify-between text-emerald-400 mb-1.5">
                <span className="font-bold text-sm">💳 PRO รายเดือน (30 วัน)</span>
                <span className="text-base group-hover:scale-125 transition-transform">✨</span>
              </div>
              <p className="text-xs text-slate-400">
                จำลองการสมัครแพ็กเกจ savefor_pro_monthly ผ่าน App Store Sandbox
              </p>
            </button>

            {/* Scenario 6: Yearly */}
            <button
              onClick={() => handleApplyPreset("yearly")}
              disabled={isSubmitting}
              className="bg-slate-950/70 hover:bg-teal-500/10 border border-slate-800 hover:border-teal-500/40 p-4 rounded-2xl text-left transition-all group disabled:opacity-50"
            >
              <div className="flex items-center justify-between text-teal-400 mb-1.5">
                <span className="font-bold text-sm">🏆 PRO รายปี (365 วัน)</span>
                <span className="text-base group-hover:scale-125 transition-transform">👑</span>
              </div>
              <p className="text-xs text-slate-400">
                จำลองการสมัครแพ็กเกจ savefor_pro_yearly สำหรับสมาชิกรายปี
              </p>
            </button>

            {/* Scenario 7: Lifetime */}
            <button
              onClick={() => handleApplyPreset("lifetime")}
              disabled={isSubmitting}
              className="bg-slate-950/70 hover:bg-indigo-500/10 border border-slate-800 hover:border-indigo-500/40 p-4 rounded-2xl text-left transition-all group disabled:opacity-50"
            >
              <div className="flex items-center justify-between text-indigo-400 mb-1.5">
                <span className="font-bold text-sm">♾️ PRO ตลอดชีพ (Lifetime)</span>
                <span className="text-base group-hover:scale-125 transition-transform">💎</span>
              </div>
              <p className="text-xs text-slate-400">
                สิทธิ์ PRO ถาวร ไม่มีวันหมดอายุ (หมดปี 2099)
              </p>
            </button>

            {/* Scenario 8: Clean Reset */}
            <button
              onClick={() => handleApplyPreset("reset_fresh")}
              disabled={isSubmitting}
              className="bg-slate-950/70 hover:bg-slate-800 border border-slate-800 hover:border-slate-700 p-4 rounded-2xl text-left transition-all group disabled:opacity-50"
            >
              <div className="flex items-center justify-between text-slate-300 mb-1.5">
                <span className="font-bold text-sm">🧹 ล้างเป็น Free บริสุทธิ์</span>
                <span className="text-base group-hover:scale-125 transition-transform">🗑️</span>
              </div>
              <p className="text-xs text-slate-400">
                ลบประวัติใน RevenueCat และรีเซ็ต DB เพื่อทดสอบกดซื้อใหม่ใน TestFlight
              </p>
            </button>
          </div>
        </section>

        {/* Custom Plan Builder Form */}
        <section className="bg-slate-900/80 border border-slate-800/90 rounded-3xl p-6 backdrop-blur-xl shadow-xl">
          <h2 className="text-base font-bold text-white flex items-center gap-2 mb-1">
            <span>🛠️</span>
            <span>กำหนดค่าและสร้างแผนทดสอบตามใจชอบ (Custom Plan Builder)</span>
          </h2>
          <p className="text-xs text-slate-400 mb-6">
            กำหนดระยะเวลา สโตร์ และประเภทแผนได้อิสระเพื่อทดสอบ Edge Cases ต่างๆ
          </p>

          <form onSubmit={handleApplyCustom} className="space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              {/* Field 1: Tier */}
              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1.5">
                  สถานะ Tier:
                </label>
                <select
                  value={customTier}
                  onChange={(e) => setCustomTier(e.target.value as any)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-purple-500"
                >
                  <option value="pro">⭐ PRO (สมาชิกพรีเมียม)</option>
                  <option value="free">👤 Free (ผู้ใช้ทั่วไป)</option>
                </select>
              </div>

              {/* Field 2: Plan identifier */}
              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1.5">
                  ชื่อแผน (Plan ID):
                </label>
                <select
                  value={customPlan}
                  onChange={(e) => setCustomPlan(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-purple-500"
                >
                  <option value="monthly">Monthly (รายเดือน)</option>
                  <option value="yearly">Yearly (รายปี)</option>
                  <option value="trial">Trial (ทดลองใช้)</option>
                  <option value="lifetime">Lifetime (ตลอดชีพ)</option>
                  <option value="custom">Custom (กำหนดเอง)</option>
                </select>
              </div>

              {/* Field 3: Duration or Custom DateTime */}
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="text-xs font-semibold text-slate-300">
                    {useExactDateTime ? "ระบุวันเวลาหมดอายุ:" : "ระยะเวลา (นาที):"}
                  </label>
                  <button
                    type="button"
                    onClick={() => setUseExactDateTime(!useExactDateTime)}
                    className="text-[10px] text-purple-400 hover:underline"
                  >
                    {useExactDateTime ? "สลับเป็นนาที" : "สลับเป็นเลือกวันที่"}
                  </button>
                </div>
                {useExactDateTime ? (
                  <input
                    type="datetime-local"
                    value={customDateTime}
                    onChange={(e) => setCustomDateTime(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-purple-500"
                  />
                ) : (
                  <input
                    type="number"
                    min="1"
                    placeholder="เช่น 30"
                    value={customDurationMinutes}
                    onChange={(e) => setCustomDurationMinutes(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-purple-500"
                  />
                )}
              </div>

              {/* Field 4: Store origin */}
              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1.5">
                  ช่องทาง (Store Origin):
                </label>
                <select
                  value={customStore}
                  onChange={(e) => setCustomStore(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-purple-500"
                >
                  <option value="app_store">Apple App Store Sandbox</option>
                  <option value="play_store">Google Play Store Test Track</option>
                  <option value="promotional">RevenueCat Promotional</option>
                  <option value="admin_grant">Admin Manual Grant</option>
                </select>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-3">
              <button
                type="submit"
                disabled={isSubmitting}
                className="flex items-center gap-2 px-6 py-3 rounded-xl bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 hover:to-indigo-500 text-white font-bold text-xs shadow-lg shadow-purple-600/30 transition-all disabled:opacity-50"
              >
                <span>🚀</span>
                <span>{isSubmitting ? "กำลังส่งคำสั่ง..." : "นำแผนทดสอบนี้ไปใช้กับผู้ใช้ทันที"}</span>
              </button>
            </div>
          </form>
        </section>

        {/* Instructions Guide */}
        <div className="bg-slate-950/60 border border-slate-800/80 rounded-3xl p-6 text-xs text-slate-400 space-y-2">
          <div className="text-sm font-bold text-white flex items-center gap-2 mb-2">
            <span>📱</span> วิธีการทดสอบกับแอปพลิเคชันมือถือ (Flutter / TestFlight)
          </div>
          <p>
            1. <strong>เลือกบัญชีและกดจำลองแผน</strong> ในหน้านี้ เช่น กด <em>"⏱️ หมดอายุใน 2 นาที"</em> หรือกด <em>"🔄 ซิงก์กับ RevenueCat สดๆ"</em>
          </p>
          <p>
            2. <strong>เปิดแอป SaveFor บนมือถือ</strong>: สิทธิ์ PRO จะถูกโหลดจาก Supabase ออนไลน์ทันที ไม่มีการค้างแคชในเครื่อง
          </p>
          <p>
            3. <strong>เมื่อเวลาผ่านไป 2 นาที</strong>: ลองกดสแกนสลิปย้อนหลังเกิน 30 วัน หรือเปิดหน้าตั้งค่า ระบบจะตรวจพบว่าวันหมดอายุผ่านไปแล้ว และล็อกกลับเป็นหน้าชำระเงินทันที!
          </p>
        </div>
      </main>
    </div>
  );
}
