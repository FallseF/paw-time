// URL parameters the dashboard accepts on load. Pure, so the game's links can be tested.
//   ?mode=live|simulated|sim  ?lang=en|ja  ?demo=1|0  ?live=1 / ?drawer=live  ?view=<saved view id>
// The game's demo ends on ?mode=sim&view=at-risk&drawer=live&demo=1&lang=en|ja: the rich simulated
// tables, with the judge's own demo actions arriving in the live drawer beside them.
import { VIEWS, type ViewId } from "./model";

export interface LaunchParams {
  mode: "simulated" | "live" | undefined;
  lang: "en" | "ja" | undefined;
  /** demo=1: only demo sessions in the live drawer; demo=0 turns that off. */
  demoOnly: boolean | undefined;
  /** Open the live activity drawer. */
  liveOpen: boolean;
  view: ViewId | undefined;
}

export function launchParams(search: string): LaunchParams {
  const q = new URLSearchParams(search);
  const mode = q.get("mode");
  const lang = q.get("lang");
  const demo = q.get("demo");
  const view = q.get("view");
  return {
    mode: mode === "live" ? "live" : mode === "simulated" || mode === "sim" ? "simulated" : undefined,
    lang: lang === "en" || lang === "ja" ? lang : undefined,
    demoOnly: demo === "1" ? true : demo === "0" ? false : undefined,
    // The game's older link ?mode=live&lang=en&demo=1 also opens the drawer right away.
    liveOpen: demo === "1" || q.get("live") === "1" || q.get("drawer") === "live",
    view: VIEWS.some((v) => v.id === view) ? (view as ViewId) : undefined,
  };
}
