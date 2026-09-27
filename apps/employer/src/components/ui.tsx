"use client";

import { useEffect, useId, useRef, useState } from "react";
import type { ReactNode } from "react";
import { Icon } from "./Icon";
import type { IconName } from "./Icon";

export function PageHead({ title, desc, actions, crumb }: { title: string; desc?: string | undefined; actions?: ReactNode | undefined; crumb?: ReactNode | undefined }) {
  return (
    <header className="page-head">
      <div>
        {crumb ? <div className="crumb">{crumb}</div> : null}
        <h1>{title}</h1>
        {desc ? <p className="desc">{desc}</p> : null}
      </div>
      {actions ? <div className="page-actions">{actions}</div> : null}
    </header>
  );
}

export function Panel({ title, sub, actions, children, footer, className, id }: { title?: ReactNode | undefined; sub?: ReactNode | undefined; actions?: ReactNode | undefined; children: ReactNode; footer?: ReactNode | undefined; className?: string | undefined; id?: string | undefined }) {
  return (
    <section className={`panel${className ? ` ${className}` : ""}`} id={id} aria-label={typeof title === "string" ? title : undefined}>
      {title ? (
        <div className="panel-h">
          <h2>{title}</h2>
          {sub ? <span className="sub">{sub}</span> : null}
          {actions ? <div className="row" style={{ marginLeft: "auto" }}>{actions}</div> : null}
        </div>
      ) : null}
      {children}
      {footer ? <div className="panel-f">{footer}</div> : null}
    </section>
  );
}

export function Empty({ icon = "info", title, body, action }: { icon?: IconName | undefined; title: string; body?: string | undefined; action?: ReactNode | undefined }) {
  return (
    <div className="empty" role="status">
      <div className="empty-ic"><Icon name={icon} /></div>
      <strong>{title}</strong>
      {body ? <p>{body}</p> : null}
      {action}
    </div>
  );
}

export function Skeleton({ rows = 4 }: { rows?: number | undefined }) {
  return (
    <div className="skel-page" aria-busy="true">
      <span className="skel" style={{ width: 180, height: 20 }} />
      <span className="skel" style={{ width: "60%" }} />
      <div className="panel" style={{ padding: 16, display: "grid", gap: 16 }}>
        {Array.from({ length: rows }, (_, i) => (
          <div className="row" key={i} style={{ gap: 24 }}>
            <span className="skel" style={{ width: "18%" }} />
            <span className="skel" style={{ width: "30%" }} />
            <span className="skel" style={{ width: "12%" }} />
            <span className="skel" style={{ width: "20%" }} />
          </div>
        ))}
      </div>
    </div>
  );
}

export type Tone = "good" | "warn" | "bad" | "info" | "neutral";
export function Status({ tone, children, plain }: { tone: Tone; children: ReactNode; plain?: boolean | undefined }) {
  return <span className={`status st-${tone}${plain ? " plain" : ""}`}>{children}</span>;
}

export function SampleBadge({ label }: { label: string }) {
  return <span className="badge synth">{label}</span>;
}

export function Segmented<T extends string>({ value, options, onChange, label }: { value: T; options: Array<{ value: T; label: ReactNode; count?: number | undefined }>; onChange: (v: T) => void; label: string }) {
  return (
    <div className="seg" role="group" aria-label={label}>
      {options.map((o) => (
        <button type="button" key={o.value} aria-pressed={value === o.value} onClick={() => onChange(o.value)}>
          {o.label}
          {o.count !== undefined ? <span className="cnt">{o.count}</span> : null}
        </button>
      ))}
    </div>
  );
}

