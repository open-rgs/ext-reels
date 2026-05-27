-- @open-rgs-ext/reels — reel-spin utilities for open-rgs Lua maths.
--
-- Conventions:
--   • Strips are column-major: strips[col][index] (1-indexed)
--   • Grids are column-major: grid[col][row]      (1-indexed)
--   • Positions are { col, row }
--   • Symbols are strings; nothing else is opaque
--   • Paylines are arrays of row indices (one per column)

local M = {}

-- ─── Spin primitives ───────────────────────────────────────────────────

-- Spin one column: pick a starting offset uniformly, return `rows` symbols
-- starting at that offset (wrapping the strip end → start). `rng` is a
-- function returning a float in [0, 1).
function M.spin_column(strip, rows, rng)
  local n = #strip
  local start = math.floor(rng() * n)
  local out = {}
  for r = 1, rows do
    out[r] = strip[((start + r - 1) % n) + 1]
  end
  return out
end

-- Spin a whole reelset. `strips` is the per-column strip table.
function M.spin(strips, rows, rng)
  local cols = #strips
  local grid = {}
  for c = 1, cols do
    grid[c] = M.spin_column(strips[c], rows, rng)
  end
  return grid
end

-- ─── Grid lookups ──────────────────────────────────────────────────────

-- Lookup the symbol at a {col, row} position. Returns nil if out of range.
function M.symbol_at(grid, pos)
  local col = grid[pos[1]]
  if not col then return nil end
  return col[pos[2]]
end

-- Count how many times `symbol` appears across the whole grid.
function M.count_symbol(grid, symbol)
  local n = 0
  for c = 1, #grid do
    local col = grid[c]
    for r = 1, #col do
      if col[r] == symbol then n = n + 1 end
    end
  end
  return n
end

