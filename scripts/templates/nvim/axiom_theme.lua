-- Follows the axiom (quickshell) theme. axiom's scripts/theme_nvim.sh writes
-- the active theme to $XDG_STATE_HOME/axiom/nvim-theme.json and calls
-- reload() in every running Neovim over RPC.
--
-- Copied here by axiom's settings (Theme integrations → Neovim); yours to
-- edit. Call it once your plugins are loaded, e.g. in init.lua after your
-- plugin manager's setup:
--
--   require("axiom_theme").setup({
--     -- axiom theme file stem -> a colorscheme you have installed
--     map = { ["tokyo-night"] = { colorscheme = "tokyonight-night", plugin = "tokyonight.nvim" } },
--   })
--
-- A theme without a map entry is built from its base16 palette: by
-- mini.base16 when it's installed, otherwise by the plain highlights below.
local M = {}

M.path = (vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")) .. "/axiom/nvim-theme.json"

-- axiom theme file stem -> { colorscheme = name, plugin = lazy.nvim plugin name (optional) }
M.map = {}

-- Colorscheme when there's no axiom theme file (nil: leave it alone)
M.fallback = nil

local function read_theme()
  local fd = io.open(M.path, "r")
  if not fd then
    return nil
  end
  local ok, theme = pcall(vim.json.decode, fd:read("*a"))
  fd:close()
  if ok and type(theme) == "table" and type(theme.colors) == "table" then
    return theme
  end
end

local function apply_native(scheme)
  if not scheme then
    return false
  end
  if scheme.plugin then
    -- A lazily loaded colorscheme plugin (lazy.nvim); harmless without it
    pcall(function()
      require("lazy").load({ plugins = { scheme.plugin } })
    end)
  end
  return pcall(vim.cmd.colorscheme, scheme.colorscheme)
end

-- The base16 styling guide's main groups, for configs without mini.base16
local function apply_plain(c)
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end
  local groups = {
    Normal = { fg = c.base05, bg = c.base00 },
    NormalFloat = { fg = c.base05, bg = c.base01 },
    FloatBorder = { fg = c.base03, bg = c.base01 },
    Comment = { fg = c.base03, italic = true },
    Constant = { fg = c.base09 },
    String = { fg = c.base0B },
    Character = { fg = c.base08 },
    Number = { fg = c.base09 },
    Boolean = { fg = c.base09 },
    Identifier = { fg = c.base08 },
    Function = { fg = c.base0D },
    Statement = { fg = c.base0E },
    Keyword = { fg = c.base0E },
    Operator = { fg = c.base05 },
    PreProc = { fg = c.base0A },
    Type = { fg = c.base0A },
    Special = { fg = c.base0C },
    Delimiter = { fg = c.base0F },
    Todo = { fg = c.base0A, bg = c.base01 },
    Error = { fg = c.base08, bg = c.base00 },
    Title = { fg = c.base0D, bold = true },
    Directory = { fg = c.base0D },
    CursorLine = { bg = c.base01 },
    CursorLineNr = { fg = c.base04, bg = c.base01 },
    LineNr = { fg = c.base03 },
    SignColumn = { fg = c.base03 },
    ColorColumn = { bg = c.base01 },
    Visual = { bg = c.base02 },
    Search = { fg = c.base01, bg = c.base0A },
    IncSearch = { fg = c.base01, bg = c.base09 },
    MatchParen = { bg = c.base03 },
    Pmenu = { fg = c.base05, bg = c.base01 },
    PmenuSel = { fg = c.base01, bg = c.base05 },
    StatusLine = { fg = c.base04, bg = c.base02 },
    StatusLineNC = { fg = c.base03, bg = c.base01 },
    TabLine = { fg = c.base03, bg = c.base01 },
    TabLineSel = { fg = c.base0B, bg = c.base01 },
    WinSeparator = { fg = c.base02 },
    Folded = { fg = c.base03, bg = c.base01 },
    NonText = { fg = c.base03 },
    WarningMsg = { fg = c.base08 },
    ErrorMsg = { fg = c.base08 },
    DiffAdd = { fg = c.base0B, bg = c.base01 },
    DiffChange = { fg = c.base03, bg = c.base01 },
    DiffDelete = { fg = c.base08, bg = c.base01 },
    DiffText = { fg = c.base0D, bg = c.base01 },
    DiagnosticError = { fg = c.base08 },
    DiagnosticWarn = { fg = c.base0A },
    DiagnosticInfo = { fg = c.base0D },
    DiagnosticHint = { fg = c.base0C },
  }
  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, spec)
  end
  return true
end

local function apply_palette(theme)
  local ok = pcall(function()
    require("mini.base16").setup({ palette = theme.colors, use_cterm = true })
  end)
  if not ok then
    ok = pcall(apply_plain, theme.colors)
  end
  if not ok then
    return false
  end
  vim.g.colors_name = "axiom-" .. theme.stem
  -- Neither fires ColorScheme itself; statuslines ('auto' themes) listen for it
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name })
  return true
end

function M.reload()
  local theme = read_theme()
  if not theme then
    apply_native(M.fallback)
    return
  end
  vim.o.background = theme.variant == "light" and "light" or "dark"
  if apply_native(M.map[theme.stem]) then
    return
  end
  if not apply_palette(theme) then
    apply_native(M.fallback)
  end
end

function M.setup(opts)
  opts = opts or {}
  M.map = vim.tbl_extend("force", M.map, opts.map or {})
  if opts.fallback then
    M.fallback = opts.fallback
  end
  M.reload()
end

return M
