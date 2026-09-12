"use client";

import React, { useState, useEffect } from "react";
import Link from "next/link";

export interface BankRule {
  id: string;
  name: string;
  appName: string;
  bankType: string;
  logoUrl?: string;
  albumKeywords: string[];
  isEnabled: boolean;
  isCustom: boolean;
  colorHex?: string;
  priority?: number;
  updatedAt?: string;
}

export const BANK_LOGO_MAP: Record<string, string> = {
  kbank: "/images/banks/kbank.png",
  scb: "/images/banks/scb.png",
  krungsri: "/images/banks/krungsri.png",
  bay: "/images/banks/krungsri.png",
  truemoney: "/images/banks/truemoney.png",
  ktb: "/images/banks/ktb.png",
  bbl: "/images/banks/bbl.png",
  ttb: "/images/banks/ttb.png",
  gsb: "/images/banks/gsb.png",
  other: "/images/banks/promptpay.png",
  promptpay: "/images/banks/promptpay.png",
};

export const DEFAULT_RULES: BankRule[] = [
  {
    id: "kbank",
    name: "กสิกรไทย",
    appName: "K PLUS • Kasikornbank",
    bankType: "kbank",
    logoUrl: "/images/banks/kbank.png",
    albumKeywords: ["k plus", "kplus", "k-plus", "kasikorn", "กสิกร"],
    isEnabled: true,
    isCustom: false,
    colorHex: "#00A950",
    priority: 1,
  },
  {
    id: "scb",
    name: "ไทยพาณิชย์",
    appName: "SCB EASY • แม่มณี",
    bankType: "scb",
    logoUrl: "/images/banks/scb.png",
    albumKeywords: ["scb easy", "scbeasy", "scb", "แม่มณี", "ไทยพาณิชย์"],
    isEnabled: true,
    isCustom: false,
    colorHex: "#4E2A84",
    priority: 2,
  },
  {
    id: "krungsri",
    name: "กรุงศรีอยุธยา",
    appName: "KMA • Bank of Ayudhya",
    bankType: "krungsri",
    logoUrl: "/images/banks/krungsri.png",
    albumKeywords: ["krungsri", "kma", "bay", "กรุงศรี"],
    isEnabled: true,
    isCustom: false,
    colorHex: "#7A6400",
    priority: 3,
  },
  {
    id: "truemoney",
    name: "ทรูมันนี่",
    appName: "TrueMoney Wallet",
    bankType: "truemoney",
    logoUrl: "/images/banks/truemoney.png",
    albumKeywords: ["truemoney", "true money", "ทรูมันนี่", "tmn"],
    isEnabled: true,
    isCustom: false,
    colorHex: "#FF6600",
    priority: 4,
  },
];

export const PRESET_BANKS = [
  { type: "ktb", name: "กรุงไทย", appName: "Krungthai NEXT", color: "#00AEEF", logoUrl: "/images/banks/ktb.png" },
  { type: "bbl", name: "กรุงเทพ", appName: "Bangkok Bank Mobile", color: "#1E3A8A", logoUrl: "/images/banks/bbl.png" },
  { type: "ttb", name: "ทีทีบี", appName: "ttb touch", color: "#002D62", logoUrl: "/images/banks/ttb.png" },
  { type: "gsb", name: "ออมสิน", appName: "MyMo GSB", color: "#EB1985", logoUrl: "/images/banks/gsb.png" },
  { type: "other", name: "พร้อมเพย์ / กำหนดเอง", appName: "PromptPay / Wallet", color: "#00A88F", logoUrl: "/images/banks/promptpay.png" },
];

export function getBankLogoUrl(rule: BankRule): string {
  if (rule.logoUrl && rule.logoUrl.trim() !== "") {
    return rule.logoUrl;
  }
  const key = (rule.bankType || rule.id || "").toLowerCase();
  return BANK_LOGO_MAP[key] || BANK_LOGO_MAP.other;
}

