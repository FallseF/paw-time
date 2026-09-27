"use client";

import { matchFaq, shopMessageDelivery } from "@paw-time/shop-console";
import type { Faq, FaqKey, Message, ThreadView } from "@paw-time/shop-console";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import type { ReactNode } from "react";
import { Cat } from "../../components/Cat";
import { Icon } from "../../components/Icon";
import { Empty, Field, Menu, PageHead, Panel, Search, Segmented, Status, Tabs } from "../../components/ui";
import { useConsole } from "../../lib/console";
import { fmtDate, fmtRange, instantDate, instantTime } from "../../lib/format";

type Filter = "all" | "waiting" | "invites";

export function ChatPage() {
  const { t } = useConsole();
  const params = useSearchParams();
  const [tab, setTab] = useState<"inbox" | "faq">("inbox");
  useEffect(() => { if (params.get("tab") === "faq") setTab("faq"); }, [params]);
  return (
    <>
      <PageHead title={t.chat.title} desc={t.chat.desc} />
      <Tabs label={t.chat.title} value={tab} onChange={setTab} options={[{ value: "inbox", label: t.chat.inbox }, { value: "faq", label: t.chat.faqTab }]} />
      {tab === "inbox" ? <Inbox /> : <FaqEditor />}
    </>
  );
}

