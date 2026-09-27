"use client";

import Link from "next/link";
import { useState } from "react";
import { Cat } from "../../components/Cat";
import { Icon } from "../../components/Icon";
import { IslandArt, LandmarkIcon, LevelBar } from "../../components/Island";
import { Empty, PageHead, Panel, Status } from "../../components/ui";
import { useConsole } from "../../lib/console";
import { fmtAgo, fmtDate, fmtRange, fmtWhen, instantTime } from "../../lib/format";
import { ArrivalPill } from "../attendance/arrival";
import { UrgentDialog } from "../job-postings/UrgentDialog";

export function TodayPage() {
  const { store, t, locale, timeZone, run, version, staffName } = useConsole();
  void version;
  const [urgent, setUrgent] = useState<{ open: boolean; initial: { jobId: string; slotId: string } | null }>({ open: false, initial: null });
  const view = store.todayView();
  const now = new Date(view.now);
  const profile = store.settings().profile;
  const onShift = view.shifts.filter((s) => s.status === "checked_in").length;
  const later = view.shifts.filter((s) => ["scheduled", "on_the_way", "running_late"].includes(s.status)).length;
  const openSpots = view.openSlots.reduce((n, o) => n + o.slot.open, 0);
  const waiting = view.unreadChats.filter((c) => c.needsStaff).length;
  const topLandmarks = [...view.island.landmarks].sort((a, b) => b.votes - a.votes).slice(0, 4);

  return (
    <>
      <PageHead
        crumb={fmtDate(view.date, locale, { long: true })}
        title={t.today.title}
        actions={
          <>
            <Link className="btn" href="/jobs?new=1"><Icon name="plus" />{t.today.newJob}</Link>
            <button type="button" className="btn primary" onClick={() => setUrgent({ open: true, initial: null })}><Icon name="bolt" />{t.today.postUrgent}</button>
          </>
        }
      />
      <section className="kpis" aria-label={t.today.title}>
        <Link className="kpi" href="/attendance">
          <div className="kpi-k">{t.today.kpiOnShift}</div>
          <div className="kpi-v">{onShift}</div>
          <div className="kpi-n">{t.today.kpiOnShiftNote(view.shifts.length)}</div>
        </Link>
        <Link className="kpi" href="/attendance">
          <div className="kpi-k">{t.today.kpiLater}</div>
          <div className="kpi-v">{later}</div>
          <div className="kpi-n">{t.today.kpiLaterNote}</div>
        </Link>
        <Link className="kpi" href="/jobs">
          <div className="kpi-k">{t.today.kpiOpen}</div>
          <div className="kpi-v">{openSpots}</div>
          <div className="kpi-n">{t.today.kpiOpenNote(view.openSlots.length)}</div>
        </Link>
        <Link className="kpi" href="/applications">
          <div className="kpi-k">{t.today.kpiApplicants}</div>
          <div className="kpi-v">{view.newApplicants.length}</div>
          <div className="kpi-n">{t.today.kpiApplicantsNote}</div>
        </Link>
        <Link className="kpi" href="/chat">
          <div className="kpi-k">{t.today.kpiChats}</div>
          <div className="kpi-v">{waiting}</div>
          <div className="kpi-n">{t.today.kpiChatsNote}</div>
        </Link>
      </section>

      <div className="today-grid">
        <div className="stack">
          <Panel title={t.today.alerts}>
            {view.alerts.length === 0 ? (
              <Empty icon="check" title={t.today.noAlerts} />
            ) : (
              <div>
                {view.alerts.map((a) => {
                  if (a.kind === "short_staffed" && a.date && a.start && a.end) {
                    const job = store.job(a.jobId ?? "");
                    return (
                      <div className="alert" key={a.id}>
                        <span className="a-ic warn"><Icon name="users" /></span>
                        <div className="grow">
                          <div className="t">{t.today.alertShort(fmtWhen(a.date, a.start, view.date, locale, t), a.short ?? 0)}</div>
                          <div className="s">{t.today.alertShortSub(job?.title ?? "", `${fmtDate(a.date, locale)} ${fmtRange(a.start, a.end, locale)}`)}</div>
                        </div>
                        <button type="button" className="btn sm primary" onClick={() => setUrgent({ open: true, initial: { jobId: a.jobId ?? "", slotId: a.slotId ?? "" } })}>
                          <Icon name="bolt" />{t.today.sendToAvailable}
                        </button>
                      </div>
                    );
                  }
                  if (a.kind === "unanswered") {
                    return (
                      <div className="alert" key={a.id}>
                        <span className="a-ic info"><Icon name="chat" /></span>
                        <div className="grow">
                          <div className="t">{t.today.alertChats(a.count ?? 0)}</div>
                          <div className="s">{t.today.alertChatsSub}</div>
                        </div>
                        <Link className="btn sm" href="/chat?filter=waiting">{t.today.openChat}</Link>
                      </div>
                    );
                  }
                  return (
                    <div className="alert" key={a.id}>
                      <span className="a-ic warn"><Icon name="clock" /></span>
                      <div className="grow"><div className="t">{t.today.alertLate(a.displayName ?? "")}</div></div>
                      <Link className="btn sm" href="/attendance">{t.nav.shifts}</Link>
                    </div>
                  );
                })}
              </div>
            )}
          </Panel>

          <Panel title={t.today.whoIsComing} sub={fmtDate(view.date, locale)} actions={<Link className="btn sm ghost" href="/attendance">{t.common.viewAll}<Icon name="chevronRight" /></Link>}>
            {view.shifts.length === 0 ? (
              <Empty icon="calendar" title={t.today.noShiftsToday} body={t.today.noShiftsTodayBody} />
            ) : (
              <>
                <div className="table-wrap collapse">
                  <table className="dt">
                    <thead>
                      <tr><th>{t.today.time}</th><th>{t.today.worker}</th><th>{t.today.job}</th><th>{t.today.arrival}</th><th><span className="sr">{t.common.more}</span></th></tr>
                    </thead>
                    <tbody>
                      {view.shifts.map((s) => {
                        const canCheckIn = ["scheduled", "on_the_way", "running_late"].includes(s.status) && now >= new Date(Date.parse(s.startAt) - 30 * 60_000);
                        return (
                          <tr key={s.id}>
                            <td className="time-cell">{fmtRange(s.start, s.end, locale)}</td>
                            <td><div className="who"><Cat color={s.cat.color} size={28} /><strong>{s.displayName}</strong></div></td>
                            <td><span className="muted">{t.roles[s.role]}</span></td>
                            <td><ArrivalPill shift={s} t={t} timeZone={timeZone} locale={locale} now={now} /></td>
                            <td className="num">
                              <div className="row" style={{ justifyContent: "flex-end" }}>
                                {canCheckIn ? (
                                  <button type="button" className="btn sm" onClick={() => run((st) => st.recordAttendance(s.id, "check_in", staffName), t.shifts.checkedIn)}>{t.shifts.checkIn}</button>
                                ) : null}
                                {s.threadId ? <Link className="btn sm ghost" href={`/chat?thread=${s.threadId}`} aria-label={`${t.applicants.message}: ${s.displayName}`}><Icon name="chat" /></Link> : null}
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
                <div className="cards">
                  {view.shifts.map((s) => (
                    <div className="card-row" key={s.id}>
                      <div className="row"><Cat color={s.cat.color} size={28} /><strong>{s.displayName}</strong><span className="spacer" /><span className="time-cell small">{fmtRange(s.start, s.end, locale)}</span></div>
                      <div className="row wrap"><span className="muted small">{t.roles[s.role]}</span><ArrivalPill shift={s} t={t} timeZone={timeZone} locale={locale} now={now} /></div>
                    </div>
                  ))}
                </div>
              </>
            )}
          </Panel>

          <Panel title={t.today.openSlots} actions={<Link className="btn sm ghost" href="/jobs">{t.nav.jobs}<Icon name="chevronRight" /></Link>}>
            {view.openSlots.length === 0 ? (
              <Empty icon="check" title={t.today.openSlotsEmpty} />
            ) : (
              <ul className="list">
                {view.openSlots.map(({ job, slot }) => (
                  <li key={slot.id}>
                    <div className="grow">
                      <div className="t">{fmtDate(slot.date, locale)} · {fmtRange(slot.start, slot.end, locale)}</div>
                      <div className="s">{job.title}</div>
                    </div>
                    <Status tone={slot.open >= 2 ? "warn" : "neutral"}>{t.today.spots(slot.open)}</Status>
                    <button type="button" className="btn sm" onClick={() => setUrgent({ open: true, initial: { jobId: job.id, slotId: slot.id } })}><Icon name="bolt" /><span className="sr">{t.today.sendToAvailable}</span></button>
                  </li>
                ))}
              </ul>
            )}
          </Panel>
        </div>

        <div className="stack">
          <Panel title={t.today.island} actions={<Link className="btn sm ghost" href="/reviews">{t.today.islandLink}<Icon name="chevronRight" /></Link>}>
            <div className="panel-b stack-sm">
              <IslandArt island={view.island} shopName={profile.name} signColor={profile.signColor} compact labels={t.landmarks} note={t.sample} />
              <ul className="lm-list">
                {topLandmarks.map((l) => (
                  <li key={l.id}>
                    <LandmarkIcon id={l.id} dim={l.level === 0} />
                    <span>{t.landmarks[l.id]} <span className="muted small">· {t.tags[l.tag]}</span></span>
                    <LevelBar level={l.level} sprout={l.sprout} />
                  </li>
                ))}
              </ul>
              <p className="small muted">{t.today.islandBasedOn(view.island.basedOn)}</p>
            </div>
          </Panel>

          <Panel title={t.today.newApplicants} actions={<Link className="btn sm ghost" href="/applications">{t.common.viewAll}<Icon name="chevronRight" /></Link>}>
            {view.newApplicants.length === 0 ? (
              <Empty icon="users" title={t.today.noNewApplicants} />
            ) : (
              <ul className="list">
                {view.newApplicants.slice(0, 4).map((a) => {
                  const job = store.job(a.jobId);
                  const slot = job?.slots.find((s) => s.id === a.slotId);
                  return (
                    <li key={a.applicationId} className="hoverable">
                      <Link className="list-link" href={`/applications?job=${a.jobId}`}>
                        <Cat color={a.cat.color} size={32} />
                        <div className="grow">
                          <div className="t">{a.displayName}</div>
                          <div className="s">{slot ? `${fmtDate(slot.date, locale)} · ${fmtRange(slot.start, slot.end, locale)}` : job?.title}</div>
                        </div>
                        <span className="small muted nowrap">{fmtAgo(a.appliedAt, now, t)}</span>
                      </Link>
                    </li>
                  );
                })}
              </ul>
            )}
          </Panel>

          <Panel title={t.today.unreadChats} actions={<Link className="btn sm ghost" href="/chat">{t.common.viewAll}<Icon name="chevronRight" /></Link>}>
            {view.unreadChats.length === 0 ? (
              <Empty icon="chat" title={t.today.noUnread} />
            ) : (
              <ul className="list">
                {view.unreadChats.slice(0, 4).map((c) => {
                  const last = c.messages.at(-1);
                  return (
                    <li key={c.id} className="hoverable">
                      <Link className="list-link" href={`/chat?thread=${c.id}`}>
                        <Cat color={c.cat.color} size={32} />
                        <div className="grow">
                          <div className="t">{c.displayName}</div>
                          <div className="s">{last?.text}</div>
                        </div>
                        {c.needsStaff ? <Status tone="warn" plain>{t.today.waitingReply}</Status> : <span className="small muted">{last ? instantTime(last.sentAt, timeZone, locale) : ""}</span>}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            )}
          </Panel>
        </div>
      </div>
      <UrgentDialog open={urgent.open} initial={urgent.initial} onClose={() => setUrgent({ open: false, initial: null })} />
    </>
  );
}
