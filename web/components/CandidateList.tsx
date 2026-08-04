"use client";

import type { MediaCandidate } from "@/lib/catalog/types";

interface CandidateListProps {
  candidates: MediaCandidate[];
  onPick: (candidate: MediaCandidate) => void;
}

/** Search results — cover thumb, title, and "2023 · Celine Song" metadata. */
export function CandidateList({ candidates, onPick }: CandidateListProps) {
  return (
    <ul className="flex flex-col divide-y divide-(--color-separator)">
      {candidates.map((candidate) => {
        const metadata = [candidate.year?.toString(), candidate.primaryCreator]
          .filter((part): part is string => Boolean(part))
          .join(" · ");

        return (
          <li key={candidate.id}>
            <button
              type="button"
              onClick={() => onPick(candidate)}
              className="flex w-full items-center gap-3 py-2 text-left"
            >
              <span className="flex h-[60px] w-[40px] shrink-0 items-center justify-center overflow-hidden rounded-sm bg-(--color-surface-strong)">
                {candidate.coverUrl && (
                  // eslint-disable-next-line @next/next/no-img-element -- see the Phase 3 spec on next/image
                  <img
                    src={candidate.coverUrl}
                    alt=""
                    loading="lazy"
                    className="h-full w-full object-cover"
                  />
                )}
              </span>
              <span className="flex flex-col">
                <span className="font-medium text-(--color-text-primary)">{candidate.title}</span>
                {metadata && (
                  <span className="text-sm text-(--color-text-secondary)">{metadata}</span>
                )}
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}
