/** A small cat-obake face: the worker's companion, or the shop's cat (with a collar in the sign color). */
export function Cat({ color, size = 32, shop, label }: { color: string; size?: number | undefined; shop?: string | undefined; label?: string | undefined }) {
  const dark = isDark(color);
  const ink = dark ? "#fff" : "#2b2f38";
  return (
    <svg className="cat" width={size} height={size} viewBox="0 0 40 40" role={label ? "img" : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
      <circle cx="20" cy="20" r="20" fill={shop ? tint(shop, 0.82) : "var(--surface-2)"} />
      <path
        d="M9.5 20c0-5 .8-9.6 2-13l5 4.3c2.3-.7 4.7-.7 7 0l5-4.3c1.2 3.4 2 8 2 13v10.5c-1.6 2.6-3.4 2.6-5 0-1.6 2.6-3.4 2.6-5 0-1.6 2.6-3.4 2.6-5 0-1.6 2.6-3.4 2.6-5 0z"
        fill={color}
        stroke="rgba(0,0,0,0.16)"
        strokeWidth="1"
        strokeLinejoin="round"
      />
      <ellipse cx="16" cy="20" rx="1.5" ry="1.9" fill={ink} />
      <ellipse cx="24" cy="20" rx="1.5" ry="1.9" fill={ink} />
      <circle cx="13.6" cy="23.2" r="1.5" fill="#f28c9b" opacity="0.45" />
      <circle cx="26.4" cy="23.2" r="1.5" fill="#f28c9b" opacity="0.45" />
      <path d="M18.4 23.4c.5.7 1.1.7 1.6 0 .5.7 1.1.7 1.6 0" fill="none" stroke={ink} strokeWidth="0.9" strokeLinecap="round" />
      {shop ? (
        <>
          <path d="M12 27.2c5 2 11 2 16 0" fill="none" stroke={shop} strokeWidth="2.2" strokeLinecap="round" />
          <circle cx="20" cy="29.4" r="1.6" fill="#f2c14e" stroke="rgba(0,0,0,0.2)" strokeWidth="0.6" />
        </>
      ) : null}
    </svg>
  );
}

function rgb(hex: string): [number, number, number] {
  const h = hex.replace("#", "");
  const n = parseInt(h.length === 3 ? h.split("").map((c) => c + c).join("") : h, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function isDark(hex: string): boolean {
  const [r, g, b] = rgb(hex);
  return 0.299 * r + 0.587 * g + 0.114 * b < 110;
}

/** Mix a color toward white. */
export function tint(hex: string, amount: number): string {
  const [r, g, b] = rgb(hex);
  const m = (c: number) => Math.round(c + (255 - c) * amount);
  return `rgb(${m(r)}, ${m(g)}, ${m(b)})`;
}
