import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import { Shell, ShellFallback } from "../components/Shell";
import { ConsoleProvider } from "../lib/console";
import "./globals.css";

export const metadata: Metadata = {
  title: "Paw Time for Shops",
  description: "Shop console for Paw Time: shifts, applicants, attendance, chat, reviews and invites. Runs on sample data.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f6f7f9" },
    { media: "(prefers-color-scheme: dark)", color: "#0f1115" },
  ],
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=Noto+Sans+JP:wght@400;500;600&display=swap" />
      </head>
      <body>
        <ConsoleProvider fallback={<ShellFallback />}>
          <Shell>{children}</Shell>
        </ConsoleProvider>
      </body>
    </html>
  );
}
