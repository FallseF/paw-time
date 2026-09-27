import { toCsv } from "@paw-time/shop-console";
import type { PayLine, ShopConsoleStore } from "@paw-time/shop-console";
import { instantTime } from "../../lib/format";
import type { Dict } from "../../lib/i18n";

/**
 * One month of attendance and pay lines as CSV, built in the browser from the store.
 * Every shift of the month is a row, no-shows included at zero pay. Only shift facts:
 * no rating, score or punctuality columns.
 */
export function attendanceCsv(store: ShopConsoleStore, month: string, t: Dict): string {
  const payroll = store.monthPayroll(month);
  const lines = new Map<string, PayLine>(payroll.lines.map((l) => [l.shiftId, l]));
  const shifts = store.shifts(`${month}-01`, `${month}-31`);
  const c = t.shifts.csv;
  const kind = { confirmed: t.payroll.confirmed, awaiting: t.payroll.awaiting, forecast: t.payroll.forecast };
  // 24-hour "HH:MM" in the shop's time zone, like the scheduled times, whatever the language.
  const time = (iso: string | null) => (iso ? instantTime(iso, store.timeZone, "ja") : "");
  const rows: Array<Array<string | number>> = [
    [c.date, c.worker, c.job, c.plannedStart, c.plannedEnd, c.checkIn, c.checkOut, c.status, c.payStatus, c.onSite, c.breakMin, c.paidMin, c.wage, c.amount, c.currency, c.corrections, c.reasons],
  ];
  for (const s of shifts) {
    const line = lines.get(s.id);
    const log = store.attendanceLog(s.id).filter((e) => e.kind === "correction" || e.kind === "no_show").reverse();
    rows.push([
      s.date,
      s.displayName,
      s.jobTitle,
      s.start,
      s.end,
      time(s.checkInAt),
      time(s.checkOutAt),
      t.shiftStatus[s.status],
      line ? kind[line.kind] : "",
      line?.spanMinutes ?? 0,
      line?.breakMinutes ?? 0,
      line?.paidMinutes ?? 0,
      line?.wage ?? store.job(s.jobId)?.wage ?? "",
      line?.amount ?? 0,
      payroll.currency,
      log.filter((e) => e.kind === "correction").length,
      log.map((e) => e.reason ?? "").filter(Boolean).join(" / "),
    ]);
  }
  return toCsv(rows);
}

/** Saves the text as a file through a temporary link; nothing leaves the browser. */
export function downloadCsv(csv: string, filename: string): void {
  const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}