-- Find every {col, row} position where `symbol` appears.
function M.positions_of(grid, symbol)
  local out = {}
  for c = 1, #grid do
    local col = grid[c]
    for r = 1, #col do
      if col[r] == symbol then
        out[#out + 1] = { c, r }
      end
    end
  end
  return out
end

-- Read the symbols along a payline. `line` is a per-column row index.
-- Returns the list of symbols column-by-column.
function M.line_symbols(grid, line)
  local out = {}
  for c = 1, #line do
    out[c] = grid[c][line[c]]
  end
  return out
end

-- ─── Payline evaluation ───────────────────────────────────────────────

-- Evaluate ONE payline left-to-right.
--
-- A "win" is the longest prefix of matching symbols starting from the
-- leftmost reel. Wilds substitute for any symbol except scatter. If the
-- entire prefix is wilds, the run is treated as "wild" itself (paid
-- via paytable[wild_id] if present, otherwise no pay).
--
-- Per-position wild multipliers compound on the winning run only.
--
-- Args:
--   symbols    : array of symbols along the line (one per column)
--   paytable   : { [symbol] = { [count] = mult, ... }, ... }
--                count is the number of matching symbols starting at left.
--   wild_id    : symbol id that substitutes for non-scatter symbols
--   scatter_id : symbol id that NEVER substitutes (skip from line pays)
--   wild_mults : optional { [col_index] = mult } — multiplier carried by
--                the wild at that position. Compounds across all wilds
--                that participate in the winning run.
--
-- Returns: { symbol, count, payout, wild_mult } or nil on no-win.
function M.eval_payline_left(symbols, paytable, wild_id, scatter_id, wild_mults)
  local n = #symbols
  if n == 0 then return nil end

  -- Anchor: first non-wild symbol from the left. If everything is wild,
  -- anchor is the wild itself (so the wild's own paytable entry, if any,
  -- determines the prize for an all-wild line).
  local anchor
  for i = 1, n do
    if symbols[i] ~= wild_id then
      anchor = symbols[i]
      break
    end
  end
  if anchor == nil then anchor = wild_id end

  -- Scatters never pay by line — only by count.
  if anchor == scatter_id then return nil end

  -- Walk the prefix: count {anchor, wild} matches, compound wild mult.
  local run_count = 0
  local wild_mult = 1
  for i = 1, n do
    local s = symbols[i]
    if s == anchor or s == wild_id then
      run_count = run_count + 1
      if s == wild_id and wild_mults and wild_mults[i] and wild_mults[i] > 0 then
        wild_mult = wild_mult * wild_mults[i]
      end
    else
      break
    end
  end

  local pt = paytable[anchor]
  if not pt then return nil end
  local base = pt[run_count] or 0
  if base == 0 then return nil end

  return {
    symbol    = anchor,
    count     = run_count,
    payout    = base * wild_mult,
    wild_mult = wild_mult,
  }
end

-- Evaluate every payline against `grid`. Returns the total payout (sum
-- of all line wins) and a per-line breakdown of every winning line.
--
-- `wild_mult_grid` is OPTIONAL: { [col] = { [row] = mult } }. Lets the
-- math attach a multiplier to specific wild landings on the grid, which
-- the per-line evaluator picks up when a wild participates in a winning
-- run. Pass nil if your wilds carry no multiplier.
function M.eval_paylines(grid, paylines, paytable, wild_id, scatter_id, wild_mult_grid)
  local total = 0
  local lines = {}
  for li = 1, #paylines do
    local line = paylines[li]
    local row_syms = {}
    local row_mults
    for c = 1, #line do
      row_syms[c] = grid[c][line[c]]
      if wild_mult_grid and wild_mult_grid[c] then
        local m = wild_mult_grid[c][line[c]]
        if m and m > 0 then
          row_mults = row_mults or {}
          row_mults[c] = m
        end
      end
    end
    local r = M.eval_payline_left(row_syms, paytable, wild_id, scatter_id, row_mults)
    if r then
      total = total + r.payout
      lines[#lines + 1] = {
        line_index = li,
        symbol     = r.symbol,
        count      = r.count,
        payout     = r.payout,
        wild_mult  = r.wild_mult,
      }
    end
  end
  return { total = total, lines = lines }
end

-- ─── Book-of mechanic ─────────────────────────────────────────────────

-- Expand a symbol across every column that contains it: any reel with
-- at least one landing of `symbol` is filled with `symbol` on all rows.
-- Mutates AND returns the grid for chaining convenience.
function M.expand_symbol(grid, symbol)
  for c = 1, #grid do
    local col = grid[c]
    local has = false
    for r = 1, #col do
      if col[r] == symbol then has = true; break end
    end
    if has then
      for r = 1, #col do
        col[r] = symbol
      end
    end
  end
  return grid
end

-- ─── Weighted picking ─────────────────────────────────────────────────

-- Pick a string key from a name→weight map proportional to weights.
-- Iteration order of pairs() is implementation-defined; for repeatable
-- results across runs, sort the keys upstream and call weighted_pick.
function M.pick_weighted_key(weights, rng)
  local total = 0
  for _, w in pairs(weights) do total = total + w end
  if total <= 0 then return nil end
  local target = rng() * total
  local acc = 0
  local last_k
  for k, w in pairs(weights) do
    last_k = k
    acc = acc + w
    if target < acc then return k end
  end
  return last_k
end

-- ─── Scatter pay lookup ───────────────────────────────────────────────

-- Tiny helper kept here for parity with line evaluator: scatters pay
-- by count (3+ usually), independent of position.
function M.count_scatter_pay(count, scatter_pays)
  return scatter_pays[count] or 0
end

-- ─── Standard payline shapes ──────────────────────────────────────────

-- 10 classic paylines for a 5×3 grid. Row 1 = top.
-- Order matches industry convention (rows first, then diagonals, zigzags).
M.PAYLINES_5x3_10 = {
  { 2, 2, 2, 2, 2 },  -- 1: middle row
  { 1, 1, 1, 1, 1 },  -- 2: top row
  { 3, 3, 3, 3, 3 },  -- 3: bottom row
  { 1, 2, 3, 2, 1 },  -- 4: V down-up
  { 3, 2, 1, 2, 3 },  -- 5: V up-down
  { 1, 1, 2, 3, 3 },  -- 6: top→bottom diag
  { 3, 3, 2, 1, 1 },  -- 7: bottom→top diag
  { 2, 1, 1, 1, 2 },  -- 8: middle, top hump
  { 2, 3, 3, 3, 2 },  -- 9: middle, bottom hump
  { 1, 2, 1, 2, 1 },  -- 10: zigzag top
}

-- 20-line set (10 above + 10 more).
M.PAYLINES_5x3_20 = {
  { 2, 2, 2, 2, 2 },
  { 1, 1, 1, 1, 1 },
  { 3, 3, 3, 3, 3 },
  { 1, 2, 3, 2, 1 },
  { 3, 2, 1, 2, 3 },
  { 1, 1, 2, 3, 3 },
  { 3, 3, 2, 1, 1 },
  { 2, 1, 1, 1, 2 },
  { 2, 3, 3, 3, 2 },
  { 1, 2, 1, 2, 1 },
  { 3, 2, 3, 2, 3 },
  { 2, 1, 2, 1, 2 },
  { 2, 3, 2, 3, 2 },
  { 1, 1, 2, 1, 1 },
  { 3, 3, 2, 3, 3 },
  { 2, 2, 1, 2, 2 },
  { 2, 2, 3, 2, 2 },
  { 1, 2, 2, 2, 1 },
  { 3, 2, 2, 2, 3 },
  { 1, 3, 1, 3, 1 },
}

return M
