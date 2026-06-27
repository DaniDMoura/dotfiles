local M = {}

function M.detect_picker()
  if pcall(require, "snacks.picker") then return "snacks" end
  if pcall(require, "telescope") then return "telescope" end
  return "vimui"
end

function M.input(prompt, default)
  return function(resume)
    vim.ui.input({ prompt = prompt, default = default or "" }, function(result)
      resume(result)
    end)
  end
end

function M.select(items, prompt, format_item)
  return function(resume)
    vim.ui.select(items, { prompt = prompt, format_item = format_item }, function(choice)
      resume(choice)
    end)
  end
end

local function flatten(deps, recent_ids, lookup, boot_version)
  local out = {}
  local seen = {}
  local util = require("spring_initializr.util")

  for _, id in ipairs(recent_ids or {}) do
    local info = lookup[id]
    if info and not seen[id] then
      seen[id] = true
      local item = vim.tbl_extend("force", {}, info)
      item.recent = true
      item.group = item.group or "Unknown"
      item.compatible = not info.versionRange or util.version_in_range(boot_version, info.versionRange)
      table.insert(out, item)
    end
  end

  for _, g in ipairs(deps) do
    for _, d in ipairs(g.values) do
      if not seen[d.id] then
        seen[d.id] = true
        local item = vim.tbl_extend("force", {}, d)
        item.group = g.name or "Unknown"
        item.compatible = not d.versionRange or util.version_in_range(boot_version, d.versionRange)
        table.insert(out, item)
      end
    end
  end

  return out
end

function M.pick_dependencies(dep_groups, recent_ids, lookup, boot_version)
  return function(resume)
    local items = flatten(dep_groups, recent_ids, lookup, boot_version)
    local picker = M.detect_picker()
    if picker == "snacks" then
      require("spring_initializr.picker.snacks").pick(items, boot_version, resume)
    elseif picker == "telescope" then
      require("spring_initializr.picker.telescope").pick(items, boot_version, resume)
    else
      require("spring_initializr.picker.vimui").pick(items, boot_version, resume)
    end
  end
end

function M.summary(params, destination)
  return function(resume)
    local deps_text = "None"
    if params.dependencies and #params.dependencies > 0 then
      if #params.dependencies <= 5 then
        deps_text = table.concat(params.dependencies, ", ")
      else
        deps_text = #params.dependencies .. " dependencies"
      end
    end

    local lines = {
      "Project:    " .. params.groupId .. ":" .. params.artifactId,
      "Type:       " .. params.type,
      "Language:   " .. params.language,
      "Java:       " .. params.javaVersion,
      "Boot:       " .. params.bootVersion,
      "Deps:       " .. deps_text,
      "Destination: " .. destination,
    }

    vim.notify("\n" .. table.concat(lines, "\n") .. "\n", vim.log.levels.INFO)

    vim.ui.select({ "Confirm", "Cancel" }, {
      prompt = "Create project?",
    }, function(choice)
      resume(choice == "Confirm")
    end)
  end
end

return M