export default function BankRulesPage() {
  const [rules, setRules] = useState<BankRule[]>(DEFAULT_RULES);
  const [loading, setLoading] = useState<boolean>(true);
  const [saving, setSaving] = useState<boolean>(false);
  const [message, setMessage] = useState<{ text: string; type: "success" | "error" } | null>(null);

  // Add Bank Modal state
  const [showAddModal, setShowAddModal] = useState<boolean>(false);
  const [selectedPreset, setSelectedPreset] = useState<string>("ktb");
  const [newBankName, setNewBankName] = useState<string>("กรุงไทย");
  const [newAppName, setNewAppName] = useState<string>("Krungthai NEXT");
  const [newBankColor, setNewBankColor] = useState<string>("#00AEEF");
  const [newLogoUrl, setNewLogoUrl] = useState<string>("/images/banks/ktb.png");
  const [newInitialKeywords, setNewInitialKeywords] = useState<string>("krungthai, ktb, สลิปกรุงไทย");

  // Logo edit per card
  const [editingLogoBankId, setEditingLogoBankId] = useState<string | null>(null);
  const [tempLogoUrlInput, setTempLogoUrlInput] = useState<string>("");

  // Keyword input per card
  const [newKeywordInput, setNewKeywordInput] = useState<{ [bankId: string]: string }>({});

  const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL || "https://saveforapp.onrender.com";

  useEffect(() => {
    fetchRules();
  }, []);

  const fetchRules = async () => {
    setLoading(true);
    // 1. Try local storage cache
    try {
      const cached = localStorage.getItem("saveforapp_bank_rules");
      if (cached) {
        const parsed = JSON.parse(cached);
        if (Array.isArray(parsed) && parsed.length > 0) {
          // Normalize logos for any legacy saved rules
          const normalized = parsed.map((r: BankRule) => ({
            ...r,
            logoUrl: r.logoUrl || getBankLogoUrl(r),
          }));
          setRules(normalized);
        }
      }
    } catch (_) {}

    // 2. Fetch from Cloudflare R2 / internal API
    try {
      const res = await fetch("/api/bank-rules");
      if (res.ok) {
        const data = await res.json();
        const loadedRules = data.rules || data;
        if (Array.isArray(loadedRules) && loadedRules.length > 0) {
          const normalized = loadedRules.map((r: BankRule) => ({
            ...r,
            logoUrl: r.logoUrl || getBankLogoUrl(r),
          }));
          setRules(normalized);
          try {
            localStorage.setItem("saveforapp_bank_rules", JSON.stringify(normalized));
          } catch (_) {}
          setLoading(false);
          return;
        }
      }
    } catch (e) {
      console.warn("Using local defaults/cache due to fetch error:", e);
    } finally {
      setLoading(false);
    }
  };

  const handleSaveToCloud = async () => {
    setSaving(true);
    setMessage(null);

    // Normalize & save locally
    const updatedWithTimestamps = rules.map((r) => ({
      ...r,
      logoUrl: getBankLogoUrl(r),
      updatedAt: new Date().toISOString(),
    }));

    try {
      localStorage.setItem("saveforapp_bank_rules", JSON.stringify(updatedWithTimestamps));
    } catch (_) {}

    // Save to Cloudflare R2 via Next.js API
    try {
      const res = await fetch("/api/bank-rules", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ rules: updatedWithTimestamps }),
      });
      if (res.ok) {
        setMessage({ text: "บันทึกข้อมูลและลิงก์โลโก้ขึ้น Cloudflare R2 สำเร็จแล้ว! แอปมือถือจะดึงค่าอัตโนมัติ", type: "success" });
      } else {
        setMessage({ text: "บันทึกในเครื่องเรียบร้อยครับ (สถานะ Cloud: " + res.status + ")", type: "success" });
      }
    } catch (e) {
      setMessage({ text: "บันทึกในเครื่องสำเร็จ พร้อมใช้งานเรียบร้อยครับ!", type: "success" });
    } finally {
      setSaving(false);
      setTimeout(() => setMessage(null), 5000);
    }
  };

  const handleAddKeyword = (bankId: string) => {
    const text = (newKeywordInput[bankId] || "").trim();
    if (!text) return;

    setRules((prev) =>
      prev.map((r) => {
        if (r.id === bankId) {
          const exists = r.albumKeywords.some((k) => k.toLowerCase() === text.toLowerCase());
          if (!exists) {
            return { ...r, albumKeywords: [...r.albumKeywords, text] };
          }
        }
        return r;
      })
    );
    setNewKeywordInput((prev) => ({ ...prev, [bankId]: "" }));
  };

  const handleRemoveKeyword = (bankId: string, keywordToRemove: string) => {
    setRules((prev) =>
      prev.map((r) => {
        if (r.id === bankId) {
          return {
            ...r,
            albumKeywords: r.albumKeywords.filter((k) => k !== keywordToRemove),
          };
        }
        return r;
      })
    );
  };

  const handleToggleBank = (bankId: string) => {
    setRules((prev) =>
      prev.map((r) => {
        if (r.id === bankId) {
          return { ...r, isEnabled: !r.isEnabled };
        }
        return r;
      })
    );
  };

  const handleDeleteBank = (bankId: string) => {
    if (confirm("คุณแน่ใจหรือไม่ว่าต้องการลบธนาคารนี้ออกจากรายการ?")) {
      setRules((prev) => prev.filter((r) => r.id !== bankId));
    }
  };

  const handleSaveCustomLogo = (bankId: string) => {
    if (!tempLogoUrlInput.trim()) return;
    setRules((prev) =>
      prev.map((r) => {
        if (r.id === bankId) {
          return { ...r, logoUrl: tempLogoUrlInput.trim() };
        }
        return r;
      })
    );
    setEditingLogoBankId(null);
    setTempLogoUrlInput("");
  };

  const handleCreateBank = () => {
    if (!newBankName.trim()) return;

    const keywords = newInitialKeywords
      .split(",")
      .map((k) => k.trim())
      .filter((k) => k.length > 0);

    const newRule: BankRule = {
      id: `custom_${Date.now()}`,
      name: newBankName.trim(),
      appName: newAppName.trim() || newBankName.trim(),
      bankType: selectedPreset,
      logoUrl: newLogoUrl.trim() || BANK_LOGO_MAP[selectedPreset] || BANK_LOGO_MAP.other,
      albumKeywords: keywords.length > 0 ? keywords : [newBankName.trim().toLowerCase()],
      isEnabled: true,
      isCustom: true,
      colorHex: newBankColor,
      priority: rules.length + 1,
      updatedAt: new Date().toISOString(),
    };

    setRules((prev) => [...prev, newRule]);
    setShowAddModal(false);
    setMessage({ text: `เพิ่ม ${newRule.name} พร้อมลิงก์โลโก้สำเร็จแล้ว อย่าลืมกด "บันทึกขึ้น Cloud" ครับ!`, type: "success" });
  };

  const handlePresetChange = (type: string) => {
    setSelectedPreset(type);
    const p = PRESET_BANKS.find((b) => b.type === type);
    if (p) {
      setNewBankName(p.name);
      setNewAppName(p.appName);
      setNewBankColor(p.color);
      setNewLogoUrl(p.logoUrl);
      if (type === "ktb") setNewInitialKeywords("krungthai, ktb, สลิปกรุงไทย");
      else if (type === "bbl") setNewInitialKeywords("bangkok bank, bbl, บัวหลวง, กรุงเทพ");
      else if (type === "ttb") setNewInitialKeywords("ttb, tmb, ธนชาต");
      else if (type === "gsb") setNewInitialKeywords("mymo, gsb, ออมสิน");
      else setNewInitialKeywords("promptpay, สลิป, slip");
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-zinc-950 text-slate-800 dark:text-zinc-100 font-sans p-4 sm:p-8">
      <div className="max-w-5xl mx-auto">
        {/* Navigation & Header */}
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 pb-6 border-b border-slate-200 dark:border-zinc-800">
          <div>
            <div className="flex items-center gap-2 text-xs font-semibold text-emerald-600 dark:text-emerald-400 uppercase tracking-wider mb-1">
              <span>SaveFor Cloud Config</span>
              <span>•</span>
              <span className="bg-emerald-100 dark:bg-emerald-950/60 px-2 py-0.5 rounded-full">Web Portal</span>
            </div>
            <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900 dark:text-white">
              จัดการธนาคารและอัลบั้มตรวจจับสลิป
            </h1>
            <p className="text-sm text-slate-500 dark:text-zinc-400 mt-1">
              เพิ่มธนาคาร กำหนดโลโก้ (Cloudflare R2 / CDN) และระบุชื่ออัลบั้มให้อ่านสลิปได้มากกว่า 1 ชื่อต่อธนาคาร
            </p>
          </div>

          <div className="flex items-center gap-2.5 w-full sm:w-auto">
            <button
              onClick={() => setShowAddModal(true)}
              className="flex-1 sm:flex-none inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-slate-900 hover:bg-slate-800 dark:bg-zinc-100 dark:hover:bg-white text-white dark:text-zinc-900 text-sm font-semibold rounded-xl shadow-sm transition-all cursor-pointer"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 4v16m8-8H4" />
              </svg>
              เพิ่มธนาคารใหม่
            </button>

            <button
              onClick={handleSaveToCloud}
              disabled={saving}
              className="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 active:scale-98 text-white text-sm font-semibold rounded-xl shadow-sm transition-all disabled:opacity-50 cursor-pointer"
            >
              {saving ? (
                <>
                  <svg className="animate-spin w-4 h-4 text-white" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path>
                  </svg>
                  กำลังบันทึก...
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                  </svg>
                  บันทึกขึ้น Cloud
                </>
              )}
            </button>
          </div>
        </div>

        {/* Message Banner */}
        {message && (
          <div
            className={`mt-4 p-4 rounded-xl text-sm font-medium flex items-center gap-2 border ${
              message.type === "success"
                ? "bg-emerald-50 dark:bg-emerald-950/40 border-emerald-200 dark:border-emerald-800 text-emerald-800 dark:text-emerald-300"
                : "bg-red-50 dark:bg-red-950/40 border-red-200 dark:border-red-800 text-red-800 dark:text-red-300"
            }`}
          >
            <svg className="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span>{message.text}</span>
          </div>
        )}

        {/* Info Box */}
        <div className="mt-4 p-4 bg-blue-50/70 dark:bg-blue-950/30 border border-blue-200/80 dark:border-blue-800/50 rounded-2xl flex items-start gap-3">
          <div className="p-2 bg-blue-500/10 text-blue-600 dark:text-blue-400 rounded-xl">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div className="text-xs sm:text-sm text-blue-900 dark:text-blue-200 leading-relaxed">
            <span className="font-bold">ระบบโลโก้และสกีม่ารองรับการสเกล:</span> โลโก้ทุกธนาคารถูกจัดเก็บและอ่านจาก <strong>Cloudflare R2 / Public CDN (<code>logoUrl</code>)</strong> เพื่อให้สามารถเพิ่มธนาคารใหม่หรือเปลี่ยนลิงก์รูปได้อิสระ โดยในมือถือจะเป็นแบบ <strong>อ่านอย่างเดียว (Read-only)</strong> เพื่อความปลอดภัยครับ
          </div>
        </div>

        {/* Bank Rules List */}
        <div className="mt-6 space-y-4">
          {rules.map((rule) => {
            const color = rule.colorHex || "#00A950";
            const logoSrc = getBankLogoUrl(rule);
            const isEditingLogo = editingLogoBankId === rule.id;

            return (
              <div
                key={rule.id}
                className={`p-5 rounded-2xl border transition-all ${
                  rule.isEnabled
                    ? "bg-white dark:bg-zinc-900/90 border-slate-200 dark:border-zinc-800 shadow-sm"
                    : "bg-slate-100/70 dark:bg-zinc-900/40 border-slate-200/60 dark:border-zinc-800/40 opacity-70"
                }`}
              >
                <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 pb-4 border-b border-slate-100 dark:border-zinc-800/80">
                  <div className="flex items-center gap-3.5">
                    {/* Bank Logo Image */}
                    <div className="w-13 h-13 sm:w-14 sm:h-14 rounded-2xl overflow-hidden bg-white dark:bg-zinc-800 border border-slate-200/80 dark:border-zinc-700/80 p-1 flex items-center justify-center shadow-sm flex-shrink-0 relative">
                      {logoSrc ? (
                        <img
                          src={logoSrc}
                          alt={rule.name}
                          className="w-full h-full object-contain rounded-xl"
                          onError={(e) => {
                            e.currentTarget.style.display = "none";
                            const fallback = e.currentTarget.nextElementSibling as HTMLElement;
                            if (fallback) fallback.style.display = "flex";
                          }}
                        />
                      ) : null}
                      <div
                        className="w-full h-full rounded-xl flex items-center justify-center font-bold text-white text-sm shadow-inner"
                        style={{
                          backgroundColor: color,
                          display: logoSrc ? "none" : "flex",
                        }}
                      >
                        {rule.name.slice(0, 2)}
                      </div>
                    </div>

                    <div>
                      <div className="flex items-center gap-2">
                        <h2 className="text-base font-bold text-slate-900 dark:text-white">
                          {rule.name}
                        </h2>
                        {rule.isCustom && (
                          <span className="text-[10px] font-semibold uppercase px-2 py-0.5 bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300 rounded-md">
                            Custom Bank
                          </span>
                        )}
                        <span
                          className={`text-[10px] font-semibold px-2 py-0.5 rounded-md ${
                            rule.isEnabled
                              ? "bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300"
                              : "bg-slate-200 text-slate-600 dark:bg-zinc-800 dark:text-zinc-400"
                          }`}
                        >
                          {rule.isEnabled ? "เปิดตรวจจับ" : "ปิดการอ่าน"}
                        </span>
                      </div>
                      <div className="flex items-center gap-2 text-xs text-slate-500 dark:text-zinc-400 mt-0.5 flex-wrap">
                        <span>{rule.appName}</span>
                        <span>•</span>
                        <span>ID: <code className="font-mono text-slate-600 dark:text-zinc-300">{rule.id}</code></span>
                        <span>•</span>
                        <button
                          onClick={() => {
                            setEditingLogoBankId(isEditingLogo ? null : rule.id);
                            setTempLogoUrlInput(rule.logoUrl || logoSrc);
                          }}
                          className="text-emerald-600 dark:text-emerald-400 hover:underline inline-flex items-center gap-1 cursor-pointer font-medium"
                        >
                          <span>🔗</span>
                          <span>{isEditingLogo ? "ปิดแก้โลโก้" : "ตั้งค่าโลโก้"}</span>
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Toggle & Action Buttons */}
                  <div className="flex items-center gap-3 w-full sm:w-auto justify-between sm:justify-end">
                    <button
                      onClick={() => handleToggleBank(rule.id)}
                      className={`px-3 py-1.5 text-xs font-semibold rounded-lg border transition-all cursor-pointer ${
                        rule.isEnabled
                          ? "bg-emerald-50 border-emerald-200 text-emerald-700 dark:bg-emerald-950/30 dark:border-emerald-800 dark:text-emerald-400"
                          : "bg-slate-100 border-slate-300 text-slate-600 dark:bg-zinc-800 dark:border-zinc-700 dark:text-zinc-400"
                      }`}
                    >
                      {rule.isEnabled ? "เปิดอยู่ (คลิกเพื่อปิด)" : "ปิดอยู่ (คลิกเพื่อเปิด)"}
                    </button>

                    {rule.isCustom && (
                      <button
                        onClick={() => handleDeleteBank(rule.id)}
                        className="p-1.5 text-red-600 hover:text-red-700 hover:bg-red-50 dark:hover:bg-red-950/40 rounded-lg transition-colors cursor-pointer"
                        title="ลบธนาคารนี้"
                      >
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                      </button>
                    )}
                  </div>
                </div>

                {/* Edit Logo URL Accordion */}
                {isEditingLogo && (
                  <div className="my-3 p-3 bg-slate-50 dark:bg-zinc-800/60 rounded-xl border border-slate-200 dark:border-zinc-700/80">
                    <label className="block text-xs font-bold text-slate-700 dark:text-zinc-300 mb-1">
                      ลิงก์โลโก้ธนาคาร (Cloudflare R2 / Public CDN URL)
                    </label>
                    <div className="flex gap-2">
                      <input
                        type="text"
                        value={tempLogoUrlInput}
                        onChange={(e) => setTempLogoUrlInput(e.target.value)}
                        placeholder="https://... หรือ /images/banks/kbank.png"
                        className="flex-1 px-3 py-1.5 bg-white dark:bg-zinc-900 border border-slate-200 dark:border-zinc-700 rounded-lg text-xs font-mono focus:outline-none focus:ring-2 focus:ring-emerald-500"
                      />
                      <button
                        onClick={() => handleSaveCustomLogo(rule.id)}
                        className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold rounded-lg cursor-pointer"
                      >
                        อัปเดตโลโก้
                      </button>
                      <button
                        onClick={() => {
                          const def = BANK_LOGO_MAP[rule.bankType] || BANK_LOGO_MAP[rule.id] || "";
                          setTempLogoUrlInput(def);
                        }}
                        className="px-2 py-1.5 bg-slate-200 hover:bg-slate-300 dark:bg-zinc-700 dark:hover:bg-zinc-600 text-xs font-semibold rounded-lg cursor-pointer"
                        title="ใช้รูปมาตรฐาน"
                      >
                        ค่าเดิม
                      </button>
                    </div>
                  </div>
                )}

                {/* Album Keywords Section */}
                <div className="pt-4">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-zinc-400">
                      ชื่ออัลบั้มที่ตรวจจับ ({rule.albumKeywords.length} ชื่อ)
                    </span>
                    <span className="text-[11px] text-slate-400 dark:text-zinc-500">
                      ตรวจจับแบบ Case-insensitive
                    </span>
                  </div>

                  {/* Chips */}
                  <div className="flex flex-wrap gap-2 mb-3">
                    {rule.albumKeywords.map((kw, idx) => (
                      <span
                        key={idx}
                        className="inline-flex items-center gap-1.5 px-3 py-1 bg-slate-100 dark:bg-zinc-800 text-slate-800 dark:text-zinc-200 text-xs font-semibold rounded-lg border border-slate-200/80 dark:border-zinc-700"
                      >
                        <span>📁</span>
                        <span>{kw}</span>
                        <button
                          onClick={() => handleRemoveKeyword(rule.id, kw)}
                          className="w-4 h-4 rounded-full flex items-center justify-center hover:bg-slate-300 dark:hover:bg-zinc-700 text-slate-400 hover:text-slate-700 dark:hover:text-zinc-200 transition-colors cursor-pointer"
                        >
                          ×
                        </button>
                      </span>
                    ))}

                    {rule.albumKeywords.length === 0 && (
                      <span className="text-xs text-amber-600 dark:text-amber-400 italic">
                        ยังไม่มีชื่ออัลบั้ม! กรุณาเพิ่มชื่ออัลบั้มด้านล่าง
                      </span>
                    )}
                  </div>

                  {/* Add keyword input */}
                  <div className="flex gap-2 max-w-md">
                    <input
                      type="text"
                      placeholder="พิมพ์ชื่ออัลบั้ม เช่น สลิปที่ทำงาน, WorkSlips..."
                      value={newKeywordInput[rule.id] || ""}
                      onChange={(e) =>
                        setNewKeywordInput((prev) => ({ ...prev, [rule.id]: e.target.value }))
                      }
                      onKeyDown={(e) => {
                        if (e.key === "Enter") {
                          e.preventDefault();
                          handleAddKeyword(rule.id);
                        }
                      }}
                      className="flex-1 px-3 py-1.5 bg-slate-50 dark:bg-zinc-800/80 border border-slate-200 dark:border-zinc-700 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500"
                    />
                    <button
                      onClick={() => handleAddKeyword(rule.id)}
                      className="px-3.5 py-1.5 bg-slate-800 hover:bg-slate-700 dark:bg-zinc-200 dark:hover:bg-white text-white dark:text-zinc-900 text-xs font-semibold rounded-xl transition-all cursor-pointer"
                    >
                      + เพิ่ม
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* Footer info & Reset */}
        <div className="mt-8 pt-6 border-t border-slate-200 dark:border-zinc-800 flex flex-col sm:flex-row items-center justify-between gap-4">
          <Link
            href="/"
            className="text-xs text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 font-semibold"
          >
            ← กลับสู่หน้าหลัก
          </Link>

          <button
            onClick={() => {
              if (confirm("ต้องการคืนค่าเริ่มต้นทั้งหมดใช่หรือไม่?")) {
                setRules(DEFAULT_RULES);
                setMessage({ text: "รีเซ็ตค่าเริ่มต้นสำเร็จแล้ว อย่าลืมกดบันทึกขึ้น Cloud ครับ", type: "success" });
              }
            }}
            className="text-xs text-slate-500 hover:text-slate-800 dark:hover:text-zinc-300 underline cursor-pointer"
          >
            คืนค่าเริ่มต้นธนาคาร 4 แห่ง
          </button>
        </div>
      </div>

      {/* Add Bank Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 rounded-2xl p-6 max-w-md w-full shadow-2xl">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-zinc-800">
              <h3 className="text-lg font-bold text-slate-900 dark:text-white">เพิ่มธนาคารใหม่</h3>
              <button
                onClick={() => setShowAddModal(false)}
                className="text-slate-400 hover:text-slate-600 dark:hover:text-zinc-200 cursor-pointer"
              >
                ✕
              </button>
            </div>

            <div className="mt-4 space-y-3.5">
              {/* Preset selection with logo thumbnails */}
              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-zinc-300 mb-1.5">
                  เลือกจากแม่แบบธนาคารยอดนิยม
                </label>
                <div className="grid grid-cols-5 gap-2 mb-2">
                  {PRESET_BANKS.map((b) => (
                    <button
                      key={b.type}
                      type="button"
                      onClick={() => handlePresetChange(b.type)}
                      className={`p-2 rounded-xl border flex flex-col items-center gap-1 transition-all cursor-pointer ${
                        selectedPreset === b.type
                          ? "border-emerald-500 bg-emerald-50/50 dark:bg-emerald-950/30 ring-2 ring-emerald-500/20"
                          : "border-slate-200 dark:border-zinc-700 hover:bg-slate-50 dark:hover:bg-zinc-800"
                      }`}
                    >
                      <div className="w-8 h-8 rounded-lg overflow-hidden bg-white p-0.5 border border-slate-200 flex items-center justify-center">
                        <img src={b.logoUrl} alt={b.name} className="w-full h-full object-contain" />
                      </div>
                      <span className="text-[10px] font-bold text-center truncate w-full">{b.name}</span>
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-zinc-300 mb-1">
                  ชื่อธนาคาร
                </label>
                <input
                  type="text"
                  value={newBankName}
                  onChange={(e) => setNewBankName(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 dark:bg-zinc-800 border border-slate-200 dark:border-zinc-700 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-zinc-300 mb-1">
                  ชื่อแอป (App Name)
                </label>
                <input
                  type="text"
                  value={newAppName}
                  onChange={(e) => setNewAppName(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 dark:bg-zinc-800 border border-slate-200 dark:border-zinc-700 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-zinc-300 mb-1">
                  ลิงก์โลโก้ธนาคาร (logoUrl)
                </label>
                <div className="flex items-center gap-2">
                  <div className="w-9 h-9 rounded-xl overflow-hidden bg-white border border-slate-200 p-0.5 flex-shrink-0">
                    <img src={newLogoUrl} alt="Preview" className="w-full h-full object-contain" />
                  </div>
                  <input
                    type="text"
                    value={newLogoUrl}
                    onChange={(e) => setNewLogoUrl(e.target.value)}
                    placeholder="https://... หรือ /images/banks/..."
                    className="flex-1 px-3 py-2 bg-slate-50 dark:bg-zinc-800 border border-slate-200 dark:border-zinc-700 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-zinc-300 mb-1">
                  ชื่ออัลบั้มที่ต้องการให้อ่าน (คั่นด้วยเครื่องหมายจุลภาค ,)
                </label>
                <input
                  type="text"
                  value={newInitialKeywords}
                  onChange={(e) => setNewInitialKeywords(e.target.value)}
                  placeholder="เช่น krungthai, ktb, สลิปที่ทำงาน"
                  className="w-full px-3 py-2 bg-slate-50 dark:bg-zinc-800 border border-slate-200 dark:border-zinc-700 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-zinc-300 mb-1">
                  สีประจำธนาคาร
                </label>
                <div className="flex items-center gap-3">
                  <input
                    type="color"
                    value={newBankColor}
                    onChange={(e) => setNewBankColor(e.target.value)}
                    className="w-10 h-10 rounded-xl border border-slate-200 cursor-pointer"
                  />
                  <span className="font-mono text-xs text-slate-600 dark:text-zinc-300">
                    {newBankColor}
                  </span>
                </div>
              </div>
            </div>

            <div className="mt-6 flex justify-end gap-2.5">
              <button
                onClick={() => setShowAddModal(false)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 dark:bg-zinc-800 dark:hover:bg-zinc-700 text-slate-700 dark:text-zinc-300 text-sm font-semibold rounded-xl cursor-pointer"
              >
                ยกเลิก
              </button>
              <button
                onClick={handleCreateBank}
                className="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-sm font-semibold rounded-xl shadow-sm cursor-pointer"
              >
                สร้างธนาคาร
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
