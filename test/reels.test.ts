// End-to-end smoke for @open-rgs-ext/reels:
//   • Verifies the extension installs into a real Lua VM via loadLuaMath
//   • Runs reels.spin against a deterministic RNG and asserts the grid
//   • Calls the native weighted_pick from Lua and asserts the bucket

import { describe, expect, test } from "bun:test";
import { writeFileSync, mkdtempSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { loadLuaMath } from "@open-rgs/core";
import { reels } from "../src/index.js";

const STRIPS = [
  ["A","K","Q","J","T","S"],
  ["K","K","A","Q","S","T"],
  ["Q","A","K","S","T","J"],
];

function writeMath(body: string): string {
  const dir = mkdtempSync(join(tmpdir(), "reels-smoke-"));
  const p = join(dir, "math.lua");
  writeFileSync(p, body);
  return p;
}

describe("@open-rgs-ext/reels", () => {
  test("exports a well-formed LuaExtension", () => {
    expect(reels.name).toBe("reels");
    expect(reels.version).toMatch(/^\d+\.\d+\.\d+$/);
    expect(typeof reels.lua).toBe("string");
    expect(reels.lua!.length).toBeGreaterThan(50);
    expect(typeof reels.host).toBe("function");
  });

  test("reels.spin produces a column-major grid against a fixed RNG", async () => {
    // Deterministic RNG: returns 0 every call → start offset 0 in each column.
    const rng = () => 0;
    const mathPath = writeMath(`
      local r = require("reels")
      local STRIPS = {
        {"A","K","Q","J","T","S"},
        {"K","K","A","Q","S","T"},
        {"Q","A","K","S","T","J"},
      }
      return {
        kind="simple", name="t", version="0.0.1", rtp=0,
        play = function(prev, ctx)
          local grid = r.spin(STRIPS, 3, host.rng_next)
          return {
            multiplier = 0,
            ops = { { kind="grid", cells = grid } },
            type = "ok",
          }
        end,
      }
    `);

    const math = await loadLuaMath(mathPath, { rng, extensions: [reels] });
    expect(math.kind).toBe("simple");
    if (math.kind !== "simple") throw new Error("not simple");

    const out = math.play(undefined, { mode: "default" });
    const result = out instanceof Promise ? await out : out;

    expect(result.type).toBe("ok");
    expect(result.ops.length).toBe(1);

    // wasmoon auto-converts 1-indexed Lua tables to 0-indexed JS arrays
    // when they're contiguous. Offset 0 → first three symbols from each strip.
    const op = result.ops[0] as { kind: string; cells: string[][] };
    expect(op.kind).toBe("grid");
    expect(op.cells[0]).toEqual(["A", "K", "Q"]);
    expect(op.cells[1]).toEqual(["K", "K", "A"]);
    expect(op.cells[2]).toEqual(["Q", "A", "K"]);
  });

  test("native weighted_pick is callable from Lua", async () => {
    const mathPath = writeMath(`
      local r = require("reels")
      return {
        kind="simple", name="t", version="0.0.1", rtp=0,
        play = function(prev, ctx)
          -- weights [10, 30, 60]; r=0.5 → cumulative threshold at 0.5*100=50,
          -- 10 (no) → 40 (no) → 100 (yes) → index 3.
          local idx = r.weighted_pick({10, 30, 60}, 0.5)
          return {
            multiplier = 0,
            ops = { { kind="pick", index = idx } },
            type = "ok",
          }
        end,
      }
    `);

    const math = await loadLuaMath(mathPath, { extensions: [reels] });
    if (math.kind !== "simple") throw new Error("not simple");
    const out = math.play(undefined, { mode: "default" });
    const result = out instanceof Promise ? await out : out;

    const op = result.ops[0] as { kind: string; index: number };
    expect(op.kind).toBe("pick");
    expect(op.index).toBe(3);
  });

  test("require() of an unregistered module surfaces a clear error", async () => {
    const mathPath = writeMath(`
      local missing = require("not-installed")
      return {
        kind="simple", name="t", version="0.0.1", rtp=0,
        play = function() return { multiplier=0, ops={}, type="ok" } end,
      }
    `);

    let err: unknown;
    try {
      await loadLuaMath(mathPath, { extensions: [reels] });
    } catch (e) {
      err = e;
    }
    expect(String(err)).toMatch(/not-installed/);
    expect(String(err)).toMatch(/not registered/);
  });
});
