import Image from "next/image";
import { useLayoutEffect, useRef } from "react";
import type { IslandView, LandmarkId, LandmarkView, PositiveTag } from "@paw-time/shop-console";
import renders from "../../public/island/island.json";

/** Landmark drawings in a 40×40 box, feet at y=36, centered on x=20. */
export function LandmarkGlyph({ id, dim }: { id: LandmarkId; dim?: boolean | undefined }) {
  const o = dim ? 0.35 : 1;
  switch (id) {
    case "clock_tower":
      return (
        <g opacity={o}>
          <rect x="13" y="12" width="14" height="24" rx="1.5" fill="#f3e2c8" stroke="#8a6a4a" strokeWidth="1" />
          <path d="M11 13 20 4l9 9z" fill="#c75b4a" stroke="#8a3a2e" strokeWidth="1" strokeLinejoin="round" />
          <circle cx="20" cy="19" r="4.6" fill="#fff8e6" stroke="#b7862f" strokeWidth="1.2" />
          <path d="M20 16.5V19l1.8 1.2" stroke="#3a3a3a" strokeWidth="1" fill="none" strokeLinecap="round" />
          <rect x="18" y="29" width="4" height="7" rx="1" fill="#8a6a4a" />
        </g>
      );
    case "rest_grove":
      return (
        <g opacity={o}>
          <rect x="11" y="22" width="3" height="14" rx="1" fill="#8a6a4a" />
          <circle cx="12.5" cy="17" r="8" fill="#6fb66a" stroke="#4a8a46" strokeWidth="1" />
          <circle cx="16" cy="13" r="4.5" fill="#86c77f" />
          <rect x="20" y="28" width="15" height="2.4" rx="1" fill="#b98552" />
          <rect x="21" y="30" width="2" height="6" fill="#8a6a4a" />
          <rect x="32" y="30" width="2" height="6" fill="#8a6a4a" />
          <rect x="20" y="24" width="15" height="2" rx="1" fill="#c99462" />
        </g>
      );
    case "guide_post":
      return (
        <g opacity={o}>
          <rect x="18.8" y="8" width="2.4" height="28" rx="1" fill="#8a6a4a" />
          <path d="M21 11h11l3 3-3 3H21z" fill="#f2c14e" stroke="#b7862f" strokeWidth="1" strokeLinejoin="round" />
          <path d="M19 19H8.5l-3 3 3 3H19z" fill="#7cc4e8" stroke="#3f8bb3" strokeWidth="1" strokeLinejoin="round" />
          <circle cx="20" cy="7.5" r="1.8" fill="#c75b4a" />
        </g>
      );
    case "payday_bell":
      return (
        <g opacity={o}>
          <path d="M8 36V12M32 36V12" stroke="#8a6a4a" strokeWidth="2.4" strokeLinecap="round" />
          <path d="M6 12.5c4-4.5 24-4.5 28 0" stroke="#8a6a4a" strokeWidth="2.4" fill="none" strokeLinecap="round" />
          <path d="M14 26c0-7 2.6-11 6-11s6 4 6 11l2 2H12z" fill="#f2c14e" stroke="#b7862f" strokeWidth="1" strokeLinejoin="round" />
          <circle cx="20" cy="30" r="1.8" fill="#b7862f" />
          <path d="M20 11v4" stroke="#8a6a4a" strokeWidth="1.2" />
        </g>
      );
    case "lantern_path":
      return (
        <g opacity={o}>
          <path d="M4 36c6-3 26-3 32 0" stroke="#d8c29a" strokeWidth="3" fill="none" strokeLinecap="round" />
          {[8, 20, 32].map((x, i) => (
            <g key={x} transform={`translate(${x} ${i === 1 ? -3 : 0})`}>
              <circle cx="0" cy="17" r="5.5" fill="#ffe3a6" opacity="0.55" />
              <rect x="-0.9" y="19" width="1.8" height="15" fill="#6b5a4a" />
              <rect x="-3" y="13.5" width="6" height="7" rx="1.5" fill="#ffd27a" stroke="#b7862f" strokeWidth="0.9" />
              <path d="M-3.5 13.5h7" stroke="#6b5a4a" strokeWidth="1.2" strokeLinecap="round" />
            </g>
          ))}
        </g>
      );
    case "fair_fountain":
      return (
        <g opacity={o}>
          <ellipse cx="20" cy="32" rx="15" ry="4.5" fill="#9fd0ec" stroke="#6ea9cc" strokeWidth="1" />
          <rect x="18.5" y="15" width="3" height="16" fill="#d9d4c8" />
          <path d="M9 17h9M22 17h9" stroke="#b5ada0" strokeWidth="1.6" strokeLinecap="round" />
          <path d="M9 17c0 3 9 3 9 0M22 17c0 3 9 3 9 0" fill="#9fd0ec" stroke="#6ea9cc" strokeWidth="1" />
          <circle cx="20" cy="11" r="2.4" fill="#9fd0ec" />
          <path d="M13.5 22v4M26.5 22v4" stroke="#9fd0ec" strokeWidth="1.4" strokeLinecap="round" strokeDasharray="1.5 2" />
        </g>
      );
    case "welcome_arch":
      return (
        <g opacity={o}>
          <path d="M8 36V20a12 12 0 0 1 24 0v16" fill="none" stroke="#8a6a4a" strokeWidth="3" />
          <path d="M8 36V20a12 12 0 0 1 24 0v16" fill="none" stroke="#7cc46a" strokeWidth="1.4" strokeDasharray="2 3" />
          {[[9, 18], [13, 11], [20, 8], [27, 11], [31, 18], [8, 26], [32, 26]].map(([x, y], i) => (
            <circle key={i} cx={x} cy={y} r="2.2" fill={["#ff8fb1", "#ffd24d", "#fff5f8"][i % 3]} stroke="rgba(0,0,0,0.12)" strokeWidth="0.6" />
          ))}
        </g>
      );
  }
}

