"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import type { ReactNode } from "react";
import { useConsole } from "../lib/console";
import { instantTime } from "../lib/format";
import { Icon } from "./Icon";
import type { IconName } from "./Icon";
import { SampleBadge, Skeleton } from "./ui";

type NavItem = { href: string; key: keyof ReturnType<typeof useConsole>["t"]["nav"]; icon: IconName; count?: number };

export function Shell({ children }: { children: ReactNode }) {
  const { t, store, locale, setLocale, timeZone, version } = useConsole();
  const pathname = usePathname();
  const [navOpen, setNavOpen] = useState(false);
  useEffect(() => setNavOpen(false), [pathname]);
  void version;

  const settings = store.settings();
  const newApplicants = store.applicants().filter((a) => a.status === "applied").length;
  const waiting = store.threads().filter((th) => th.needsStaff || th.unread > 0).length;
  const run: NavItem[] = [
    { href: "/", key: "today", icon: "home" },
    { href: "/jobs", key: "jobs", icon: "briefcase" },
    { href: "/applications", key: "applicants", icon: "users", count: newApplicants },
    { href: "/attendance", key: "shifts", icon: "calendar" },
    { href: "/payroll", key: "payroll", icon: "chart" },
    { href: "/chat", key: "chat", icon: "chat", count: waiting },
  ];
  const people: NavItem[] = [
    { href: "/reviews", key: "reviews", icon: "island" },
    { href: "/invites", key: "invites", icon: "mail" },
    { href: "/settings", key: "settings", icon: "settings" },
  ];
  const isActive = (href: string) => (href === "/" ? pathname === "/" : pathname.startsWith(href));
  const item = (n: NavItem) => (
    <Link key={n.href} href={n.href} className="nav-item" aria-current={isActive(n.href) ? "page" : undefined}>
      <Icon name={n.icon} />
      <span>{t.nav[n.key]}</span>
      {n.count ? <span className="nav-count" aria-label={`${n.count}`}>{n.count}</span> : null}
    </Link>
  );
  const now = store.now();
  const tzShort = new Intl.DateTimeFormat(store.region === "jp" ? "ja-JP" : "en-US", { timeZone, timeZoneName: "short" }).formatToParts(now).find((p) => p.type === "timeZoneName")?.value ?? "";

  return (
    <div className={`app${navOpen ? " nav-open" : ""}`}>
      <a className="skip" href="#content">{t.skip}</a>
      <aside className="nav" aria-label="Main">
        <div className="brand">
          <span className="logo" aria-hidden="true" />
          <span className="brand-name">Paw Time</span>
          <span className="brand-product">{t.product}</span>
        </div>
        <div className="shop-card">
          <span className="shop-sign" style={{ background: settings.profile.signColor }} aria-hidden="true">{settings.profile.name.replace(/^カフェ\s*/, "").slice(0, 1)}</span>
          <div>
            <strong>{settings.profile.name}</strong>
            <small>{settings.profile.area}</small>
          </div>
        </div>
        <div className="nav-h">{t.nav.sectionRun}</div>
        {run.map(item)}
        <div className="nav-h">{t.nav.sectionPeople}</div>
        {people.map(item)}
        <div className="nav-foot">
          <SampleBadge label={t.sample} />
        </div>
      </aside>
      <div className="scrim" onClick={() => setNavOpen(false)} aria-hidden="true" />
      <div className="main">
        <header className="topbar">
          <button type="button" className="icon-btn menu-btn" aria-label={t.menu} aria-expanded={navOpen} onClick={() => setNavOpen((v) => !v)}>
            <Icon name="menu" />
          </button>
          <SampleBadge label={t.sample} />
          <span className="spacer" />
          <span className="clock" title={t.shopClock}>
            <Icon name="clock" />
            <span className="sr">{t.shopClock}</span>
            {instantTime(now.toISOString(), timeZone, locale)}
            <span className="tz muted">{tzShort}</span>
          </span>
          <div className="seg" role="group" aria-label={t.language}>
            <button type="button" aria-pressed={locale === "en"} onClick={() => setLocale("en")} lang="en">EN</button>
            <button type="button" aria-pressed={locale === "ja"} onClick={() => setLocale("ja")} lang="ja">JA</button>
          </div>
        </header>
        <main className="content" id="content" tabIndex={-1}>
          <div className="banner synth" role="note">
            <Icon name="info" />
            <span>{t.sampleBanner(settings.profile.name)}</span>
          </div>
          {children}
        </main>
        <footer className="foot">{t.foot}</footer>
      </div>
    </div>
  );
}

export function ShellFallback() {
  return (
    <div className="app">
      <aside className="nav" aria-hidden="true">
        <div className="brand"><span className="logo" /><span className="brand-name">Paw Time</span><span className="brand-product">for Shops</span></div>
        <div style={{ display: "grid", gap: 12, padding: 8 }}>
          {Array.from({ length: 8 }, (_, i) => <span key={i} className="skel" style={{ width: `${60 + ((i * 13) % 30)}%` }} />)}
        </div>
      </aside>
      <div className="main">
        <header className="topbar" />
        <main className="content"><Skeleton rows={6} /></main>
      </div>
    </div>
  );
}
