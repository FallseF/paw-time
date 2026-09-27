"use client";

import type { ApplicantView, JobView, SkillBadge } from "@paw-time/shop-console";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { Cat } from "../../components/Cat";
import { Icon } from "../../components/Icon";
import { Dialog, Empty, PageHead, Panel, Progress, Segmented, Status } from "../../components/ui";
import type { Tone } from "../../components/ui";
import { useConsole } from "../../lib/console";
import type { Dict } from "../../lib/i18n";
import { fmtAgo, fmtDate, fmtRange } from "../../lib/format";

type StatusFilter = "applied" | "accepted" | "declined";
const TONE: Record<string, Tone> = { applied: "info", accepted: "good", declined: "neutral", withdrawn: "neutral" };

export function Badge({ b, t }: { b: SkillBadge; t: Dict }) {
  return (
    <span className="chip">
      {t.roles[b.role]} <span className="star" aria-label={`${b.level}`}>{"★".repeat(b.level)}</span> · {b.shifts}
      <span className="sr">{t.applicants.skills}</span>
    </span>
  );
}

export function SharedInfo({ a, t }: { a: ApplicantView; t: Dict }) {
  return (
    <div className="shared">
      <span className="k">{t.applicants.skills}</span>
      {a.shared.badges ? a.shared.badges.map((b) => <Badge key={b.role} b={b} t={t} />) : <span className="chip muted">{t.common.notShared}</span>}
      <span className="k" style={{ marginLeft: 8 }}>{t.applicants.onTime}</span>
      {a.shared.onTime ? <span className="chip">{t.applicants.onTimeValue(a.shared.onTime.onTime, a.shared.onTime.total)}</span> : <span className="chip muted">{t.common.notShared}</span>}
    </div>
  );
}