/**
 * Renders of the game's own shop island (apps/worker/tools/render_shop_island.gd), one per island the
 * console can show. An island only uses a render whose landmarks match its own levels exactly, so the
 * picture never shows a landmark the shop has not earned; anything else falls back to the bare island.
 */
type Render = { levels: Record<string, string>; pins: Record<string, [number, number]>; stage: number };
const RENDERS = renders as unknown as Record<string, Render>;

type Box = { l: number; t: number; r: number; b: number };
const GAP = 3;
const hits = (a: Box, b: Box) => a.l < b.r + GAP && b.l < a.r + GAP && a.t < b.b + GAP && b.t < a.b + GAP;
/** Offsets to try for a pin, nearest first; moving up (a longer stem) is cheaper than moving sideways. */
const NUDGES: Array<[number, number]> = [];
for (let dy = 0; dy <= 96; dy += 4) {
  for (let dx = -72; dx <= 72; dx += 6) NUDGES.push([dx, -dy]);
}
NUDGES.sort((a, b) => Math.abs(a[0]) * 1.6 + Math.abs(a[1]) - (Math.abs(b[0]) * 1.6 + Math.abs(b[1])));

/**
 * Name tags are placed over the landmarks, but at some widths two tags land on top of each other.
 * After layout, keep the lowest tag (nearest to the viewer) in place and nudge each tag above it
 * to the nearest free spot inside the picture, stretching its stem so it still points at its landmark.
 */
