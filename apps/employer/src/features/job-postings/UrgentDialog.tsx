"use client";

import { addDays } from "@paw-time/shop-console";
import type { Role, UrgentReach } from "@paw-time/shop-console";
import { useEffect, useState } from "react";
import { Icon } from "../../components/Icon";
import { Dialog, Field } from "../../components/ui";
import { useConsole } from "../../lib/console";
import { fmtCount, fmtDate, fmtRange } from "../../lib/format";
import { WageCheck } from "./WageCheck";

const ROLES: Role[] = ["register", "barista", "hall", "kitchen", "dish", "stock"];

export function UrgentDialog({ open, onClose, initial }: { open: boolean; onClose: () => void; initial?: { jobId: string; slotId: string } | null }) {
  const { store, t, locale, run, currency, version } = useConsole();
  void version;
  const today = store.today();
  const openSlots = store.todayView().openSlots;
  const [mode, setMode] = useState<"slot" | "new">("slot");
  const [pick, setPick] = useState<string>("");
  const [role, setRole] = useState<Role>("register");
  const [date, setDate] = useState(addDays(today, 1));
  const [start, setStart] = useState("17:00");
  const [end, setEnd] = useState("21:00");
  const [people, setPeople] = useState(1);
  const [wage, setWage] = useState(currency === "USD" ? "22.00" : "1300");

  useEffect(() => {
    if (!open) return;
    const slots = store.todayView().openSlots;
    const busiest = [...slots].sort((a, b) => b.slot.open - a.slot.open)[0];
    const first = initial ? `${initial.jobId}|${initial.slotId}` : busiest ? `${busiest.job.id}|${busiest.slot.id}` : "";
    setPick(first);
    setMode(first ? "slot" : "new");
    setWage(currency === "USD" ? "22.00" : "1300");
  }, [open, initial, store, currency]);

  const chosen = openSlots.find((o) => `${o.job.id}|${o.slot.id}` === pick);
  const target = mode === "slot" && chosen
    ? { role: chosen.job.role, date: chosen.slot.date, start: chosen.slot.start, end: chosen.slot.end }
    : { role, date, start, end };
  const validNew = /^\d{4}-\d{2}-\d{2}$/.test(date) && start < end;
  const reach: UrgentReach | null = mode === "slot" ? (chosen ? store.urgentReach(target.role, target) : null) : validNew ? store.urgentReach(role, target) : null;
  const wageNum = Number(wage);
  const wageOk = mode === "slot" || store.checkWage(wageNum, [date]).ok;

  const send = () => {
    const done = (r: UrgentReach) => (r.underCap === null ? t.urgent.sentFew : t.urgent.sent(fmtCount(r.underCap, t)));
    if (mode === "slot" && chosen) {
      const res = run((s) => s.sendUrgent(chosen.job.id, chosen.slot.id), (d) => done(d.reach));
      if (res.ok) onClose();
      return;
    }
    const res = run(
      (s) => s.postUrgentShift({ title: `${t.roles[role]} · ${t.jobs.urgent}`, role, status: "published", wage: wageNum, payStyle: "same_day", dressCode: s.faq().dressCode, notes: "", slots: [{ date, start, end, capacity: people }] }),
      (d) => done(d.reach),
    );
    if (res.ok) onClose();
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={t.urgent.title}
      closeLabel={t.common.close}
      wide
      footer={
        <>
          <button type="button" className="btn" onClick={onClose}>{t.common.cancel}</button>
          <button type="button" className="btn primary" onClick={send} disabled={!reach || !wageOk || (mode === "slot" && !chosen)}>
            <Icon name="bolt" />{t.urgent.send}
          </button>
        </>
      }
    >
      <div className="stack">
        <p className="desc" style={{ marginTop: 0 }}>{t.urgent.desc}</p>
        <div className="seg" role="group" aria-label={t.urgent.title}>
          <button type="button" aria-pressed={mode === "slot"} onClick={() => setMode("slot")}>{t.urgent.pickSlot}</button>
          <button type="button" aria-pressed={mode === "new"} onClick={() => setMode("new")}>{t.urgent.newSlot}</button>
        </div>
        {mode === "slot" ? (
          openSlots.length ? (
            <div className="stack-sm" role="radiogroup" aria-label={t.urgent.pickSlot}>
              {openSlots.map(({ job, slot }) => {
                const key = `${job.id}|${slot.id}`;
                return (
                  <label className="radio-card" key={key}>
                    <input type="radio" name="urgent-slot" checked={pick === key} onChange={() => setPick(key)} />
                    <span>
                      <span className="t">{fmtDate(slot.date, locale)} · {fmtRange(slot.start, slot.end, locale)}</span>
                      <span className="s" style={{ display: "block" }}>{job.title} · {t.today.spots(slot.open)}</span>
                    </span>
                  </label>
                );
              })}
            </div>
          ) : (
            <div className="note"><Icon name="info" />{t.urgent.noSlots}</div>
          )
        ) : (
          <div className="stack">
            <div className="grid-2">
              <Field label={t.editor.role} htmlFor="u-role">
                <select id="u-role" className="select" value={role} onChange={(e) => setRole(e.target.value as Role)}>
                  {ROLES.map((r) => <option key={r} value={r}>{t.roles[r]}</option>)}
                </select>
              </Field>
              <Field label={t.editor.date} htmlFor="u-date">
                <input id="u-date" className="input" type="date" value={date} min={today} onChange={(e) => setDate(e.target.value)} />
              </Field>
            </div>
            <div className="grid-3">
              <Field label={t.editor.start} htmlFor="u-start"><input id="u-start" className="input" type="time" value={start} onChange={(e) => setStart(e.target.value)} /></Field>
              <Field label={t.editor.end} htmlFor="u-end" error={start >= end ? t.editor.beforeStart : undefined}><input id="u-end" className="input" type="time" value={end} onChange={(e) => setEnd(e.target.value)} /></Field>
              <Field label={t.editor.people} htmlFor="u-people"><input id="u-people" className="input" type="number" min={1} max={20} value={people} onChange={(e) => setPeople(Math.max(1, Number(e.target.value) || 1))} /></Field>
            </div>
            <div className="field">
              <label htmlFor="u-wage">{t.editor.wage}</label>
              <div className="affix" aria-invalid={!wageOk}>
                <span>{currency === "USD" ? "$" : "¥"}</span>
                <input id="u-wage" inputMode="decimal" value={wage} onChange={(e) => setWage(e.target.value)} />
                <span>{t.common.perHour}</span>
              </div>
              <WageCheck wage={wageNum} dates={[date]} />
            </div>
          </div>
        )}
        <div className="funnel" aria-live="polite">
          <div className="step"><span>{t.urgent.free}<small>{t.urgent.freeSub}</small></span><strong>{reach ? fmtCount(reach.available, t) : "—"}</strong></div>
          <div className="step"><span>{t.urgent.skilled}<small>{t.urgent.skilledSub(t.roles[target.role])}</small></span><strong>{reach ? fmtCount(reach.skilled, t) : "—"}</strong></div>
          <div className="step"><span>{t.urgent.underCap}<small>{t.urgent.underCapSub}</small></span><strong>{reach ? fmtCount(reach.underCap, t) : "—"}</strong></div>
          <div className="step final"><span>{t.urgent.reach}<small>{t.urgent.names}</small></span><strong>{reach ? fmtCount(reach.underCap, t) : "—"}</strong></div>
        </div>
        <p className="small muted">{t.urgent.fewerNote}</p>
      </div>
    </Dialog>
  );
}
