import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || "https://ngenmoney.com";

  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        disallow: ["/admin", "/api/", "/bank-rules", "/test-plan"],
      },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
  };
}
