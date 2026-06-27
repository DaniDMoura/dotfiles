local metadata = require("spring_initializr.metadata")
local ui = require("spring_initializr.ui")
local util = require("spring_initializr.util")

local M = {}

function M.build_url(params)
  local query = {
    type = params.type,
    language = params.language,
    bootVersion = params.bootVersion,
    groupId = params.groupId,
    artifactId = params.artifactId,
    name = params.artifactId,
    packageName = params.groupId .. "." .. params.artifactId,
    javaVersion = params.javaVersion,
    packaging = "jar",
    description = "",
  }
  if params.dependencies and #params.dependencies > 0 then
    query.dependencies = table.concat(params.dependencies, ",")
  end
  local parts = {}
  for k, v in pairs(query) do
    table.insert(parts, k .. "=" .. vim.uri_encode(v))
  end
  return "https://start.spring.io/starter.zip?" .. table.concat(parts, "&")
end

function M.find_extractor()
  local extractors = {
    { cmd = "unzip", args = function(zip, dir) return { "unzip", "-o", zip, "-d", dir } end },
    { cmd = "bsdtar", args = function(zip, dir) return { "bsdtar", "-xf", zip, "-C", dir } end },
    { cmd = "7z", args = function(zip, dir) return { "7z", "x", "-o" .. dir, "-y", zip } end },
    { cmd = "unar", args = function(zip, dir) return { "unar", "-o", dir, zip } end },
  }
  for _, e in ipairs(extractors) do
    if vim.fn.executable(e.cmd) == 1 then
      return e
    end
  end
  return nil
end

function M.download_and_extract(config, url, dest)
  return function(resume)
    local cache_dir = vim.fn.stdpath("cache") .. "/spring_initializr"
    local zip = cache_dir .. "/starter.zip"
    local tmp_dir = cache_dir .. "/tmp_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
    vim.fn.mkdir(cache_dir, "p")

    local extractor = M.find_extractor()
    if not extractor then
      resume("No archive extractor found. Install unzip, bsdtar, 7z, or unar.")
      return
    end

    local max_retries = 2
    local attempt = 1
    local timeout = math.floor(config.download_timeout / 1000)

    local function try_download()
      vim.notify("Downloading project... (attempt " .. attempt .. "/" .. max_retries .. ")", vim.log.levels.INFO)
      vim.system(
        { "curl", "-sSL", "-f", "-o", zip, "-m", tostring(timeout), url },
        { timeout = config.download_timeout },
        function(dl)
          vim.schedule(function()
            if dl.code ~= 0 then
              if attempt < max_retries then
                attempt = attempt + 1
                vim.notify("Download failed, retrying in 2s...", vim.log.levels.WARN)
                vim.defer_fn(try_download, 2000)
                return
              end
              local msg = "Download failed"
              if dl.stderr and dl.stderr ~= "" then
                msg = msg .. ": " .. dl.stderr:gsub("\r", ""):gsub("\n", " ")
              end
              pcall(vim.fn.delete, tmp_dir, "rf")
              pcall(os.remove, zip)
              resume(msg)
              return
            end

            vim.notify("Extracting project...", vim.log.levels.INFO)
            vim.fn.mkdir(tmp_dir, "p")

            local extract_cmd = extractor.args(zip, tmp_dir)
            vim.system(extract_cmd, {}, function(ex)
              vim.schedule(function()
                pcall(os.remove, zip)
                if ex.code ~= 0 then
                  pcall(vim.fn.delete, tmp_dir, "rf")
                  resume("Extraction failed with " .. extractor.cmd)
                  return
                end

                local ok, move_err = pcall(function()
                  local entries = vim.fn.glob(tmp_dir .. "/*", false, true)
                  if #entries == 1 and vim.fn.isdirectory(entries[1]) == 1 then
                    vim.fn.rename(entries[1], dest)
                  else
                    vim.fn.rename(tmp_dir, dest)
                  end
                end)

                pcall(vim.fn.delete, tmp_dir, "rf")

                if not ok then
                  resume("Failed to move project: " .. tostring(move_err))
                else
                  resume(nil)
                end
              end)
            end)
          end)
        end
      )
    end

    try_download()
  end
end

function M.find_build_file(path, project_type)
  local candidates = {}
  if project_type == "maven-project" then
    candidates = { "pom.xml" }
  elseif project_type == "gradle-project-kotlin" then
    candidates = { "build.gradle.kts", "build.gradle" }
  else
    candidates = { "build.gradle", "build.gradle.kts" }
  end
  for _, f in ipairs(candidates) do
    local full = path .. "/" .. f
    if vim.fn.filereadable(full) == 1 then
      return full
    end
  end
  return path
end

function M.open_project(config, path, project_type)
  local target = M.find_build_file(path, project_type)

  local mode = config.auto_open
  if mode == "no" then
    return
  elseif mode == "yes" then
    vim.cmd("cd " .. vim.fn.fnameescape(path))
    vim.cmd("edit " .. vim.fn.fnameescape(target))
    return
  elseif mode == "tab" then
    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(path))
    vim.cmd("edit " .. vim.fn.fnameescape(target))
    return
  end

  vim.ui.select({
    "Open here",
    "Open in new tab",
    "Do nothing",
  }, { prompt = "Open project?" }, function(choice)
    if choice == "Open here" then
      vim.cmd("cd " .. vim.fn.fnameescape(path))
      vim.cmd("edit " .. vim.fn.fnameescape(target))
    elseif choice == "Open in new tab" then
      vim.cmd("tabnew")
      vim.cmd("tcd " .. vim.fn.fnameescape(path))
      vim.cmd("edit " .. vim.fn.fnameescape(target))
    end
  end)
