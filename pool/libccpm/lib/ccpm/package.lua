-- CCPM library
-- Copyright (C) 2025 Deleranax
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

local package = {}

local deptree = require("deptree")
local tact = require("tact")
local turfu = require("turfu")
local sha256 = require("crypt.sha256")
local tamed = require("tamed")
local ctable = require("commons.table")
local storage = require("ccpm.storage")
local drivers = require("ccpm.drivers")

--- Retrieve all packages that matches a certain name.
---
--- The package can be repository constrained (i.e. restricting the research in specific repositories) by adding a "@"
--- followed by a repository identifier with wildcard at the end of the package name.
---
--- For instance, if you want to match all CCPM drivers within all of Deleranax's repositories, you can use the following
--- pattern: "ccpm-driver-*@Deleranax/*"
---
--- @param pattern string Package name with wildcards.
--- @return table Table of arrays of package manifests for each repository where packages where found.
function package.find(pattern)
    local result = {}

    local wildcard = tamed.Wildcard(pattern)

    for repo_name, repo in pairs(storage.store) do
        local result_repo = {}
        local found = false

        for pack_name, pack in pairs(repo.packages) do
            if wildcard.matches(pack_name.."@"..repo_name) then
                local manifest = {}

                ctable.copy(manifest, pack)

                table.insert(result_repo, manifest)
                found = true
            end
        end

        if found then
            result[repo_name] = result_repo
        end
    end

    return result
end

--- Build the package index. The package index needs to be rebuilt every time a repository index changes.
---
--- @return table A turfu.Future object, eventually returning a deduplicated list of all packages.
function package.buildIndex()
    storage.unprotectedLoad()

    local packs = {}
    storage.index = {}

    local function collect(_, repo)
        ctable.insertUniqueAll(packs, ctable.keys(repo.packages))
    end

    -- Comparison function: Highest Priority -> Lowest Priority (fallback: Alphabetic order)
    local function comp(a, b)
        if a.priority == b.priority then
            return a.identifier < b.identifier
        else
            return a.priority > b.priority
        end
    end

    local function insert(_, pack)
        local first = true

        local result = package.find(pack.."@*")

        for repo_name, repo_packs in pairs(result) do
            local _pack = repo_packs[1]

            if _pack ~= nil then
                _pack["repository"] = repo_name
                _pack["identifier"] = pack

                if first then
                    storage.index[pack] = repo_packs[1]
                    first = false
                else
                    storage.index[pack.."@"..repo_name] = repo_packs[1]
                end
            end
        end
    end

    local function finish(_)
        storage.unprotectedFlush()
        return packs
    end

    return turfu.merge(
        finish,
        turfu.sort(storage.store, comp),
        turfu.foreach(collect, pairs(storage.store)),
        turfu.foreach(insert, ipairs(packs))
    )
end


--- Get the first (in the repository priority order) package that matches a certain name.
---
--- The package can be repository constrained (i.e. restricting the research in specific repositories) by adding a "@"
--- followed by a repository identifier with wildcard at the end of the package name.
--- For instance, if you want to match all CCPM drivers within all of Deleranax's repositories, you can use the following
--- pattern: "ccpm-driver-*@Deleranax/*"
---
--- @param pattern string Package name with wildcards.
--- @return table Package manifest (or nil).
function package.select(pattern)
    storage.unprotectedLoad()

    local wildcard = tamed.Wildcard(pattern, "@")

    for identifier, manifest in pairs(storage.index) do
        if wildcard.matches(identifier) then
            return manifest
        end
    end

    return nil
end

--- Download package files. The dependencies are not checked.
---
--- @param pack table Package manifest.
function package.downloadFiles(pack)
    storage.unprotectedLoad()

    local repo_name = pack.repository

    local repo = storage.store[repo_name]

    if repo == nil then
        error("repository not found: "..repo_name)
    end

    local driver = drivers[repo.driver]

    if driver == nil then
        error("driver not found: "..repo.driver)
    end

    for path, digest in pairs(pack.files) do
        local content, message = driver.fetchPackageFile(repo_name, pack.identifier, path)

        if content == nil then
            error(pack.identifier.."/"..path..": "..message)
        end

        local localDigest = tostring(sha256.digest(content))

        if digest ~= localDigest then
            error(pack.identifier.."/"..path..": mismatched digests ("..localDigest..")")
        end

        local file
        file, message = fs.open("/test/"..path, "w")

        if file == nil then
            error(pack.identifier.."/"..path..": "..message)
        end

        file.write(content)
        file.close()
    end

    storage.pool[pack.name.."@"..pack.repository] = {}
    ctable.copy(storage.pool[pack.name.."@"..pack.repository], pack)

    return true
end

