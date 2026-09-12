import { NextRequest, NextResponse } from "next/server";
import crypto from "crypto";
import fs from "fs";
import path from "path";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
};

const DEFAULT_RULES = [
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
  {
    id: "ktb",
    name: "กรุงไทย",
    appName: "Krungthai NEXT",
    bankType: "ktb",
    logoUrl: "/images/banks/ktb.png",
    albumKeywords: ["krungthai", "ktb", "สลิปกรุงไทย", "กรุงไทย"],
    isEnabled: true,
    isCustom: false,
    colorHex: "#00AEEF",
    priority: 5,
  },
];

function getR2Config() {
  return {
    accountId: process.env.CLOUDFLARE_ACCOUNT_ID || "d9e78a2733b29316b2848d6c87e60baa",
    accessKey: process.env.CLOUDFLARE_R2_ACCESS_KEY_ID || "04019926bc6590f6d6284b648a901dd7",
    secretKey: process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY || "45ab44ffc58e1d8e7daadcee35653a2fc01e62c1839e4bebd238a2f726622086",
    bucket: process.env.CLOUDFLARE_R2_BUCKET_NAME || "savfor",
  };
}

function hmacSHA256(key: Buffer | string, data: string): Buffer {
  return crypto.createHmac("sha256", key).update(data).digest();
}

function getSignatureKey(key: string, dateStamp: string, regionName: string, serviceName: string): Buffer {
  const kDate = hmacSHA256("AWS4" + key, dateStamp);
  const kRegion = hmacSHA256(kDate, regionName);
  const kService = hmacSHA256(kRegion, serviceName);
  return hmacSHA256(kService, "aws4_request");
}

async function fetchFromR2(objectKey: string): Promise<string | null> {
  const cfg = getR2Config();
  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, "");
  const dateStamp = amzDate.substring(0, 8);
  const host = `${cfg.accountId}.r2.cloudflarestorage.com`;
  const canonicalUri = `/${cfg.bucket}/${objectKey}`;

  const payloadHash = crypto.createHash("sha256").update("").digest("hex");
  const canonicalHeaders = `host:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
  const signedHeaders = "host;x-amz-content-sha256;x-amz-date";
  const canonicalRequest = ["GET", canonicalUri, "", canonicalHeaders, signedHeaders, payloadHash].join("\n");

  const credentialScope = `${dateStamp}/auto/s3/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    crypto.createHash("sha256").update(canonicalRequest).digest("hex"),
  ].join("\n");

  const signingKey = getSignatureKey(cfg.secretKey, dateStamp, "auto", "s3");
  const signature = crypto.createHmac("sha256", signingKey).update(stringToSign).digest("hex");
  const authHeader = `AWS4-HMAC-SHA256 Credential=${cfg.accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  try {
    const res = await fetch(`https://${host}${canonicalUri}`, {
      method: "GET",
      headers: {
        Authorization: authHeader,
        "x-amz-content-sha256": payloadHash,
        "x-amz-date": amzDate,
      },
    });
    if (res.ok) {
      return await res.text();
    }
  } catch (e) {
    console.warn("fetchFromR2 error:", e);
  }
  return null;
}

async function saveToR2(objectKey: string, content: string): Promise<boolean> {
  const cfg = getR2Config();
  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, "");
  const dateStamp = amzDate.substring(0, 8);
  const host = `${cfg.accountId}.r2.cloudflarestorage.com`;
  const canonicalUri = `/${cfg.bucket}/${objectKey}`;

  const payloadHash = crypto.createHash("sha256").update(content).digest("hex");
  const canonicalHeaders = `content-type:application/json\nhost:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
  const signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date";
  const canonicalRequest = ["PUT", canonicalUri, "", canonicalHeaders, signedHeaders, payloadHash].join("\n");

  const credentialScope = `${dateStamp}/auto/s3/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    crypto.createHash("sha256").update(canonicalRequest).digest("hex"),
  ].join("\n");

  const signingKey = getSignatureKey(cfg.secretKey, dateStamp, "auto", "s3");
  const signature = crypto.createHmac("sha256", signingKey).update(stringToSign).digest("hex");
  const authHeader = `AWS4-HMAC-SHA256 Credential=${cfg.accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  try {
    const res = await fetch(`https://${host}${canonicalUri}`, {
      method: "PUT",
      headers: {
        Authorization: authHeader,
        "Content-Type": "application/json",
        "x-amz-content-sha256": payloadHash,
        "x-amz-date": amzDate,
      },
      body: content,
    });
    return res.ok;
  } catch (e) {
    console.error("saveToR2 error:", e);
    return false;
  }
}

