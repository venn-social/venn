/**
 * Fill the taste engine's feature tables from the catalogs (spec §1).
 *
 * For every `media` row with a catalog identity, this asks TMDB, Open
 * Library or MusicBrainz for the item, normalises what comes back (year,
 * people, taxonomy, length, origin, sound) and writes `media_features`,
 * `media_taxonomy`, `people` and `media_people`. It also seeds the taxonomy
 * tree and its mappings from lib/taste/taxonomy.ts.
 *
 * Re-runnable. Items already extracted at the current EXTRACTOR_VERSION are
 * skipped unless --refresh is passed; each item's rows are replaced whole,
 * so a re-run never leaves stale credits or nodes behind. Commitment is
 * recomputed for a whole kind once it has enough items for a real
 * percentile (lib/taste/commitment.ts).
 *
 * The feature tables have no client write policy — they describe rows every
 * user shares — so --apply needs the service-role key. A dry run only reads,
 * and anon is enough.
 *
 * Usage, from `web/`:
 *
 *     SUPABASE_URL=... TMDB_API_KEY=... npx tsx scripts/extract-media-features.ts [--limit=50] [--kind=book]
 *     …same plus SUPABASE_SERVICE_ROLE_KEY=... and --apply to write
 *     --refresh re-extracts items already at the current version
 *
 * Dry by default: prints what it would write and writes nothing.
 */

import { createClient } from "@supabase/supabase-js";
import type { MediaKind } from "@/lib/media";
import { buildRows, type BuiltRows } from "@/lib/taste/build";
import { MIN_SAMPLE, commitmentFor } from "@/lib/taste/commitment";
import { fetchFeatures } from "@/lib/taste/fetchFeatures";
import { hasIdentity, planPerson, type ExtractedPerson, type PersonRow } from "@/lib/taste/people";
import { EXTRACTOR_VERSION, featureRowProblems, type ExtractedFeatures } from "@/lib/taste/record";
import {
  TAXONOMY_NODES,
  indexMappings,
  labelKey,
  seedMappings,
  type MappingSource,
  type TaxonomyMapping
} from "@/lib/taste/taxonomy";

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const REFRESH = args.includes("--refresh");
const LIMIT = Number(args.find((arg) => arg.startsWith("--limit="))?.split("=")[1] ?? Infinity);
const KIND = args.find((arg) => arg.startsWith("--kind="))?.split("=")[1] as MediaKind | undefined;

const url = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const readKey = serviceKey ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const tmdbApiKey = process.env.TMDB_API_KEY ?? null;

if (!url || !readKey) {
  console.error("Needs SUPABASE_URL and a key (anon is enough for a dry run).");
  process.exit(1);
}
if (APPLY && !serviceKey) {
  console.error(
    "--apply needs SUPABASE_SERVICE_ROLE_KEY: the feature tables have no client write policy."
  );
  process.exit(1);
}

const db = createClient(url, readKey, { auth: { persistSession: false } });
const PAGE = 1000;

interface MediaRow {
  id: string;
  kind: MediaKind;
  title: string;
  external_source: string;
  external_id: string;
}

function fail(what: string, error: { message: string } | null): void {
  if (error) throw new Error(`${what}: ${error.message}`);
}

type Page = PromiseLike<{ data: unknown[] | null; error: { message: string } | null }>;

/** Read every row a query matches, a page at a time (PostgREST caps each response). */
async function readAll<T>(what: string, page: (from: number, to: number) => Page): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await page(from, from + PAGE - 1);
    fail(`read ${what}`, error);
    rows.push(...((data ?? []) as T[]));
    if (!data || data.length < PAGE) return rows;
  }
}

