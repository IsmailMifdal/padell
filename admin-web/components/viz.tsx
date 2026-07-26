'use client';

// Composants de data-visualisation.
//
// Specs suivies (catalogue dataviz) : trait 2px joint/extrémité ronds, aire de
// remplissage à ~10 %, grille en filet 1px pleine (jamais pointillée), marqueur
// de fin ≥8px cerclé de 2px dans la couleur de surface, étiquetage sélectif
// (uniquement le dernier point), graduations Y arrondies et alignées en
// tabular-nums, survol crosshair + infobulle, et surtout : jamais deux axes Y
// sur un même graphique — on bascule entre les mesures.

import { useEffect, useMemo, useRef, useState } from 'react';
import { CaretDown, CaretUp, Table as TableIcon, ChartLine } from '@phosphor-icons/react';

export interface Point {
  date: string;
  value: number;
}

const fmtCompact = (n: number) =>
  n >= 1_000_000
    ? `${(n / 1_000_000).toFixed(1).replace('.0', '')}M`
    : n >= 1_000
      ? `${(n / 1_000).toFixed(1).replace('.0', '')}K`
      : `${Math.round(n)}`;

const fmtFull = (n: number) => new Intl.NumberFormat('fr-MA').format(Math.round(n * 100) / 100);

const fmtDay = (iso: string) =>
  new Date(`${iso}T00:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });

/** Graduations Y sur des nombres ronds (0 / 500 / 1 000 …). */
function niceTicks(max: number, count = 4): number[] {
  if (max <= 0) return [0, 1];
  const raw = max / count;
  const mag = Math.pow(10, Math.floor(Math.log10(raw)));
  const norm = raw / mag;
  const step = (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10) * mag;
  const ticks: number[] = [];
  for (let v = 0; v <= max + step * 0.001; v += step) ticks.push(v);
  return ticks;
}

/** Largeur réelle du conteneur — évite de déformer les traits par mise à l'échelle SVG. */
function useWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width));
    ro.observe(el);
    setWidth(el.getBoundingClientRect().width);
    return () => ro.disconnect();
  }, []);
  return [ref, width] as const;
}

// ------------------------------------------------------------------ delta

export function Delta({ pct, suffix = 'vs période précédente' }: { pct: number | null; suffix?: string }) {
  if (pct === null) {
    return <span className="delta delta-flat">— pas de base de comparaison</span>;
  }
  const dir = pct > 0 ? 'up' : pct < 0 ? 'down' : 'flat';
  return (
    <span className={`delta delta-${dir}`}>
      {dir === 'up' && <CaretUp size={11} weight="fill" />}
      {dir === 'down' && <CaretDown size={11} weight="fill" />}
      {pct > 0 ? '+' : ''}
      {pct} %
      <span style={{ color: 'var(--text-muted)', fontWeight: 500 }}>&nbsp;{suffix}</span>
    </span>
  );
}

// -------------------------------------------------------------- sparkline

/** Micro-courbe de tendance : contexte en gris, dernier point en accent. */
export function Sparkline({ data, width = 96, height = 28 }: { data: number[]; width?: number; height?: number }) {
  if (data.length < 2) return <div style={{ height }} />;
  const max = Math.max(...data);
  const min = Math.min(...data);
  const span = max - min || 1;
  const pad = 3;
  const x = (i: number) => (i / (data.length - 1)) * (width - pad * 2) + pad;
  const y = (v: number) => height - pad - ((v - min) / span) * (height - pad * 2);
  const d = data.map((v, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
  const lastX = x(data.length - 1);
  const lastY = y(data[data.length - 1]);

  return (
    <svg width={width} height={height} aria-hidden="true" style={{ display: 'block' }}>
      <path d={d} fill="none" stroke="var(--viz-muted)" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
      {/* Anneau de 2px dans la couleur de surface : le point reste lisible
          là où il croise le trait. */}
      <circle cx={lastX} cy={lastY} r={4} fill="var(--viz-series)" stroke="var(--surface)" strokeWidth={2} />
    </svg>
  );
}

// -------------------------------------------------------------- stat tile

export function StatTile({
  label,
  value,
  deltaPct,
  trend,
  hero = false,
}: {
  label: string;
  value: string;
  deltaPct?: number | null;
  trend?: number[];
  hero?: boolean;
}) {
  return (
    <div className="kpi" style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div className="kpi-label">{label}</div>
      <div className={hero ? 'hero-figure' : 'kpi-value'} style={{ marginTop: 0 }}>
        {value}
      </div>
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 8 }}>
        {deltaPct !== undefined && <Delta pct={deltaPct} suffix="" />}
        {trend && trend.length > 1 && <Sparkline data={trend} />}
      </div>
    </div>
  );
}

// ------------------------------------------------------------- line chart

/**
 * Courbe d'évolution, une seule série à la fois.
 * Une série unique ne porte pas de légende : le titre dit déjà ce qui est tracé.
 */
export function LineChart({
  points,
  unit = '',
  height = 260,
}: {
  points: Point[];
  unit?: string;
  height?: number;
}) {
  const [wrapRef, width] = useWidth<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);
  const [showTable, setShowTable] = useState(false);

  const pad = { top: 16, right: 18, bottom: 26, left: 52 };
  const plotW = Math.max(width - pad.left - pad.right, 10);
  const plotH = height - pad.top - pad.bottom;

  const max = Math.max(...points.map((p) => p.value), 0);
  const ticks = useMemo(() => niceTicks(max), [max]);
  const yMax = ticks[ticks.length - 1] || 1;

  const px = (i: number) => (points.length <= 1 ? 0 : (i / (points.length - 1)) * plotW);
  const py = (v: number) => plotH - (v / yMax) * plotH;

  const line = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${px(i).toFixed(1)},${py(p.value).toFixed(1)}`).join(' ');
  const area = points.length
    ? `${line} L${px(points.length - 1).toFixed(1)},${plotH} L0,${plotH} Z`
    : '';

  const last = points[points.length - 1];
  const active = hover !== null ? points[hover] : null;

  // La vue tableau est le jumeau accessible : aucune valeur n'est
  // accessible uniquement au survol.
  if (showTable) {
    return (
      <div>
        <ChartToggle showTable={showTable} onToggle={() => setShowTable((v) => !v)} />
        <div className="table-wrap" style={{ maxHeight: height, overflowY: 'auto' }}>
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th style={{ textAlign: 'right' }}>Valeur{unit && ` (${unit})`}</th>
              </tr>
            </thead>
            <tbody>
              {[...points].reverse().map((p) => (
                <tr key={p.date}>
                  <td>{fmtDay(p.date)}</td>
                  <td style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{fmtFull(p.value)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    );
  }

  return (
    <div>
      <ChartToggle showTable={showTable} onToggle={() => setShowTable((v) => !v)} />
      <div ref={wrapRef} style={{ position: 'relative', width: '100%' }}>
        {width > 0 && (
          <svg
            width={width}
            height={height}
            role="img"
            aria-label={`Évolution sur ${points.length} jours`}
            onMouseLeave={() => setHover(null)}
            onMouseMove={(e) => {
              const rect = e.currentTarget.getBoundingClientRect();
              const rel = e.clientX - rect.left - pad.left;
              if (points.length < 2) return;
              const idx = Math.round((rel / plotW) * (points.length - 1));
              setHover(Math.min(Math.max(idx, 0), points.length - 1));
            }}
          >
            <g transform={`translate(${pad.left},${pad.top})`}>
              {/* Grille : filets pleins, une teinte au-dessus de la surface */}
              {ticks.map((t) => (
                <g key={t}>
                  <line x1={0} x2={plotW} y1={py(t)} y2={py(t)} stroke="var(--viz-grid)" strokeWidth={1} />
                  <text
                    x={-10}
                    y={py(t)}
                    textAnchor="end"
                    dominantBaseline="middle"
                    fontSize={11}
                    fill="var(--viz-muted)"
                    style={{ fontVariantNumeric: 'tabular-nums' }}
                  >
                    {fmtCompact(t)}
                  </text>
                </g>
              ))}

              <path d={area} fill="var(--viz-series)" opacity={0.1} />
              <path
                d={line}
                fill="none"
                stroke="var(--viz-series)"
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
              />

              {/* Crosshair + point actif au survol */}
              {active && hover !== null && (
                <>
                  <line
                    x1={px(hover)}
                    x2={px(hover)}
                    y1={0}
                    y2={plotH}
                    stroke="var(--viz-axis)"
                    strokeWidth={1}
                  />
                  <circle
                    cx={px(hover)}
                    cy={py(active.value)}
                    r={5}
                    fill="var(--viz-series)"
                    stroke="var(--surface)"
                    strokeWidth={2}
                  />
                </>
              )}

              {/* Étiquetage sélectif : uniquement le dernier point */}
              {last && hover === null && (
                <circle
                  cx={px(points.length - 1)}
                  cy={py(last.value)}
                  r={4}
                  fill="var(--viz-series)"
                  stroke="var(--surface)"
                  strokeWidth={2}
                />
              )}

              {/* Axe X : premier, milieu, dernier — jamais toutes les dates */}
              {[0, Math.floor((points.length - 1) / 2), points.length - 1]
                .filter((i, k, arr) => points[i] && arr.indexOf(i) === k)
                .map((i) => (
                  <text
                    key={i}
                    x={px(i)}
                    y={plotH + 18}
                    textAnchor={i === 0 ? 'start' : i === points.length - 1 ? 'end' : 'middle'}
                    fontSize={11}
                    fill="var(--viz-muted)"
                  >
                    {fmtDay(points[i].date)}
                  </text>
                ))}
            </g>
          </svg>
        )}

        {active && hover !== null && width > 0 && (
          <div
            className="viz-tooltip"
            style={{
              left: Math.min(Math.max(pad.left + px(hover) - 60, 0), width - 130),
              top: pad.top + py(active.value) - 52,
            }}
          >
            <div style={{ color: 'var(--text-muted)', marginBottom: 2 }}>{fmtDay(active.date)}</div>
            <div style={{ fontWeight: 700 }}>
              {fmtFull(active.value)}
              {unit && ` ${unit}`}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function ChartToggle({ showTable, onToggle }: { showTable: boolean; onToggle: () => void }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 4 }}>
      <button className="icon-btn" onClick={onToggle} title={showTable ? 'Voir le graphique' : 'Voir le tableau'}>
        {showTable ? <ChartLine size={15} /> : <TableIcon size={15} />}
        {showTable ? 'Graphique' : 'Tableau'}
      </button>
    </div>
  );
}
