local M = {}

local PREFS_FILE = vim.fn.stdpath("cache") .. "/spring_initializr/prefs.json"

---Run an async coroutine wizard.
---Each async step yields a function(resume) that calls resume when done.
---@param fn function
function M.run(fn)
  local co = coroutine.create(fn)
  local function step(...)
    if coroutine.status(co) == "dead" then return end
    local ok, ret = coroutine.resume(co, ...)
    if not ok then
      vim.notify("Spring wizard error: " .. tostring(ret), vim.log.levels.ERROR)
    elseif type(ret) == "function" then
      local cb_ok, cb_err = pcall(ret, step)
      if not cb_ok then
        vim.notify("Spring wizard callback error: " .. tostring(cb_err), vim.log.levels.ERROR)
      end
    end
  end
  step()
end

---Await an async operation inside a coroutine.
---@param async_fn fun(resume:fun(...))
function M.await(async_fn)
  return coroutine.yield(async_fn)
end

---Load persisted user preferences.
---@return table
function M.load_prefs()
  local fd = io.open(PREFS_FILE, "r")
  if not fd then return {} end
  local content = fd:read("*a")
  fd:close()
  local ok, data = pcall(vim.json.decode, content)
  return ok and type(data) == "table" and data or {}
end

---Save user preferences.
---@param prefs table
function M.save_prefs(prefs)
  local dir = vim.fn.fnamemodify(PREFS_FILE, ":h")
  vim.fn.mkdir(dir, "p")
  local fd = io.open(PREFS_FILE, "w")
  if fd then
    fd:write(vim.json.encode(prefs))
    fd:close()
  end
end

---Add dependency IDs to recent list inside a prefs table.
---Mutates the prefs table in-place. Does NOT save to disk.
---@param prefs table
---@param dep_ids string[]
function M.add_recent_deps(prefs, dep_ids)
  prefs.recent_deps = prefs.recent_deps or {}
  for _, dep_id in ipairs(dep_ids) do
    for i, id in ipairs(prefs.recent_deps) do
      if id == dep_id then
        table.remove(prefs.recent_deps, i)
        break
      end
    end
    table.insert(prefs.recent_deps, 1, dep_id)
  end
  while #prefs.recent_deps > 10 do
    table.remove(prefs.recent_deps)
  end
end

---Build a lookup table from deps to find info by ID.
---@param dependencies {name:string,values:table[]}[]
---@return table<string,table>
function M.build_dep_lookup(dependencies)
  local lookup = {}
  for _, group in ipairs(dependencies) do
    for _, dep in ipairs(group.values) do
      lookup[dep.id] = vim.tbl_extend("force", {}, dep, { group = group.name })
    end
  end
  return lookup
end

---Filter valid project types (full projects only, not build files).
---@param types SpringMetadataValue[]
---@return SpringMetadataValue[]
function M.filter_types(types)
  local valid = { ["maven-project"] = true, ["gradle-project"] = true, ["gradle-project-kotlin"] = true }
  local out = {}
  for _, t in ipairs(types) do
    if valid[t.id] then
      table.insert(out, t)
    end
  end
  return out
end

---Move a default item to the top of a list.
---@param items SpringMetadataValue[]
---@param default_id string|nil
function M.sort_default_first(items, default_id)
  if not default_id then return items end
  local idx = nil
  for i, item in ipairs(items) do
    if item.id == default_id then
      idx = i
      break
    end
  end
  if idx and idx > 1 then
    local copy = vim.deepcopy(items)
    local item = table.remove(copy, idx)
    table.insert(copy, 1, item)
    return copy
  end
  return items
end

-- Version comparison helpers for Spring/Maven version ranges

---Split a version string into base numeric parts and qualifier.
---Examples: "4.2.0.M1" -> base="4.2.0", qual="M1"
---          "3.2.0-SNAPSHOT" -> base="3.2.0", qual="SNAPSHOT"
---@param v string
---@return string base, string|nil qualifier
local function split_version(v)
  for i = #v, 1, -1 do
    local c = v:sub(i, i)
    if c == "." or c == "-" then
      local after = v:sub(i + 1)
      if after:match("^[A-Za-z]") then
        return v:sub(1, i - 1), after
      end
    end
  end
  return v, nil
end

---Compare two version strings. Returns -1, 0, or 1.
---@param v1 string
---@param v2 string
---@return integer
function M.compare_versions(v1, v2)
  local b1, q1 = split_version(v1)
  local b2, q2 = split_version(v2)

  local p1, p2 = {}, {}
  for n in b1:gmatch("(%d+)") do table.insert(p1, tonumber(n)) end
  for n in b2:gmatch("(%d+)") do table.insert(p2, tonumber(n)) end

  for i = 1, math.max(#p1, #p2) do
    local a = p1[i] or 0
    local b = p2[i] or 0
    if a ~= b then return a < b and -1 or 1 end
  end

  local function rank(q)
    if not q then return 100 end
    if q:match("^RELEASE") then return 100 end
    if q:match("^SNAPSHOT") then return 1 end
    if q:match("^M") then return 2 end
    if q:match("^RC") then return 3 end
    return 0
  end

  local r1, r2 = rank(q1), rank(q2)
  if r1 ~= r2 then return r1 < r2 and -1 or 1 end

  local n1 = q1 and tonumber(q1:match("%d+")) or 0
  local n2 = q2 and tonumber(q2:match("%d+")) or 0
  if n1 ~= n2 then return n1 < n2 and -1 or 1 end

  return 0
end

---Check whether a version satisfies a Maven-style range.
---Supports formats: [a,b), [a,b], (a,b), (a,b], [a,), (a,), (,b], (,b).
---Malformed ranges are allowed (return true).
---@param version string
---@param range string|nil
---@return boolean
function M.version_in_range(version, range)
  if not range or range == "" then return true end

  local first = range:sub(1, 1)
  local last = range:sub(-1, -1)
  local inner = range:sub(2, -2)

  if (first ~= "[" and first ~= "(") or (last ~= "]" and last ~= ")") then
    return true
  end

  local lower_raw, upper_raw = inner:match("^([^,]*),(.*)$")
  if not lower_raw then return true end

  local lower = vim.trim(lower_raw)
  local upper = vim.trim(upper_raw)
  local lower_inc = first == "["
  local upper_inc = last == "]"

  local cmp_low = lower ~= "" and M.compare_versions(version, lower) or 1
  local cmp_high = upper ~= "" and M.compare_versions(version, upper) or -1

  local low_ok = lower == ""
    or (lower_inc and cmp_low >= 0)
    or (not lower_inc and cmp_low > 0)

  local high_ok = upper == ""
    or (upper_inc and cmp_high <= 0)
    or (not upper_inc and cmp_high < 0)

  return low_ok and high_ok
end

return M
