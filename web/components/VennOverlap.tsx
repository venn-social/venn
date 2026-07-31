import { pairGeometry, VENN_DIAGRAM_HEIGHT } from "@/lib/vennGeometry";
import { tasteMatchPercent, type OverlapSummary } from "@/lib/overlap";

const DIAGRAM_WIDTH = 360;

interface VennOverlapProps {
  viewerLabel: string;
  otherLabel: string;
  summary: OverlapSummary;
}

export function VennOverlap({ viewerLabel, otherLabel, summary }: VennOverlapProps) {
  const { viewerTotal, otherTotal, sharedTotal, kinds } = summary;
  const percent = tasteMatchPercent(sharedTotal, viewerTotal, otherTotal);
  const geometry = pairGeometry(viewerTotal, otherTotal, sharedTotal);
  const centerX = DIAGRAM_WIDTH / 2;
  const centerY = VENN_DIAGRAM_HEIGHT / 2;
  const viewerX = centerX - geometry.halfDistance;
  const otherX = centerX + geometry.halfDistance;
  const sharedKinds = kinds.filter((k) => k.sharedCount > 0);

  const accessibilityLabel = `${percent ?? 0}% taste match. ${sharedTotal} in common, ${
    viewerTotal - sharedTotal
  } only you, ${otherTotal - sharedTotal} only them.`;

  return (
    <div className="flex flex-col gap-4">
      {percent !== null && (
        <div className="flex flex-col items-center gap-0.5">
          <span className="text-4xl font-bold text-(--color-accent)">{percent}%</span>
          <span className="text-xs font-semibold tracking-wide text-(--color-text-secondary) uppercase">
            taste match
          </span>
        </div>
      )}

      <svg
        viewBox={`0 0 ${DIAGRAM_WIDTH} ${VENN_DIAGRAM_HEIGHT}`}
        width="100%"
        height={VENN_DIAGRAM_HEIGHT}
        role="img"
        aria-label={accessibilityLabel}
      >
        <defs>
          <clipPath id="venn-lens-clip">
            <circle cx={viewerX} cy={centerY} r={geometry.viewerRadius} />
          </clipPath>
        </defs>

        <circle
          cx={viewerX}
          cy={centerY}
          r={geometry.viewerRadius}
          fill="var(--color-graphite)"
          fillOpacity={0.08}
          stroke="var(--color-graphite)"
          strokeOpacity={0.45}
          strokeWidth={1.5}
        />
        <circle
          cx={otherX}
          cy={centerY}
          r={geometry.otherRadius}
          fill="var(--color-graphite)"
          fillOpacity={0.08}
          stroke="var(--color-graphite)"
          strokeOpacity={0.45}
          strokeWidth={1.5}
        />

        {/* The lens: the other lobe filled solid accent, clipped to the
            viewer lobe's shape, so only the intersection shows. */}
        <circle
          cx={otherX}
          cy={centerY}
          r={geometry.otherRadius}
          fill="var(--color-accent)"
          clipPath="url(#venn-lens-clip)"
        />

        <text
          x={viewerX - geometry.viewerRadius * 0.45}
          y={centerY}
          textAnchor="middle"
          dominantBaseline="middle"
          fontWeight={600}
          fill="var(--color-text-primary)"
        >
          {viewerTotal - sharedTotal}
        </text>
        <text
          x={otherX + geometry.otherRadius * 0.45}
          y={centerY}
          textAnchor="middle"
          dominantBaseline="middle"
          fontWeight={600}
          fill="var(--color-text-primary)"
        >
          {otherTotal - sharedTotal}
        </text>

        {sharedTotal > 0 && (
          <g>
            <rect
              x={centerX - 16}
              y={centerY - 12}
              width={32}
              height={24}
              rx={12}
              fill="var(--color-accent)"
              stroke="var(--color-background)"
              strokeWidth={2}
            />
            <text
              x={centerX}
              y={centerY}
              textAnchor="middle"
              dominantBaseline="middle"
              fontWeight={700}
              fill="var(--color-on-accent)"
            >
              {sharedTotal}
            </text>
          </g>
        )}
      </svg>

      <div className="flex flex-col gap-1">
        <LegendRow label={viewerLabel} count={viewerTotal - sharedTotal} />
        <LegendRow label="in common" count={sharedTotal} emphasized />
        <LegendRow label={otherLabel} count={otherTotal - sharedTotal} />
      </div>

      {sharedKinds.length > 0 && (
        <div className="flex flex-col gap-1">
          {sharedKinds.map((k) => (
            <div key={k.kind} className="flex items-center justify-between text-sm">
              <span className="text-(--color-text-primary)">
                {k.kind.charAt(0).toUpperCase() + k.kind.slice(1)}s in common
              </span>
              <span className="font-semibold text-(--color-text-secondary)">{k.sharedCount}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function LegendRow({
  label,
  count,
  emphasized = false
}: {
  label: string;
  count: number;
  emphasized?: boolean;
}) {
  return (
    <div className="flex items-center gap-2">
      <span
        className="h-2 w-2 rounded-full"
        style={{
          backgroundColor: emphasized ? "var(--color-accent)" : "var(--color-graphite)",
          opacity: emphasized ? 1 : 0.55
        }}
      />
      <span className={`flex-1 text-(--color-text-primary) ${emphasized ? "font-semibold" : ""}`}>
        {label}
      </span>
      <span className="text-(--color-text-secondary)">{count}</span>
    </div>
  );
}