export function ApplicantsPage() {
  const { store, t, locale, run, version } = useConsole();
  void version;
  const params = useSearchParams();
  const router = useRouter();
  const [jobId, setJobId] = useState<string>("");
  const [status, setStatus] = useState<StatusFilter>("applied");
  const [view, setView] = useState<"cards" | "table">("cards");
  const [declining, setDeclining] = useState<ApplicantView | null>(null);

  useEffect(() => setJobId(params.get("job") ?? ""), [params]);

  const now = store.now();
  const jobs = store.jobs().filter((j) => j.status !== "draft" || j.applied > 0);
  const all = store.applicants();
  const inJob = all.filter((a) => !jobId || a.jobId === jobId);
  const counts: Record<StatusFilter, number> = {
    applied: inJob.filter((a) => a.status === "applied").length,
    accepted: inJob.filter((a) => a.status === "accepted").length,
    declined: inJob.filter((a) => a.status === "declined").length,
  };
  const shown = inJob.filter((a) => a.status === status);

  const slotOf = (a: ApplicantView) => store.job(a.jobId)?.slots.find((s) => s.id === a.slotId);
  const jobOf = (a: ApplicantView) => store.job(a.jobId);
  const groups = new Map<string, { job: JobView; slotId: string; list: ApplicantView[] }>();
  for (const a of shown) {
    const job = jobOf(a);
    if (!job) continue;
    const g = groups.get(a.slotId) ?? { job, slotId: a.slotId, list: [] };
    g.list.push(a);
    groups.set(a.slotId, g);
  }
  const ordered = [...groups.values()].sort((x, y) => {
    const a = x.job.slots.find((s) => s.id === x.slotId);
    const b = y.job.slots.find((s) => s.id === y.slotId);
    return `${a?.date}${a?.start}`.localeCompare(`${b?.date}${b?.start}`);
  });

  const accept = (a: ApplicantView) => run((s) => s.decide(a.applicationId, "accepted"), () => t.applicants.accepted(a.displayName));
  const message = (a: ApplicantView) => {
    const res = run((s) => s.openThread(a.workerId));
    if (res.ok) router.push(`/chat?thread=${res.data.id}`);
  };

  const actions = (a: ApplicantView) => (
    <div className="acts">
      {a.status === "applied" ? (
        <>
          <button type="button" className="btn sm" onClick={() => setDeclining(a)}>{t.applicants.decline}</button>
          <button type="button" className="btn sm primary" onClick={() => accept(a)}><Icon name="check" />{t.applicants.accept}</button>
        </>
      ) : (
        <Status tone={TONE[a.status] ?? "neutral"}>{t.applicants.status[a.status]}</Status>
      )}
      {a.canMessage ? (
        <button type="button" className="btn sm" onClick={() => message(a)}><Icon name="chat" />{t.applicants.message}</button>
      ) : (
        <button type="button" className="btn sm" aria-disabled="true" title={t.applicants.messageLocked} onClick={(e) => e.preventDefault()}>
          <Icon name="lock" />{t.applicants.message}
          <span className="sr">{t.applicants.messageLocked}</span>
        </button>
      )}
    </div>
  );

  const card = (a: ApplicantView) => (
    <article className="applicant" key={a.applicationId}>
      <Cat color={a.cat.color} size={40} />
      <div style={{ minWidth: 0 }}>
        <div className="name">
          <strong>{a.displayName}</strong>
          <span className="muted small">{a.cat.name}</span>
          <Status tone={a.firstTimeHere ? "info" : "neutral"} plain>{a.firstTimeHere ? t.applicants.firstTime : t.applicants.workedBefore}</Status>
        </div>
        <div className="meta">{t.applicants.applied(fmtAgo(a.appliedAt, now, t))}</div>
        <SharedInfo a={a} t={t} />
        {a.note ? <blockquote>{a.note}</blockquote> : null}
      </div>
      {actions(a)}
    </article>
  );

  return (
    <>
      <PageHead title={t.applicants.title} desc={t.applicants.desc} />
      <div className="app-layout">
        <Panel title={t.nav.jobs}>
          <ul className="job-pick">
            <li>
              <button type="button" aria-pressed={!jobId} onClick={() => router.replace("/applications")}>
                <span className="t">{t.applicants.allJobs}</span>
                <span className="count-pill">{all.filter((a) => a.status === "applied").length}</span>
              </button>
            </li>
            {jobs.map((j) => (
              <li key={j.id}>
                <button type="button" aria-pressed={jobId === j.id} onClick={() => router.replace(`/applications?job=${j.id}`)}>
                  <span className="t">{j.title}</span>
                  {j.applied ? <span className="count-pill">{j.applied}</span> : <span />}
                  <span className="s">{t.jobStatus[j.status]} · {t.applicants.filled(j.accepted, j.capacity)}</span>
                </button>
              </li>
            ))}
          </ul>
        </Panel>
        <div className="stack" style={{ minWidth: 0 }}>
          <div className="row wrap">
            <Segmented<StatusFilter>
              label={t.applicants.colStatus}
              value={status}
              onChange={setStatus}
              options={(["applied", "accepted", "declined"] as const).map((s) => ({ value: s, label: t.applicants.filters[s], count: counts[s] }))}
            />
            <span className="spacer" />
            <Segmented<"cards" | "table">
              label={t.applicants.cards}
              value={view}
              onChange={setView}
              options={[{ value: "cards", label: <><IconInline name="grid" />{t.applicants.cards}</> }, { value: "table", label: <><IconInline name="list" />{t.applicants.table}</> }]}
            />
          </div>
          <div className="note"><Icon name="shield" />{t.applicants.privacy}</div>
          {shown.length === 0 ? (
            <Panel><Empty icon="users" title={t.applicants.empty} body={t.applicants.emptyBody} /></Panel>
          ) : view === "cards" ? (
            ordered.map((g) => {
              const slot = g.job.slots.find((s) => s.id === g.slotId);
              return (
                <section className="panel slot-group" key={g.slotId}>
                  <div className="slot-head">
                    <div>
                      <h3>{slot ? `${fmtDate(slot.date, locale)} · ${fmtRange(slot.start, slot.end, locale)}` : ""}</h3>
                      <div className="small muted">{g.job.title}</div>
                    </div>
                    {slot ? <Progress value={slot.accepted} max={slot.capacity} label={t.applicants.filled(slot.accepted, slot.capacity)} tone={slot.open === 0 ? "good" : undefined} /> : null}
                  </div>
                  {g.list.map(card)}
                </section>
              );
            })
          ) : (
            <Panel>
              <div className="table-wrap">
                <table className="dt">
                  <thead><tr><th>{t.applicants.colWorker}</th><th>{t.applicants.colSlot}</th><th>{t.applicants.colShared}</th><th><span className="sr">{t.common.more}</span></th></tr></thead>
                  <tbody>
                    {shown.map((a) => {
                      const slot = slotOf(a);
                      return (
                        <tr key={a.applicationId}>
                          <td><div className="who"><Cat color={a.cat.color} size={28} /><div><strong>{a.displayName}</strong><small>{a.firstTimeHere ? t.applicants.firstTime : t.applicants.workedBefore} · {fmtAgo(a.appliedAt, now, t)}</small></div></div></td>
                          <td className="nowrap">{slot ? `${fmtDate(slot.date, locale)} ${fmtRange(slot.start, slot.end, locale)}` : ""}<div className="small muted">{jobOf(a)?.title}</div></td>
                          <td style={{ minWidth: 280 }}><SharedInfo a={a} t={t} /></td>
                          <td>{actions(a)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </Panel>
          )}
        </div>
      </div>
      <Dialog
        open={!!declining}
        onClose={() => setDeclining(null)}
        title={declining ? t.applicants.declineTitle(declining.displayName) : ""}
        closeLabel={t.common.close}
        footer={
          <>
            <button type="button" className="btn" onClick={() => setDeclining(null)}>{t.common.cancel}</button>
            <button type="button" className="btn danger solid" onClick={() => {
              if (declining) run((s) => s.decide(declining.applicationId, "declined"), t.applicants.declined(declining.displayName));
              setDeclining(null);
            }}>{t.applicants.decline}</button>
          </>
        }
      >
        <p className="desc" style={{ marginTop: 0 }}>{t.applicants.declineBody}</p>
      </Dialog>
    </>
  );
}

function IconInline({ name }: { name: "grid" | "list" }) {
  return <Icon name={name} width={14} height={14} />;
}
