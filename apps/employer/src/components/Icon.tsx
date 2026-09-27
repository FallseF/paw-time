import type { SVGProps } from "react";

/** 16px line icons, 1.5 stroke. One set so every page looks the same. */
const PATHS = {
  home: "M2.5 7.2 8 2.8l5.5 4.4V13a.5.5 0 0 1-.5.5H9.5V10h-3v3.5H3a.5.5 0 0 1-.5-.5z",
  briefcase: "M2 5.5h12v7a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1zM5.5 5.5V4a1 1 0 0 1 1-1h3a1 1 0 0 1 1 1v1.5M2 8.5h12",
  users: "M6 7.5a2.25 2.25 0 1 0 0-4.5 2.25 2.25 0 0 0 0 4.5zM1.5 13.5c0-2.2 2-3.8 4.5-3.8s4.5 1.6 4.5 3.8M11 3.2a2.2 2.2 0 0 1 0 4.2M12.2 9.9c1.4.4 2.3 1.6 2.3 3.1",
  calendar: "M2.5 4h11v9.5h-11zM2.5 7h11M5.5 2.5v3M10.5 2.5v3",
  chat: "M2.5 3.5h11v7h-6l-3 2.5v-2.5h-2z",
  island: "M1.5 12.5c2 0 2-1 4-1s2 1 4 1 2-1 4-1M4 10.5c.5-2.5 2.2-4 4.5-4s3.5 1.5 4 4M8 6.5V3M8 3c1.3-.8 2.7-.8 3.5.2M8 3c-1.3-.8-2.7-.8-3.5.2",
  send: "M2 8l12-5.5L10 14l-2.2-4.2zM7.8 9.8 14 2.5",
  mail: "M2 4h12v8.5H2zM2 4.5l6 4.5 6-4.5",
  settings: "M8 10a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM8 1.5v1.8M8 12.7v1.8M3.4 3.4l1.3 1.3M11.3 11.3l1.3 1.3M1.5 8h1.8M12.7 8h1.8M3.4 12.6l1.3-1.3M11.3 4.7l1.3-1.3",
  plus: "M8 3v10M3 8h10",
  check: "M3 8.5 6.5 12 13 4.5",
  x: "M4 4l8 8M12 4l-8 8",
  clock: "M8 14A6 6 0 1 0 8 2a6 6 0 0 0 0 12zM8 4.5V8l2.5 1.5",
  alert: "M8 2 14.5 13.5h-13zM8 6.5v3.2M8 11.6v.1",
  info: "M8 14A6 6 0 1 0 8 2a6 6 0 0 0 0 12zM8 7.2v4M8 5v.1",
  chevronLeft: "M10 3 5 8l5 5",
  chevronRight: "M6 3l5 5-5 5",
  chevronDown: "M3.5 6 8 10.5 12.5 6",
  search: "M7 12A5 5 0 1 0 7 2a5 5 0 0 0 0 10zM10.6 10.6 14 14",
  menu: "M2 4h12M2 8h12M2 12h12",
  flag: "M3.5 14V2.5M3.5 3h8l-1.8 3 1.8 3h-8",
  block: "M8 14A6 6 0 1 0 8 2a6 6 0 0 0 0 12zM3.8 3.8l8.4 8.4",
  more: "M3.5 8h.1M8 8h.1M12.5 8h.1",
  moon: "M13 9.5A5.5 5.5 0 0 1 6.5 3a5.5 5.5 0 1 0 6.5 6.5z",
  bolt: "M9 1.5 3.5 9H8l-1 5.5L12.5 7H8z",
  edit: "M10.5 2.5l3 3-8 8H2.5v-3zM9 4l3 3",
  trash: "M2.5 4h11M6 4V2.5h4V4M4 4l.7 9.5h6.6L12 4",
  lock: "M4 7h8v6.5H4zM5.5 7V5a2.5 2.5 0 0 1 5 0v2",
  arrowRight: "M2.5 8h11M9 3.5 13.5 8 9 12.5",
  swap: "M2.5 5.5h10l-2.5-2.5M13.5 10.5h-10L6 13",
  sparkle: "M8 2v3M8 11v3M2 8h3M11 8h3M4 4l1.8 1.8M10.2 10.2 12 12M12 4l-1.8 1.8M5.8 10.2 4 12",
  eye: "M1.5 8S4 3.5 8 3.5 14.5 8 14.5 8 12 12.5 8 12.5 1.5 8 1.5 8zM8 10a2 2 0 1 0 0-4 2 2 0 0 0 0 4z",
  link: "M6.5 9.5l3-3M5 11 3.8 12.2a2 2 0 0 1-2.8-2.8L4.6 5.8a2 2 0 0 1 2.8 0M11 5l1.2-1.2a2 2 0 0 1 2.8 2.8l-3.6 3.6a2 2 0 0 1-2.8 0",
  shield: "M8 1.8 13 3.5v4c0 3.2-2.2 5.5-5 6.7-2.8-1.2-5-3.5-5-6.7v-4z",
  heart: "M8 13.5S2 10 2 6a3 3 0 0 1 6-1 3 3 0 0 1 6 1c0 4-6 7.5-6 7.5z",
  reset: "M2.5 8a5.5 5.5 0 1 0 1.6-3.9M2.5 2.5v3h3",
  list: "M5.5 4h8M5.5 8h8M5.5 12h8M2.5 4h.1M2.5 8h.1M2.5 12h.1",
  download: "M8 2.5v8M4.5 7 8 10.5 11.5 7M2.5 13.5h11",
  chart: "M2.5 13.5h11M4.5 11.5v-4M8 11.5v-8M11.5 11.5v-5.5",
  grid: "M2.5 2.5h4.5V7H2.5zM9 2.5h4.5V7H9zM2.5 9h4.5v4.5H2.5zM9 9h4.5v4.5H9z",
} as const;

export type IconName = keyof typeof PATHS;

export function Icon({ name, ...props }: { name: IconName } & SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}>
      <path d={PATHS[name]} />
    </svg>
  );
}
