import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactCompiler: true,
  async rewrites() {
    return [
      {
        source: "/api/opencode/:path*",
        destination: "http://localhost:4096/:path*",
      },
    ];
  },
};

export default nextConfig;
