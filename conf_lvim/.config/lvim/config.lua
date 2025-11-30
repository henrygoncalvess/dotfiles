-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Example configs: https://github.com/LunarVim/starter.lvim
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

-- ========================================
-- APPEARANCE
-- ========================================
lvim.colorscheme = "dracula"
lvim.transparent_window = true
lvim.builtin.illuminate.active = false
vim.opt.cursorline = false

-- line number style
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 2
vim.opt.wrap = true
vim.opt.showmode = true
vim.opt.showtabline = 2

-- window
vim.opt.titlestring = "%{fnamemodify(getcwd(), ':t')} (%{get(b:,'gitsigns_head','')}) | %f%{&modified?' ●':''}"

-- ========================================
-- SYSTEM
-- ========================================
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.smartcase = true
vim.opt.smartindent = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2

-- ========================================
-- KEYBINDINGS
-- ========================================

lvim.keys.normal_mode["<S-x>"] = ":BufferKill<CR>"
lvim.keys.normal_mode["<S-l>"] = ":BufferLineCycleNext<CR>"
lvim.keys.normal_mode["<S-h>"] = ":BufferLineCyclePrev<CR>"
lvim.keys.normal_mode["<C-d>"] = "<C-d>zz"
lvim.keys.normal_mode["<C-u>"] = "<C-u>zz"

-- ========================================
-- FILE EXPLORER
-- ========================================
lvim.builtin.lir.show_hidden_files = true

-- ========================================
-- ADDITIONAL PLUGINS
-- ========================================
lvim.plugins = {
  { "Mofiqul/dracula.nvim" },
  {
    "mrjones2014/nvim-ts-rainbow",
  },
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
  },
  {
    "kevinhwang91/nvim-bqf",
    event = { "BufRead", "BufNew" },
    config = function()
      require("bqf").setup({
        auto_enable = true,
        preview = {
          win_height = 12,
          win_vheight = 12,
          delay_syntax = 80,
          border_chars = { "┃", "┃", "━", "━", "┏", "┓", "┗", "┛", "█" },
        },
        func_map = {
          vsplit = "",
          ptogglemode = "z,",
          stoggleup = "",
        },
        filter = {
          fzf = {
            action_for = { ["ctrl-s"] = "split" },
            extra_opts = { "--bind", "ctrl-o:toggle-all", "--prompt", "> " },
          },
        },
      })
    end,
  },
  {
    "andymass/vim-matchup",
    event = "CursorMoved",
    config = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },
}

-- ========================================
-- FORMATTERS AND LINTERS
-- ========================================
-- install via :Mason -> (linter) -> press i
lvim.builtin.treesitter.matchup.enable = true
lvim.lsp.installer.setup.automatic_installation = false
lvim.format_on_save = {
  timeout = 1000,
  enabled = true
}

local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  { name = "black" },
  { name = "biome" },
  { name = "prettier" },
}
