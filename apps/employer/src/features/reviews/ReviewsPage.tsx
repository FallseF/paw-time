"use client";

import Link from "next/link";
import { Icon } from "../../components/Icon";
import { IslandArt, LandmarkIcon, LevelBar } from "../../components/Island";
import { Empty, PageHead, Panel } from "../../components/ui";
import { useConsole } from "../../lib/console";
import { fmtDate } from "../../lib/format";

const ACTION_LINK: Record<string, string> = {
  break_schedule: "/chat?tab=faq",
  first_day_checklist: "/chat?tab=faq",
  add_peak_slot: "/jobs?urgent=1",
  confirm_payday: "/jobs",
  closing_plan: "/jobs",
  team_guide: "/settings#staff",
};

export function ReviewsPage() {
  const { store, t, locale, version } = useConsole();
  void version;
  const island = store.island();
  const report = store.improvementReport();
  const profile = store.settings().profile;
  const tags = [...island.landmarks].sort((a, b) => b.votes - a.votes);
  const maxVotes = Math.max(1, ...tags.map((l) => l.votes));
  const maxTrend = Math.max(5, ...report.issues.flatMap((i) => i.trend.map((w) => w.workers ?? 0)));

  return (
    <>
      <PageHead title={t.reviews.title} desc={t.reviews.desc} />
      <div className="stack">
        <Panel title={t.reviews.island} sub={t.reviews.basedOn(island.basedOn)}>
          <div className="island-panel">
            <div className="island-art">
              <IslandArt island={island} shopName={profile.name} signColor={profile.signColor} labels={t.landmarks} tags={t.tags} note={t.sample} />
              <p className="small muted" style={{ marginTop: 8 }}>“{profile.values}”</p>
            </div>
            <div className="island-side">
              <div className="note"><Icon name="shield" />{t.reviews.rule}</div>
              <div>
                {island.landmarks.map((l) => (
                  <div className="lm-row" key={l.id}>
                    <LandmarkIcon id={l.id} dim={l.level === 0} />
                    <div style={{ minWidth: 0 }}>
                      <div className="t">{t.landmarks[l.id]}</div>
                      <div className="s">{t.tags[l.tag]}</div>
                    </div>
                    <div className="r">
                      <span>{l.level > 0 ? t.reviews.level(l.level) : l.sprout ? t.reviews.sprout : t.reviews.notYet} · {t.reviews.votes(l.votes)}</span>
                      <span className="row" style={{ gap: 6 }}>
                        <LevelBar level={l.level} sprout={l.sprout} />
                        <span className="muted">{l.nextAt ? t.reviews.nextAt(l.nextAt) : t.reviews.maxed}</span>
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </Panel>

        <div className="layout-2" style={{ gridTemplateColumns: "minmax(0, 1fr) minmax(0, 1.4fr)" }}>
          <Panel title={t.reviews.positive} sub={t.reviews.positiveDesc}>
            <div className="panel-b">
              {tags.map((l) => (
                <div className="hbar" key={l.tag}>
                  <span>{t.tags[l.tag]}</span>
                  <span className="track" aria-hidden="true"><i style={{ width: `${(l.votes / maxVotes) * 100}%` }} /></span>
                  <span className="v">{l.votes}</span>
                </div>
              ))}
            </div>
          </Panel>

          <Panel title={t.reviews.report} sub={t.reviews.reportDesc}>
            {report.status === "not_enough" ? (
              <Empty icon="shield" title={t.reviews.notEnough} body={t.reviews.notEnoughBody} />
            ) : (
              <>
                <div className="table-wrap">
                  <table className="dt">
                    <thead>
                      <tr><th>{t.reviews.colIssue}</th><th className="num">{t.reviews.colWorkers}</th><th>{t.reviews.colTrend}</th><th>{t.reviews.colAction}</th></tr>
                    </thead>
                    <tbody>
                      {report.issues.map((row) => (
                        <tr key={row.issue}>
                          <td style={{ minWidth: 140 }}><strong style={{ fontWeight: 500 }}>{t.issues[row.issue]}</strong></td>
                          <td className="num">{row.workers}</td>
                          <td>
                            <div className="trend" role="img" aria-label={row.trend.map((w) => `${fmtDate(w.week, locale, { weekday: false })}: ${w.workers ?? t.common.fewerThan5}`).join(", ")}>
                              {row.trend.map((w) => (
                                <div className="col" key={w.week} title={`${fmtDate(w.week, locale, { weekday: false })} · ${w.workers ?? t.common.fewerThan5}`}>
                                  <i className={w.workers === null ? "na" : undefined} style={{ height: w.workers === null ? 2 : `${Math.max(4, (w.workers / maxTrend) * 28)}px` }} />
                                  <span>{w.workers ?? "–"}</span>
                                </div>
                              ))}
                            </div>
                          </td>
                          <td style={{ minWidth: 220 }}>
                            <Link href={ACTION_LINK[row.action] ?? "/"} className="row" style={{ fontWeight: 500 }}>{t.actions[row.action]}<Icon name="arrowRight" width={14} height={14} /></Link>
                            <div className="small muted">{t.actionHelp[row.action]}</div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <div className="panel-f">{t.reviews.trendNa}</div>
              </>
            )}
          </Panel>
        </div>

        <Panel title={t.reviews.rules}>
          <div className="panel-b"><ul className="rule-list">
            <li><Icon name="island" /><span>{t.reviews.rule1}</span></li>
            <li><Icon name="users" /><span>{t.reviews.rule2}</span></li>
            <li><Icon name="shield" /><span>{t.reviews.rule3}</span></li>
          </ul></div>
        </Panel>
      </div>
    </>
  );
}
