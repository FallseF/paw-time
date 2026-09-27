"use client";

import type { JobStatus, JobView } from "@paw-time/shop-console";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { Icon } from "../../components/Icon";
import { Empty, Menu, PageHead, Panel, Progress, Search, Segmented, Status } from "../../components/ui";
import type { Tone } from "../../components/ui";
import { useConsole } from "../../lib/console";
import { fmtDate } from "../../lib/format";
import { JobEditor } from "./JobEditor";
import { UrgentDialog } from "./UrgentDialog";

type Filter = "all" | JobStatus;
const TONE: Record<JobStatus, Tone> = { published: "good", draft: "neutral", closed: "neutral" };

export function JobsPage() {
  const { store, t, locale, money, run, version } = useConsole();
  void version;
  const params = useSearchParams();
  const router = useRouter();
  const [filter, setFilter] = useState<Filter>("all");
  const [q, setQ] = useState("");
  const [editor, setEditor] = useState<{ open: boolean; jobId: string | null }>({ open: false, jobId: null });
  const [urgent, setUrgent] = useState<{ open: boolean; initial: { jobId: string; slotId: string } | null }>({ open: false, initial: null });

  useEffect(() => {
    if (params.get("new") === "1") setEditor({ open: true, jobId: null });
    const edit = params.get("edit");
    if (edit) setEditor({ open: true, jobId: edit });
    if (params.get("urgent") === "1") setUrgent({ open: true, initial: null });
  }, [params]);

  const closeEditor = () => {
    setEditor({ open: false, jobId: null });
    if (params.get("new") || params.get("edit")) router.replace("/jobs");
  };

  const jobs = store.jobs();
  const counts = { all: jobs.length, published: 0, draft: 0, closed: 0 } as Record<Filter, number>;
  for (const j of jobs) counts[j.status] += 1;
  const needle = q.trim().toLowerCase();
  const shown = jobs.filter((j) => (filter === "all" || j.status === filter) && (!needle || `${j.title} ${t.roles[j.role]}`.toLowerCase().includes(needle)));

  const dates = (j: JobView) => {
    if (!j.firstDate) return "—";
    const a = fmtDate(j.firstDate, locale, { weekday: false });
    const b = j.lastDate && j.lastDate !== j.firstDate ? fmtDate(j.lastDate, locale, { weekday: false }) : null;
    return b ? `${a} – ${b}` : a;
  };
  const nextOpen = (j: JobView) => {
    const today = store.today();
    return j.slots.find((s) => s.open > 0 && s.date >= today);
  };
  const actions = (j: JobView) => [
    { label: t.common.edit, icon: "edit" as const, onSelect: () => setEditor({ open: true, jobId: j.id }) },
    { label: t.jobs.viewApplicants, icon: "users" as const, onSelect: () => router.push(`/applications?job=${j.id}`) },
    { label: t.jobs.publish, icon: "check" as const, hidden: j.status === "published", onSelect: () => run((s) => s.setJobStatus(j.id, "published"), t.jobs.published) },
    { label: t.today.postUrgent, icon: "bolt" as const, hidden: j.status !== "published" || !nextOpen(j), onSelect: () => { const s = nextOpen(j); if (s) setUrgent({ open: true, initial: { jobId: j.id, slotId: s.id } }); } },
    { label: t.jobs.reopen, icon: "reset" as const, hidden: j.status !== "closed", onSelect: () => run((s) => s.setJobStatus(j.id, "draft"), t.jobs.savedDraft) },
    { label: t.jobs.close, icon: "x" as const, danger: true, hidden: j.status !== "published", onSelect: () => run((s) => s.setJobStatus(j.id, "closed"), t.jobs.closed) },
  ];

  return (
    <>
      <PageHead
        title={t.jobs.title}
        desc={t.jobs.desc}
        actions={
          <>
            <button type="button" className="btn" onClick={() => setUrgent({ open: true, initial: null })}><Icon name="bolt" />{t.today.postUrgent}</button>
            <button type="button" className="btn primary" onClick={() => setEditor({ open: true, jobId: null })}><Icon name="plus" />{t.today.newJob}</button>
          </>
        }
      />
      <Panel>
        <div className="panel-h">
          <Segmented<Filter>
            label={t.jobs.colStatus}
            value={filter}
            onChange={setFilter}
            options={(["all", "published", "draft", "closed"] as const).map((f) => ({ value: f, label: t.jobs.filters[f], count: counts[f] }))}
          />
          <span className="spacer" />
          <Search value={q} onChange={setQ} placeholder={t.common.search} />
        </div>
        {shown.length === 0 ? (
          <Empty
            icon="briefcase"
            title={needle ? t.jobs.emptySearch : t.jobs.empty}
            body={needle ? undefined : t.jobs.emptyBody}
            action={needle ? undefined : <button type="button" className="btn primary" onClick={() => setEditor({ open: true, jobId: null })}><Icon name="plus" />{t.today.newJob}</button>}
          />
        ) : (
          <>
            <div className="table-wrap collapse">
              <table className="dt">
                <thead>
                  <tr>
                    <th>{t.jobs.colJob}</th>
                    <th>{t.jobs.colStatus}</th>
                    <th>{t.jobs.colDates}</th>
                    <th>{t.jobs.colFill}</th>
                    <th className="num">{t.jobs.colWaiting}</th>
                    <th className="num">{t.jobs.colWage}</th>
                    <th><span className="sr">{t.common.more}</span></th>
                  </tr>
                </thead>
                <tbody>
                  {shown.map((j) => (
                    <tr
                      key={j.id}
                      className="clickable"
                      tabIndex={0}
                      onClick={() => setEditor({ open: true, jobId: j.id })}
                      onKeyDown={(e) => { if (e.key === "Enter") setEditor({ open: true, jobId: j.id }); }}
                    >
                      <td className="title-cell">
                        <strong>{j.title}</strong>
                        <small>{t.roles[j.role]} · {t.pay[j.payStyle]}</small>
                      </td>
                      <td>
                        <div className="row">
                          <Status tone={TONE[j.status]}>{t.jobStatus[j.status]}</Status>
                          {j.urgent && j.status === "published" ? <Status tone="warn" plain>{t.jobs.urgent}</Status> : null}
                        </div>
                      </td>
                      <td className="nowrap">{dates(j)}<div className="small muted">{t.jobs.slots(j.slots.length)}</div></td>
                      <td><Progress value={j.accepted} max={j.capacity} tone={j.accepted >= j.capacity ? "good" : undefined} /></td>
                      <td className="num">{j.applied ? <Link href={`/applications?job=${j.id}`} onClick={(e) => e.stopPropagation()} className="count-pill">{j.applied}</Link> : <span className="muted">0</span>}</td>
                      <td className="num nowrap">{money(j.wage, true)}</td>
                      <td className="num" onClick={(e) => e.stopPropagation()}><Menu label={t.common.more} items={actions(j)} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="cards">
              {shown.map((j) => (
                <div className="card-row" key={j.id}>
                  <div className="row">
                    <button type="button" className="btn ghost" style={{ padding: 0, fontWeight: 600, whiteSpace: "normal", textAlign: "left" }} onClick={() => setEditor({ open: true, jobId: j.id })}>{j.title}</button>
                    <span className="spacer" />
                    <Menu label={t.common.more} items={actions(j)} />
                  </div>
                  <div className="row wrap">
                    <Status tone={TONE[j.status]}>{t.jobStatus[j.status]}</Status>
                    {j.urgent && j.status === "published" ? <Status tone="warn" plain>{t.jobs.urgent}</Status> : null}
                    <span className="small muted">{dates(j)} · {money(j.wage, true)}</span>
                  </div>
                  <Progress value={j.accepted} max={j.capacity} tone={j.accepted >= j.capacity ? "good" : undefined} />
                </div>
              ))}
            </div>
          </>
        )}
      </Panel>
      <JobEditor open={editor.open} jobId={editor.jobId} onClose={closeEditor} />
      <UrgentDialog open={urgent.open} initial={urgent.initial} onClose={() => setUrgent({ open: false, initial: null })} />
    </>
  );
}
