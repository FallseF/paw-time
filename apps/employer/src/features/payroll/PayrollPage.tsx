"use client";

import { addMonths, monthClose, monthOf } from "@paw-time/shop-console";
import type { MonthPayroll, PayKind } from "@paw-time/shop-console";
import Link from "next/link";
import { useState } from "react";
import { Icon } from "../../components/Icon";
import { Empty, PageHead, Panel, SampleBadge, Status } from "../../components/ui";
import type { Tone } from "../../components/ui";
import { useConsole } from "../../lib/console";
import { fmtDate, fmtMonth, fmtRange, fmtTime, instantTime } from "../../lib/format";
import { attendanceCsv, downloadCsv } from "../attendance/exportCsv";
import { PayrollChart } from "./PayrollChart";

const KIND_TONE: Record<PayKind, Tone> = { confirmed: "good", awaiting: "warn", forecast: "neutral" };

export function PayrollPage() {
  const { store, t, locale, money, toast, version } = useConsole();
  void version;
  const today = store.today();
  const [offset, setOffset] = useState(0);
  const month = addMonths(monthOf(today), offset);
  const payroll = store.monthPayroll(month);
  const label = fmtMonth(month, locale);
  const p = t.payroll;
  const exportCsv = () => {
    downloadCsv(attendanceCsv(store, month, t), t.shifts.csv.filename(month));
    toast(t.shifts.exported);
  };

  return (
    <>
      <PageHead
        title={p.title}
        desc={p.desc}
        actions={
          <div className="row">
            <button type="button" className="icon-btn" aria-label={p.prevMonth} onClick={() => setOffset((o) => o - 1)}><Icon name="chevronLeft" /></button>
            <button type="button" className="btn" onClick={() => setOffset(0)} aria-pressed={offset === 0}>{p.thisMonth}</button>
            <button type="button" className="icon-btn" aria-label={p.nextMonth} onClick={() => setOffset((o) => o + 1)}><Icon name="chevronRight" /></button>
            <button type="button" className="btn" onClick={exportCsv}><Icon name="download" />{p.exportCsv}</button>
          </div>
        }
      />
      <div className="stack">
        <section className="kpis k4" aria-label={`${p.total} · ${label}`}>
          <div className="kpi">
            <div className="kpi-k">{p.total} · {label}</div>
            <div className="kpi-v">{money(payroll.totals.all)}</div>
            <div className="kpi-n"><SampleBadge label={t.sample} /></div>
          </div>
          {(["confirmed", "awaiting", "forecast"] as const).map((k) => (
            <div className="kpi" key={k}>
              <div className="kpi-k">{p[k]}</div>
              <div className="kpi-v">{money(payroll.totals[k])}<small>{p.shifts(payroll.counts[k])}</small></div>
              <div className="kpi-n">{p[`${k}Hint`]}</div>
            </div>
          ))}
        </section>

        {payroll.lines.length === 0 ? (
          <Panel title={label}><Empty icon="chart" title={p.empty} /></Panel>
        ) : (
          <>
            <Panel title={p.byDay} sub={p.byDayHint}>
              <div className="panel-b">
                <PayrollChart days={payroll.days} t={t} money={(v) => money(v)} />
              </div>
            </Panel>
            <PayLines payroll={payroll} />
          </>
        )}

        <div className="layout-2 pay-bottom">
          <MonthClosePanel payroll={payroll} today={today} label={label} />
          <Panel title={p.breakRule}>
            <div className="panel-b stack-sm">
              <div className="note"><Icon name="shield" />{p.breakRuleBody}</div>
              <ul className="rule-list">
                <li><span className="n">6h</span><span>{p.rule6}</span></li>
                <li><span className="n">8h</span><span>{p.rule8}</span></li>
              </ul>
            </div>
          </Panel>
        </div>
      </div>
    </>
  );
}

