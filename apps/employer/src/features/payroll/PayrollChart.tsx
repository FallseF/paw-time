"use client";

import { niceScale } from "@paw-time/shop-console";
import type { PayrollDay } from "@paw-time/shop-console";
import type { Dict } from "../../lib/i18n";

/**
 * Stacked columns per day: confirmed pay on the baseline, the rest of the projection on top.
 * One y axis with clean ticks, a legend, and a readout per column on hover and keyboard focus.
 */
export function PayrollChart({ days, t, money }: { days: PayrollDay[]; t: Dict; money: (v: number) => string }) {
  const max = Math.max(0, ...days.map((d) => d.total));
  const { ceiling, ticks } = niceScale(max);
  const p = t.payroll;
  return (
    <figure className="pay-chart">
      <figcaption className="pay-legend">
        <span><i className="swatch confirmed" />{p.legendConfirmed}</span>
        <span><i className="swatch projected" />{p.legendProjected}</span>
      </figcaption>
      <div className="pay-plot">
        <div className="pay-axis" aria-hidden="true">
          {[...ticks].reverse().map((tick) => <span key={tick}>{money(tick)}</span>)}
        </div>
        <div className="pay-area">
          <div className="pay-grid" aria-hidden="true">
            {ticks.map((tick) => <span key={tick} />)}
          </div>
          <ol className="pay-cols">
            {days.map((d) => {
              const label = p.day(d.day);
              const readout = `${label}: ${p.legendConfirmed} ${money(d.confirmed)}, ${p.legendProjected} ${money(d.projected)}, ${p.chartTotal} ${money(d.total)}`;
              return (
                <li key={d.day} className={d.total > 0 ? "pay-col" : "pay-col pay-col-empty"}>
                  <button type="button" className="pay-hit" aria-label={readout} title={readout}>
                    <span className="pay-stack">
                      {d.projected > 0 ? <span className="seg-bar projected" style={{ height: `${(d.projected / ceiling) * 100}%` }} /> : null}
                      {d.confirmed > 0 ? <span className="seg-bar confirmed" style={{ height: `${(d.confirmed / ceiling) * 100}%` }} /> : null}
                    </span>
                    <span className="pay-tip" aria-hidden="true">
                      <strong>{money(d.total)}</strong>
                      <span>{label}</span>
                    </span>
                  </button>
                  <span className="pay-day" aria-hidden="true">{d.day}</span>
                </li>
              );
            })}
          </ol>
        </div>
      </div>
    </figure>
  );
}