local function deleteWithParent(path)
    fs.delete(path)

    local dir = fs.getDir(path)

    if next(fs.find(dir.."/*")) == nil then
        deleteWithParent(dir)
    end
end

--- Delete package files. The dependencies are not checked.
---
--- @param pack table Package manifest.
function package.deleteFiles(pack)
    storage.unprotectedLoad()

    if pack == nil then
        return
    end

    local repo_name = pack.repository

    local repo = storage.store[repo_name]

    if repo == nil then
        error("repository not found: "..repo_name)
    end

    local driver = drivers[repo.driver]

    if driver == nil then
        error("driver not found: "..repo.driver)
    end

    local files = pack.files

    for path, _ in ipairs(files) do
        deleteWithParent(path)
    end

    storage.pool[pack.name.."@"..pack.repository] = nil

    return true
end

--- Add packages and their dependencies.
---
--- IMPORTANT: Do not modify the open and close handlers of the transaction. They are used, respectively, to load and
--- flush the store. Only do so if you know what you do, or if you want to do a "dry run" (by replacing the close
--- handler responsible for flushing the store by a load).
---
--- @vararg string List of package names.
--- @return table, string A turfu.Future object (or nil) eventually returning a table containing a tact.Transaction and an array of error messages.
function package.add(...)
    storage.unprotectedLoad()

    local addedPacks = { ...}
    local pool = ctable.keys(storage.pool)
    local errors = {}
    local actions = {}
    local result

    ctable.insertAll(pool, addedPacks)

    local function getDeps(name)
        local pack = storage.index[name]

        if pack == nil then
            pack = package.select(name)

            if pack == nil then
                table.insert(errors, "package not found: "..name)
                return {}
            end
        end

        return pack.dependencies
    end

    local future = deptree.expand(pool, getDeps)

    local function poll()
        if future.isPending() then
            _, result = future.poll()
        else
            local name = table.remove(result)

            if name ~= nil then
                local pack = package.select(name)

                if pack == nil then
                    table.insert(errors, "package not found: "..name)
                    return false
                end

                table.insert(actions, tact.Action(pack, package.downloadFiles, package.deleteFiles))
            else
                name = table.remove(addedPacks)

                if name ~= nil then
                    local pack = package.select(name)

                    if pack == nil then
                        table.insert(errors, "package not found: "..name)
                        return false
                    end

                    pack.user_installed = true

                    table.insert(actions, tact.Action(pack, package.downloadFiles, package.deleteFiles))
                else
                    return true, {
                        transaction = tact.Transaction(actions, { open = storage.unprotectedLoad, close = storage.unprotectedFlush }),
                        errors = errors
                    }
                end
            end
        end

        return false
    end

    return turfu.Future(poll)
end

--- Remove packages and their unused dependencies.
---
--- IMPORTANT: Do not modify the open and close handlers of the transaction. They are used, respectively, to load and
--- flush the store. Only do so if you know what you do, or if you want to do a "dry run" (by replacing the close
--- handler responsible for flushing the store by a load).
---
--- @vararg string List of package names.
--- @return table, string A turfu.Future object (or nil) eventually returning a table containing a tact.Transaction and an array of error messages.
function package.remove(...)
    storage.unprotectedLoad()

    local pool = ctable.keys(storage.pool)
    local errors = {}
    local actions = {}
    local result

    local wildcards = {}

    for i, pack in ipairs({...}) do
        if not string.find(pack, "@") then
            pack = pack.."@*"
        end
        wildcards[i] = tamed.Wildcard(pack, "@")
    end

    local function predicate(name)
        local rtn = true

        for _, wildcard in ipairs(wildcards) do
            rtn = rtn and not wildcard.matches(name)
        end

        return rtn
    end

    ctable.removeAll(pool, predicate)

    local function getDeps(name)
        local pack = storage.index[name]

        if pack == nil then
            table.insert(errors, "package not found: "..name)
            return {}
        end

        return pack.dependencies
    end

    local function isPinned(name)
        if storage.index[name] == nil then
            return false
        end
        return storage.index[name].user_installed
    end

    local future = deptree.shrink(pool, getDeps, isPinned)

    local function poll()
        if future.isPending() then
            _, result = future.poll()
        else
            local name = table.remove(result)

            if name ~= nil then
                local pack = storage.index[name]

                if pack == nil then
                    table.insert(errors, "package not found: "..name)
                    return false
                end
                -- TODO: Change the rollback/delete to something else (to avoid redownloading)
                table.insert(actions, tact.Action(pack, package.deleteFiles, package.downloadFiles))
            else
                return true, {
                    transaction = tact.Transaction(actions, { open = storage.unprotectedLoad, close = storage.unprotectedFlush }),
                    errors = errors
                }
            end
        end

        return false
    end

    return turfu.Future(poll)
end

return package