async function saveToSupabase(content: string): Promise<boolean> {
  const supabaseUrl = "https://nqgmimfkxgkkofaoddre.supabase.co";
  const supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xZ21pbWZreGdra29mYW9kZHJlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MzA4MzQwMSwiZXhwIjoyMDk4NjU5NDAxfQ.n5sv4EyzAfV0zd9kIetUZQB1DDXibtqvhwUPgvjJCnY";
  try {
    const res = await fetch(`${supabaseUrl}/storage/v1/object/app_config/bank_rules.json`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${supabaseKey}`,
        apikey: supabaseKey,
        "Content-Type": "application/json",
        "x-upsert": "true",
      },
      body: content,
    });
    return res.ok;
  } catch (e) {
    console.warn("saveToSupabase error:", e);
    return false;
  }
}

function getLocalBackupPath(): string {
  return path.join(process.cwd(), "public", "bank_rules.json");
}

export async function OPTIONS() {
  return NextResponse.json({}, { headers: corsHeaders });
}

export async function GET() {
  // 1. Try Supabase Public Cloud Storage
  try {
    const res = await fetch(
      "https://nqgmimfkxgkkofaoddre.supabase.co/storage/v1/object/public/app_config/bank_rules.json",
      { cache: "no-store" }
    );
    if (res.ok) {
      const data = await res.json();
      const list = Array.isArray(data) ? data : data.rules || [];
      if (list.length > 0) {
        return NextResponse.json({ rules: list, count: list.length, source: "supabase_cloud" }, { headers: corsHeaders });
      }
    }
  } catch (_) {}

  // 2. Try Cloudflare R2
  const r2Text = await fetchFromR2("bank-rules/config.json");
  if (r2Text) {
    try {
      const parsed = JSON.parse(r2Text);
      const list = Array.isArray(parsed) ? parsed : parsed.rules || [];
      if (list.length > 0) {
        return NextResponse.json({ rules: list, count: list.length, source: "cloudflare_r2" }, { headers: corsHeaders });
      }
    } catch (_) {}
  }

  // 3. Try local file backup
  try {
    const filePath = getLocalBackupPath();
    if (fs.existsSync(filePath)) {
      const fileData = fs.readFileSync(filePath, "utf-8");
      const parsed = JSON.parse(fileData);
      const list = Array.isArray(parsed) ? parsed : parsed.rules || [];
      if (list.length > 0) {
        return NextResponse.json({ rules: list, count: list.length, source: "local_cache" }, { headers: corsHeaders });
      }
    }
  } catch (_) {}

  // 4. Fallback defaults
  return NextResponse.json({ rules: DEFAULT_RULES, count: DEFAULT_RULES.length, source: "defaults" }, { headers: corsHeaders });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const rules = Array.isArray(body) ? body : body.rules || [];

    if (!Array.isArray(rules) || rules.length === 0) {
      return NextResponse.json({ error: "Invalid rules array" }, { status: 400, headers: corsHeaders });
    }

    const jsonString = JSON.stringify(rules, null, 2);

    // 1. Save to Supabase Public Cloud Storage
    const sbOk = await saveToSupabase(jsonString);

    // 2. Save to Cloudflare R2
    const r2Ok = await saveToR2("bank-rules/config.json", jsonString);

    // 3. Save to local file backup
    try {
      const filePath = getLocalBackupPath();
      fs.writeFileSync(filePath, jsonString, "utf-8");
    } catch (e) {
      console.warn("Could not write local backup file:", e);
    }

    return NextResponse.json(
      {
        success: true,
        supabaseSynced: sbOk,
        r2Synced: r2Ok,
        count: rules.length,
        rules,
      },
      { headers: corsHeaders }
    );
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500, headers: corsHeaders });
  }
}
