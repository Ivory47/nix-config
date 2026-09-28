vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.autoindent = true
vim.opt.smartindent = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.scrolloff = 2

vim.opt.clipboard = "unnamedplus"

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

-- prevent lines starting with # from being forcefully unindented
vim.opt.smartindent = false
vim.opt.cinkeys:remove("0#")
vim.opt.indentkeys:remove("0#")

-- keymaps 
vim.keymap.set("i", "jk", "<ESC>", { desc = "Exist insert mode" })
vim.keymap.set({'n', 'v'}, 'J', '<C-d>', { noremap = true, silent = true } )
vim.keymap.set({'n', 'v'}, 'K', '<C-u>', { noremap = true, silent = true })

vim.keymap.set('n', '] ', function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, { "" })
end, { desc = "Add blank line below" })
vim.keymap.set('n', '[ ', function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { "" })
end, { desc = "Add blank line below" })


local function jump_to_same_indent(direction)
    local current_line_num = vim.fn.line('.')
    local current_line_text = vim.fn.getline(current_line_num)
    
    -- Extract the exact leading whitespace of the current line (spaces or tabs)
    local leading_whitespace = current_line_text:match("^(%s*)")
    if not leading_whitespace then return end
    
    -- Escape the whitespace string so it can be used safely in a regex pattern
    local target_pattern = "^" .. leading_whitespace:gsub("%s", "%%s") .. "%S"
    
    local last_line = vim.fn.line('$')
    local step = (direction == "up") and -1 or 1
    local check_line = current_line_num + step

    while check_line >= 1 and check_line <= last_line do
        local line_text = vim.fn.getline(check_line)
        
        -- Match lines with the exact same leading whitespace followed by a character
        if line_text:match(target_pattern) then
            -- Set cursor directly to that line, at the indentation column
            vim.api.nvim_win_set_cursor(0, { check_line, #leading_whitespace })
            return
        end
        check_line = check_line + step
    end
end

-- Keymaps (Single bracket mappings)
vim.keymap.set('n', ']i', function() jump_to_same_indent("down") end, { desc = "Jump to next line with same indent" })
vim.keymap.set('n', '[i', function() jump_to_same_indent("up") end, { desc = "Jump to previous line with same indent" })

vim.g.mapleader = " "
vim.keymap.set("n", "<leader>ld", function()
    vim.diagnostic.setqflist({ open = true })
end, { desc = "Show LSP diagnostics list" })


local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        config = function()
            -- 1. Prepend Nix runtime paths so Neovim can find the Nix-installed parsers
            vim.opt.runtimepath:prepend(vim.fn.expand("$HOME/.nix-profile/share/nvim") .. "/site")
            vim.opt.runtimepath:prepend("/run/current-system/sw/share/nvim/site")

            -- 2. Treesitter now enables highlighting by default when a parser is loaded.
            -- However, to force Neovim's native Treesitter engine to handle indents, 
            -- we explicitly turn on filetype indents here:
            vim.cmd("filetype plugin indent on")
        end,
    },

    {
        "folke/snacks.nvim",
        priority = 1000,
        lazy = false,
        opts = {
            bigfile = { enabled = true },
            dashboard = { 
                enabled = true,
                preset = {
                    -- Re-define the dashboard action buttons
                    keys = {
                        { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
                        { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
                        { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
                        { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
                        -- Custom config shortcut pointing to your home-manager path:
                        { icon = " ", key = "c", desc = "Config", action = ":e ~/.config/home-manager/nvim/init.lua" },
                        { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
                        { icon = " ", key = "q", desc = "Quit", action = ":qa" },
                    },
                },
            },
            -- explorer = { enabled = true },
            indent = { enabled = true },
            input = { enabled = true },
            picker = { enabled = true },
            -- notifier = { enabled = true },
            quickfile = { enabled = true },
            scope = { enabled = true },
            scroll = { 
                enabled = true,

                animate = {
                    duration = { step = 10, total = 100 },
                    easing = "linear",
                },
            },
            statuscolumn = { enabled = true },
            words = { enabled = true },
        },

        keys = {
            { "<leader>fr", function() Snacks.picker.recent() end, desc = "Find Recent Files" },
            -- Bonus: A couple of other highly useful companion picker shortcuts
            { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
            { "<leader>fg", function() Snacks.picker.grep() end, desc = "Live Grep (Search Text)" },
            { "<leader>fo", function() Snacks.picker.buffers() end, desc = "Find Open Buffers" },
        },
    },

    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            preset = "modern",

            win = {
                border = "rounded",
                padding = { 2, 2 },

                wo = {
                    winblend = 0,
                    winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
                },
            },
            config = function(_, opts)
                vim.api.nvim_set_hl(0, "WhichKeyNormal", {
                    bg = "NONE",
                })

                require("which-key").setup(opts)
            end,
        },
    },

    {
        "saghen/blink.cmp",
        version = "1.*",
        dependencies = {
            "rafamadriz/friendly-snippets",
        },
        opts = {
            keymap = {
                preset = "default",
                ["<CR>"] = { "accept", "fallback" }, -- Shift + Enter to accept
                ["<S-CR>"] = { "fallback" },             -- Regular Enter creates a new line
            },
            completion = {
                documentation = {
                    auto_show = false,
                },
            },
            sources = {
                default = {
                    "lsp",
                    "path",
                    "snippets",
                    "buffer",
                },
            },
        },
    },

    {
        "folke/noice.nvim",
        event = "VeryLazy",
        dependencies = {
            "MunifTanjim/nui.nvim",
            "rcarriga/nvim-notify",
        },
        opts = {},
    },

    {
        "ThorstenRhau/token",
        version = "*",
        lazy = false,

        config = function()
            local token = require("token")

            token.setup({
                transparent = false,
                plugins = {
                    gitsigns = true,
                    snacks = true,
                },
            })

            vim.cmd.colorscheme("token")
        end,
    },

    {
        "folke/flash.nvim",
        event = "VeryLazy",
        ---@type Flash.Config
        opts = {
            modes = {
                search = {
                    enabled = false,
                },
            },
        },
        keys = {
            { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
            { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
            { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
            { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
            { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
        },
    },

    {
        'altermo/ultimate-autopair.nvim',
        event={'InsertEnter','CmdlineEnter'},
        branch='v0.6', --recommended as each new version will have breaking changes
        opts={
            --Config goes here
        },
    },

    {
        "brenoprata10/nvim-highlight-colors",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            ---@usage 'background'|'foreground'|'virtual'
            render = "virtual", -- This enables the VS Code style colored square
            virtual_symbol = "■", -- The icon used for the square (e.g., "■", "█", "")
            virtual_symbol_position = "inline", -- Puts it right next to the hex string
            enable_named_colors = true,
            enable_tailwind = true,
        },
    },
})

-- autoconfig

vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
    end,
})
