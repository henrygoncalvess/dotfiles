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
vim.opt.titlestring = "%<%F%=%l/%L - nvim"

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
  "Mofiqul/dracula.nvim",
}

