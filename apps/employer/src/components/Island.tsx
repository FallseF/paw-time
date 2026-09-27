import type { IslandView, LandmarkId, LandmarkView } from "@paw-time/shop-console";

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

function Sprout() {
  return (
    <g>
      <ellipse cx="20" cy="35" rx="6" ry="2" fill="#8a6a4a" opacity="0.6" />
      <path d="M20 35v-7" stroke="#4a8a46" strokeWidth="1.4" />
      <path d="M20 29c-3-1-5-3-5-5 3 0 5 2 5 5zM20 29c3-1 5-3 5-5-3 0-5 2-5 5z" fill="#86c77f" stroke="#4a8a46" strokeWidth="0.8" />
    </g>
  );
}

function Placeholder() {
  return <ellipse cx="20" cy="34" rx="9" ry="3" fill="none" stroke="rgba(0,0,0,0.18)" strokeDasharray="2 2" />;
}

/** Island slots: back row, front row, and the pier for the welcome-back arch. */
const SLOTS: Record<LandmarkId, [number, number]> = {
  clock_tower: [150, 168],
  fair_fountain: [468, 168],
  lantern_path: [98, 222],
  rest_grove: [212, 272],
  guide_post: [320, 286],
  payday_bell: [428, 272],
  welcome_arch: [556, 226],
};

export function IslandArt({ island, shopName, signColor, compact, labels }: {
  island: IslandView;
  shopName: string;
  signColor: string;
  compact?: boolean;
  labels: Record<LandmarkId, string>;
}) {
  const titleText = island.landmarks.map((l) => `${labels[l.id]} ${l.level}`).join(", ");
  return (
    <svg viewBox="0 0 640 330" className="island-mini" role="img" aria-label={`${shopName}: ${titleText}`}>
      <defs>
        <linearGradient id="sea" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="var(--sea)" />
          <stop offset="1" stopColor="var(--sea-2)" />
        </linearGradient>
      </defs>
      <rect width="640" height="330" rx="12" fill="url(#sea)" />
      {[[60, 60], [560, 70], [590, 290], [40, 280]].map(([x, y], i) => (
        <path key={i} d={`M${x} ${y}q8 -6 16 0t16 0`} stroke="#fff" strokeOpacity="0.6" strokeWidth="2" fill="none" strokeLinecap="round" />
      ))}
      {/* pier */}
      <rect x="548" y="226" width="70" height="10" rx="2" fill="#b98552" />
      {[556, 576, 596, 612].map((x) => <rect key={x} x={x} y="234" width="4" height="16" fill="#8a6a4a" />)}
      {/* island */}
      <path d="M58 214c-6-52 58-104 150-114 60-7 110-14 170-8 104 10 184 50 190 110 6 56-70 94-250 96-176 2-254-30-260-84z" fill="var(--sand)" />
      <path d="M78 206c-4-44 54-88 136-96 56-6 104-12 160-6 94 9 164 42 170 94 5 44-64 76-232 78-164 2-230-28-234-70z" fill="var(--grass)" />
      <path d="M150 128c40-14 110-20 170-18 60 2 118 12 152 26" stroke="var(--grass-2)" strokeWidth="10" strokeLinecap="round" fill="none" opacity="0.5" />
      {/* the shop on the hill */}
      <g transform="translate(262 38)">
        <rect x="8" y="40" width="100" height="48" rx="3" fill="#fff6ea" stroke="rgba(0,0,0,0.12)" />
        <path d="M0 42 58 12l58 30z" fill={signColor} stroke="rgba(0,0,0,0.18)" strokeLinejoin="round" />
        {Array.from({ length: 8 }, (_, i) => (
          <rect key={i} x={8 + i * 12.5} y="46" width="12.5" height="9" fill={i % 2 ? "#fdf7ee" : signColor} />
        ))}
        <rect x="18" y="60" width="30" height="18" rx="2" fill="#ffe9b8" stroke="rgba(0,0,0,0.12)" />
        <rect x="70" y="60" width="20" height="28" rx="2" fill="#b98552" />
        <rect x="16" y="-4" width="84" height="20" rx="4" fill={signColor} stroke="rgba(0,0,0,0.15)" />
        <text x="58" y="10" textAnchor="middle" fontSize="11" fontWeight="600" fill="#fff" fontFamily="var(--font)">{shopName.length > 16 ? `${shopName.slice(0, 15)}…` : shopName}</text>
      </g>
      {island.landmarks.map((lm) => {
        const [x, y] = SLOTS[lm.id];
        const scale = lm.level === 3 ? 2.5 : lm.level === 2 ? 2.1 : lm.level === 1 ? 1.7 : 1.3;
        return (
          <g key={lm.id} transform={`translate(${x - 20 * scale} ${y - 36 * scale}) scale(${scale})`}>
            <title>{`${labels[lm.id]} · ${lm.votes}`}</title>
            <ellipse cx="20" cy="36" rx="12" ry="3" fill="rgba(0,0,0,0.12)" />
            {lm.level > 0 ? <LandmarkGlyph id={lm.id} /> : lm.sprout ? <Sprout /> : <Placeholder />}
          </g>
        );
      })}
      {!compact
        ? island.landmarks.map((lm) => {
            const [x, y] = SLOTS[lm.id];
            return <LevelPips key={lm.id} x={x} y={y + 8} lm={lm} />;
          })
        : null}
    </svg>
  );
}

function LevelPips({ x, y, lm }: { x: number; y: number; lm: LandmarkView }) {
  return (
    <g transform={`translate(${x - 19} ${y})`}>
      <rect x="-3" y="-3" width="44" height="12" rx="6" fill="rgba(255,255,255,0.85)" />
      {[0, 1, 2].map((i) => (
        <rect key={i} x={i * 13 + 1} y="0" width="10" height="6" rx="3" fill={i < lm.level ? "#3f9e8f" : "#d5dbe3"} />
      ))}
    </g>
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
