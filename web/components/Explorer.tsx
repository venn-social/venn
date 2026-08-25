"use client";

import { useEffect, useState } from "react";
import { CandidateList } from "@/components/CandidateList";
import { browseKindFor, searchKindsFor, type ExploreCategory } from "@/components/CategoryChips";
import { ProfileRow } from "@/components/ProfileRow";
import { SearchPanel } from "@/components/SearchPanel";
import type { MediaCandidate } from "@/lib/catalog/types";
import { searchProfiles } from "@/lib/people";
import type { UserProfile } from "@/lib/profile";
import { RecommendationShelves } from "@/components/RecommendationShelves";
import { shelvesForKind, type Shelf } from "@/lib/recommendations";
import { createClient } from "@/lib/supabase/client";
import { useOpenCandidate } from "@/lib/useOpenCandidate";

const SEARCH_DEBOUNCE_MS = 350;

interface ExplorerProps {
  /** Recommendation shelves, fetched on the server. Empty renders nothing. */
  shelves?: Shelf[];
}

/** Ports ExplorerView.swift: category chips over a search field. */
export function Explorer({ shelves = [] }: ExplorerProps) {
  const { open: openCandidate } = useOpenCandidate();
  const [category, setCategory] = useState<ExploreCategory>("all");
  const [query, setQuery] = useState("");
  const [people, setPeople] = useState<UserProfile[]>([]);
  const [candidates, setCandidates] = useState<MediaCandidate[]>([]);
  const [searching, setSearching] = useState(false);
  const [error, setError] = useState("");

  const trimmed = query.trim();
  // Derived: an empty query means "show nothing" whatever the last search
  // returned. Clearing it inside the effect would be a synchronous setState
  // in an effect body, which React 19's set-state-in-effect rule rejects.
  const visiblePeople = trimmed.length === 0 ? [] : people;
  const visibleCandidates = trimmed.length === 0 ? [] : candidates;
  const browseKind = browseKindFor(category);
  // Derived, not fetched: the shelves are already here, just narrower.
  const kindShelves = browseKind ? shelvesForKind(shelves, browseKind) : [];

  // Search. The effect owns only the debounced fetch.
  useEffect(() => {
    const term = query.trim();
    if (term.length === 0) return;

    const timer = setTimeout(async () => {
      setSearching(true);
      setError("");
      try {
        if (category === "people") {
          setPeople(await searchProfiles(createClient(), term));
          setCandidates([]);
        } else {
          const kinds = searchKindsFor(category);
          const responses = await Promise.all(
            kinds.map((kind) =>
              fetch(`/api/catalog/search?kind=${kind}&q=${encodeURIComponent(term)}`).then(
                (response) => response.json()
              )
            )
          );
          setCandidates(responses.flatMap((json) => json.candidates ?? []));
          setPeople([]);
        }
      } catch {
        setError("Search failed.");
        setPeople([]);
        setCandidates([]);
      } finally {
        setSearching(false);
      }
    }, SEARCH_DEBOUNCE_MS);

    return () => clearTimeout(timer);
  }, [query, category]);

  return (
    <div className="flex flex-col gap-4">
      <SearchPanel
        category={category}
        onCategoryChange={setCategory}
        query={query}
        onQueryChange={setQuery}
        placeholder="Search movies, TV, music, books, people"
      />

      {error && <p className="text-sm text-red-500">{error}</p>}
      {searching && <p className="text-(--color-text-secondary)">Searching…</p>}

      {trimmed.length === 0 && category === "people" && (
        <Prompt
          title="Find your people"
          message="Search by name or username to see what they're into."
        />
      )}

      {/* Only with an empty query: shelves are for browsing, and leaving
          them above live results would push what the user just typed off
          the screen. */}
      {trimmed.length === 0 && category === "all" && <RecommendationShelves shelves={shelves} />}

      {trimmed.length === 0 && category === "all" && shelves.length === 0 && (
        <Prompt
          title="Search everything"
          message="Type in the search bar to find movies, TV shows, music, and books all at once."
        />
      )}

      {/* Per-kind tabs answer the same question the All tab does. They used
          to list the newest rows in the catalog, which is what other people
          happened to log — the profile page's job, not Explorer's. */}
      {trimmed.length === 0 && browseKind && (
        <>
          <RecommendationShelves shelves={kindShelves} />
          {kindShelves.length === 0 && (
            <Prompt
              title="No recommendations yet"
              message="Log a few things you liked and they'll show up here."
            />
          )}
        </>
      )}

      {category === "people" && trimmed.length > 0 && !searching && (
        <>
          {visiblePeople.length === 0 ? (
            <Prompt title="No one found" message="Try a different name or username." />
          ) : (
            <ul className="flex flex-col divide-y divide-(--color-separator)">
              {visiblePeople.map((profile) => (
                <li key={profile.id}>
                  <ProfileRow profile={profile} />
                </li>
              ))}
            </ul>
          )}
        </>
      )}

      {category !== "people" && (
        <CandidateList candidates={visibleCandidates} onPick={(c) => void openCandidate(c)} />
      )}
    </div>
  );
}

function Prompt({ title, message }: { title: string; message: string }) {
  return (
    <div className="flex flex-col gap-1 py-6 text-center">
      <p className="font-semibold text-(--color-text-primary)">{title}</p>
      <p className="text-(--color-text-secondary)">{message}</p>
    </div>
  );
}
