local M = {}

local TITLE = "Dependencies — <Tab>/<Space> toggle  <CR> confirm  <Esc> cancel"

function M.pick(items, _, callback)
  local selected = {}
  local selected_set = {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local function make_finder()
    return finders.new_table({
      results = items,
      entry_maker = function(item)
        local prefix = selected_set[item.id] and "[x] " or "[ ] "
        local display = prefix .. string.format("[%s] %s", item.group or "Unknown", item.name)
        if not item.compatible then
          display = display .. " (incompatible)"
        end
        return {
          value = item,
          display = display,
          ordinal = item.name .. " " .. item.group,
        }
      end,
    })
  end

  pickers.new({}, {
    prompt_title = TITLE,
    finder = make_finder(),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      local toggle = function()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        local dep = entry.value
        if selected_set[dep.id] then
          selected_set[dep.id] = nil
          for i, id in ipairs(selected) do
            if id == dep.id then table.remove(selected, i); break end
          end
        else
          selected_set[dep.id] = true
          table.insert(selected, dep.id)
        end
        action_state.get_current_picker(prompt_bufnr):refresh(make_finder(), { reset_prompt = false })
      end

      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        callback(selected)
      end)

      map("i", "<Tab>", toggle)
      map("n", "<Tab>", toggle)
      map("i", "<Esc>", actions.close)
      map("n", "<Esc>", actions.close)
      return true
    end,
  }):find()
end

return M
