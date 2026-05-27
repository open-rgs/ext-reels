# @open-rgs-ext/reels

Reel-spin utilities for open-rgs Lua maths. The reference implementation
of the [`LuaExtension`](https://github.com/open-rgs/open-rgs/blob/main/packages/contract/src/index.ts)
contract — use it directly, or copy the shape to ship your own.

## What's in it

- A pure-Lua module (`reels.lua`) that math files `require("reels")` for:
  `spin`, `spin_column`, `symbol_at`, `count_symbol`, `positions_of`,
  `line_symbols`.
- A native helper, `weighted_pick(weights, r)`, for hot paths where
  iterating a big bucket list in Lua is slower than doing it in TS
  (mostly relevant inside simulator loops, not normal in-game spins).
- Lua-language-server annotations in `meta/reels.d.lua` so your editor
  knows the types on the Lua side.

## Install

```bash
bun add @open-rgs-ext/reels
```

## Wire into a game

```ts
import { loadLuaMath } from "@open-rgs/core";
import { reels } from "@open-rgs-ext/reels";

const math = await loadLuaMath("./maths/spin.lua", {
  extensions: [reels],
});
```

Then in Lua:

```lua
local r = require("reels")

local STRIPS = {
  {"A","K","Q","J","T","S","A","K","S","Q"},
  {"K","Q","A","S","T","J","S","A","Q","K"},
  -- …
}

return {
  kind = "simple", name = "demo", version = "0.1.0", rtp = 0.95,
  play = function(prev, ctx)
    local grid     = r.spin(STRIPS, 3, host.rng_next)
    local scatters = r.count_symbol(grid, "S")

    local mult = 0
    if scatters >= 3 then mult = 5 end

    return {
      multiplier = mult,
      ops = {
        { kind = "grid",    cells = grid },
        { kind = "scatter", count = scatters },
      },
      type = mult > 0 and "trigger" or "spin",
    }
  end,
}
```

## Editor types on the Lua side

Add this to your game's `.luarc.json`:

```json
{
  "workspace.library": ["./node_modules/@open-rgs-ext/reels/meta"]
}
```

You get completion + type-checking on `r.spin`, `r.count_symbol`, etc.

## Test it

```bash
bun install
bun test
```

The smoke test spins up a real Lua VM, registers the extension, and
verifies a deterministic grid against a known RNG seed.

## Build your own extension

The shape is two-and-a-half things:

```ts
import type { LuaExtension } from "@open-rgs/contract";

export const ext: LuaExtension = {
  name: "your-module",     // require("your-module") in Lua
  version: "0.1.0",
  lua: `-- optional pure-Lua source; should return a table
        local M = {}
        function M.hello() return "hi" end
        return M`,
  host: (vm) => ({
    // optional TS-backed functions; shadow same-named lua keys
    fast_thing(x: number) { return x * 2; },
  }),
  transform: (src, path) => src,  // optional preprocessor
};
```

Then publish under `@your-scope/<name>` and document the require() shape.
That's it.

## License

MIT.
