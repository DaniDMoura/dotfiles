local metadata = require("spring_initializr.metadata")
local util = require("spring_initializr.util")
local wizard = require("spring_initializr.wizard")

local M = {}

local config = {
  auto_open = "ask",
  download_timeout = 60000,
  background_refresh = false,
}

function M.setup(opts)
  opts = opts or {}
  -- Normalize legacy auto_open values
  if opts.auto_open == true then
    opts.auto_open = "yes"
  elseif opts.auto_open == false then
    opts.auto_open = "no"
  end
  config = vim.tbl_deep_extend("force", config, opts)

  vim.api.nvim_create_user_command("SpringNew", function(cmd)
    local args = vim.trim(cmd.args or "")
    if args == "" then
      M.wizard()
    else
      M.quick(args)
    end
  end, {
    desc = "Create a new Spring Boot project",
    nargs = "?",
    complete = function()
      local prefs = util.load_prefs()
      return { (prefs.groupId or "com.example") .. ":" }
    end,
  })

  vim.api.nvim_create_user_command("SpringRefreshMetadata", function() M.refresh() end,
    { desc = "Refresh Spring metadata cache" })
  vim.api.nvim_create_user_command("SpringClearCache", function() M.clear() end,
    { desc = "Clear Spring metadata cache" })

  if config.background_refresh then
    vim.defer_fn(function()
      metadata.fetch({}, function(err)
        if not err then
          vim.notify("Spring metadata refreshed in background", vim.log.levels.DEBUG)
        end
      end)
    end, 1000)
  end
end

function M.wizard()
  wizard.run_wizard(config)
end

function M.quick(args)
  wizard.run_quick(config, args)
end

function M.refresh()
  vim.notify("Refreshing Spring metadata...", vim.log.levels.INFO)
  metadata.fetch({ force = true }, function(err)
    if err then
      vim.notify("Spring: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("Spring metadata refreshed", vim.log.levels.INFO)
    end
  end)
end

function M.clear()
  metadata.clear_cache()
  util.save_prefs({})
end

return M
