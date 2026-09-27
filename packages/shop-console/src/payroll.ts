/**
 * Labor cost for a month, computed from the shifts and punches the store already has.
 * Pure functions: the labor cost page, the month-close summary and the CSV export all use them.
 * Only shift facts and totals: nothing here scores or ranks a worker.
 */
import type { Currency, ShiftStatus, ShiftView } from "./types";

/**
 * confirmed = checked in and out; awaiting = the shift has started but a punch is missing;
 * forecast = not started yet, priced from the schedule.
 */
export type PayKind = "confirmed" | "awaiting" | "forecast";

/** Labor Standards Act art. 34: at least 45 min of break over 6 h, 60 min over 8 h. */
export const BREAK_RULES: ReadonlyArray<{ workedOver: number; requiredBreak: number }> = [
  { workedOver: 8 * 60, requiredBreak: 60 },
  { workedOver: 6 * 60, requiredBreak: 45 },
];

/** Minimum unpaid break for a shift of this length (minutes on site). */
export function legalBreakMinutes(minutes: number): number {
  return BREAK_RULES.find((rule) => minutes > rule.workedOver)?.requiredBreak ?? 0;
}

/** Money rounded the way it is paid: whole yen, or cents. */
export function roundMoney(amount: number, currency: Currency): number {
  return currency === "JPY" ? Math.round(amount) : Math.round(amount * 100) / 100;
}

export type PayLine = {
  shiftId: string;
  date: string;
  workerId: string;
  displayName: string;
  jobId: string;
  jobTitle: string;
  start: string;
  end: string;
  status: ShiftStatus;
  checkInAt: string | null;
  checkOutAt: string | null;
  corrected: boolean;
  kind: PayKind;
  /** Minutes on site (actual when punched, scheduled otherwise). */
  spanMinutes: number;
  /** Legal minimum break taken out of the span. */
  breakMinutes: number;
  paidMinutes: number;
  wage: number;
  amount: number;
};

const minutesBetween = (from: string, to: string) => Math.max(0, Math.round((Date.parse(to) - Date.parse(from)) / 60_000));

/** What one shift costs, or null for a no-show (nothing is paid). */
export function payLine(shift: ShiftView, wage: number, currency: Currency, now: Date): PayLine | null {
  if (shift.status === "no_show") return null;
  let kind: PayKind;
  let spanMinutes: number;
  if (shift.checkInAt && shift.checkOutAt) {
    kind = "confirmed";
    spanMinutes = minutesBetween(shift.checkInAt, shift.checkOutAt);
  } else if (shift.checkInAt) {
    kind = "awaiting";
    spanMinutes = minutesBetween(shift.checkInAt, shift.endAt);
  } else {
    kind = Date.parse(shift.startAt) <= now.getTime() ? "awaiting" : "forecast";
    spanMinutes = minutesBetween(shift.startAt, shift.endAt);
  }
  const breakMinutes = legalBreakMinutes(spanMinutes);
  const paidMinutes = Math.max(0, spanMinutes - breakMinutes);
  return {
    shiftId: shift.id,
    date: shift.date,
    workerId: shift.workerId,
    displayName: shift.displayName,
    jobId: shift.jobId,
    jobTitle: shift.jobTitle,
    start: shift.start,
    end: shift.end,
    status: shift.status,
    checkInAt: shift.checkInAt,
    checkOutAt: shift.checkOutAt,
    corrected: shift.corrected,
    kind,
    spanMinutes,
    breakMinutes,
    paidMinutes,
    wage,
    amount: roundMoney((wage * paidMinutes) / 60, currency),
  };
}

// ---------------------------------------------------------------- months

/** "2026-09" for "2026-09-27". */
export function monthOf(date: string): string {
  return date.slice(0, 7);
}

export function daysInMonth(month: string): number {
  const [y, m] = month.split("-").map(Number);
  return new Date(Date.UTC(y ?? 1970, m ?? 1, 0)).getUTCDate();
}

export function addMonths(month: string, delta: number): string {
  const [y, m] = month.split("-").map(Number);
  const d = new Date(Date.UTC(y ?? 1970, (m ?? 1) - 1 + delta, 1));
  return d.toISOString().slice(0, 7);
}

export type PayrollDay = { day: number; confirmed: number; projected: number; total: number };