function Inbox() {
  const { store, t, locale, timeZone, version, run } = useConsole();
  void version;
  const params = useSearchParams();
  const router = useRouter();
  const [filter, setFilter] = useState<Filter>("all");
  const [q, setQ] = useState("");
  const selected = params.get("thread");
  useEffect(() => { if (params.get("filter") === "waiting") setFilter("waiting"); }, [params]);
  useEffect(() => {
    if (selected) {
      store.markRead(selected);
    }
  }, [selected, store]);

  const threads = store.threads();
  const needle = q.trim().toLowerCase();
  const shown = threads.filter((th) =>
    (filter === "all" || (filter === "waiting" ? th.needsStaff : th.kind === "invite")) &&
    (!needle || `${th.displayName} ${th.cat.name} ${th.context?.jobTitle ?? ""}`.toLowerCase().includes(needle)));
  const counts = { all: threads.length, waiting: threads.filter((x) => x.needsStaff).length, invites: threads.filter((x) => x.kind === "invite").length };
  const active = selected ? store.thread(selected) : null;
  const today = store.today();

  return (
    <Panel>
      <div className={`chat${active ? " has-thread" : ""}`}>
        <div className="threads">
          <div className="threads-h">
            <Search value={q} onChange={setQ} placeholder={t.chat.searchPh} />
            <Segmented<Filter> label={t.chat.inbox} value={filter} onChange={setFilter} options={(["all", "waiting", "invites"] as const).map((f) => ({ value: f, label: t.chat.filters[f], count: counts[f] }))} />
          </div>
          {shown.length === 0 ? (
            <Empty icon="chat" title={t.chat.empty} body={t.chat.emptyBody} />
          ) : (
            <ul className="thread-list">
              {shown.map((th) => {
                const last = th.messages.at(-1);
                const d = last ? instantDate(last.sentAt, timeZone) : today;
                return (
                  <li key={th.id}>
                    <button type="button" aria-current={th.id === selected} onClick={() => router.replace(`/chat?thread=${th.id}`)}>
                      <Cat color={th.cat.color} size={36} />
                      <span className="t">
                        <span>{th.displayName}</span>
                        {th.kind === "invite" ? <Status tone="info" plain>{t.chat.filters.invites}</Status> : null}
                        {th.reported ? <Status tone="bad" plain>{t.chat.reportedTag}</Status> : null}
                      </span>
                      <span className="when">{last ? (d === today ? instantTime(last.sentAt, timeZone, locale) : fmtDate(d, locale, { weekday: false })) : ""}</span>
                      <span className="p">{last ? `${last.from === "worker" ? "" : "↩ "}${last.text}` : th.context?.jobTitle}</span>
                      {th.unread > 0 && th.id !== selected ? <span className="count-pill unread">{th.unread}</span> : th.needsStaff ? <span className="waiting">{t.today.waitingReply}</span> : null}
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
        {active ? (
          <Conversation key={active.id} thread={active} onBack={() => router.replace("/chat")} onAction={(fn, ok) => run(fn, ok)} />
        ) : (
          <div className="convo"><Empty icon="chat" title={t.chat.pick} body={t.chat.pickBody} /></div>
        )}
      </div>
    </Panel>
  );
}

function Conversation({ thread, onBack, onAction }: { thread: ThreadView; onBack: () => void; onAction: ReturnType<typeof useConsole>["run"] }) {
  const { store, t, locale, timeZone, staffName, toast } = useConsole();
  const [text, setText] = useState("");
  const endRef = useRef<HTMLDivElement>(null);
  const profile = store.settings().profile;
  const today = store.today();
  useEffect(() => { endRef.current?.scrollIntoView({ block: "end" }); }, [thread.messages.length]);

  const delivery = shopMessageDelivery(store.now(), timeZone);
  const at = (iso: string) => instantTime(iso, timeZone, locale);
  const send = (body = text) => {
    const res = onAction((s) => s.sendMessage(thread.id, body, staffName));
    if (res.ok) {
      setText("");
      if (res.data.status === "queued") toast(t.chat.willDeliver(at(res.data.deliverAt)));
    }
  };

  const dayLabel = (iso: string) => {
    const d = instantDate(iso, timeZone);
    const y = new Date(`${today}T12:00:00Z`);
    y.setUTCDate(y.getUTCDate() - 1);
    return d === today ? t.chat.today : d === y.toISOString().slice(0, 10) ? t.chat.yesterday : fmtDate(d, locale);
  };

  let lastDay = "";
  return (
    <div className="convo">
      <div className="convo-h">
        <button type="button" className="icon-btn menu-btn" aria-label={t.chat.backToList} onClick={onBack}><Icon name="chevronLeft" /></button>
        <div className="cat-pair" aria-hidden="true">
          <Cat color={thread.cat.color} size={36} />
          <Icon name="swap" className="link-ic" />
          <Cat color="#fdf7ee" shop={profile.signColor} size={36} />
        </div>
        <div className="names">
          <strong>{thread.displayName} · {thread.cat.name} ⇄ {t.chat.shopCat(profile.name)}</strong>
          <small>{thread.context ? `${thread.context.jobTitle} · ${fmtDate(thread.context.date, locale)} ${fmtRange(thread.context.start, thread.context.end, locale)}` : ""}</small>
        </div>
        {thread.reported ? <Status tone="bad" plain>{t.chat.reportedTag}</Status> : null}
        <Menu
          label={t.common.more}
          items={[
            { label: t.chat.report, icon: "flag", hidden: thread.reported, onSelect: () => onAction((s) => s.report(thread.id), t.chat.reported) },
            { label: t.chat.block, icon: "block", danger: true, hidden: thread.blocked, onSelect: () => onAction((s) => s.setBlocked(thread.id, true), t.chat.blocked) },
            { label: t.chat.unblock, icon: "block", hidden: !thread.blocked, onSelect: () => onAction((s) => s.setBlocked(thread.id, false), t.chat.unblocked) },
          ]}
        />
      </div>
      <div className="msgs" aria-live="polite">
        {thread.messages.map((m: Message) => {
          const day = dayLabel(m.sentAt);
          const sep = day !== lastDay ? <div className="day-sep" key={`d-${m.id}`}>{day}</div> : null;
          lastDay = day;
          const out = m.from !== "worker";
          const queued = m.status === "queued";
          const wasHeld = !queued && m.deliverAt !== m.sentAt && m.from === "staff";
          return (
            <FragmentWith key={m.id} sep={sep}>
              <div className={`msg ${out ? "out" : "in"}${m.from === "auto" ? " auto" : ""}${queued ? " queued" : ""}`}>
                <div className="who-line">
                  {m.from === "worker" ? thread.displayName : m.from === "auto" ? <><Icon name="sparkle" width={12} height={12} />{t.chat.auto}</> : m.staffName}
                  {m.template ? <span className="chip tmpl">{t.chat.tmpl[m.template]}</span> : null}
                  <span>· {at(m.sentAt)}</span>
                </div>
                <div className="bubble">{m.text}</div>
                {queued ? (
                  <span className="deliv"><Icon name="moon" />{t.chat.willDeliver(at(m.deliverAt))}</span>
                ) : wasHeld ? (
                  <span className="deliv"><Icon name="moon" />{t.chat.sentAt(`${dayLabel(m.sentAt)} ${at(m.sentAt)}`)} · {t.chat.deliveredAt(at(m.deliverAt))}</span>
                ) : null}
              </div>
            </FragmentWith>
          );
        })}
        <div ref={endRef} />
      </div>
      {thread.blocked ? (
        <div className="locked"><Icon name="block" />{t.chat.lockedBlocked}<span className="spacer" /><button type="button" className="btn sm" onClick={() => onAction((s) => s.setBlocked(thread.id, false), t.chat.unblocked)}>{t.chat.unblock}</button></div>
      ) : !thread.canMessage ? (
        <div className="locked"><Icon name="lock" />{t.chat.lockedNoShift}</div>
      ) : (
        <form className="composer" onSubmit={(e) => { e.preventDefault(); send(); }}>
          <div className="quick">
            {t.chat.quick.map((qr) => <button type="button" key={qr} onClick={() => setText(qr)}>{qr}</button>)}
          </div>
          <div className="box">
            <label className="sr" htmlFor="reply">{t.chat.placeholder}</label>
            <textarea
              id="reply"
              className="textarea"
              rows={1}
              value={text}
              placeholder={t.chat.placeholder}
              maxLength={1000}
              onChange={(e) => setText(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); if (text.trim()) send(); } }}
            />
            <button type="submit" className="btn primary" disabled={!text.trim()}><Icon name="send" />{t.common.send}</button>
          </div>
          <div className={`quiet${delivery.status === "queued" ? " on" : ""}`}>
            <Icon name={delivery.status === "queued" ? "moon" : "clock"} />
            {delivery.status === "queued" ? t.chat.quietNow(at(delivery.deliverAt)) : t.chat.liveNow}
            <span className="muted">· {t.chat.noPhones}</span>
          </div>
        </form>
      )}
    </div>
  );
}

function FragmentWith({ sep, children }: { sep: ReactNode; children: ReactNode }) {
  return <>{sep}{children}</>;
}

function FaqEditor() {
  const { store, t, run, version, locale } = useConsole();
  void version;
  const [faq, setFaq] = useState<Faq>(() => store.faq());
  const [q, setQ] = useState("");
  useEffect(() => setFaq(store.faq()), [store]);
  const key: FaqKey | null = q.trim() ? matchFaq(q, faq) : null;
  const answer = key === "contactName" ? t.chat.contactAnswer(faq.contactName) : key ? faq[key] : "";
  const phoneInContact = /\d{3,}/.test(faq.contactName);
  const fields: Array<[FaqKey, string, string?]> = [
    ["dressCode", t.chat.faqDress],
    ["entrance", t.chat.faqEntrance],
    ["breaks", t.chat.faqBreaks],
  ];
  return (
    <div className="faq-grid">
      <Panel title={t.chat.faqTitle} sub={t.chat.faqDesc}>
        <form className="panel-b stack" onSubmit={(e) => { e.preventDefault(); if (!phoneInContact) run(() => ({ ok: true as const, data: store.updateFaq(faq) }), t.chat.faqSaved); }}>
          {fields.map(([k, label]) => (
            <Field key={k} label={label} htmlFor={`faq-${k}`} hint={<span className="counter">{faq[k].length}/400</span>}>
              <textarea id={`faq-${k}`} className="textarea" rows={2} maxLength={400} value={faq[k]} onChange={(e) => setFaq({ ...faq, [k]: e.target.value })} />
            </Field>
          ))}
          <Field label={t.chat.faqContact} htmlFor="faq-contact" hint={t.chat.faqContactHint} error={phoneInContact ? t.errors.no_phone_numbers : undefined}>
            <input id="faq-contact" className="input" maxLength={40} value={faq.contactName} aria-invalid={phoneInContact} onChange={(e) => setFaq({ ...faq, contactName: e.target.value })} />
          </Field>
          <div className="row">
            <span className="spacer" />
            <button type="button" className="btn" onClick={() => setFaq(store.faq())}>{t.common.cancel}</button>
            <button type="submit" className="btn primary" disabled={phoneInContact}>{t.common.save}</button>
          </div>
        </form>
      </Panel>
      <Panel title={t.chat.tryTitle}>
        <div className="panel-b stack-sm">
          <label className="sr" htmlFor="faq-try">{t.chat.tryTitle}</label>
          <input id="faq-try" className="input" value={q} placeholder={t.chat.tryPh} onChange={(e) => setQ(e.target.value)} />
          {q.trim() ? (
            <div className={`try-result${key ? "" : " none"}`} aria-live="polite">
              {key ? <><small>{t.chat.tryAnswer} · {t.chat.faqKey[key]}</small>{answer}</> : t.chat.tryNone}
            </div>
          ) : null}
          <div className="row wrap" style={{ marginTop: 8 }}>
            {[t.chat.tryPh.replace(/^(e\.g\.|例：)\s*/, ""), locale === "ja" ? "休憩はありますか？" : "Is there a break?", locale === "ja" ? "どこから入ればいいですか？" : "Which entrance do I use?"].map((ex) => (
              <button type="button" className="chip" key={ex} onClick={() => setQ(ex)} style={{ cursor: "pointer" }}>{ex}</button>
            ))}
          </div>
        </div>
      </Panel>
    </div>
  );
}

