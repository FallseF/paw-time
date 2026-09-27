import type { ShiftView } from "@paw-time/shop-console";
import { Status } from "../../components/ui";
import type { Tone } from "../../components/ui";
import type { Dict } from "../../lib/i18n";
import { instantTime } from "../../lib/format";
import type { Locale } from "@paw-time/shop-console";

export function arrivalTone(s: ShiftView, now: Date): Tone {
  switch (s.status) {
    case "checked_out":
      return "good";
    case "checked_in":
      return s.minutesLate ? "warn" : "good";
    case "on_the_way":
      return "info";
    case "running_late":
      return "warn";
    case "no_show":
      return "bad";
    default:
      return now.getTime() > Date.parse(s.startAt) + 5 * 60_000 ? "warn" : "neutral";
  }
}

export function arrivalText(s: ShiftView, t: Dict, timeZone: string, locale: Locale): string {
  const time = (iso: string) => instantTime(iso, timeZone, locale);
  switch (s.status) {
    case "checked_out":
      return s.checkOutAt ? t.today.checkedOutAt(time(s.checkOutAt)) : t.shiftStatus.checked_out;
    case "checked_in":
      return s.checkInAt ? `${t.today.checkedInAt(time(s.checkInAt))}${s.minutesLate ? ` · ${t.today.lateBy(s.minutesLate)}` : ""}` : t.shiftStatus.checked_in;
    default:
      return t.shiftStatus[s.status];
  }
}

export function ArrivalPill({ shift, t, timeZone, locale, now }: { shift: ShiftView; t: Dict; timeZone: string; locale: Locale; now: Date }) {
  return <Status tone={arrivalTone(shift, now)}>{arrivalText(shift, t, timeZone, locale)}</Status>;
}
