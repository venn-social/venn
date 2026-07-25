// =============================================================================
// Commitlint — enforces conventional commit messages.
// =============================================================================
// All commit messages must follow the Conventional Commits spec:
//   <type>(<optional scope>): <subject>
//
// Examples (good):
//   feat(auth): add sign-in with Apple
//   fix(feed): crash when post has no caption
//   docs: clarify PR review rubric
//   chore(deps): bump expo to 52.0.1
//
// Examples (bad — will be rejected):
//   updated stuff
//   WIP
//   fixed the bug
//
// Allowed types:
//   feat      — a new user-facing feature
//   fix       — a bug fix
//   docs      — documentation only
//   style     — formatting, whitespace (no behavior change)
//   refactor  — code restructuring (no behavior change, no new feature)
//   perf      — performance improvement
//   test      — adding or fixing tests
//   build     — build system / dependencies
//   ci        — CI configuration
//   chore     — anything else (e.g., tidying up)
//   revert    — reverts a previous commit
//
// Why? Conventional commits make changelogs, release notes, and git history
// legible at a glance. They also let us automate semantic versioning later.
//
// Dependabot commits are exempt (see `ignores` below). Dependabot's
// auto-generated body embeds a YAML `updated-dependencies:` block ahead of
// its `Signed-off-by:` trailer — a format @commitlint/cli 21.2.1 (itself a
// past Dependabot bump) started rejecting under `footer-leading-blank`,
// even though the header already follows Conventional Commits. We don't
// control Dependabot's commit body, so we skip linting it rather than
// fight an upstream parser change on every future dependency PR. This
// still lints every human-authored commit exactly as before; the ignore
// only matches on Dependabot's own signoff line.
// =============================================================================

/** @type {import('@commitlint/types').UserConfig} */
export default {
  extends: ['@commitlint/config-conventional'],
  ignores: [(message) => message.includes('Signed-off-by: dependabot[bot]')],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'docs',
        'style',
        'refactor',
        'perf',
        'test',
        'build',
        'ci',
        'chore',
        'revert',
      ],
    ],
    'subject-case': [2, 'never', ['upper-case', 'pascal-case', 'start-case']],
    'subject-full-stop': [2, 'never', '.'],
    'header-max-length': [2, 'always', 100],
    'body-leading-blank': [2, 'always'],
    'body-max-line-length': [0, 'always'],
    'footer-leading-blank': [2, 'always'],
  },
};
