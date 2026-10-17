import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Protect all internal admin, rule management, and test plan routes
  const isProtectedInternalRoute =
    pathname.startsWith("/admin") ||
    pathname.startsWith("/api/admin") ||
    pathname.startsWith("/bank-rules") ||
    pathname.startsWith("/test-plan") ||
    pathname.startsWith("/api/bank-rules");

  if (isProtectedInternalRoute) {
    const forwardedHost = request.headers.get("x-forwarded-host") || "";
    const rawHost = request.headers.get("host") || "";
    const host = (forwardedHost || rawHost).toLowerCase();
    const hostname = host.split(":")[0];

    const isLocalhost =
      hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      hostname === "::1" ||
      hostname.endsWith(".local") ||
      hostname.startsWith("192.168.") ||
      hostname.startsWith("10.") ||
      hostname.startsWith("172.");

    // Strict rejection for public production domains or non-local hosts
    const isPublicProduction =
      hostname.includes("ngenmoney.com") ||
      hostname.includes("vercel.app") ||
      hostname.includes("render.com") ||
      !isLocalhost;

    if (isPublicProduction) {
      if (pathname.startsWith("/api/")) {
        return new NextResponse(
          JSON.stringify({ error: "Not Found" }),
          {
            status: 404,
            headers: { "Content-Type": "application/json" },
          }
        );
      }

      // Rewrite to 404 so public visitors see the standard Not Found page
      const notFoundUrl = new URL("/_not-found", request.url);
      return NextResponse.rewrite(notFoundUrl, { status: 404 });
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/admin/:path*",
    "/api/admin/:path*",
    "/bank-rules/:path*",
    "/test-plan/:path*",
    "/api/bank-rules/:path*",
  ],
};
