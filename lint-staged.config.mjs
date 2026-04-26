// =============================================================================
// lint-staged — runs against staged files on every `git commit`.
// =============================================================================
// We use the function form (rather than the package.json shorthand) so we can
// ONLY run typecheck when TypeScript files are staged. Doc-only and JSON-only
// commits skip the ~3-5s typecheck step.
//
// To skip in an emergency: `git commit --no-verify`. Prefer fixing the issue.

/** @type {import('lint-staged').Configuration} */
export default {
  '*.{ts,tsx,js,jsx}': (files) => {
    const list = files.join(' ');
    // --no-warn-ignored stops ESLint from warning when a staged file matches
    // our ignore globs (e.g. *.config.js). Otherwise lint-staged would fail
    // pre-commit on jest.config.js even though the file is intentionally
    // unlinted.
    const cmds = [
      `eslint --fix --max-warnings=0 --no-warn-ignored ${list}`,
      `prettier --write ${list}`,
    ];
    // Only run a project-wide typecheck if any TS file is staged.
    if (files.some((f) => f.endsWith('.ts') || f.endsWith('.tsx'))) {
      cmds.push('npm run typecheck');
    }
    return cmds;
  },
  '*.{json,md,yml,yaml}': 'prettier --write',
};
