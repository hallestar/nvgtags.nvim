local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error('telescope-nvgtags.nvim requires nvim-telescope/telescope.nvim')
end

local log = require "plenary.log"
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local make_entry = require "telescope.make_entry"
local entry_display = require('telescope.pickers.entry_display')
local nvgtags = require('nvgtags')
local previewers = require "telescope.previewers"
local Path = require "plenary.path"

local filter = vim.tbl_filter
local flatten = vim.tbl_flatten

local line_no_width = 8

-- local gnu_global_result_pattern = "(%w+)%s+(%d+)%s+(.-)%s+(.+)"
local gnu_global_result_pattern = "(%w+)%s+(%d+)%s+([^%s]+)%s*(.*)"

local gtags_conf
local gtags_default_conf = {
  gtags = { 'gtags' },
  global = { 'global' },
  opts = {
    preview = {
      timeout = 200,
    },
  },
  args = {
    definition = {
      "--encode-path",
      " ",
      "-xaT",
    },
    reference = {
      "--encode-path",
      " ",
      "-xra",
    },
    completion = {
      "-cT",
    },
    document = {
      "--encode-path",
      " ",
      "-xaf",
    },
  }
}


local escape_chars = function(string)
  return string.gsub(string, "[%(|%)|\\|%[|%]|%-|%{%}|%?|%+|%*|%^|%$|%.]", {
    ["\\"] = "\\\\",
    ["-"] = "\\-",
    ["("] = "\\(",
    [")"] = "\\)",
    ["["] = "\\[",
    ["]"] = "\\]",
    ["{"] = "\\{",
    ["}"] = "\\}",
    ["?"] = "\\?",
    ["+"] = "\\+",
    ["*"] = "\\*",
    ["^"] = "\\^",
    ["$"] = "\\$",
    ["."] = "\\.",
  })
end


-- as a extension of telescope, we need a setup step
local my_setup = function(ext_config, config)
  log.debug("[INFO] nvgtags starting")

  gtags_conf = gtags_default_conf
  if ext_config.global then
    gtags_conf.global = ext_config.global
  end

  if ext_config.opts then
    for k, v in pairs(ext_config.opts) do
      gtags_conf.opts[k] = v
    end
  end
end


-- get_open_filelist
local get_open_filelist = function(grep_open_files, cwd)
  if not grep_open_files then
    return nil
  end

  local bufnrs = filter(function(b)
    if 1 ~= vim.fn.buflisted(b) then
      return false
    end
    return true
  end, vim.api.nvim_list_bufs())
  if not next(bufnrs) then
    return
  end

  local filelist = {}
  for _, bufnr in ipairs(bufnrs) do
    local file = vim.api.nvim_buf_get_name(bufnr)
    table.insert(filelist, Path:new(file):make_relative(cwd))
  end
  return filelist
end


-- create entry_maker for telescope finder
local create_entry_maker = function(opts)
  opts = opts or { line_no_width = line_no_width }
  opts.line_no_width = opts.line_no_width or line_no_width

  -- we only need line number and file path
  local display_items = {
    { width = opts.line_no_width },
    { remaining = true },
  }

  local displayer = entry_display.create({
    separator = ' ',
    items = display_items,
  })

  local make_display = function(entry)
    local display_columns = {
      { '[' .. entry.value.line .. ']', 'TelescopeResultsComment' },
      { entry.value.filename,           'TelescopeResultsNormal' },
    }

    return displayer(display_columns)
  end

  return function(entry)
    if entry == '' then
      log.debug('entry is empty')
      return nil
    end

    local value = {}

    value.name, value.line, value.filename, value.func_prev = string.match(entry, gnu_global_result_pattern)
    -- log.debug('entry: ', entry)
    -- log.debug('name: ', value.name)
    -- log.debug('line: ', value.line)
    -- log.debug('filename: ', value.filename)
    -- log.debug('func_prev: ', value.func_prev)
    local ordinal = value.name .. value.line
    value.lnum = tonumber(value.line)

    return {
      value = value,
      ordinal = ordinal,
      filename = value.filename,
      lnum = value.lnum,
      display = make_display,
    }
  end
end