end

local function fetch_general_metadata(resume)
  metadata.fetch({}, function(err, meta_general)
    if err then
      resume(err)
      return
    end
    if not meta_general or #meta_general.types == 0 then
      resume("No metadata available from Spring Initializr")
      return
    end
    local defaults = meta_general.defaults or {}
    local prefs = util.load_prefs()
    resume(nil, meta_general, defaults, prefs)
  end)
end

local function run_wizard_steps(config, meta_general, defaults, prefs, params, artifact_id, is_quick)
  local types = util.filter_types(meta_general.types)
  types = util.sort_default_first(types, prefs.type or defaults.type)
  local languages = util.sort_default_first(meta_general.languages, prefs.language or defaults.language)
  local javaVersions = util.sort_default_first(
    meta_general.javaVersions,
    prefs.javaVersion or defaults.javaVersion
  )
  local boot_versions = metadata.filter_stable_versions(meta_general.bootVersions)
  boot_versions = util.sort_default_first(boot_versions, prefs.bootVersion or defaults.bootVersion)
  local dependencies = meta_general.dependencies
  local lookup = util.build_dep_lookup(dependencies)

  -- 1. Project Type
  local type_choice = util.await(ui.select(types, "Project type", function(i) return i.name end))
  if not type_choice then return end
  params.type = type_choice.id
  prefs.type = type_choice.id

  -- 2. Language
  local lang_choice = util.await(ui.select(languages, "Language", function(i) return i.name end))
  if not lang_choice then return end
  params.language = lang_choice.id
  prefs.language = lang_choice.id

  -- 3. Java Version
  local java_choice = util.await(ui.select(javaVersions, "Java version", function(i) return i.name end))
  if not java_choice then return end
  params.javaVersion = java_choice.id
  prefs.javaVersion = java_choice.id

  -- 4. Boot Version
  local boot_choice = util.await(ui.select(boot_versions, "Spring Boot version", function(i) return i.name end))
  if not boot_choice then return end
  params.bootVersion = boot_choice.id:gsub("%.RELEASE$", "")
  prefs.bootVersion = boot_choice.id

  -- 5. Group + Artifact (full wizard only)
  if not is_quick then
    local default_coords = (prefs.groupId or defaults.groupId or "com.example") .. ":" .. (defaults.artifactId or "demo")
    local coords = util.await(ui.input("Coordinates (group:artifact): ", default_coords))
    if not coords then return end

    local gid, aid = coords:match("^(.-):(.+)$")
    if not gid or gid == "" then
      gid = prefs.groupId or defaults.groupId or "com.example"
    end
    if not aid or aid == "" then
      aid = defaults.artifactId or "demo"
    end
    params.groupId = gid
    params.artifactId = aid
    prefs.groupId = gid
    artifact_id = aid
  end

  -- 6. Dependencies
  local recent_ids = prefs.recent_deps or {}
  local deps = util.await(ui.pick_dependencies(dependencies, recent_ids, lookup, params.bootVersion))
  if deps == nil then return end
  params.dependencies = deps

  util.add_recent_deps(prefs, deps)
  util.save_prefs(prefs)

  -- 7. Destination
  local dest = util.await(ui.select(
    { "Current directory", "Custom directory" },
    "Destination",
    function(i) return i end
  ))
  if not dest then return end

  local project_path
  if dest == "Current directory" then
    project_path = vim.fn.getcwd()
  else
    project_path = util.await(ui.input("Path: ", vim.fn.getcwd()))
    if not project_path or project_path == "" then return end
  end

  -- 8. Summary
  local final = project_path .. "/" .. artifact_id
  local confirmed = util.await(ui.summary(params, final))
  if not confirmed then
    vim.notify("Project creation cancelled", vim.log.levels.WARN)
    return
  end

  -- 9. Download and extract
  local url = M.build_url(params)
  local dl_err = util.await(M.download_and_extract(config, url, final))
  if dl_err then
    vim.notify("Spring: " .. dl_err, vim.log.levels.ERROR)
    return
  end
  vim.notify("Project created at " .. final, vim.log.levels.INFO)
  M.open_project(config, final, params.type)
end

function M.run_wizard(config)
  util.run(function()
    local err, meta_general, defaults, prefs = util.await(fetch_general_metadata)
    if err then
      vim.notify("Spring: " .. err, vim.log.levels.ERROR)
      return
    end
    local params = {}
    run_wizard_steps(config, meta_general, defaults, prefs, params, nil, false)
  end)
end

function M.run_quick(config, args)
  local group_id, artifact_id = args:match("^(.-):(.+)$")
  if not artifact_id then
    vim.notify("Spring: invalid format. Use :SpringNew group:artifact", vim.log.levels.ERROR)
    return
  end
  if not group_id or group_id == "" then
    group_id = "com.example"
  end

  local prefs = util.load_prefs()
  local params = {
    groupId = group_id,
    artifactId = artifact_id,
    dependencies = {},
  }

  util.run(function()
    local err, meta_general, defaults, _ = util.await(fetch_general_metadata)
    if err then
      vim.notify("Spring: " .. err, vim.log.levels.ERROR)
      return
    end
    run_wizard_steps(config, meta_general, defaults, prefs, params, artifact_id, true)
  end)
end

return M