function useUnoverlap(ref: React.RefObject<HTMLElement | null>, deps: string) {
  useLayoutEffect(() => {
    const fig = ref.current;
    if (!fig) return;
    const place = () => {
      const pins = [...fig.querySelectorAll<HTMLElement>(".island-pin")];
      pins.forEach((p) => { p.style.setProperty("--dx", "0px"); p.style.setProperty("--dy", "0px"); });
      const f = fig.getBoundingClientRect();
      const sign = fig.querySelector<HTMLElement>(".island-sign")?.getBoundingClientRect();
      const placed: Box[] = sign ? [{ l: sign.left, t: sign.top, r: sign.right, b: sign.bottom }] : [];
      for (const p of pins.reverse()) {
        const r = p.getBoundingClientRect();
        if (r.width === 0) continue;
        const at = NUDGES.find(([dx, dy]) => {
          const b = { l: r.left + dx, t: r.top + dy, r: r.right + dx, b: r.bottom + dy };
          return b.l >= f.left + 2 && b.r <= f.right - 2 && b.t >= f.top + 2 && !placed.some((q) => hits(b, q));
        }) ?? [0, 0];
        p.style.setProperty("--dx", `${at[0]}px`);
        p.style.setProperty("--dy", `${at[1]}px`);
        placed.push({ l: r.left + at[0], t: r.top + at[1], r: r.right + at[0], b: r.bottom + at[1] });
      }
    };
    place();
    const ro = new ResizeObserver(place);
    ro.observe(fig);
    return () => ro.disconnect();
  }, [ref, deps]);
}

function levelKey(lm: LandmarkView): string {
  return lm.sprout ? "s" : String(lm.level);
}

function pickRender(island: IslandView): [string, Render] {
  for (const [key, r] of Object.entries(RENDERS)) {
    if (island.landmarks.every((lm) => r.levels[lm.id] === levelKey(lm))) return [key, r];
  }
  return ["bare", RENDERS.bare!];
}

export function IslandArt({ island, shopName, signColor, compact, labels, tags, note }: {
  island: IslandView;
  shopName: string;
  signColor: string;
  compact?: boolean;
  labels: Record<LandmarkId, string>;
  tags?: Record<PositiveTag, string> | undefined;
  note?: string | undefined;
}) {
  const [key, render] = pickRender(island);
  const titleText = island.landmarks.map((l) => `${labels[l.id]} ${l.level}`).join(", ");
  const shopPin = render.pins.shop;
  const pinned = island.landmarks
    .filter((lm) => lm.level > 0 && render.pins[lm.id])
    .sort((a, b) => render.pins[a.id]![1] - render.pins[b.id]![1]);
  const figRef = useRef<HTMLElement>(null);
  useUnoverlap(figRef, `${key}|${pinned.map((l) => labels[l.id]).join("|")}|${tags ? "t" : ""}|${shopName}`);
  return (
    <figure ref={figRef} className={`island-v2${compact ? " compact" : ""}`} role="img" aria-label={`${shopName}: ${titleText}`}>
      <Image
        src={`/island/island-${key}-1600.webp`}
        alt=""
        width={1600}
        height={1000}
        sizes={compact ? "(max-width: 900px) 100vw, 420px" : "(max-width: 900px) 100vw, 760px"}
        priority={!compact}
      />
      {shopPin ? (
        <span className="island-sign" style={{ left: `${shopPin[0] * 100}%`, top: `${shopPin[1] * 100}%`, background: signColor }}>
          {shopName}
        </span>
      ) : null}
      {!compact
        ? pinned.map((lm) => {
            const [x, y] = render.pins[lm.id]!;
            return (
              // Tall landmarks reach the top edge; keep their name tag inside the picture.
              <span key={lm.id} className="island-pin" style={{ left: `${x * 100}%`, top: `${Math.max(y, 0.11) * 100}%` }}>
                <b>{labels[lm.id]}</b>
                {tags ? <i>{tags[lm.tag]}</i> : null}
              </span>
            );
          })
        : null}
      {note ? <span className="island-note">{note}</span> : null}
    </figure>
  );
}

export function LevelBar({ level, sprout }: { level: number; sprout?: boolean | undefined }) {
  return (
    <span className={`pips${sprout ? " sprout" : ""}`} aria-hidden="true">
      {[0, 1, 2].map((i) => <i key={i} className={i < level ? "on" : undefined} />)}
    </span>
  );
}

export function LandmarkIcon({ id, dim }: { id: LandmarkId; dim?: boolean | undefined }) {
  return (
    <span className="lm-ic">
      <svg viewBox="0 0 40 40" aria-hidden="true"><LandmarkGlyph id={id} dim={dim} /></svg>
    </span>
  );
}
