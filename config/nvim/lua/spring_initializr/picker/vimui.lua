local M = {}

local TITLE = "Dependencies — <Tab>/<Space> toggle  <CR> confirm  <Esc> cancel"

function M.pick(items, _, callback)
  local selected = {}
  local selected_set = {}

  local function loop()
    local choices = vim.deepcopy(items)
    table.insert(choices, 1, { id = "__done__", name = "Done", group = "", compatible = true })

    local display = vim.tbl_map(function(item)
      local prefix = item.id == "__done__" and "" or (selected_set[item.id] and "[x] " or "[ ] ")
      local text = prefix .. string.format("[%s] %s", item.group or "Unknown", item.name)
      if not item.compatible then
        text = text .. " [INCOMPATIBLE]"
      end
      return { item = item, text = text }
    end, choices)

    vim.ui.select(display, {
      prompt = TITLE,
      format_item = function(d) return d.text end,
    }, function(choice)
      if not choice then callback(selected); return end
      local item = choice.item
      if item.id == "__done__" then callback(selected); return end
      if selected_set[item.id] then
        selected_set[item.id] = nil
        for i, id in ipairs(selected) do
          if id == item.id then table.remove(selected, i); break end
        end
      else
        selected_set[item.id] = true
        table.insert(selected, item.id)
      end
      loop()
    end)
  end

  loop()
end

return M
