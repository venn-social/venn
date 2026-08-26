import { pairGeometry, VENN_DIAGRAM_HEIGHT } from "@/lib/vennGeometry";
import { tasteMatchPercent, type OverlapSummary } from "@/lib/overlap";

const DIAGRAM_WIDTH = 360;

interface VennOverlapProps {
  summary: OverlapSummary;
}

export function VennOverlap({ summary }: VennOverlapProps) {
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
          fillOpacity={0.05}
          stroke="var(--color-graphite)"
          strokeOpacity={0.3}
          strokeWidth={1}
        />
        <circle
          cx={otherX}
          cy={centerY}
          r={geometry.otherRadius}
          fill="var(--color-graphite)"
          fillOpacity={0.05}
          stroke="var(--color-graphite)"
          strokeOpacity={0.3}
          strokeWidth={1}
        />

        {/* The lens: the other lobe clipped to the viewer lobe's shape, so
            only the intersection shows. Translucent rather than solid —
            an opaque block reads as a third shape sitting on top of the
            two circles, where the whole idea is that it is the part they
            share. */}
        <circle
          cx={otherX}
          cy={centerY}
          r={geometry.otherRadius}
          fill="var(--color-accent)"
          fillOpacity={0.35}
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
          <text
            x={centerX}
            y={centerY}
            textAnchor="middle"
            dominantBaseline="middle"
            fontWeight={700}
            fill="var(--color-text-primary)"
          >
            {sharedTotal}
          </text>
        )}
      </svg>

      {sharedKinds.length > 0 && (
        // One line, not a table. The diagram has already said how much is
        // shared; this only says what kind of thing it was, and the legend
        // it replaced named three numbers the diagram was already showing.
        <p className="text-center text-sm text-(--color-text-secondary)">
          {sharedKinds
            .map((k) => `${k.sharedCount} ${k.kind}${k.sharedCount === 1 ? "" : "s"}`)
            .join(" · ")}
        </p>
      )}
    </div>
  );
}
