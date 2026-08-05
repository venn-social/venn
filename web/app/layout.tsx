import type { Metadata } from "next";
import { Manrope } from "next/font/google";
import "./globals.css";

/**
 * App-wide typeface (CLAUDE.md rule 17 — one conceptual source of truth
 * with iOS's Theme.Font, which uses the bundled Manrope font files).
 * next/font self-hosts the files at build time — no runtime request to
 * Google Fonts.
 */
const manrope = Manrope({
  variable: "--font-sans",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "venn",
  description: "you have good taste. explore it.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${manrope.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
