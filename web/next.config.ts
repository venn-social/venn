import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // This repo also has a root-level package-lock.json (for non-web
  // tooling: prettier, commitlint, ...), which Turbopack otherwise
  // mistakes for the workspace root.
  turbopack: {
    root: import.meta.dirname,
  },
};

export default nextConfig;
