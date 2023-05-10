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

local line_no_width = 6

local global_result_grep_pattern = "(%w+)%s+(%d+)%s+(.-)%s+(.+)"

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
      "--xra",
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

local create_definition_entry_maker = function(opts)
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
      { entry.value.filename, 'TelescopeResultsNormal' },
    }

    return displayer(display_columns)
  end

  return function(entry)
    if entry == '' then
      return nil
    end

    local value = {}

    value.name, value.line, value.filename, value.func_prev = string.match(entry, global_result_grep_pattern)
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

local find_reference = function(opts)

end

local find_completion = function(opts)

end


local find_document = function(opts)

end


local find_definition = function(opts)
  opts = opts or { buf = 'cur' }

  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  opts.max_results = 50
  local cmd = {}

  opts.entry_maker = create_definition_entry_maker(opts)
  opts.bufnr = vim.fn.bufnr()

  for _, v in ipairs(gtags_conf.global) do
    table.insert(cmd, v)
  end

  -- find definition
  local definition_arguments = {
    gtags_conf.global,
    gtags_conf.args.definition,
  }

  local args = flatten { definition_arguments }
  local cmd_genrator = function(prompt)
    if not prompt or prompt == "" then
      return nil
    end

    return flatten { args, prompt }
  end

  local entry_maker = opts.entry_maker or make_entry.gen_from_vimgrep(opts)
  local live_finder = finders.new_job(cmd_genrator, entry_maker, opts.max_results, opts.cwd)

  pickers.new(opts, {
    prompt_title = 'nvgtags',
    finder = live_finder,
    sorter = conf.generic_sorter(opts),
    previewer = conf.qflist_previewer(opts),
  }):find()
end

return require("telescope").register_extension({
  setup = my_setup,
  exports = {
    find_definition = find_definition,
    find_reference = find_reference,
    find_document = find_document,
    find_completion = find_completion,
  },
})

