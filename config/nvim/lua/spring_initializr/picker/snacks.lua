local M = {}

local TITLE_BASE = "Dependencies — <Tab>/<Space> toggle  <CR> confirm  <Esc> cancel"

function M.pick(items, boot_version, callback)
  local selected = {}
  local selected_set = {}

  local picker_items = vim.tbl_map(function(item)
    return {
      text = string.format("[%s] %s", item.group or "Unknown", item.name),
      id = item.id,
      file = "",
      recent = item.recent,
      compatible = item.compatible,
      name = item.name,
      group = item.group,
      description = item.description,
      versionRange = item.versionRange,
      _links = item._links,
    }
  end, items)

  local Snacks = require("snacks")

  Snacks.picker.pick({
    source = "spring_deps",
    title = TITLE_BASE,
    items = picker_items,
    format = function(item, _)
      local prefix = selected_set[item.id] and "[x] " or "[ ] "
      local hl
      if not item.compatible then
        hl = "Error"
      elseif item.recent then
        hl = "Special"
      else
        hl = "Normal"
      end
      return { { prefix .. item.text, hl } }
    end,
    preview = function(ctx)
      local item = ctx.item
      if not item then return end

      local function add(lines, label, value)
        if value and value ~= "" then
          table.insert(lines, "  " .. label .. ": " .. tostring(value))
        end
      end

      local lines = {}
      if not item.compatible then
        table.insert(lines, "  ⚠ INCOMPATIBLE with Boot " .. boot_version)
        if item.versionRange and item.versionRange ~= "" then
          table.insert(lines, "  Requires: " .. item.versionRange)
        end
        table.insert(lines, "")
      end
      table.insert(lines, "  " .. item.name)
      table.insert(lines, "")
      add(lines, "ID", item.id)
      add(lines, "Group", item.group)
      if item.description and item.description ~= "" then
        table.insert(lines, "")
        table.insert(lines, "  Description:")
        local desc = item.description
        while #desc > 0 do
          local chunk = desc:sub(1, 56)
          local last_space = chunk:find(" +[^ ]*$")
          if last_space and #desc > 56 then
            chunk = desc:sub(1, last_space - 1)
            desc = desc:sub(last_space + 1)
          else
            desc = ""
          end
          table.insert(lines, "    " .. chunk)
        end
      end
      add(lines, "Version Range", item.versionRange)
      if item._links then
        table.insert(lines, "")
        table.insert(lines, "  Links:")
        for link_type, link_data in pairs(item._links) do
          if type(link_data) == "table" and link_data.href then
            table.insert(lines, "    " .. link_type .. ": " .. link_data.href)
          elseif type(link_data) == "table" then
            for _, ld in ipairs(link_data) do
              if type(ld) == "table" and ld.href then
                table.insert(lines, "    " .. link_type .. ": " .. ld.href)
              end
            end
          end
        end
      end
      vim.api.nvim_set_option_value("modifiable", true, { buf = ctx.buf })
      vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
      vim.api.nvim_set_option_value("modifiable", false, { buf = ctx.buf })
    end,
    confirm = function(picker, item)
      if not item then return end
      if selected_set[item.id] then
        selected_set[item.id] = nil
        for i, id in ipairs(selected) do
          if id == item.id then table.remove(selected, i); break end
        end
      else
        selected_set[item.id] = true
        table.insert(selected, item.id)
      end
      local current_id = item.id
      picker.input:set("")
      picker:find()
      if picker.list and picker.list.items then
        for i, it in ipairs(picker.list.items) do
          if it.id == current_id then
            picker.list:move(i, true)
            break
          end
        end
      end
    end,
    actions = {
      confirm_done = function(picker)
        picker:close()
        callback(selected)
      end,
    },
    win = {
      input = {
        keys = {
          ["<Tab>"] = { "confirm", mode = { "i", "n" } },
          ["<Space>"] = { "confirm", mode = { "i", "n" } },
          ["<CR>"] = { "confirm_done", mode = { "i", "n" } },
          ["<Esc>"] = { "close", mode = { "i", "n" } },
        },
      },
      list = {
        keys = {
          ["<Tab>"] = { "confirm", mode = { "n" } },
          ["<Space>"] = { "confirm", mode = { "n" } },
          ["<CR>"] = { "confirm_done", mode = { "n" } },
          ["<Esc>"] = { "close", mode = { "n" } },
        },
      },
    },
  })
end

return M