/** Upsert the seed tree and mappings, then return every mapping the table holds. */
async function loadTaxonomy(): Promise<{
  mappings: Map<string, TaxonomyMapping[]>;
  nodeIds: Map<string, number>;
}> {
  if (APPLY) {
    // Families first, so children can point at them.
    for (const pass of [true, false]) {
      const nodes = TAXONOMY_NODES.filter((node) => (node.parent === null) === pass);
      const { data: existing, error } = await db.from("taxonomy_nodes").select("id, slug");
      fail("read taxonomy_nodes", error);
      const ids = new Map(
        (existing ?? []).map((row: { id: number; slug: string }) => [row.slug, row.id])
      );
      const rows = nodes.map((node) => ({
        slug: node.slug,
        label_key: labelKey(node.slug),
        parent_id: node.parent ? (ids.get(node.parent) ?? null) : null,
        family: node.family,
        kind_scope: node.kindScope
      }));
      fail(
        "upsert taxonomy_nodes",
        (await db.from("taxonomy_nodes").upsert(rows, { onConflict: "slug" })).error
      );
    }
  }

  const nodes = await readAll<{ id: number; slug: string }>("taxonomy_nodes", (from, to) =>
    db.from("taxonomy_nodes").select("id, slug").range(from, to)
  );
  const nodeIds = new Map(nodes.map((row) => [row.slug, row.id]));
  const seed = seedMappings();

  if (APPLY) {
    const rows = seed
      .filter((row) => nodeIds.has(row.node))
      .map((row) => ({
        source: row.source,
        source_key: row.sourceKey,
        node_id: nodeIds.get(row.node),
        weight: row.weight
      }));
    // ignoreDuplicates: a weight someone has tuned in the table is theirs to keep.
    fail(
      "upsert taxonomy_mappings",
      (
        await db
          .from("taxonomy_mappings")
          .upsert(rows, { onConflict: "source,source_key,node_id", ignoreDuplicates: true })
      ).error
    );
  }

  const slugs = new Map(nodes.map((row) => [row.id, row.slug]));
  const stored = (
    await readAll<{ source: MappingSource; source_key: string; node_id: number; weight: number }>(
      "taxonomy_mappings",
      (from, to) =>
        db.from("taxonomy_mappings").select("source, source_key, node_id, weight").range(from, to)
    )
  )
    .filter((row) => slugs.has(row.node_id))
    .map((row): TaxonomyMapping => ({
      source: row.source,
      sourceKey: row.source_key,
      node: slugs.get(row.node_id) as string,
      weight: row.weight
    }));
  // Stored rows first, so a tuned weight wins over the seed's default.
  return { mappings: indexMappings([...stored, ...seed]), nodeIds };
}

async function findPeople(people: ExtractedPerson[]): Promise<PersonRow[]> {
  const columns = [
    ["wikidata_qid", people.map((p) => p.ids.wikidata)],
    ["tmdb_id", people.map((p) => p.ids.tmdb)],
    ["openlibrary_id", people.map((p) => p.ids.openlibrary)],
    ["musicbrainz_id", people.map((p) => p.ids.musicbrainz)]
  ] as const;
  const found = new Map<string, PersonRow>();
  for (const [column, values] of columns) {
    const ids = values.filter((value): value is string => Boolean(value));
    if (ids.length === 0) continue;
    const { data, error } = await db.from("people").select("*").in(column, ids);
    fail("read people", error);
    for (const row of (data ?? []) as PersonRow[]) found.set(row.id, row);
  }
  return [...found.values()];
}

async function writePeople(mediaId: string, people: ExtractedPerson[]): Promise<void> {
  const credited = people.filter(hasIdentity);
  const links: { media_id: string; person_id: string; role: string; billing: number | null }[] = [];
  for (const person of credited) {
    const plan = planPerson(person, await findPeople([person]));
    let id: string;
    if (plan.action === "insert") {
      const { data, error } = await db.from("people").insert(plan.row).select("id").single();
      fail("insert person", error);
      id = (data as { id: string }).id;
    } else if (plan.action === "update") {
      fail(
        "update person",
        (
          await db
            .from("people")
            .update({ ...plan.patch, updated_at: new Date().toISOString() })
            .eq("id", plan.id)
        ).error
      );
      id = plan.id;
    } else {
      id = plan.id;
    }
    if (!links.some((link) => link.person_id === id && link.role === person.role)) {
      links.push({ media_id: mediaId, person_id: id, role: person.role, billing: person.billing });
    }
  }
  fail(
    "clear media_people",
    (await db.from("media_people").delete().eq("media_id", mediaId)).error
  );
  if (links.length > 0)
    fail("insert media_people", (await db.from("media_people").insert(links)).error);
}

async function writeItem(
  mediaId: string,
  extracted: ExtractedFeatures,
  rows: BuiltRows,
  nodeIds: Map<string, number>
): Promise<void> {
  await writePeople(mediaId, extracted.people);
  fail(
    "upsert media_features",
    (
      await db
        .from("media_features")
        .upsert({ ...rows.features, extracted_at: new Date().toISOString() })
    ).error
  );
  fail(
    "clear media_taxonomy",
    (await db.from("media_taxonomy").delete().eq("media_id", mediaId)).error
  );
  const taxonomy = rows.taxonomy
    .filter((entry) => nodeIds.has(entry.node))
    .map((entry) => ({
      media_id: mediaId,
      node_id: nodeIds.get(entry.node),
      weight: entry.weight
    }));
  if (taxonomy.length > 0)
    fail("insert media_taxonomy", (await db.from("media_taxonomy").insert(taxonomy)).error);
}

