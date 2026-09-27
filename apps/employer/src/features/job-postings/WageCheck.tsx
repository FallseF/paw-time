"use client";

import { REGIONS } from "@paw-time/shop-console";
import { Icon } from "../../components/Icon";
import { useConsole } from "../../lib/console";
import { fmtDate } from "../../lib/format";

/** Live minimum-wage line under a wage input. Uses the same rule the store enforces on save. */
export function WageCheck({ wage, dates }: { wage: number; dates: string[] }) {
  const { store, t, locale, money } = useConsole();
  const valid = dates.filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d));
  if (!Number.isFinite(wage) || wage <= 0) return <span className="hint">{t.editor.required}</span>;
  const check = store.checkWage(wage, valid.length ? valid : [store.today()]);
  const area = REGIONS[store.region].minimumWageArea;
  if (check.ok) {
    return <span className="ok"><Icon name="check" />{t.editor.minOk(area, money(check.minimum, false), fmtDate(check.from, locale, { weekday: false }))}</span>;
  }
  return (
    <span className="err" role="alert">
      <Icon name="alert" />
      {t.editor.minBad(money(check.minimum, false), fmtDate(check.date, locale, { weekday: false }), money(check.shortBy, false))}
    </span>
  );
}
