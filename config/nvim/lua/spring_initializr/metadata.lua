local M = {}

---@class SpringMetadataValue
---@field id string
---@field name string

---@class SpringMetadata
---@field types SpringMetadataValue[]
---@field languages SpringMetadataValue[]
---@field javaVersions SpringMetadataValue[]
---@field bootVersions SpringMetadataValue[]
---@field dependencies {name:string, values:{id:string,name:string}[]}[]

local CACHE_DIR = vim.fn.stdpath("cache") .. "/spring_initializr"
local CACHE_FILE = CACHE_DIR .. "/metadata.json"
local CACHE_TTL = 86400
local CACHE_SCHEMA = 1

local function ensure_dir()
  if vim.loop.fs_stat(CACHE_DIR) == nil then
    vim.fn.mkdir(CACHE_DIR, "p")
  end
end

local function read_cache(accept_stale)
  local fd = io.open(CACHE_FILE, "r")
  if not fd then return nil end
  local content = fd:read("*a")
  fd:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" then
    pcall(os.remove, CACHE_FILE)
    return nil
  end
  if not data._cached_at or data._schema_version ~= CACHE_SCHEMA then
    pcall(os.remove, CACHE_FILE)
    return nil
  end
  local age = os.time() - data._cached_at
  if age > CACHE_TTL and not accept_stale then
    return nil
  end
  return data.raw
end

local function write_cache(raw)
  ensure_dir()
  local tmp = CACHE_FILE .. ".tmp"
  local fd = io.open(tmp, "w")
  if not fd then return end
  local ok, encoded = pcall(vim.json.encode, { raw = raw, _cached_at = os.time(), _schema_version = CACHE_SCHEMA })
  if ok then
    fd:write(encoded)
    fd:close()
    vim.fn.rename(tmp, CACHE_FILE)
  else
    fd:close()
    pcall(os.remove, tmp)
  end
end

local function extract_values(field)
  local vals = field and field.values
  if type(vals) ~= "table" then return {} end
  local out = {}
  for _, v in ipairs(vals) do
    if type(v) == "table" and v.id then
      table.insert(out, { id = v.id, name = v.name or v.id })
    end
  end
  return out
end

local function extract_deps(field)
  local vals = field and field.values
  if type(vals) ~= "table" then return {} end
  local groups = {}
  for _, g in ipairs(vals) do
    if type(g) == "table" then
      local deps = {}
      for _, d in ipairs(g.values or {}) do
        if type(d) == "table" and d.id then
          table.insert(deps, {
            id = d.id,
            name = d.name or d.id,
            description = d.description,
            versionRange = d.versionRange,
            _links = d._links,
          })
        end
      end
      if #deps > 0 then
        table.insert(groups, { name = g.name or "Other", values = deps })
      end
    end
  end
  return groups
end

local function parse(raw)
  return {
    types = extract_values(raw.type),
    languages = extract_values(raw.language),
    javaVersions = extract_values(raw.javaVersion),
    bootVersions = extract_values(raw.bootVersion),
    dependencies = extract_deps(raw.dependencies),
    defaults = {
      groupId = raw.groupId and raw.groupId.default or "com.example",
      artifactId = raw.artifactId and raw.artifactId.default or "demo",
      type = raw.type and raw.type.default,
      language = raw.language and raw.language.default,
      bootVersion = raw.bootVersion and raw.bootVersion.default,
      javaVersion = raw.javaVersion and raw.javaVersion.default,
      packaging = raw.packaging and raw.packaging.default,
    },
  }
end

---Filter out SNAPSHOT versions (keep Milestones and RCs for visibility).
---@param versions SpringMetadataValue[]
---@return SpringMetadataValue[]
function M.filter_stable_versions(versions)
  local out = {}
  for _, v in ipairs(versions) do
    if not v.id:match("SNAPSHOT") then
      table.insert(out, v)
    end
  end
  return out
end

---Get the latest non-SNAPSHOT boot version.
---Also normalizes by stripping `.RELEASE` suffix which breaks Gradle.
---@param versions SpringMetadataValue[]
---@return string
function M.resolve_boot_version(versions)
  local stable = M.filter_stable_versions(versions)
  for _, v in ipairs(stable) do
    local id = v.id
    if not id:match("M%d+") and not id:match("RC%d+") then
      return id:gsub("%.RELEASE$", "")
    end
  end
  return stable[1] and stable[1].id:gsub("%.RELEASE$", "") or ""
end

---Fetch metadata from Spring Initializr.
---@param opts? {force?:boolean, bootVersion?:string}
---@param callback fun(err:string|nil, meta:SpringMetadata|nil)
function M.fetch(opts, callback)
  opts = opts or {}

  local url = "https://start.spring.io"
  if opts.bootVersion then
    url = url .. "?bootVersion=" .. vim.uri_encode(opts.bootVersion)
  end

  if not opts.force and not opts.bootVersion then
    local cached = read_cache(false)
    if cached then
      vim.schedule(function()
        callback(nil, parse(cached))
      end)
      return
    end
  end

  vim.notify("Fetching Spring metadata...", vim.log.levels.INFO)

  vim.system(
    { "curl", "-sL", "-f", "-m", "30", "-H", "Accept: application/hal+json", url },
    { timeout = 30000 },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          local stale = read_cache(true)
          if stale then
            vim.notify("Using cached metadata (offline mode)", vim.log.levels.WARN)
            callback(nil, parse(stale))
            return
          end
          callback("Failed to fetch metadata: " .. (result.stderr or ""), nil)
          return
        end
        local ok, decoded = pcall(vim.json.decode, result.stdout)
        if not ok or type(decoded) ~= "table" then
          local stale = read_cache(true)
          if stale then
            vim.notify("Using cached metadata (invalid response)", vim.log.levels.WARN)
            callback(nil, parse(stale))
            return
          end
          callback("Invalid metadata JSON", nil)
          return
        end
        if not opts.bootVersion then
          write_cache(decoded)
        end
        callback(nil, parse(decoded))
      end)
    end
  )
end

function M.clear_cache()
  pcall(os.remove, CACHE_FILE)
  vim.notify("Spring metadata cache cleared", vim.log.levels.INFO)
end

return M
