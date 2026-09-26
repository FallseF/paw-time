import type { Metadata } from "next";
import Link from "next/link";
import type { ReactNode } from "react";
import "./globals.css";

export const metadata: Metadata = {
  title: "Paw Time for Business",
  description: "求人、応募者、勤怠と企業の家を管理します。",
};

const navigation = [
  ["/", "ホーム"],
  ["/jobs", "求人"],
  ["/applications", "応募者"],
  ["/attendance", "勤怠"],
  ["/evaluations", "評価"],
  ["/house", "みんなの家"],
] as const;

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="ja">
      <body>
        <div className="shell">
          <aside className="sidebar">
            <div className="brand"><span>🐾</span><div><strong>Paw Time</strong><small>for Business</small></div></div>
            <nav>
              {navigation.map(([href, label]) => <Link href={href} key={href}>{label}</Link>)}
            </nav>
            <div className="organization"><small>現在の店舗</small><strong>カフェ こもれび</strong></div>
          </aside>
          <main>{children}</main>
        </div>
      </body>
    </html>
  );
}
