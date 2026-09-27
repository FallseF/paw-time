"use client";

import { addDays, shopMessageDelivery } from "@paw-time/shop-console";
import type { InviteCandidate } from "@paw-time/shop-console";
import { useEffect, useState } from "react";
import { Cat } from "../../components/Cat";
import { Icon } from "../../components/Icon";
import { Dialog, Empty, Field, PageHead, Panel, Status } from "../../components/ui";
import { useConsole } from "../../lib/console";
import { fmtAgo, fmtCount, fmtDate, fmtInstant, fmtRange, instantTime } from "../../lib/format";

export function InvitesPage() {
  const { store, t, locale, timeZone, version } = useConsole();
  void version;
  const [inviting, setInviting] = useState<InviteCandidate | null>(null);
  const view = store.invites();
  const now = store.now();
  const today = store.today();
  const monthAgo = addDays(today, -30);
  const recent = view.sent.filter((s) => s.sentAt.slice(0, 10) >= monthAgo);
  const slotLabel = (jobId: string, slotId: string) => {
    const job = store.job(jobId);
    const slot = job?.slots.find((s) => s.id === slotId);
    return slot ? `${fmtDate(slot.date, locale)} ${fmtRange(slot.start, slot.end, locale)}` : "";
  };

  return (
    <>
      <PageHead title={t.invites.title} desc={t.invites.desc} />
      <section className="kpis k3" aria-label={t.invites.title}>
        <div className="kpi"><div className="kpi-k">{t.invites.eligible}</div><div className="kpi-v">{fmtCount(view.eligible, t)}</div><div className="kpi-n">{t.invites.eligibleNote}</div></div>
        <div className="kpi"><div className="kpi-k">{t.invites.contactable}</div><div className="kpi-v">{view.contactable.length}</div><div className="kpi-n">{t.invites.contactableNote}</div></div>
        <div className="kpi"><div className="kpi-k">{t.invites.sentCount}</div><div className="kpi-v">{recent.length}</div><div className="kpi-n">{t.invites.sentNote}</div></div>
      </section>
      <div className="stack">
        <Panel title={t.invites.listTitle} sub={t.invites.listDesc}>
          {view.contactable.length === 0 ? (
            <Empty icon="mail" title={t.invites.empty} body={t.invites.emptyBody} />
          ) : (
            <>
              <div className="table-wrap collapse">
                <table className="dt">
                  <thead><tr><th>{t.invites.colWorker}</th><th>{t.invites.colLast}</th><th className="num">{t.invites.colShifts}</th><th>{t.invites.colRoles}</th><th><span className="sr">{t.common.more}</span></th></tr></thead>
                  <tbody>
                    {view.contactable.map((c) => (
                      <tr key={c.workerId}>
                        <td><div className="who"><Cat color={c.cat.color} size={28} /><div><strong>{c.displayName}</strong><small>{c.cat.name}</small></div></div></td>
                        <td className="nowrap">{fmtDate(c.lastWorked, locale)}</td>
                        <td className="num">{c.shiftsHere}</td>
                        <td><div className="row wrap" style={{ gap: 4 }}>{c.roles.map((r) => <span className="chip" key={r}>{t.roles[r]}</span>)}</div></td>
                        <td className="num">
                          <div className="row" style={{ justifyContent: "flex-end" }}>
                            {c.invitedAt ? <span className="small muted nowrap">{t.invites.invitedAgo(fmtAgo(c.invitedAt, now, t))}</span> : null}
                            <button type="button" className="btn sm" onClick={() => setInviting(c)}><Icon name="mail" />{t.invites.invite}</button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="cards">
                {view.contactable.map((c) => (
                  <div className="card-row" key={c.workerId}>
                    <div className="row"><Cat color={c.cat.color} size={28} /><strong>{c.displayName}</strong><span className="spacer" /><button type="button" className="btn sm" onClick={() => setInviting(c)}><Icon name="mail" />{t.invites.invite}</button></div>
                    <div className="small muted">{t.invites.colLast}: {fmtDate(c.lastWorked, locale)} · {t.invites.colShifts}: {c.shiftsHere}{c.invitedAt ? ` · ${t.invites.invitedAgo(fmtAgo(c.invitedAt, now, t))}` : ""}</div>
                  </div>
                ))}
              </div>
            </>
          )}
          <div className="panel-f"><span className="row"><Icon name="shield" width={14} height={14} />{t.urgent.fewerNote}</span></div>
        </Panel>

        <Panel title={t.invites.sentTitle}>
          {view.sent.length === 0 ? (
            <Empty icon="send" title={t.invites.sentEmpty} />
          ) : (
            <div className="table-wrap">
              <table className="dt">
                <thead><tr><th>{t.invites.colWorker}</th><th>{t.invites.colFor}</th><th>{t.invites.colSent}</th><th>{t.invites.colDelivery}</th></tr></thead>
                <tbody>
                  {view.sent.map((s) => (
                    <tr key={s.id}>
                      <td><strong style={{ fontWeight: 500 }}>{s.displayName}</strong></td>
                      <td className="nowrap">{slotLabel(s.jobId, s.slotId)}</td>
                      <td className="nowrap">{fmtInstant(s.sentAt, timeZone, locale, today, t)}</td>
                      <td>{s.status === "queued" ? <Status tone="warn">{t.invites.queuedTag(instantTime(s.deliverAt, timeZone, locale))}</Status> : <Status tone="good">{t.invites.delivered}</Status>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Panel>
      </div>
      <InviteDialog candidate={inviting} onClose={() => setInviting(null)} />
    </>
  );
}

function InviteDialog({ candidate, onClose }: { candidate: InviteCandidate | null; onClose: () => void }) {
  const { store, t, locale, timeZone, run, staffName } = useConsole();
  const today = store.today();
  const slots = store.jobs()
    .filter((j) => j.status === "published")
    .flatMap((j) => j.slots.filter((s) => s.open > 0 && s.date > today).map((s) => ({ job: j, slot: s })))
    .sort((a, b) => `${a.slot.date}${a.slot.start}`.localeCompare(`${b.slot.date}${b.slot.start}`));
  const [pick, setPick] = useState("");
  const [text, setText] = useState("");
  const chosen = slots.find((o) => o.slot.id === pick);
  const shopName = store.settings().profile.name;

  useEffect(() => {
    if (!candidate) return;
    const first = slots.find((o) => candidate.roles.includes(o.job.role)) ?? slots[0];
    setPick(first?.slot.id ?? "");
    setText(first ? t.invites.defaultMessage(shopName, `${fmtDate(first.slot.date, locale)} ${fmtRange(first.slot.start, first.slot.end, locale)}`) : "");
  }, [candidate]);

  const delivery = shopMessageDelivery(store.now(), timeZone);
  const send = () => {
    if (!candidate || !chosen) return;
    const res = run(
      (s) => s.sendInvite(candidate.workerId, chosen.job.id, chosen.slot.id, staffName, text),
      delivery.status === "queued" ? t.invites.queued(candidate.displayName, instantTime(delivery.deliverAt, timeZone, locale)) : t.invites.sent(candidate.displayName),
    );
    if (res.ok) onClose();
  };

  return (
    <Dialog
      open={!!candidate}
      onClose={onClose}
      title={candidate ? t.invites.dialogTitle(candidate.displayName) : ""}
      closeLabel={t.common.close}
      footer={
        <>
          <button type="button" className="btn" onClick={onClose}>{t.common.cancel}</button>
          <button type="button" className="btn primary" disabled={!chosen || !text.trim()} onClick={send}><Icon name="send" />{t.invites.sendInvite}</button>
        </>
      }
    >
      {slots.length === 0 ? (
        <div className="note"><Icon name="info" />{t.invites.noSlots}</div>
      ) : (
        <div className="stack">
          <Field label={t.invites.slot} htmlFor="inv-slot">
            <select id="inv-slot" className="select" value={pick} onChange={(e) => {
              setPick(e.target.value);
              const o = slots.find((x) => x.slot.id === e.target.value);
              if (o) setText(t.invites.defaultMessage(shopName, `${fmtDate(o.slot.date, locale)} ${fmtRange(o.slot.start, o.slot.end, locale)}`));
            }}>
              {slots.map((o) => <option key={o.slot.id} value={o.slot.id}>{fmtDate(o.slot.date, locale)} · {fmtRange(o.slot.start, o.slot.end, locale)} · {o.job.title}</option>)}
            </select>
          </Field>
          <Field label={t.invites.message} htmlFor="inv-text" hint={<span className="counter">{text.length}/1000</span>}>
            <textarea id="inv-text" className="textarea" rows={3} maxLength={1000} value={text} onChange={(e) => setText(e.target.value)} />
          </Field>
          <div className={`quiet${delivery.status === "queued" ? " on" : ""}`}>
            <Icon name={delivery.status === "queued" ? "moon" : "clock"} />
            {delivery.status === "queued" ? t.chat.quietNow(instantTime(delivery.deliverAt, timeZone, locale)) : t.chat.liveNow}
          </div>
        </div>
      )}
    </Dialog>
  );
}
