// @open-rgs/ext-reels
//
// Reference LuaExtension for open-rgs. Adds a `reels` module the math
// can `require("reels")` to get reel-spin utilities.
//
// Two parts:
//   • A pure-Lua module (src/reels.lua) with spin / symbol_at / count /
//     positions_of / line_symbols. Editor-friendly via meta/reels.d.lua.
//   • A native helper (weighted_pick) for cases where Lua iteration is
//     slow enough to matter — e.g. running an exhaustive RTP simulator.
//
// Wiring (in the integrator's boot file):
//
//   import { reels } from "@open-rgs/ext-reels";
//   const math = await loadLuaMath("./maths/spin.lua", {
//     extensions: [reels],
//   });
//
// Lua-side usage:
//
//   local r = require("reels")
//   local grid = r.spin(STRIPS, 3, host.rng_next)
//   local scatters = r.count_symbol(grid, "S")

import type { LuaExtension } from "@open-rgs/contract";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const luaSource = readFileSync(join(here, "reels.lua"), "utf-8");

export const reels: LuaExtension = {
  name: "reels",
  version: "0.1.0",
  lua: luaSource,
  host: () => ({
    /** Pick an index 1..weights.length with probability proportional
     *  to each weight. `r` ∈ [0, 1) selects the slot.
     *
     *  Faster than the equivalent Lua loop for big buckets — useful
     *  inside hot simulator loops; for normal in-game spins the Lua
     *  side is fine. */
    weighted_pick(weights: readonly number[], r: number): number {
      let total = 0;
      for (const w of weights) total += w;
      if (total <= 0) return 1;
      const target = r * total;
      let acc = 0;
      for (let i = 0; i < weights.length; i++) {
        acc += weights[i]!;
        if (target < acc) return i + 1; // 1-indexed for Lua
      }
      return weights.length;
    },
  }),
};

export default reels;