function PayLines({ payroll }: { payroll: MonthPayroll }) {
  const { t, locale, money, store } = useConsole();
  const p = t.payroll;
  const kind = (k: PayKind) => <Status tone={KIND_TONE[k]}>{p[k]}</Status>;
  const onSite = (l: MonthPayroll["lines"][number]) =>
    l.checkInAt && l.checkOutAt
      ? `${instantTime(l.checkInAt, store.timeZone, locale)} – ${instantTime(l.checkOutAt, store.timeZone, locale)}`
      : l.checkInAt
        ? `${instantTime(l.checkInAt, store.timeZone, locale)} – (${fmtTime(l.end, locale)})`
        : fmtRange(l.start, l.end, locale);
  return (
    <Panel title={p.lines} sub={p.linesHint}>
      <div className="table-wrap collapse">
        <table className="dt">
          <thead>
            <tr>
              <th>{p.colDate}</th><th>{p.colWorker}</th><th>{p.colJob}</th><th>{p.colTime}</th>
              <th className="num">{p.colBreak}</th><th className="num">{p.colPaid}</th><th className="num">{p.colWage}</th><th className="num">{p.colAmount}</th><th>{p.colKind}</th>
            </tr>
          </thead>
          <tbody>
            {payroll.lines.map((l) => (
              <tr key={l.shiftId}>
                <td className="nowrap">{fmtDate(l.date, locale)}</td>
                <td className="nowrap">{l.displayName}</td>
                <td>{l.jobTitle}</td>
                <td className="time-cell">{onSite(l)}{l.corrected ? <span className="chip tmpl" style={{ marginLeft: 6 }}>{p.correctedMark}</span> : null}</td>
                <td className="num">{p.min(l.breakMinutes)}</td>
                <td className="num nowrap">{p.hours(l.paidMinutes)}</td>
                <td className="num nowrap">{money(l.wage, true)}</td>
                <td className="num"><strong style={{ fontWeight: 600 }}>{money(l.amount)}</strong></td>
                <td>{kind(l.kind)}</td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr>
              <td colSpan={7}><strong style={{ fontWeight: 600 }}>{p.total}</strong></td>
              <td className="num"><strong style={{ fontWeight: 600 }}>{money(payroll.totals.all)}</strong></td>
              <td />
            </tr>
          </tfoot>
        </table>
      </div>
      <div className="cards">
        {payroll.lines.map((l) => (
          <div className="card-row" key={l.shiftId}>
            <div className="row"><strong>{l.displayName}</strong><span className="spacer" /><strong>{money(l.amount)}</strong></div>
            <div className="small muted">{fmtDate(l.date, locale)} · {l.jobTitle}</div>
            <div className="small">{onSite(l)} · {p.colBreak} {p.min(l.breakMinutes)} · {p.colPaid} {p.hours(l.paidMinutes)}</div>
            <div className="row">{kind(l.kind)}{l.corrected ? <span className="chip tmpl">{p.correctedMark}</span> : null}</div>
          </div>
        ))}
      </div>
    </Panel>
  );
}

function MonthClosePanel({ payroll, today, label }: { payroll: MonthPayroll; today: string; label: string }) {
  const { t } = useConsole();
  const p = t.payroll;
  const close = monthClose(payroll, today);
  const item = (ok: boolean, text: string) => (
    <li className="close-item"><Icon name={ok ? "check" : "alert"} className={ok ? "ok" : "todo"} /><span>{text}</span></li>
  );
  return (
    <Panel title={p.close} sub={p.closeDesc(label)} actions={<Status tone={close.ready ? "good" : "warn"}>{close.ready ? p.closeReady : p.closeNotYet}</Status>}>
      <div className="panel-b stack-sm">
        <ul className="close-list">
          {item(close.monthEnded, close.monthEnded ? p.closeMonthEnded : p.closeMonthOpen)}
          {item(close.missingPunches === 0, p.closeMissing(close.missingPunches))}
          {item(close.upcoming === 0, p.closeUpcoming(close.upcoming))}
          {close.corrected > 0 ? item(true, p.closeCorrected(close.corrected)) : null}
          {payroll.noShows > 0 ? item(true, p.closeNoShows(payroll.noShows)) : null}
        </ul>
        {close.missingPunches > 0 ? <Link className="btn sm" href="/attendance" style={{ justifySelf: "start" }}>{p.openShifts}<Icon name="arrowRight" /></Link> : null}
      </div>
    </Panel>
  );
}
