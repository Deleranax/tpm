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
local SHA2_256 = require("lockbox.digest.sha2_256")
local tamed = require("tamed")
local ctable = require("commons.table")
local storage = require("ccpm.storage")
local drivers = require("ccpm.drivers")

--- Retrieve all packages that matches a certain name. The same package can appear in multiple repositories.
---
--- The package can be repository constrained (i.e. restricting the research in specific repositories) by adding a "@"
--- followed by a repository identifier with wildcard at the end of the package name.
---
--- For instance, if you want to match all CCPM drivers within all of Deleranax's repositories, you can use the following
--- pattern: "ccpm-driver-*@Deleranax/*"
---
--- @param pattern string Package name with wildcards.
--- @return table Table of arrays of package manifests for each repository where packages where found.
function package.findInRepositories(pattern)
    local result = {}

    local wildcard = tamed.Wildcard(pattern)

    for repo_name, repo in pairs(storage.store) do
        local result_repo = {}
        local found = false

        for pack_name, pack in pairs(repo.packages) do
            if wildcard.matches(pack_name .."@".. repo_name) then
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
            return a.name < b.name
        else
            return a.priority > b.priority
        end
    end

    local function insert(_, pack)
        local result = package.findInRepositories(pack .."@*")

        for repo_name, repo_packs in pairs(result) do
            local _pack = repo_packs[1] -- Should always be only one package per repository

            if _pack ~= nil then
                _pack["repository"] = repo_name

                storage.index[pack .."@".. repo_name] = repo_packs[1]
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


--- Retrieve all packages that matches a certain name. Each package only appears once (the first candidate in the
--- repository priority order is picked).
---
--- The package can be repository constrained (i.e. restricting the research in specific repositories) by adding a "@"
--- followed by a repository identifier with wildcard at the end of the package name.
---
--- For instance, if you want to match all CCPM drivers within all of Deleranax's repositories, you can use the following
--- pattern: "ccpm-driver-*@Deleranax/*"
---
--- @param pattern string Package name with wildcards (identifier).
--- @param installedOnly boolean True to search in the installed packages (false otherwise).
--- @return table Package identifier list.
function package.find(pattern, installedOnly)
    storage.unprotectedLoad()

    local packs = {}
    local rtn = {}
    local pool = storage.index

    if installedOnly then
        pool = storage.pool
    end

    if not string.find(pattern, "@") then
        pattern = pattern .."@*"
    end

    local wildcard = tamed.Wildcard(pattern, "@")

    for identifier, manifest in pairs(pool) do
        if not ctable.find(packs, manifest.name) then
            if wildcard.matches(identifier) then
                table.insert(packs, manifest.name)
                table.insert(rtn, identifier)
            end
        end
    end

    return rtn
end

--- Download package files. The dependencies are not checked.
---
--- @param pack table Package manifest.
function package.downloadFiles(pack)
    storage.unprotectedLoad()

    local repo_name = pack.repository

    local repo = storage.store[repo_name]

    if repo == nil then
        error("repository not found: ".. repo_name)
    end

    local driver = drivers[repo.driver]

    if driver == nil then
        error("driver not found: ".. repo.driver)
    end

    for path, digest in pairs(pack.files) do
        local content, message = driver.fetchPackageFile(repo_name, pack.name, path)

        if content == nil then
            error(pack.name .."/".. path ..": ".. message)
        end

        local localDigest = tostring(sha256.digest(content))

        if digest ~= localDigest then
            error(pack.name .."/".. path ..": mismatched digests (".. localDigest ..")")
        end

        local file
        file, message = fs.open(path, "w")

        if file == nil then
            error(pack.name .."/".. path ..": ".. message)
        end

        file.write(content)
        file.close()
    end

    storage.pool[pack.name .."@".. pack.repository] = {}
    ctable.copy(storage.pool[pack.name .."@".. pack.repository], pack)

    return true
end

local function deleteWithParent(path)
    fs.delete(path)

    local dir = fs.getDir(path)

    if next(fs.find(dir .."/*")) == nil then
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

    for path, _ in pairs(pack.files) do
        deleteWithParent(path)
    end

    storage.pool[pack.name .."@".. pack.repository] = nil

    return true
end

local function moveWithParent(path)
    if fs.isDir(path) then
        fs.delete(path)
    else
        fs.delete(".trash/".. path)
        fs.move(path, ".trash/".. path)
    end

    local dir = fs.getDir(path)

    if next(fs.find(dir .."/*")) == nil then
        moveWithParent(dir)
    end
end

--- Move package files to trash. The dependencies are not checked.
---
--- @param pack table Package manifest.
function package.moveFiles(pack)
    storage.unprotectedLoad()

    if pack == nil then
        return
    end

    for path, _ in pairs(pack.files) do
        moveWithParent(path)
    end

    storage.pool[pack.name .."@".. pack.repository] = nil

    return true
end

--- Retore package files from trash. The dependencies are not checked.
---
--- @param pack table Package manifest.
function package.restoreFiles(pack)
    storage.unprotectedLoad()

    for path, digest in pairs(pack.files) do
        local file, message = fs.open(path, "r")

        if file == nil then
            error(pack.identifier .."/".. path ..": ".. message)
        end

        local content = file.readAll()
        file.close()

        local localDigest = tostring(sha256.digest(content))

        if digest ~= localDigest then
            error(pack.identifier .."/".. path ..": mismatched digests (".. localDigest ..")")
        end

        fs.move(".trash/".. path, path)
    end

    storage.pool[pack.name .."@".. pack.repository] = {}
    ctable.copy(storage.pool[pack.name .."@".. pack.repository], pack)

    return true
