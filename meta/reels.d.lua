---@meta
--
-- lua-language-server type annotations for @open-rgs/ext-reels.
-- Add this file's directory to the workspace.library setting in
-- .luarc.json to get editor completion and type-checking on the
-- Lua side.

---@alias reels.Symbol string
---@alias reels.Strip  reels.Symbol[]
---@alias reels.Grid   reels.Strip[]
---@alias reels.Pos    integer[]
---@alias reels.Line   integer[]
---@alias reels.Rng    fun(): number

---@class reels.LineWin
---@field symbol     reels.Symbol
---@field count      integer
---@field payout     number
---@field wild_mult  number       multiplier applied from wilds on the line

---@class reels.PaylineWin : reels.LineWin
---@field line_index integer

---@class reels.PaylinesResult
---@field total number
---@field lines reels.PaylineWin[]

---@alias reels.Paytable        table<reels.Symbol, table<integer, number>>
---@alias reels.ScatterPaytable table<integer, number>
---@alias reels.WildMultGrid    table<integer, table<integer, number>>

---@class reels
local M = {}

---Spin a single column. Returns `rows` symbols starting from a uniform
---random offset, wrapping at the strip end.
---@param strip reels.Strip
---@param rows  integer
---@param rng   reels.Rng
---@return reels.Strip
function M.spin_column(strip, rows, rng) end

---Spin a whole reelset.
---@param strips reels.Strip[]
---@param rows   integer
---@param rng    reels.Rng
---@return reels.Grid
function M.spin(strips, rows, rng) end

---Get the symbol at a {col, row} position. nil if out of range.
---@param grid reels.Grid
---@param pos  reels.Pos
---@return reels.Symbol?
function M.symbol_at(grid, pos) end

---Count occurrences of `symbol` across the entire grid.
---@param grid   reels.Grid
---@param symbol reels.Symbol
---@return integer
function M.count_symbol(grid, symbol) end

---Find every {col, row} where `symbol` appears.
---@param grid   reels.Grid
---@param symbol reels.Symbol
---@return reels.Pos[]
function M.positions_of(grid, symbol) end

---Read the column-by-column symbols along a payline.
---@param grid reels.Grid
---@param line reels.Line  per-column row indices
---@return reels.Symbol[]
function M.line_symbols(grid, line) end

---Evaluate ONE payline left-to-right. Wilds substitute for any symbol
---except scatter; per-position wild multipliers compound across the
---winning run. Returns nil on no-win.
---@param symbols    reels.Symbol[]
---@param paytable   reels.Paytable
---@param wild_id    reels.Symbol
---@param scatter_id reels.Symbol
---@param wild_mults table<integer, number>?
---@return reels.LineWin?
function M.eval_payline_left(symbols, paytable, wild_id, scatter_id, wild_mults) end

---Evaluate every payline against the grid, return total + per-line winners.
---@param grid           reels.Grid
---@param paylines       reels.Line[]
---@param paytable       reels.Paytable
---@param wild_id        reels.Symbol
---@param scatter_id     reels.Symbol
---@param wild_mult_grid reels.WildMultGrid?
---@return reels.PaylinesResult
function M.eval_paylines(grid, paylines, paytable, wild_id, scatter_id, wild_mult_grid) end

---Book-of mechanic: fill every reel containing `symbol` with `symbol`
---on all rows. Mutates and returns `grid` for chaining.
---@param grid   reels.Grid
---@param symbol reels.Symbol
---@return reels.Grid
function M.expand_symbol(grid, symbol) end

---Pick a string key from a name→weight map proportional to weights.
---@param weights table<string, number>
---@param rng     reels.Rng
---@return string?
function M.pick_weighted_key(weights, rng) end

---Scatter pay lookup. `count` >= the smallest key with a non-zero value triggers.
---@param count        integer
---@param scatter_pays reels.ScatterPaytable
---@return number
function M.count_scatter_pay(count, scatter_pays) end

---10 classic 5×3 paylines (rows then diagonals then zigzags).
---@type reels.Line[]
M.PAYLINES_5x3_10 = {}

---20-line 5×3 set (10 classic + 10 alternating).
---@type reels.Line[]
M.PAYLINES_5x3_20 = {}

---Native: pick a 1..#weights index with probability ∝ weights[i]. `r` ∈ [0,1).
---@param weights number[]
---@param r       number
---@return integer
function M.weighted_pick(weights, r) end

return M
