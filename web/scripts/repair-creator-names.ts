/**
 * Re-resolve stored creator names that are not in the reader's alphabet.
 *
 * The rule itself lives in the app and runs on every search, so anything
 * logged today is already correct. This exists for rows written before that
 * rule did — it applies the *same* resolution rather than restating it, by
 * calling the provider detail fetchers the app uses.
 *
 * Deliberately not a migration with values in it. A migration that says
 * `set primary_creator = 'Haruki Murakami'` fixes one row and teaches the
 * codebase nothing; the next Japanese author arrives broken. This asks the
 * provider the same question the app asks, so it works for any row, any
 * author, any language, and can be re-run whenever.
 *
 * `media` has no UPDATE policy — rows are shared across every user, so a
 * client that could rewrite them could rewrite them for everyone. That is
 * why this needs the service-role key and is not something the app does to
 * itself.
 *
 * Usage, from `web/`:
 *
 *     SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... npx tsx scripts/repair-creator-names.ts
 *     …same, with --apply to actually write
 *
 * Dry by default. It prints every change it would make and writes nothing
 * until asked.
 */

import { createClient } from "@supabase/supabase-js";
import { isLatinScript } from "@/lib/catalog/authorName";
import { loadMediaDetail } from "@/lib/mediaDetail";
import { toMedia, type MediaRow } from "@/lib/media";

const APPLY = process.argv.includes("--apply");

const url = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
// media is world-readable, so a dry run needs no privileged key. Only the
// write path does — seeing what would change should never require the
// ability to change it.
const readKey = serviceKey ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!url || !readKey) {
  console.error("Needs SUPABASE_URL and a key (anon is enough for a dry run).");
  process.exit(1);
}
if (APPLY && !serviceKey) {
  console.error(
    "--apply needs SUPABASE_SERVICE_ROLE_KEY: media has no UPDATE policy for clients, " +
      "because its rows are shared by every user."
  );
  process.exit(1);
}

const client = createClient(url, readKey, { auth: { persistSession: false } });

const { data, error } = await client.from("media").select("*");
if (error) {
  console.error("Could not read media:", error.message);
  process.exit(1);
}

const rows = (data ?? []) as MediaRow[];

// Filtered here rather than in SQL on purpose. Postgres range comparisons
// follow collation, not code points, so `primary_creator ~ '[^ -ʯ]'` also
// matches Patrick Süskind — whose name is Latin and correct. Getting that
// wrong would rewrite a name this is supposed to leave alone.
const suspect = rows.filter((row) => row.primary_creator && !isLatinScript(row.primary_creator));

console.log(`${rows.length} media rows, ${suspect.length} with a creator outside the Latin script`);
if (suspect.length === 0) {
  console.log("Nothing to do.");
  process.exit(0);
}

let changed = 0;
let unresolved = 0;

for (const row of suspect) {
  const media = toMedia(row);
  if (!media) continue;

  // The same call the media page makes, so the answer is the app's answer.
  const detail = await loadMediaDetail(media, "US");
  const resolved = detail.creators[0]?.name;

  if (!resolved || !isLatinScript(resolved)) {
    // No Latin form exists for this author. A name in the wrong script
    // beats no name, so the row is left exactly as it is.
    console.log(`  keep    ${row.title} — no Latin form for ${row.primary_creator}`);
    unresolved += 1;
    continue;
  }
  if (resolved === row.primary_creator) continue;

  console.log(`  ${APPLY ? "update " : "would  "} ${row.title}: ${row.primary_creator} → ${resolved}`);
  changed += 1;

  if (APPLY) {
    const { error: updateError } = await client
      .from("media")
      .update({ primary_creator: resolved })
      .eq("id", row.id);
    if (updateError) console.error(`    failed: ${updateError.message}`);
  }
}

console.log(
  `\n${changed} ${APPLY ? "updated" : "would change"}, ${unresolved} left alone.` +
    (APPLY ? "" : "\nRe-run with --apply to write.")
);
