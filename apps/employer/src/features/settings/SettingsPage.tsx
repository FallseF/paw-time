"use client";

import type { NotificationSettings, ShopProfile, StaffMember } from "@paw-time/shop-console";
import { useEffect, useState } from "react";
import { Cat } from "../../components/Cat";
import { Icon } from "../../components/Icon";
import { Field, PageHead, Panel, Switch } from "../../components/ui";
import { useConsole } from "../../lib/console";

/** Sign colors shops can pick (same set as the worker game's shop styles). */
const SIGN_COLORS = ["#3f9e8f", "#c9454a", "#4f9bd6", "#e8a23a", "#d9894f", "#5fa864", "#e8705b", "#8b7bff"];

export function SettingsPage() {
  const { store, t, run, version, resetSample, toast } = useConsole();
  void version;
  const settings = store.settings();
  const [profile, setProfile] = useState<ShopProfile>(settings.profile);
  const [notif, setNotif] = useState<NotificationSettings>(settings.notifications);
  const [staffDraft, setStaffDraft] = useState<{ name: string; email: string; role: StaffMember["role"] }>({ name: "", email: "", role: "staff" });
  const [staffTried, setStaffTried] = useState(false);

  useEffect(() => {
    setProfile(store.settings().profile);
    setNotif(store.settings().notifications);
  }, [store]);

  const validEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(staffDraft.email);
  const sections: Array<[string, string]> = [
    ["profile", t.settings.profile],
    ["staff", t.settings.staff],
    ["notifications", t.settings.notifications],
    ["rules", t.settings.rules],
    ["data", t.settings.data],
  ];

  return (
    <>
      <PageHead title={t.settings.title} desc={t.settings.desc} />
      <div className="settings">
        <nav className="settings-nav" aria-label={t.settings.title}>
          {sections.map(([id, label]) => <a key={id} href={`#${id}`}>{label}</a>)}
        </nav>
        <div className="stack">
          <Panel id="profile" title={t.settings.profile} sub={t.settings.profileDesc}>
            <form className="panel-b stack" onSubmit={(e) => { e.preventDefault(); run((s) => s.updateProfile({ name: profile.name, area: profile.area, signColor: profile.signColor, values: profile.values }), t.common.saved); }}>
              <div className="grid-2">
                <Field label={t.settings.name} htmlFor="p-name" error={!profile.name.trim() ? t.editor.required : undefined}>
                  <input id="p-name" className="input" maxLength={40} value={profile.name} onChange={(e) => setProfile({ ...profile, name: e.target.value })} />
                </Field>
                <Field label={t.settings.area} htmlFor="p-area">
                  <input id="p-area" className="input" maxLength={80} value={profile.area} onChange={(e) => setProfile({ ...profile, area: e.target.value })} />
                </Field>
              </div>
              <div className="field">
                <span className="label">{t.settings.signColor}</span>
                <div className="swatches" role="group" aria-label={t.settings.signColor}>
                  {SIGN_COLORS.map((c) => (
                    <button type="button" key={c} className="swatch" style={{ background: c }} aria-pressed={profile.signColor.toLowerCase() === c} aria-label={c} onClick={() => setProfile({ ...profile, signColor: c })} />
                  ))}
                </div>
              </div>
              <Field label={t.settings.values} htmlFor="p-values" hint={<><span>{t.settings.valuesHint}</span> <span className="counter">{profile.values.length}/80</span></>}>
                <input id="p-values" className="input" maxLength={80} value={profile.values} onChange={(e) => setProfile({ ...profile, values: e.target.value })} />
              </Field>
              <div className="field">
                <span className="label">{t.settings.preview}</span>
                <div className="sign-preview">
                  <Cat color="#fdf7ee" shop={profile.signColor} size={40} />
                  <span className="board" style={{ background: profile.signColor }}>{profile.name || "—"}</span>
                  <span className="vals">“{profile.values}”</span>
                </div>
              </div>
              <div className="row"><span className="spacer" /><button type="submit" className="btn primary" disabled={!profile.name.trim()}>{t.common.save}</button></div>
            </form>
          </Panel>

          <Panel id="staff" title={t.settings.staff} sub={t.settings.staffDesc}>
            <div className="table-wrap">
              <table className="dt">
                <thead><tr><th>{t.settings.staffName}</th><th>{t.settings.staffRole}</th><th>{t.settings.staffEmail}</th><th><span className="sr">{t.common.more}</span></th></tr></thead>
                <tbody>
                  {settings.staff.map((m) => (
                    <tr key={m.id}>
                      <td><strong style={{ fontWeight: 500 }}>{m.name}</strong></td>
                      <td>{t.staffRole[m.role]}</td>
                      <td className="muted">{m.email}</td>
                      <td className="num">
                        {m.role !== "owner" ? (
                          <button type="button" className="icon-btn" aria-label={`${t.common.remove}: ${m.name}`} onClick={() => run((s) => s.removeStaff(m.id), t.settings.removed)}><Icon name="trash" /></button>
                        ) : null}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <form className="panel-b" style={{ borderTop: "1px solid var(--line)" }} onSubmit={(e) => {
              e.preventDefault();
              setStaffTried(true);
              if (!staffDraft.name.trim() || !validEmail) return;
              const res = run((s) => s.addStaff(staffDraft.name, staffDraft.role, staffDraft.email), t.settings.added(staffDraft.name.trim()));
              if (res.ok) { setStaffDraft({ name: "", email: "", role: "staff" }); setStaffTried(false); }
            }}>
              <div className="grid-3" style={{ alignItems: "end", gridTemplateColumns: "minmax(0,1fr) minmax(0,1.3fr) 140px auto" }}>
                <Field label={t.settings.staffName} htmlFor="s-name" error={staffTried && !staffDraft.name.trim() ? t.editor.required : undefined}>
                  <input id="s-name" className="input" maxLength={60} value={staffDraft.name} onChange={(e) => setStaffDraft({ ...staffDraft, name: e.target.value })} />
                </Field>
                <Field label={t.settings.staffEmail} htmlFor="s-email" error={staffTried && !validEmail ? t.editor.invalid : undefined}>
                  <input id="s-email" className="input" type="email" value={staffDraft.email} onChange={(e) => setStaffDraft({ ...staffDraft, email: e.target.value })} />
                </Field>
                <Field label={t.settings.staffRole} htmlFor="s-role">
                  <select id="s-role" className="select" value={staffDraft.role} onChange={(e) => setStaffDraft({ ...staffDraft, role: e.target.value as StaffMember["role"] })}>
                    <option value="staff">{t.staffRole.staff}</option>
                    <option value="manager">{t.staffRole.manager}</option>
                  </select>
                </Field>
                <button type="submit" className="btn"><Icon name="plus" />{t.settings.addStaff}</button>
              </div>
            </form>
          </Panel>

          <Panel id="notifications" title={t.settings.notifications} sub={t.settings.notificationsDesc}>
            <form className="panel-b stack" onSubmit={(e) => { e.preventDefault(); run((s) => s.updateNotifications(notif), t.common.saved); }}>
              <div className="grid-2" style={{ maxWidth: 360 }}>
                <Field label={t.settings.from} htmlFor="n-from"><input id="n-from" className="input" type="time" value={notif.from} onChange={(e) => setNotif({ ...notif, from: e.target.value })} /></Field>
                <Field label={t.settings.to} htmlFor="n-to" error={notif.to <= notif.from ? t.editor.beforeStart : undefined}><input id="n-to" className="input" type="time" value={notif.to} onChange={(e) => setNotif({ ...notif, to: e.target.value })} /></Field>
              </div>
              <div>
                <Switch checked={notif.newApplicants} onChange={(v) => setNotif({ ...notif, newApplicants: v })} label={t.settings.nApplicants} />
                <Switch checked={notif.chats} onChange={(v) => setNotif({ ...notif, chats: v })} label={t.settings.nChats} />
                <Switch checked={notif.attendance} onChange={(v) => setNotif({ ...notif, attendance: v })} label={t.settings.nAttendance} />
                <Switch checked={notif.weeklyReport} onChange={(v) => setNotif({ ...notif, weeklyReport: v })} label={t.settings.nWeekly} />
              </div>
              <div className="row"><span className="spacer" /><button type="submit" className="btn primary" disabled={notif.to <= notif.from}>{t.common.save}</button></div>
            </form>
          </Panel>

          <Panel id="rules" title={t.settings.rules} sub={t.settings.rulesDesc}>
            <div className="panel-b"><ul className="rule-list">
              <li><Icon name="moon" /><span>{t.settings.r1}</span></li>
              <li><Icon name="lock" /><span>{t.settings.r2}</span></li>
              <li><Icon name="shield" /><span>{t.settings.r3}</span></li>
              <li><Icon name="flag" /><span>{t.settings.r4}</span></li>
            </ul></div>
          </Panel>

          <Panel id="data" title={t.settings.data} sub={t.settings.dataDesc}>
            <div className="panel-b row wrap">
              <span className="small"><span className="muted">{t.settings.region}:</span> {t.settings.regionValue}</span>
              <span className="spacer" />
              <button type="button" className="btn" onClick={() => { resetSample(); toast(t.settings.resetDone); }}><Icon name="reset" />{t.settings.reset}</button>
            </div>
          </Panel>
        </div>
      </div>
    </>
  );
}