/** Once a kind has enough lengths for a real percentile, rewrite every row of it on that basis. */
async function recomputeCommitment(
  samples: Map<MediaKind, { mediaId: string; length: number }[]>
): Promise<void> {
  for (const [kind, entries] of samples) {
    if (entries.length < MIN_SAMPLE) continue;
    const lengths = entries.map((entry) => entry.length);
    console.log(`  recomputing commitment for ${entries.length} ${kind} items`);
    if (!APPLY) continue;
    for (const entry of entries) {
      const commitment = commitmentFor(kind, entry.length, lengths);
      fail(
        "update commitment",
        (await db.from("media_features").update({ commitment }).eq("media_id", entry.mediaId)).error
      );
    }
  }
}

function describe(media: MediaRow, extracted: ExtractedFeatures, rows: BuiltRows): string {
  const f = rows.features;
  const nodes = rows.taxonomy
    .slice(0, 4)
    .map((t) => `${t.node} ${t.weight.toFixed(2)}`)
    .join(", ");
  return (
    `  ${media.kind} "${media.title}": year ${f.year ?? "–"}, length ${f.length_raw ?? "–"}, ` +
    `commitment ${f.commitment ?? "–"}, lang ${f.language ?? "–"}, ${extracted.people.length} people, ` +
    `nodes [${nodes || "none"}]${f.sound_tags.length ? `, sound [${f.sound_tags.join(", ")}]` : ""}`
  );
}

async function main(): Promise<void> {
  console.log(
    APPLY ? "Extracting and WRITING features." : "Dry run: nothing will be written (pass --apply)."
  );
  const { mappings, nodeIds } = await loadTaxonomy();

  const media = (
    await readAll<MediaRow>("media", (from, to) =>
      db
        .from("media")
        .select("id, kind, title, external_source, external_id")
        .not("external_source", "is", null)
        .not("external_id", "is", null)
        .order("created_at")
        .range(from, to)
    )
  ).filter((row) => !KIND || row.kind === KIND);
  const existing = await readAll<{
    media_id: string;
    extractor_version: number;
    length_raw: number | null;
  }>("media_features", (from, to) =>
    db.from("media_features").select("media_id, extractor_version, length_raw").range(from, to)
  );
  const done = new Map(existing.map((row) => [row.media_id, row]));
  const kindOf = new Map(media.map((row) => [row.id, row.kind]));

  // Every known length per kind: the sample a percentile is taken over.
  const samples = new Map<MediaKind, { mediaId: string; length: number }[]>();
  const addSample = (kind: MediaKind, mediaId: string, length: number | null) => {
    if (length === null) return;
    const list = (samples.get(kind) ?? []).filter((entry) => entry.mediaId !== mediaId);
    samples.set(kind, [...list, { mediaId, length }]);
  };
  for (const row of existing) {
    const kind = kindOf.get(row.media_id);
    if (kind) addSample(kind, row.media_id, row.length_raw);
  }

  const todo = media
    .filter((row) => REFRESH || (done.get(row.id)?.extractor_version ?? 0) < EXTRACTOR_VERSION)
    .slice(0, LIMIT);
  console.log(`${todo.length} of ${media.length} catalog items to extract.`);

  let written = 0;
  const failures: string[] = [];
  for (const row of todo) {
    try {
      const extracted = await fetchFeatures(row.kind, row.external_source, row.external_id, {
        tmdbApiKey
      });
      const lengths = (samples.get(row.kind) ?? []).map((entry) => entry.length);
      const rows = buildRows(row.id, extracted, mappings, lengths);
      const problems = featureRowProblems(rows.features);
      if (problems.length > 0) throw new Error(problems.join("; "));
      console.log(describe(row, extracted, rows));
      if (APPLY) await writeItem(row.id, extracted, rows, nodeIds);
      addSample(row.kind, row.id, rows.features.length_raw);
      written += 1;
    } catch (error) {
      failures.push(
        `  ${row.kind} "${row.title}" (${row.external_source}:${row.external_id}): ${(error as Error).message}`
      );
    }
  }

  await recomputeCommitment(samples);
  console.log(`\n${written} extracted${APPLY ? " and written" : ""}, ${failures.length} failed.`);
  if (failures.length > 0) console.log(failures.join("\n"));
}

await main();
