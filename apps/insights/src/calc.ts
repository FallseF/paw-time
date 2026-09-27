// Pilot value calculator. Every input is an assumption to validate in the pilot, not a result.

export const WEEKS_PER_MONTH = 52 / 12;

export interface CalcInput {
  shops: number;
  workers: number; // workers in the pilot
  shiftsPerWeek: number; // posted shifts per shop per week
  currentFill: number; // 0..1
  noShowRate: number; // 0..1, of filled shifts
  fillFee: number; // ¥ per additional filled shift
  noShowCost: number; // ¥ per no-show (manager time, lost sales, urgent re-posting)
  fillUplift: number; // percentage points as 0..1 (0.03 = +3 pt)
  noShowReduction: number; // relative, 0..1 (0.2 = 20% fewer)
}

export interface CalcOutput {
  postedPerMonth: number;
  fillsGained: number;
  noShowsAvoided: number;
  valueFills: number;
  valueNoShows: number;
  total: number;
  perWorker: number | null;
  annual: number;
}

/** Defaults are deliberately conservative. None is a measured result. */
export const CALC_DEFAULTS: CalcInput = {
  shops: 5,
  workers: 60,
  shiftsPerWeek: 20,
  currentFill: 0.75,
  noShowRate: 0.05,
  fillFee: 1500,
  noShowCost: 5000,
  fillUplift: 0.03,
  noShowReduction: 0.2,
};

const nonneg = (x: number) => (Number.isFinite(x) && x > 0 ? x : 0);
const unit = (x: number) => Math.min(1, nonneg(x));

export function pilotValue(raw: CalcInput): CalcOutput {
  const shops = nonneg(raw.shops);
  const currentFill = unit(raw.currentFill);
  const posted = shops * nonneg(raw.shiftsPerWeek) * WEEKS_PER_MONTH;
  // Fill can't pass 100%: the uplift is capped by the openings still unfilled.
  const uplift = Math.min(unit(raw.fillUplift), 1 - currentFill);
  const fillsGained = posted * uplift;
  // Conservative: no-shows avoided only on shifts that are filled today.
  const noShowsAvoided = posted * currentFill * unit(raw.noShowRate) * unit(raw.noShowReduction);
  const valueFills = fillsGained * nonneg(raw.fillFee);
  const valueNoShows = noShowsAvoided * nonneg(raw.noShowCost);
  const total = valueFills + valueNoShows;
  return {
    postedPerMonth: posted,
    fillsGained,
    noShowsAvoided,
    valueFills,
    valueNoShows,
    total,
    perWorker: raw.workers > 0 ? total / raw.workers : null,
    annual: total * 12,
  };
}
