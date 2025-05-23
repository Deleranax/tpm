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
local repository = require("ccpm.repository")

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

        local packages = repo.packages

        for pack_name, pack in pairs(packages) do
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
        ctable.insertUniqueAll(packs, ctable.keys(repo.local_packages))
        print(textutils.serialize(packs))
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
        print(pack)
        local first = true

        local result = package.find("pack@*")

        for repo_name, repo_packs in pairs(result) do
            if first then
                storage.index[pack] = repo_packs[1]
                first = false
            else
                storage.index[pack.."@"..repo_name] = repo_packs[1]
            end
        end
    end

    local function finish(_)
        storage.unprotectedFlush()
        return packs
    end

    return turfu.merge(
        finish,
        turfu.foreach(collect, pairs(storage.store)),
        turfu.sort(storage.store, comp),
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
--- @return table Package manifest (or nil), package identifier (or nil).
function package.select(pattern)
    storage.unprotectedLoad()

    local wildcard = tamed.Wildcard(pattern, "@")

    for identifier, manifest in pairs(storage.index) do
        if wildcard.matches(identifier) then
            return manifest, identifier
        end
    end

    return nil
end

--- Download package files. The dependencies are not checked.
---
--- @param repo_name string Repository identifier.
--- @param pack_name string Package name.
--- @return boolean True if successful (false otherwise), error message (or nil).
function package.downloadFiles(repo_name, pack_name)
    storage.unprotectedLoad()

    -- TODO: Rewrite

    local repo = storage.store[repo_name]

    if repo == nil then
        return nil, "repository not found: "..repo_name
    end

    local driver = drivers[repo.driver]

    if driver == nil then
        return nil, "driver not found: "..repo.driver
    end

    local pack = repo.packages[pack_name]

    if pack == nil then
        return nil, "package not found: "..pack_name
    end

    local files = pack.files

    for path, digest in ipairs(files) do
        local content, message = driver.fetchPackageFile(repo_name, pack_name, path)

        if content == nil then
            return nil, path..": "..message
        end

        if digest ~= sha256.digest(content) then
            return nil, path..": mismatched digests"
        end

        local file
        file, message = fs.open(path, "w")

        if file == nil then
            return nil, path..": "..message
        end

        file.write(content)
        file.close()
    end

    return true
end

--- Delete package files. The dependencies are not checked.
---
--- @param repo_name string Repository identifier.
--- @param pack_name string Package name.
--- @return boolean True if successful (false otherwise), error message (or nil).
function package.deleteFiles(repo_name, pack_name)
    storage.unprotectedLoad()

    -- TODO: Rewrite

    local repo = storage.store[repo_name]

    if repo == nil then
        return nil, "repository not found: "..repo_name
    end

    local pack = repo.local_packages[pack_name]

    if pack == nil then
        return nil, "package not found: "..pack_name
    end

    local files = pack.files

    for path, _ in ipairs(files) do
        fs.delete(path)

        local dir = fs.getDir(path)

        if next(fs.find(dir.."/*")) == nil then
            fs.delete(dir)
        end
    end

    repo.local_packages[pack_name] = nil

    return true
end

--- Add packages and their dependencies.
---
--- IMPORTANT: Do not modify the open and close handlers of the transaction. They are used, respectively, to load and
--- flush the store. Only do so if you know what you do, or if you want to do a "dry run" (by removing the close handler
--- responsible for flushing the store).
---
--- @param repos table Array of allowed repositories identifiers (where to resolve the dependencies).
--- @vararg string List of package names.
--- @return table, string A turfu.Future object (or nil) eventually returning a table containing a tact.Transaction and an array of error messages.
function package.add(repos, ...)
    storage.unprotectedLoad()

    local initialPackages = {}
    local errors = {}

    -- TODO: Build a local index
end

return package