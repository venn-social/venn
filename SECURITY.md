# Security policy

## Reporting a vulnerability

If you believe you've found a security vulnerability in Venn, please **do not** open a public issue or PR. Instead, email chmsalomon@gmail.com with:

- A description of the issue.
- Steps to reproduce.
- The potential impact.

You can expect an acknowledgment within 72 hours.

## Our commitments

- We rotate the Supabase `service_role` key if it's ever exposed.
- We turn on GitHub Secret Scanning + Push Protection so secrets can't be pushed to the repo by accident.
- We enable Dependabot for both npm and GitHub Actions updates.
- We review and merge security-related dependency bumps within a week of release.
