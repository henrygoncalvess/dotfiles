-- ==========================================
-- VANILLA NEOVIM CONFIG (LVIM FLAVOR)
-- ==========================================

-- Leader key
vim.g.mapleader = " "

-- Appearance
vim.opt.background = "dark"   -- Force dark theme
vim.opt.cursorline = false    -- Hide cursor line
vim.opt.number = true         -- Show absolute line numbers
vim.opt.relativenumber = true -- Show relative line numbers
vim.opt.numberwidth = 2       -- Gutter width
vim.opt.wrap = true           -- Wrap long lines
vim.opt.showmode = true       -- Show current mode (e.g., -- INSERT --)
vim.opt.showtabline = 2       -- Always show top tabline

-- Native Window Transparency
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

-- Window Title (Safe fallback if gitsigns is missing)
vim.opt.title = true
vim.opt.titlestring = "%{fnamemodify(getcwd(), ':t')} (%{get(b:,'gitsigns_head','')}) | %f%{&modified?' ●':''}"

-- System & Indentation
vim.opt.clipboard = "unnamedplus" -- Use system clipboard
vim.opt.termguicolors = true      -- True color support
vim.opt.smartcase = true          -- Smart case search
vim.opt.smartindent = true        -- Smart auto-indenting
vim.opt.expandtab = true          -- Convert tabs to spaces
vim.opt.shiftwidth = 2            -- Indent size
vim.opt.tabstop = 2               -- Tab size

-- Undo & Backup
vim.opt.swapfile = false -- Disable swap files
vim.opt.backup = false   -- Disable backup files
vim.opt.undofile = true  -- Save undo history across sessions

-- Splits
vim.opt.splitbelow = true -- Horizontal splits open below
vim.opt.splitright = true -- Vertical splits open right

-- Native File Explorer (Netrw acting like Lir)
vim.g.netrw_banner = 0       -- Hide top banner
vim.g.netrw_liststyle = 3    -- Tree view mode
vim.g.netrw_hide = 0         -- Show hidden files by default

-- ==========================================
-- KEYMAPS
-- ==========================================
local map = vim.keymap.set

-- Auto-close brackets
map('i', '(', '()<Left>', { noremap = true })
map('i', '[', '[]<Left>', { noremap = true })
map('i', '{', '{}<Left>', { noremap = true })
map('i', '"', '""<Left>', { noremap = true })
map('i', "'", "''<Left>", { noremap = true })

-- Clear search highlights
map('n', '<leader>h', ':nohlsearch<CR>', { noremap = true, silent = true })

-- Split navigation
map('n', '<C-h>', '<C-w>h', { noremap = true })
map('n', '<C-j>', '<C-w>j', { noremap = true })
map('n', '<C-k>', '<C-w>k', { noremap = true })
map('n', '<C-l>', '<C-w>l', { noremap = true })

-- Toggle native File Explorer
map('n', '<leader>e', ':Lexplore<CR>', { noremap = true, silent = true })

-- LunarVim buffer navigation (Native equivalents)
map('n', '<S-x>', ':bdelete<CR>', { noremap = true, silent = true })   -- Close buffer
map('n', '<S-l>', ':bnext<CR>', { noremap = true, silent = true })      -- Next buffer
map('n', '<S-h>', ':bprevious<CR>', { noremap = true, silent = true })  -- Previous buffer

-- Keep cursor centered when scrolling
map('n', '<C-d>', '<C-d>zz', { noremap = true })
map('n', '<C-u>', '<C-u>zz', { noremap = true })

-- Escape terminal mode
map('t', '<Esc>', '<C-\\><C-n>', { noremap = true })

-- ==========================================
-- NATIVE BEHAVIOR SIMULATORS (ZERO INSTALLS)
-- ==========================================

-- Format on save (Fails silently if no LSP is attached)
vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function()
        pcall(vim.lsp.buf.format)
    end,
})

-- Restore cursor to last known position when opening a file
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- ==========================================
-- NATIVE "BUFFERLINE" (HACK THE TOP BAR)
-- ==========================================

function _G.custom_buffer_tabline()
    local names = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        -- Only show listed buffers (ignore Netrw, quickfix, terminals)
        if vim.bo[buf].buflisted then
            local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
            if filename == "" then filename = "[No Name]" end

            local is_selected = (buf == vim.api.nvim_get_current_buf())
            local is_modified = vim.bo[buf].modified and " ●" or ""

            -- TabLineSel = active color / TabLine = inactive color
            local hl = is_selected and "%#TabLineSel#" or "%#TabLine#"
            table.insert(names, hl .. "  " .. filename .. is_modified .. "  ")
        end
    end
    -- Append TabLineFill to paint the remaining empty space on the right
    return table.concat(names, "") .. "%#TabLineFill#"
end

-- Force Neovim to use our Lua function to draw the top bar
vim.opt.tabline = "%!v:lua.custom_buffer_tabline()"