export type MonthPayroll = {
  month: string;
  currency: Currency;
  lines: PayLine[];
  totals: Record<PayKind, number> & { all: number };
  counts: Record<PayKind, number>;
  paidMinutes: Record<PayKind, number>;
  noShows: number;
  days: PayrollDay[];
};

/**
 * One month of labor cost from the shop's shifts. `wageOf` gives the hourly wage of a job.
 * Shifts outside the month are ignored; no-shows are counted but cost nothing.
 */
export function monthPayroll(
  month: string,
  shifts: ShiftView[],
  wageOf: (jobId: string) => number,
  currency: Currency,
  now: Date,
): MonthPayroll {
  const inMonth = shifts.filter((s) => monthOf(s.date) === month);
  const lines = inMonth
    .map((s) => payLine(s, wageOf(s.jobId), currency, now))
    .filter((line): line is PayLine => line !== null)
    .sort((a, b) => a.date.localeCompare(b.date) || a.start.localeCompare(b.start) || a.displayName.localeCompare(b.displayName));

  const totals = { confirmed: 0, awaiting: 0, forecast: 0, all: 0 };
  const counts = { confirmed: 0, awaiting: 0, forecast: 0 };
  const paidMinutes = { confirmed: 0, awaiting: 0, forecast: 0 };
  const days: PayrollDay[] = Array.from({ length: daysInMonth(month) }, (_, i) => ({ day: i + 1, confirmed: 0, projected: 0, total: 0 }));

  for (const line of lines) {
    totals[line.kind] += line.amount;
    totals.all += line.amount;
    counts[line.kind] += 1;
    paidMinutes[line.kind] += line.paidMinutes;
    const day = days[Number(line.date.slice(8)) - 1];
    if (!day) continue;
    day.total += line.amount;
    if (line.kind === "confirmed") day.confirmed += line.amount;
    else day.projected += line.amount;
  }
  const round = (n: number) => roundMoney(n, currency);
  for (const key of ["confirmed", "awaiting", "forecast", "all"] as const) totals[key] = round(totals[key]);
  for (const day of days) {
    day.confirmed = round(day.confirmed);
    day.projected = round(day.projected);
    day.total = round(day.total);
  }

  return { month, currency, lines, totals, counts, paidMinutes, noShows: inMonth.length - lines.length, days };
}

export type MonthClose = {
  /** The month has ended and every shift has both punches. */
  ready: boolean;
  monthEnded: boolean;
  /** Started shifts still missing a punch. */
  missingPunches: number;
  /** Shifts later in the month that have not happened yet. */
  upcoming: number;
  corrected: number;
};

/** What is left before the month's labor cost can be closed. */
export function monthClose(payroll: MonthPayroll, today: string): MonthClose {
  const monthEnded = monthOf(today) > payroll.month;
  const missingPunches = payroll.counts.awaiting;
  const upcoming = payroll.counts.forecast;
  return {
    ready: monthEnded && missingPunches === 0 && upcoming === 0,
    monthEnded,
    missingPunches,
    upcoming,
    corrected: payroll.lines.filter((l) => l.corrected).length,
  };
}

/** A clean axis ceiling (1, 2, 2.5, 5 × 10ⁿ) at or above the largest value, split into four ticks. */
export function niceScale(max: number): { ceiling: number; ticks: number[] } {
  if (!(max > 0)) return { ceiling: 4, ticks: [0, 1, 2, 3, 4] };
  const rawStep = max / 4;
  const magnitude = 10 ** Math.floor(Math.log10(rawStep));
  const step = [1, 2, 2.5, 5, 10].map((f) => f * magnitude).find((c) => c >= rawStep) ?? 10 * magnitude;
  return { ceiling: step * 4, ticks: [0, 1, 2, 3, 4].map((i) => i * step) };
}

// ---------------------------------------------------------------- CSV

/**
 * Quotes a CSV cell when it needs quoting. Text that a spreadsheet would run as a formula
 * (starting with =, +, -, @, tab or CR) gets a leading ' so names, job titles and correction
 * reasons stay plain text. Numbers are left as numbers.
 */
export function csvCell(value: string | number): string {
  const text = typeof value === "string" && /^[=+\-@\t\r]/.test(value) ? `'${value}` : String(value);
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/** CSV for payroll software: UTF-8 with a BOM and CRLF, so Excel opens Japanese correctly. */
export function toCsv(rows: Array<Array<string | number>>): string {
  return `﻿${rows.map((row) => row.map(csvCell).join(",")).join("\r\n")}\r\n`;
}
