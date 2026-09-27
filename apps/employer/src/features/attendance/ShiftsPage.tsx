"use client";

import { addDays, monthOf, weekStart } from "@paw-time/shop-console";
import type { AttendanceLogEntry, ShiftView } from "@paw-time/shop-console";
import Link from "next/link";
import { useState } from "react";
import { Cat } from "../../components/Cat";
import { Icon } from "../../components/Icon";
import { Empty, Field, PageHead, Panel, Segmented, Sheet } from "../../components/ui";
import { useConsole } from "../../lib/console";
import { fmtDate, fmtInstant, fmtMonth, fmtRange, fmtWeekday, instantTime } from "../../lib/format";
import { ArrivalPill, arrivalText, arrivalTone } from "./arrival";
import { attendanceCsv, downloadCsv } from "./exportCsv";

export function ShiftsPage() {
  const { store, t, locale, timeZone, version, toast } = useConsole();
  void version;
  const today = store.today();
  const [offset, setOffset] = useState(0);
  const [openId, setOpenId] = useState<string | null>(null);
  const start = addDays(weekStart(today), offset * 7);
  const end = addDays(start, 6);
  const days = Array.from({ length: 7 }, (_, i) => addDays(start, i));
  const shifts = store.shifts(start, end);
  const now = store.now();
  const openByDay = new Map<string, Array<{ title: string; start: string; end: string; open: number }>>();
  for (const job of store.jobs()) {
    if (job.status !== "published") continue;
    for (const s of job.slots) {
      if (s.open > 0 && s.date >= start && s.date <= end && s.date >= today) {
        const list = openByDay.get(s.date) ?? [];
        list.push({ title: job.title, start: s.start, end: s.end, open: s.open });
        openByDay.set(s.date, list);
      }
    }
  }
  const log = store.attendanceLog().filter((e) => (e.kind === "correction" || e.kind === "no_show") && e.date >= start && e.date <= end);
  // The month of the week on screen: this month for this week, otherwise the month the week starts in.
  const month = monthOf(offset === 0 ? today : start);
  const exportCsv = () => {
    downloadCsv(attendanceCsv(store, month, t), t.shifts.csv.filename(month));
    toast(t.shifts.exported);
  };
  const rangeLabel = `${fmtDate(start, locale, { weekday: false })} – ${fmtDate(end, locale, { weekday: false })}`;

  return (
    <>
      <PageHead
        title={t.shifts.title}
        desc={t.shifts.desc}
        actions={
          <div className="row">
            <button type="button" className="icon-btn" aria-label={t.shifts.prevWeek} onClick={() => setOffset((o) => o - 1)}><Icon name="chevronLeft" /></button>
            <button type="button" className="btn" onClick={() => setOffset(0)} aria-pressed={offset === 0}>{t.shifts.thisWeek}</button>
            <button type="button" className="icon-btn" aria-label={t.shifts.nextWeek} onClick={() => setOffset((o) => o + 1)}><Icon name="chevronRight" /></button>
            <button type="button" className="btn" onClick={exportCsv}><Icon name="download" />{t.shifts.exportCsv(fmtMonth(month, locale))}</button>
          </div>
        }
      />
      <div className="stack">
        <Panel title={rangeLabel} sub={t.shifts.count(shifts.length)}>
          <div className="week">
            {days.map((d) => {
              const list = shifts.filter((s) => s.date === d);
              const open = openByDay.get(d) ?? [];
              return (
                <div className={`day${d === today ? " today" : ""}`} key={d}>
                  <div className="day-h">
                    <span className="wd">{fmtWeekday(d, locale)}</span>
                    <span className="dn">{Number(d.slice(8))}</span>
                  </div>
                  <div className="day-b">
                    {list.length === 0 && open.length === 0 ? <span className="small muted">{t.shifts.noShifts}</span> : null}
                    {list.map((s) => (
                      <button type="button" key={s.id} className={`shift-card s-${arrivalTone(s, now)}`} onClick={() => setOpenId(s.id)}>
                        <span className="tm">{fmtRange(s.start, s.end, locale)}</span>
                        <span className="nm"><Cat color={s.cat.color} size={18} /><span>{s.displayName}</span></span>
                        <span className="stt muted">{t.roles[s.role]} · {arrivalText(s, t, timeZone, locale)}</span>
                      </button>
                    ))}
                    {open.map((o, i) => (
                      <div className="open-card" key={i}>
                        <div>{fmtRange(o.start, o.end, locale)}</div>
                        <div>{t.shifts.open(o.open)} · {o.title}</div>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </Panel>

        <Panel title={t.shifts.log} sub={t.shifts.logDesc}>
          {log.length === 0 ? (
            <Empty icon="list" title={t.shifts.logEmpty} />
          ) : (
            <>
              <div className="table-wrap collapse">
                <table className="dt">
                  <thead><tr><th>{t.shifts.colWhen}</th><th>{t.shifts.colShift}</th><th>{t.shifts.colChange}</th><th>{t.shifts.colReason}</th><th>{t.shifts.colBy}</th></tr></thead>
                  <tbody>
                    {log.map((e) => (
                      <tr key={e.id} className="clickable" tabIndex={0} onClick={() => setOpenId(e.shiftId)} onKeyDown={(k) => { if (k.key === "Enter") setOpenId(e.shiftId); }}>
                        <td className="nowrap">{fmtInstant(e.recordedAt, timeZone, locale, today, t)}</td>
                        <td className="nowrap"><strong style={{ fontWeight: 500 }}>{e.displayName}</strong><div className="small muted">{fmtDate(e.date, locale)}</div></td>
                        <td><Change e={e} /></td>
                        <td>{e.reason}</td>
                        <td className="nowrap">{e.by}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="cards">
                {log.map((e) => (
                  <div className="card-row" key={e.id}>
                    <div className="row"><strong>{e.displayName}</strong><span className="spacer" /><span className="small muted">{fmtInstant(e.recordedAt, timeZone, locale, today, t)}</span></div>
                    <Change e={e} />
                    <div className="small">{e.reason}</div>
                    <div className="small muted">{e.by}</div>
                  </div>
                ))}
              </div>
            </>
          )}
        </Panel>
      </div>
      <ShiftSheet id={openId} onClose={() => setOpenId(null)} />
    </>
  );
}

function Change({ e }: { e: AttendanceLogEntry }) {
  const { t, timeZone, locale } = useConsole();
  const time = (iso: string | null | undefined) => (iso ? instantTime(iso, timeZone, locale) : "—");
  if (e.kind === "no_show") return <span className="status st-bad">{t.shifts.noShow}</span>;
  return (
    <span className="nowrap">
      {e.field === "check_in" ? t.shifts.changeIn : t.shifts.changeOut}{" "}
      <span className="strike">{time(e.previous)}</span> → <strong style={{ fontWeight: 600 }}>{time(e.at)}</strong>
    </span>
  );
}

function ShiftSheet({ id, onClose }: { id: string | null; onClose: () => void }) {
  const { store, t, locale, timeZone, run, staffName } = useConsole();
  const [mode, setMode] = useState<"none" | "correct" | "noshow">("none");
  const [field, setField] = useState<"check_in" | "check_out">("check_out");
  const [time, setTime] = useState("");
  const [reason, setReason] = useState("");
  const [tried, setTried] = useState(false);
  const s: ShiftView | null = id ? store.shift(id) : null;
  const close = () => { setMode("none"); setReason(""); setTime(""); setTried(false); onClose(); };
  if (!s) return null;
  const now = store.now();
  const today = store.today();
  const started = now.toISOString() >= s.startAt;
  const events = store.attendanceLog(s.id).slice().reverse();
  const tm = (iso: string | null) => (iso ? instantTime(iso, timeZone, locale) : t.shifts.notRecorded);

  const submit = () => {
    setTried(true);
    if (!reason.trim()) return;
    const res = mode === "correct"
      ? run((st) => st.correct(s.id, field, time, reason, staffName), t.shifts.corrected)
      : run((st) => st.markNoShow(s.id, reason, staffName), t.shifts.markedNoShow);
    if (res.ok) { setMode("none"); setReason(""); setTried(false); }
  };

  return (
    <Sheet
      open={!!s}
      onClose={close}
      closeLabel={t.common.close}
      kicker={`${fmtDate(s.date, locale, { long: true })} · ${t.roles[s.role]}`}
      title={<span className="row"><Cat color={s.cat.color} size={28} />{s.displayName}</span>}
      footer={mode !== "none" ? (
        <>
          <button type="button" className="btn" onClick={() => { setMode("none"); setTried(false); }}>{t.common.cancel}</button>
          <button type="button" className={`btn ${mode === "noshow" ? "danger solid" : "primary"}`} onClick={submit}>{mode === "noshow" ? t.shifts.markNoShow : t.shifts.saveCorrection}</button>
        </>
      ) : undefined}
    >
      <div className="stack">
        <div className="row wrap">
          <ArrivalPill shift={s} t={t} timeZone={timeZone} locale={locale} now={now} />
          <span className="small muted">{s.jobTitle}</span>
          <span className="spacer" />
          {s.threadId ? <Link className="btn sm" href={`/chat?thread=${s.threadId}`}><Icon name="chat" />{t.applicants.message}</Link> : null}
        </div>
        <dl className="kv">
          <div><dt>{t.shifts.scheduled}</dt><dd>{fmtRange(s.start, s.end, locale)}</dd></div>
          <div><dt>{t.today.arrival}</dt><dd>{s.minutesLate ? t.today.lateBy(s.minutesLate) : s.checkInAt ? "✓" : "—"}</dd></div>
          <div><dt>{t.shifts.changeIn}</dt><dd>{tm(s.checkInAt)}</dd></div>
          <div><dt>{t.shifts.changeOut}</dt><dd>{tm(s.checkOutAt)}</dd></div>
        </dl>

        {mode === "none" ? (
          <div className="row wrap">
            {!s.checkInAt && s.status !== "no_show" ? <button type="button" className="btn primary" onClick={() => run((st) => st.recordAttendance(s.id, "check_in", staffName), t.shifts.checkedIn)}>{t.shifts.checkIn}</button> : null}
            {s.checkInAt && !s.checkOutAt ? <button type="button" className="btn primary" onClick={() => run((st) => st.recordAttendance(s.id, "check_out", staffName), t.shifts.checkedOut)}>{t.shifts.checkOut}</button> : null}
            <button type="button" className="btn" onClick={() => { setMode("correct"); setField(s.checkOutAt || s.checkInAt ? "check_out" : "check_in"); setTime(s.checkOutAt ? tmRaw(s.checkOutAt, store) : s.end); }}><Icon name="edit" />{t.shifts.correct}</button>
            {!s.checkInAt && s.status !== "no_show" ? (
              <button type="button" className="btn danger" disabled={!started} title={started ? undefined : t.errors.not_started} onClick={() => setMode("noshow")}>{t.shifts.markNoShow}</button>
            ) : null}
          </div>
        ) : (
          <div className="panel" style={{ padding: 16 }}>
            <div className="stack">
              {mode === "correct" ? (
                <div className="grid-2">
                  <div className="field">
                    <span className="label">{t.shifts.field}</span>
                    <Segmented<"check_in" | "check_out"> label={t.shifts.field} value={field} onChange={(f) => { setField(f); setTime(f === "check_in" ? (s.checkInAt ? tmRaw(s.checkInAt, store) : s.start) : (s.checkOutAt ? tmRaw(s.checkOutAt, store) : s.end)); }} options={[{ value: "check_in", label: t.shifts.changeIn }, { value: "check_out", label: t.shifts.changeOut }]} />
                  </div>
                  <Field label={t.shifts.newTime} htmlFor="c-time">
                    <input id="c-time" className="input" type="time" value={time} onChange={(e) => setTime(e.target.value)} />
                  </Field>
                </div>
              ) : (
                <div className="note"><Icon name="shield" />{t.shifts.noShowNote}</div>
              )}
              <Field label={t.shifts.reason} htmlFor="c-reason" error={tried && !reason.trim() ? t.errors.reason_required : undefined}>
                <input id="c-reason" data-autofocus className="input" value={reason} maxLength={200} placeholder={mode === "noshow" ? t.shifts.noShowReasonPh : t.shifts.reasonPh} onChange={(e) => setReason(e.target.value)} aria-invalid={tried && !reason.trim()} />
              </Field>
            </div>
          </div>
        )}

        <section>
          <h3 style={{ fontSize: 13, fontWeight: 600, marginBottom: 12 }}>{t.shifts.history}</h3>
          {events.length === 0 ? <p className="small muted">{t.shifts.notRecorded}</p> : (
            <ol className="timeline">
              {events.map((e) => (
                <li key={e.id}>
                  <span className={`dot ${e.kind === "no_show" ? "bad" : e.kind === "correction" ? "info" : "good"}`} />
                  <div>
                    <div className="t">
                      {e.kind === "correction"
                        ? t.shifts.ev.correction(e.field === "check_in" ? t.shifts.changeIn : t.shifts.changeOut, e.previous ? instantTime(e.previous, timeZone, locale) : "—", instantTime(e.at, timeZone, locale))
                        : e.kind === "running_late"
                          ? t.shifts.ev.running_late(e.minutesLate ?? 0)
                          : t.shifts.ev[e.kind]}
                      {e.kind !== "correction" ? ` · ${instantTime(e.at, timeZone, locale)}` : ""}
                    </div>
                    <div className="s">
                      {e.source === "worker" ? t.shifts.byWorker : t.shifts.by(e.by)} · {fmtInstant(e.recordedAt, timeZone, locale, today, t)}
                      {e.reason ? ` · ${e.reason}` : ""}
                    </div>
                  </div>
                </li>
              ))}
            </ol>
          )}
        </section>
      </div>
    </Sheet>
  );
}

function tmRaw(iso: string, store: { timeZone: string }): string {
  const d = new Date(iso);
  const f = new Intl.DateTimeFormat("en-GB", { timeZone: store.timeZone, hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
  return f.format(d);
}