export function Tabs<T extends string>({ value, options, onChange, label }: { value: T; options: Array<{ value: T; label: ReactNode }>; onChange: (v: T) => void; label: string }) {
  return (
    <div className="tabs" role="tablist" aria-label={label}>
      {options.map((o) => (
        <button type="button" role="tab" key={o.value} aria-selected={value === o.value} onClick={() => onChange(o.value)}>
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function Search({ value, onChange, placeholder }: { value: string; onChange: (v: string) => void; placeholder: string }) {
  return (
    <label className="search">
      <Icon name="search" />
      <span className="sr">{placeholder}</span>
      <input type="search" value={value} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} />
    </label>
  );
}

export function Field({ label, hint, error, ok, children, htmlFor, className }: { label: ReactNode; hint?: ReactNode | undefined; error?: ReactNode | undefined; ok?: ReactNode | undefined; children: ReactNode; htmlFor?: string | undefined; className?: string | undefined }) {
  return (
    <div className={`field${className ? ` ${className}` : ""}`}>
      <label htmlFor={htmlFor}>{label}</label>
      {children}
      {error ? <span className="err" role="alert"><Icon name="alert" />{error}</span> : ok ? <span className="ok"><Icon name="check" />{ok}</span> : hint ? <span className="hint">{hint}</span> : null}
    </div>
  );
}

export function Switch({ checked, onChange, label, sub }: { checked: boolean; onChange: (v: boolean) => void; label: string; sub?: string | undefined }) {
  return (
    <label className="switch">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      <span className="track"><span className="thumb" /></span>
      <span className="sw-text">{label}{sub ? <small>{sub}</small> : null}</span>
    </label>
  );
}

export function Progress({ value, max, label, tone }: { value: number; max: number; label?: string | undefined; tone?: "good" | undefined }) {
  const pct = max > 0 ? Math.min(100, Math.round((value / max) * 100)) : 0;
  return (
    <div className="progress">
      <div className={`bar${tone ? ` ${tone}` : ""}`} role="progressbar" aria-valuenow={value} aria-valuemin={0} aria-valuemax={max} aria-label={label}>
        <i style={{ width: `${pct}%` }} />
      </div>
      <span>{label ?? `${value} / ${max}`}</span>
    </div>
  );
}

/** Keeps Tab inside an open sheet or dialog, closes on Escape, and restores focus after. */
function useModal(open: boolean, onClose: () => void) {
  const ref = useRef<HTMLDivElement>(null);
  const close = useRef(onClose);
  close.current = onClose;
  useEffect(() => {
    if (!open) return;
    const before = document.activeElement as HTMLElement | null;
    const node = ref.current;
    const focusables = () => Array.from(node?.querySelectorAll<HTMLElement>('button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])') ?? []);
    const first = node?.querySelector<HTMLElement>("[data-autofocus]") ?? focusables()[1] ?? focusables()[0];
    first?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.stopPropagation();
        close.current();
      } else if (e.key === "Tab") {
        const list = focusables();
        if (!list.length) return;
        const a = list[0] as HTMLElement;
        const z = list[list.length - 1] as HTMLElement;
        if (e.shiftKey && document.activeElement === a) { e.preventDefault(); z.focus(); }
        else if (!e.shiftKey && document.activeElement === z) { e.preventDefault(); a.focus(); }
      }
    };
    document.addEventListener("keydown", onKey);
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = overflow;
      before?.focus?.();
    };
  }, [open]);
  return ref;
}

export function Sheet({ open, onClose, title, kicker, children, footer, closeLabel }: { open: boolean; onClose: () => void; title: ReactNode; kicker?: ReactNode | undefined; children: ReactNode; footer?: ReactNode | undefined; closeLabel: string }) {
  const ref = useModal(open, onClose);
  const id = useId();
  if (!open) return null;
  return (
    <>
      <div className="overlay" onClick={onClose} aria-hidden="true" />
      <div className="sheet" role="dialog" aria-modal="true" aria-labelledby={id} ref={ref}>
        <div className="sheet-h">
          <div style={{ minWidth: 0 }}>
            {kicker ? <div className="kicker">{kicker}</div> : null}
            <h2 id={id}>{title}</h2>
          </div>
          <span className="spacer" />
          <button type="button" className="icon-btn" onClick={onClose} aria-label={closeLabel}><Icon name="x" /></button>
        </div>
        <div className="sheet-b">{children}</div>
        {footer ? <div className="sheet-f">{footer}</div> : null}
      </div>
    </>
  );
}

export function Dialog({ open, onClose, title, children, footer, closeLabel, wide }: { open: boolean; onClose: () => void; title: ReactNode; children: ReactNode; footer?: ReactNode | undefined; closeLabel: string; wide?: boolean | undefined }) {
  const ref = useModal(open, onClose);
  const id = useId();
  if (!open) return null;
  return (
    <>
      <div className="overlay" onClick={onClose} aria-hidden="true" />
      <div className={`dialog${wide ? " wide" : ""}`} role="dialog" aria-modal="true" aria-labelledby={id} ref={ref}>
        <div className="sheet-h">
          <h2 id={id}>{title}</h2>
          <span className="spacer" />
          <button type="button" className="icon-btn" onClick={onClose} aria-label={closeLabel}><Icon name="x" /></button>
        </div>
        <div className="sheet-b">{children}</div>
        {footer ? <div className="sheet-f">{footer}</div> : null}
      </div>
    </>
  );
}

export function Menu({ label, items }: { label: string; items: Array<{ label: string; icon?: IconName | undefined; onSelect: () => void; danger?: boolean | undefined; hidden?: boolean | undefined }> }) {
  const [open, setOpen] = useState(false);
  const wrap = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => { if (!wrap.current?.contains(e.target as Node)) setOpen(false); };
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
    document.addEventListener("mousedown", onDoc);
    document.addEventListener("keydown", onKey);
    wrap.current?.querySelector<HTMLElement>(".menu button")?.focus();
    return () => { document.removeEventListener("mousedown", onDoc); document.removeEventListener("keydown", onKey); };
  }, [open]);
  return (
    <div className="menu-wrap" ref={wrap}>
      <button type="button" className="icon-btn" aria-label={label} aria-haspopup="menu" aria-expanded={open} onClick={(e) => { e.stopPropagation(); setOpen((v) => !v); }}>
        <Icon name="more" />
      </button>
      {open ? (
        <div className="menu" role="menu">
          {items.filter((i) => !i.hidden).map((i) => (
            <button type="button" role="menuitem" key={i.label} className={i.danger ? "danger" : undefined} onClick={(e) => { e.stopPropagation(); setOpen(false); i.onSelect(); }}>
              {i.icon ? <Icon name={i.icon} /> : null}
              {i.label}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}