end

--- Add packages and their dependencies.
---
--- IMPORTANT: Do not modify the open and close handlers of the transaction. They are used, respectively, to load and
--- flush the store. Only do so if you know what you do, or if you want to do a "dry run" (by replacing the close
--- handler responsible for flushing the store by a load).
---
--- @vararg string List of package names.
--- @return table, string A turfu.Future object eventually returning a list containing a tact.Transaction (or nil) and array of error messages.
function package.add(...)
    storage.unprotectedLoad()

    local addedPacks = {}
    local pool = ctable.keys(storage.pool)
    local errors = {}
    local actions = {}
    local result

    local function findAll(_, pack)
        local results = package.find(pack)

        ctable.insertUniqueAll(addedPacks, results)
    end

    local function insertAll(_, pack)
        if ctable.find(pool, pack) then
            ctable.insertUnique(errors, "package already present: ".. pack)
        else
            table.insert(pool, pack)
        end
    end

    local function getDeps(name)
        local pack = storage.index[name]

        if pack == nil then
            ctable.insertUnique(errors, "package not found: ".. name)
            return {}
        end

        local deps = {}

        for _, dep_name in ipairs(pack.dependencies) do
            local results = package.find(dep_name)

            if #results == 0 then
                ctable.insertUnique(errors, "package not found: ".. dep_name)
            else
               ctable.insertUniqueAll(deps, results)
            end
        end

        return deps
    end

    local function getResult(r)
        result = r
    end

    local function poll()
        local name = table.remove(result)

        if name ~= nil then
            local pack = storage.index[name]

            if pack == nil then
                ctable.insertUnique(errors, "package not found: ".. name)
                return false
            end

            table.insert(actions, tact.Action(pack, package.downloadFiles, package.deleteFiles))
        else
            name = table.remove(addedPacks)

            if name ~= nil then
                local pack = storage.index[name]

                if pack == nil then
                    ctable.insertUnique(errors, "package not found: ".. name)
                    return false
                end

                pack.user_installed = true

                table.insert(actions, tact.Action(pack, package.downloadFiles, package.deleteFiles))
            else
                result = tact.Transaction(actions, { open = storage.unprotectedLoad, close = storage.unprotectedFlush })
                return true, nil
            end
        end

        return false
    end

    local function merge(_)
        if next(errors) then
            return { nil, errors }
        else
            return { result, {} }
        end
    end

    return turfu.merge(
        merge,
        turfu.foreach(findAll, ipairs({...})),
        turfu.foreach(insertAll, next, addedPacks, nil),
        turfu.map(deptree.expand(pool, getDeps), getResult),
        turfu.Future(poll)
    )
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

    local removedPacks = {}
    local pool = ctable.keys(storage.pool)
    local errors = {}
    local actions = {}
    local result

    local function findAll(_, pack)
        local results = package.find(pack, true)
        ctable.insertUniqueAll(removedPacks, results)
    end

    local function removeAll(_, pack)
        if not ctable.find(pool, pack) then
            ctable.insertUnique(errors, "package not present: ".. pack)
        else
            ctable.removeValue(pool, pack)
        end
    end

    local function getDeps(name)
        local pack = storage.pool[name]

        if pack == nil then
            ctable.insertUnique(errors, "package not found: ".. name)
            return {}
        end

        local deps = {}

        for _, dep_name in ipairs(pack.dependencies) do
            local results = package.find(dep_name, true)

            if #results == 0 then
                ctable.insertUnique(errors, "package not found: ".. dep_name)
            else
               ctable.insertUniqueAll(deps, results)
            end
        end

        return deps
    end

    local function isPinned(name)
        if storage.pool[name] == nil then
            return false
        end
        return storage.pool[name].user_installed
    end

    local function getResult(r)
        result = r
    end

    local function poll()
        local name = table.remove(result)

        if name ~= nil then
            local pack = storage.pool[name]

            if pack == nil then
                ctable.insertUnique(errors, "package not found: ".. name)
                return false
            end
            table.insert(actions, tact.Action(pack, package.moveFiles, package.restoreFiles))
        else
            name = table.remove(removedPacks)

            if name ~= nil then
                local pack = storage.pool[name]

                if pack == nil then
                    ctable.insertUnique(errors, "package not found: ".. name)
                    return false
                end
                table.insert(actions, tact.Action(pack, package.moveFiles, package.restoreFiles))
            else
                result = tact.Transaction(actions, { open = storage.unprotectedLoad, close = storage.unprotectedFlush })
                return true, nil
            end
        end

        return false
    end

    local function merge(_)
        if next(errors) then
            return { nil, errors }
        else
            return { result, {} }
        end
    end

    return turfu.merge(
        merge,
        turfu.foreach(findAll, ipairs({...})),
        turfu.foreach(removeAll, next, removedPacks, nil),
        turfu.map(deptree.shrink(pool, getDeps, isPinned), getResult),
        turfu.Future(poll)
    )
end

return package