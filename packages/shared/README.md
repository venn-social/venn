# @venn/shared

Types, constants, and pure utilities shared across every Venn app — mobile today, web and backend tomorrow.

**Rules:**

- Never import React, React Native, or any platform SDK here.
- Only put code here if *at least two* apps will use it. Otherwise it belongs in the app.
- All functions must be pure (no side effects, no I/O).
