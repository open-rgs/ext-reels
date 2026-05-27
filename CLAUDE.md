# CLAUDE.md — handoff for ext-reels

Reference `LuaExtension` for open-rgs. Lives under the same `open-rgs`
GitHub org as `open-rgs/open-rgs` (contract + core + adapter-kit + …).

This repo is **MIT, publishable**. It's the reference for anyone
writing their own Lua extension — the shape, the testing pattern, the
LSP-types pattern.

## What's in it

- `src/index.ts` — exports `reels: LuaExtension`. Reads sibling
  `reels.lua` at import time so the source ships with the package.
- `src/reels.lua` — pure-Lua module returned by `require("reels")`.
  Conventions: column-major grids/strips, 1-indexed, symbols are strings.
- `meta/reels.d.lua` — lua-language-server type annotations. Consumers
  add this directory to their `.luarc.json` `workspace.library`.
- `test/reels.test.ts` — bun:test smoke. Uses `loadLuaMath` from
  `@open-rgs/core` to install the extension into a real VM and assert
  grid output against a deterministic RNG.

## Editing guide

- **Adding a Lua function:** edit `src/reels.lua` AND `meta/reels.d.lua`
  in the same PR. The .d.lua is what gives editor completion; out-of-
  sync = silent regression.
- **Adding a host function:** edit `src/index.ts` (the `host()` return)
  AND `meta/reels.d.lua`. Host functions shadow lua ones — if you add
  one with the same name as a lua one, document why.
- **Adding a transform:** rarely needed; if you do, write a clear
  spec in the README about what input shape it expects.
- **Bumping the version:** semver. The version string surfaces in
  `loadLuaMath`'s debug logs.

## How it works under the hood

`loadLuaMath` in `@open-rgs/core` iterates `opts.extensions`, evaluates
each `lua` source as a closure, merges `host()` keys, and stores the
combined table in a registry. It then overrides Lua's `require()` to
read from that registry only — no filesystem fallback. So:

- `require("reels")` works.
- `require("io")` / `require("os")` from the math file does NOT work —
  by design, math is sandboxed away from host resources.

## Sharp edges

- The lua source is `readFileSync`'d at import time. That's fine for
  Node/Bun runtime but breaks if you bundle into a browser context
  without a polyfill.
- `weighted_pick` returns a 1-indexed integer because Lua expects it.
  If you add more native helpers, follow the same convention or
  document the exception.

## Typecheck + test

```bash
bun install
bun run typecheck
bun test
```
