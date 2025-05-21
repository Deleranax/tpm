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
local storage = require("ccpm.storage")
local drivers = require("ccpm.drivers")
local repository = require("/apis/tpm/repository")

--- Retrieve all packages (available of installed) that matches a certain name.
---
--- The package can be repository constrained (i.e. restricting the research in specific repositories) by adding a "@"
--- followed by a repository identifier with wildcard at the end of the package name.
---
--- For instance, if you want to match all CCPM drivers within all of Deleranax's repositories, you can use the following
--- pattern: "tpm-driver-*@Deleranax/*"
---
--- @param pattern string Package name with wildcards.
--- @param installed boolean Installed packages (true if it only matches with installed packages, false or nil otherwise).
--- @param first boolean Find first (true if it returns when the first package is found, false otherwise).
--- @return table Table of arrays of package manifests for each repository where packages where found (or just a manifest).
function package.find(pattern, installed, first)
    local result = {}

    local wildcard = tamed.Wildcard(pattern)

    for repo_name, repo in pairs(storage.store) do
        local result_repo = {}
        local found = false

        local pool = repo.packages

        if installed then
            pool = repo.local_packages
        end

        for pack_name, _ in pairs(pool) do
            if wildcard.matches(pack_name) then
                local manifest = {}

                -- Copy table
                for key, val in pairs(repo) do
                    manifest[key] = val
                end

                if first then
                    return { [repo_name] = { manifest } }
                end

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

--- Build the package index
function package.buildIndex()

end

--- Download package files. The dependencies are not checked.
---
--- @param repo_name string Repository identifier.
--- @param pack_name string Package name.
--- @return boolean True if successful (false otherwise), error message (or nil).
function package.downloadFiles(repo_name, pack_name)
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

    repo.local_packages[pack_name] = {}

    local localPack = repo.local_packages[pack_name]

    for key, val in pairs(pack) do
        localPack[key] = val
    end

    return true
end

--- Delete package files. The dependencies are not checked.
---
--- @param repo_name string Repository identifier.
--- @param pack_name string Package name.
--- @return boolean True if successful (false otherwise), error message (or nil).
function package.deleteFiles(repo_name, pack_name)
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
--- @params List of package names.
--- @return table, string A turfu.Future object (or nil) eventually returning a table containing a tact.Transaction and an array of error messages.
function package.add(repos, ...)
    storage.load()

    local initialPackages = {}
    local errors = {}

    -- TODO: Build a local index
end