"use client";

import { addDays, validateJob } from "@paw-time/shop-console";
import type { FieldError, JobInput, JobStatus, PayStyle, Role } from "@paw-time/shop-console";
import { useEffect, useState } from "react";
import { Icon } from "../../components/Icon";
import { Field, Sheet } from "../../components/ui";
import { useConsole } from "../../lib/console";
import { WageCheck } from "./WageCheck";

const ROLES: Role[] = ["register", "barista", "hall", "kitchen", "dish", "stock"];
const PAY: PayStyle[] = ["same_day", "weekly", "monthly"];

type SlotDraft = { id?: string | undefined; date: string; start: string; end: string; capacity: number };
type Draft = { title: string; role: Role; wage: string; payStyle: PayStyle; dressCode: string; notes: string; slots: SlotDraft[] };

export function JobEditor({ open, jobId, onClose }: { open: boolean; jobId: string | null; onClose: () => void }) {
  const { store, t, run, currency } = useConsole();
  const existing = jobId ? store.job(jobId) : null;
  const [draft, setDraft] = useState<Draft | null>(null);
  const [tried, setTried] = useState(false);
  const [serverErrors, setServerErrors] = useState<FieldError[]>([]);

  useEffect(() => {
    if (!open) return;
    setTried(false);
    setServerErrors([]);
    const job = jobId ? store.job(jobId) : null;
    if (job) {
      setDraft({
        title: job.title,
        role: job.role,
        wage: currency === "USD" ? job.wage.toFixed(2) : String(job.wage),
        payStyle: job.payStyle,
        dressCode: job.dressCode,
        notes: job.notes,
        slots: job.slots.map((s) => ({ id: s.id, date: s.date, start: s.start, end: s.end, capacity: s.capacity })),
      });
    } else {
      setDraft({
        title: "",
        role: "register",
        wage: currency === "USD" ? "22.00" : "1300",
        payStyle: "weekly",
        dressCode: store.faq().dressCode,
        notes: "",
        slots: [{ date: addDays(store.today(), 3), start: "17:00", end: "21:00", capacity: 2 }],
      });
    }
  }, [open, jobId, store, currency]);

  if (!open || !draft) return null;

  const input = (status: JobStatus): JobInput => ({
    ...(jobId ? { id: jobId } : {}),
    title: draft.title,
    role: draft.role,
    status,
    wage: Number(draft.wage),
    payStyle: draft.payStyle,
    dressCode: draft.dressCode,
    notes: draft.notes,
    slots: draft.slots,
  });
  const liveErrors = tried ? [...validateJob(input("draft"), store.region), ...serverErrors] : [];
  const err = (field: string) => {
    const e = liveErrors.find((x) => x.field === field);
    if (!e) return undefined;
    if (e.code === "required") return t.editor.required;
    if (e.code === "before_start") return t.editor.beforeStart;
    if (e.code === "has_accepted") return t.editor.hasAccepted;
    if (e.code === "below_minimum") return undefined; // WageCheck explains it
    return t.editor.invalid;
  };
  const set = (patch: Partial<Draft>) => setDraft({ ...draft, ...patch });
  const setSlot = (i: number, patch: Partial<SlotDraft>) => set({ slots: draft.slots.map((s, k) => (k === i ? { ...s, ...patch } : s)) });

  const save = (status: JobStatus) => {
    setTried(true);
    const res = run(
      (s) => s.saveJob(input(status)),
      status === "published" ? t.jobs.published : status === "draft" ? t.jobs.savedDraft : t.common.saved,
    );
    if (res.ok) onClose();
    else setServerErrors(res.errors ?? []);
  };

  const status = existing?.status ?? "draft";
  return (
    <Sheet
      open={open}
      onClose={onClose}
      closeLabel={t.common.close}
      kicker={existing ? t.jobStatus[existing.status] : undefined}
      title={existing ? t.editor.editTitle : t.editor.newTitle}
      footer={
        <>
          <button type="button" className="btn" onClick={onClose}>{t.common.cancel}</button>
          {existing && status !== "draft" ? (
            <button type="button" className="btn primary" onClick={() => save(status)}>{t.editor.saveChanges}</button>
          ) : (
            <>
              <button type="button" className="btn" onClick={() => save("draft")}>{t.editor.saveDraft}</button>
              <button type="button" className="btn primary" onClick={() => save("published")}>{t.editor.publish}</button>
            </>
          )}
        </>
      }
    >
      <form className="stack" onSubmit={(e) => { e.preventDefault(); save(existing ? status : "published"); }} noValidate>
        <section className="form-sec">
          <h3>{t.editor.basics}</h3>
          <Field label={t.editor.jobTitle} htmlFor="j-title" error={err("title")}>
            <input id="j-title" data-autofocus className="input" value={draft.title} placeholder={t.editor.jobTitlePh} maxLength={80} aria-invalid={!!err("title")} onChange={(e) => set({ title: e.target.value })} />
          </Field>
          <Field label={t.editor.role} htmlFor="j-role">
            <select id="j-role" className="select" value={draft.role} onChange={(e) => set({ role: e.target.value as Role })}>
              {ROLES.map((r) => <option key={r} value={r}>{t.roles[r]}</option>)}
            </select>
          </Field>
        </section>

        <section className="form-sec">
          <h3>{t.editor.slots}</h3>
          {err("slots") ? <span className="field"><span className="err"><Icon name="alert" />{err("slots")}</span></span> : null}
          {draft.slots.map((s, i) => (
            <div className="slot-row" key={s.id ?? `n${i}`}>
              <Field className="f-date" label={t.editor.date} htmlFor={`s-date-${i}`} error={err(`slots.${i}.date`)}>
                <input id={`s-date-${i}`} className="input" type="date" value={s.date} onChange={(e) => setSlot(i, { date: e.target.value })} />
              </Field>
              <Field label={t.editor.start} htmlFor={`s-start-${i}`} error={err(`slots.${i}.start`)}>
                <input id={`s-start-${i}`} className="input" type="time" step={900} value={s.start} onChange={(e) => setSlot(i, { start: e.target.value })} />
              </Field>
              <Field label={t.editor.end} htmlFor={`s-end-${i}`} error={err(`slots.${i}.end`)}>
                <input id={`s-end-${i}`} className="input" type="time" step={900} value={s.end} onChange={(e) => setSlot(i, { end: e.target.value })} />
              </Field>
              <Field label={t.editor.people} htmlFor={`s-cap-${i}`} error={err(`slots.${i}.capacity`)}>
                <input id={`s-cap-${i}`} className="input" type="number" min={1} max={50} value={s.capacity} onChange={(e) => setSlot(i, { capacity: Math.round(Number(e.target.value)) })} />
              </Field>
              <button type="button" className="icon-btn" aria-label={t.editor.removeSlot} disabled={draft.slots.length === 1} onClick={() => set({ slots: draft.slots.filter((_, k) => k !== i) })}>
                <Icon name="trash" />
              </button>
            </div>
          ))}
          <div>
            <button type="button" className="btn sm" onClick={() => {
              const last = draft.slots.at(-1);
              set({ slots: [...draft.slots, { date: last ? addDays(last.date, 1) : store.today(), start: last?.start ?? "17:00", end: last?.end ?? "21:00", capacity: last?.capacity ?? 1 }] });
            }}>
              <Icon name="plus" />{t.editor.addSlot}
            </button>
          </div>
        </section>

        <section className="form-sec">
          <h3>{t.editor.pay}</h3>
          <div className="stack">
            <div className="field">
              <label htmlFor="j-wage">{t.editor.wage}</label>
              <div className="affix" aria-invalid={liveErrors.some((e) => e.field === "wage")}>
                <span>{currency === "USD" ? "$" : "¥"}</span>
                <input id="j-wage" inputMode="decimal" value={draft.wage} onChange={(e) => set({ wage: e.target.value.replace(/[^\d.]/g, "") })} />
                <span>{t.common.perHour}</span>
              </div>
              <WageCheck wage={Number(draft.wage)} dates={draft.slots.map((s) => s.date)} />
            </div>
            <div className="field">
              <span className="label">{t.editor.payStyle}</span>
              <div className="seg" role="group" aria-label={t.editor.payStyle}>
                {PAY.map((p) => <button type="button" key={p} aria-pressed={draft.payStyle === p} onClick={() => set({ payStyle: p })}>{t.pay[p]}</button>)}
              </div>
            </div>
          </div>
        </section>

        <section className="form-sec">
          <h3>{t.editor.details}</h3>
          <Field label={t.editor.dress} htmlFor="j-dress" hint={<span className="counter">{draft.dressCode.length}/200</span>} error={err("dressCode")}>
            <input id="j-dress" className="input" value={draft.dressCode} maxLength={200} placeholder={t.editor.dressPh} onChange={(e) => set({ dressCode: e.target.value })} />
          </Field>
          <Field label={t.editor.notes} htmlFor="j-notes" error={err("notes")}>
            <textarea id="j-notes" className="textarea" rows={4} value={draft.notes} maxLength={1000} placeholder={t.editor.notesPh} onChange={(e) => set({ notes: e.target.value })} />
          </Field>
        </section>
      </form>
    </Sheet>
  );
}