-- use gnu global to find references
local find_reference = function(opts)
  log.debug('find_reference')
  opts = opts or { buf = 'cur' }
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  opts.max_results = 50

  -- find reference
  local reference_arguments = {
    gtags_conf.global,
    gtags_conf.args.reference,
  }

  local args = flatten { reference_arguments }
  local cmd_generator = function(prompt)
    if not prompt or prompt == "" then
      return nil
    end

    log.debug('find_reference prompt: ' .. prompt .. ' args: ' .. string.format("%s", args))
    log.debug('test traceback ' .. debug.traceback())

    return flatten { args, prompt }
  end

  opts.entry_maker = create_entry_maker(opts)
  local live_finder = finders.new_job(cmd_generator, opts.entry_maker, opts.max_results, opts.cwd)

  pickers.new(opts, {
    prompt_title = 'Find Reference',
    finder = live_finder,
    sorter = conf.generic_sorter(opts),
    previewer = conf.qflist_previewer(opts),
  }):find()
end

local find_reference_under_cursor = function(opts)
  -- get word under cursor
  -- copy from telescope.builtin
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  local word
  local visual = vim.fn.mode() == "v"

  if visual == true then
    local saved_reg = vim.fn.getreg "v"
    vim.cmd [[noautocmd sil norm "vy]]
    local sele = vim.fn.getreg "v"
    vim.fn.setreg("v", saved_reg)
    word = vim.F.if_nil(opts.search, sele)
  else
    word = vim.F.if_nil(opts.search, vim.fn.expand "<cword>")
  end
  local search = opts.use_regex and word or escape_chars(word)

  log.debug('find_reference_under_cursor search: ' .. search)

  local args
  if visual == true then
    args = flatten {
      gtags_conf.global,
      gtags_conf.args.reference,
      search,
    }
  else
    args = flatten {
      gtags_conf.global,
      gtags_conf.args.reference,
      opts.word_match,
      search,
    }
  end

  opts.entry_maker = create_entry_maker(opts)
  pickers
      .new(opts, {
        prompt_title = "Find Reference (" .. word:gsub("\n", "\\n") .. ")",
        finder = finders.new_oneshot_job(args, opts),
        previewer = conf.qflist_previewer(opts),
        sorter = conf.generic_sorter(opts),
      })
      :find()
end


-- use gnu global to find completion of words
local find_completion = function(opts)

end


-- use gnu global to find token of files
local find_document = function(opts)

end


-- use gnu global to find definitions
local find_definition = function(opts)
  opts = opts or { buf = 'cur' }
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  opts.max_results = 50

  opts.entry_maker = create_entry_maker(opts)
  opts.bufnr = vim.fn.bufnr()

  -- find definition
  local definition_arguments = {
    gtags_conf.global,
    gtags_conf.args.definition,
  }

  local args = flatten { definition_arguments }
  local cmd_generator = function(prompt)
    if not prompt or prompt == "" then
      return nil
    end

    return flatten { args, prompt }
  end

  local entry_maker = opts.entry_maker or make_entry.gen_from_vimgrep(opts)
  local live_finder = finders.new_job(cmd_generator, entry_maker, opts.max_results, opts.cwd)

  pickers.new(opts, {
    prompt_title = 'Find Definition',
    finder = live_finder,
    sorter = conf.generic_sorter(opts),
    previewer = conf.qflist_previewer(opts),
  }):find()
end


-- use gnu global to find definitions of text under cursor
local find_definition_under_cursor = function(opts)
  -- get word under cursor
  -- copy from telescope.builtin
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  local word
  local visual = vim.fn.mode() == "v"

  if visual == true then
    local saved_reg = vim.fn.getreg "v"
    vim.cmd [[noautocmd sil norm "vy]]
    local sele = vim.fn.getreg "v"
    vim.fn.setreg("v", saved_reg)
    word = vim.F.if_nil(opts.search, sele)
  else
    word = vim.F.if_nil(opts.search, vim.fn.expand "<cword>")
  end
  local search = opts.use_regex and word or escape_chars(word)

  log.debug('find_definition_under_cursor search: ' .. search)

  local args
  if visual == true then
    args = flatten {
      gtags_conf.global,
      gtags_conf.args.definition,
      search,
    }
  else
    args = flatten {
      gtags_conf.global,
      gtags_conf.args.definition,
      opts.word_match,
      search,
    }
  end

  opts.entry_maker = create_entry_maker(opts)
  pickers
      .new(opts, {
        prompt_title = "Find Definition (" .. word:gsub("\n", "\\n") .. ")",
        finder = finders.new_oneshot_job(args, opts),
        previewer = conf.qflist_previewer(opts),
        sorter = conf.generic_sorter(opts),
      })
      :find()
end


return require("telescope").register_extension({
  setup = my_setup,
  exports = {
    find_definition = find_definition,
    find_definition_under_cursor = find_definition_under_cursor,
    find_reference = find_reference,
    find_reference_under_cursor = find_reference_under_cursor,
    find_document = find_document,
    find_completion = find_completion,
  },
})
