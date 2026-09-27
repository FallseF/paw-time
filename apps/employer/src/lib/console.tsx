"use client";

import { createStore } from "@paw-time/shop-console";
import type { Currency, Locale, Region, Result, ShopConsoleStore } from "@paw-time/shop-console";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type { ReactNode } from "react";
import { Icon } from "../components/Icon";
import { fmtMoney } from "./format";
import { DICTS } from "./i18n";
import type { Dict } from "./i18n";

/**
 * The console runs on the shared shop-console store in the browser, seeded with sample data:
 * EN = San Francisco (USD), JA = Japan (JPY). Each language keeps its own store, so edits
 * survive switching back and forth until the page is reloaded.
 */
type Toast = { id: number; text: string; kind: "ok" | "err" };

type ConsoleContext = {
  store: ShopConsoleStore;
  locale: Locale;
  setLocale: (l: Locale) => void;
  t: Dict;
  currency: Currency;
  timeZone: string;
  staffName: string;
  version: number;
  now: () => Date;
  money: (v: number, perHour?: boolean) => string;
  /** Runs a store action, re-renders, and shows the success text or the error. */
  run: <T>(action: (s: ShopConsoleStore) => Result<T>, okText?: string | ((data: T) => string)) => Result<T>;
  refresh: () => void;
  toast: (text: string, kind?: Toast["kind"]) => void;
  resetSample: () => void;
};

const Ctx = createContext<ConsoleContext | null>(null);
const LOCALE_KEY = "pawtime.shop.locale";

const regionOf = (l: Locale): Region => (l === "ja" ? "jp" : "sf");

function initialLocale(): Locale {
  try {
    const q = new URLSearchParams(window.location.search).get("lang");
    if (q === "ja" || q === "en") return q;
    const saved = window.localStorage.getItem(LOCALE_KEY);
    if (saved === "ja" || saved === "en") return saved;
  } catch {
    // Storage can be blocked; English is the default.
  }
  return "en";
}

export function ConsoleProvider({ children, fallback }: { children: ReactNode; fallback: ReactNode }) {
  const stores = useRef(new Map<Region, ShopConsoleStore>());
  const [locale, setLocaleState] = useState<Locale | null>(null);
  const [version, setVersion] = useState(0);
  const [toasts, setToasts] = useState<Toast[]>([]);

  useEffect(() => setLocaleState(initialLocale()), []);

  // Tick once a minute so the shop clock, arrivals and quiet-hours hints stay current.
  useEffect(() => {
    const id = window.setInterval(() => setVersion((v) => v + 1), 60_000);
    return () => window.clearInterval(id);
  }, []);

  useEffect(() => {
    if (!locale) return;
    document.documentElement.lang = locale;
    try {
      window.localStorage.setItem(LOCALE_KEY, locale);
    } catch {
      // ignore
    }
  }, [locale]);

  const storeFor = useCallback((l: Locale) => {
    const region = regionOf(l);
    let s = stores.current.get(region);
    if (!s) {
      s = createStore(region);
      stores.current.set(region, s);
    }
    return s;
  }, []);

  const toast = useCallback((text: string, kind: Toast["kind"] = "ok") => {
    const id = Date.now() + Math.random();
    setToasts((list) => [...list.slice(-2), { id, text, kind }]);
    window.setTimeout(() => setToasts((list) => list.filter((x) => x.id !== id)), 3600);
  }, []);

  const value = useMemo<ConsoleContext | null>(() => {
    if (!locale) return null;
    const store = storeFor(locale);
    const t = DICTS[locale];
    const settings = store.settings();
    const staff = settings.staff.find((m) => m.role === "manager") ?? settings.staff[0];
    return {
      store,
      locale,
      setLocale: (l: Locale) => setLocaleState(l),
      t,
      currency: settings.currency,
      timeZone: settings.timeZone,
      staffName: staff?.name ?? "",
      version,
      now: () => store.now(),
      money: (v: number, perHour?: boolean) => fmtMoney(v, settings.currency, perHour ? { cents: settings.currency === "USD", perHour: t.common.perHour } : {}),
      run: (action, okText) => {
        const result = action(store);
        setVersion((v) => v + 1);
        if (result.ok) {
          if (okText) toast(typeof okText === "function" ? okText(result.data) : okText);
        } else {
          toast(t.errors[result.error] ?? t.errors.generic ?? "Error", "err");
        }
        return result;
      },
      refresh: () => setVersion((v) => v + 1),
      toast,
      resetSample: () => {
        stores.current.delete(regionOf(locale));
        setVersion((v) => v + 1);
      },
    };
  }, [locale, version, storeFor, toast]);

  if (!value) return <>{fallback}</>;
  return (
    <Ctx.Provider value={value}>
      {children}
      <div className="toasts" role="status" aria-live="polite">
        {toasts.map((x) => (
          <div key={x.id} className={`toast${x.kind === "err" ? " err" : ""}`}>
            <Icon name={x.kind === "err" ? "alert" : "check"} />
            {x.text}
          </div>
        ))}
      </div>
    </Ctx.Provider>
  );
}

export function useConsole(): ConsoleContext {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useConsole must be used inside ConsoleProvider");
  return ctx;
}
