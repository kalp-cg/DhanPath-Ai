import type { Metadata } from "next";
import { Manrope, Sora } from "next/font/google";

import "./globals.css";

const manrope = Manrope({ subsets: ["latin"], variable: "--font-manrope" });
const sora = Sora({ subsets: ["latin"], variable: "--font-sora" });

export const metadata: Metadata = {
  title: "DhanPath - Finance Workspace",
  description: "Family finance workspace with transaction analytics, budgeting, billing, and reporting.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${manrope.variable} ${sora.variable}`}
      data-theme="light"
      data-scroll-behavior="smooth"
    >
      <body>{children}</body>
    </html>
  );
}
