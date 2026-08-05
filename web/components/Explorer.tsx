"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { CandidateList } from "@/components/CandidateList";
import {
  browseKindFor,
  CategoryChips,
  searchKindsFor,
  type ExploreCategory
} from "@/components/CategoryChips";
import { MediaCover } from "@/components/MediaCover";
import { ProfileRow } from "@/components/ProfileRow";
import type { MediaCandidate } from "@/lib/catalog/types";
import { fetchRecentMedia } from "@/lib/explore";
import type { Media } from "@/lib/media";
import { searchProfiles } from "@/lib/people";
import type { UserProfile } from "@/lib/profile";
import { createClient } from "@/lib/supabase/client";

const SEARCH_DEBOUNCE_MS = 350;

/** Ports ExplorerView.swift: category chips over a search field. */
export function Explorer() {
  const router = useRouter();
  const [category, setCategory] = useState<ExploreCategory>("all");
  const [query, setQuery] = useState("");
  const [people, setPeople] = useState<UserProfile[]>([]);
  const [candidates, setCandidates] = useState<MediaCandidate[]>([]);
  const [browse, setBrowse] = useState<Media[]>([]);
  const [searching, setSearching] = useState(false);
  const [error, setError] = useState("");

  const trimmed = query.trim();
  // Derived: an empty query means "show nothing" whatever the last search
  // returned. Clearing it inside the effect would be a synchronous setState
  // in an effect body, which React 19's set-state-in-effect rule rejects.
  const visiblePeople = trimmed.length === 0 ? [] : people;
  const visibleCandidates = trimmed.length === 0 ? [] : candidates;
  const browseKind = browseKindFor(category);

  // Browse panel: only for the four single-kind categories.
  useEffect(() => {
    if (!browseKind) return;
    let cancelled = false;

    fetchRecentMedia(createClient(), browseKind)
      .then((media) => {
        if (!cancelled) setBrowse(media);
      })
      .catch(() => {
        if (!cancelled) setBrowse([]);
      });

    return () => {
      cancelled = true;
    };
  }, [browseKind]);

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

  function openComposer(candidate: MediaCandidate) {
    const params = new URLSearchParams({ kind: candidate.kind, q: candidate.title });
    router.push(`/composer?${params.toString()}`);
  }

  return (
    <div className="flex flex-col gap-4">
      <CategoryChips value={category} onChange={setCategory} />

      <input
        type="text"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder="Search movies, TV, music, books, people"
        className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
      />

      {error && <p className="text-sm text-red-500">{error}</p>}
      {searching && <p className="text-(--color-text-secondary)">Searching…</p>}

      {trimmed.length === 0 && category === "people" && (
        <Prompt
          title="Find your people"
          message="Search by name or username to see what they're into."
        />
      )}

      {trimmed.length === 0 && category === "all" && (
        <Prompt
          title="Search everything"
          message="Type in the search bar to find movies, TV shows, music, and books all at once."
        />
      )}

      {trimmed.length === 0 && browseKind && (
        <section className="flex flex-col gap-3">
          <h2 className="font-semibold text-(--color-text-primary)">Recently added</h2>
          {browse.length === 0 ? (
            <Prompt title="Nothing here yet" message="Search to find something to log." />
          ) : (
            <ul className="grid grid-cols-3 gap-2">
              {browse.map((media) => (
                <li key={media.id}>
                  <MediaCover media={media} />
                </li>
              ))}
            </ul>
          )}
        </section>
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

      {category !== "people" && <CandidateList candidates={visibleCandidates} onPick={openComposer} />}
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
