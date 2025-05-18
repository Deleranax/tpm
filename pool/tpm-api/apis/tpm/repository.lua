-- TPM library
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

local repository

local deptree = require("/apis/deptree")
local tact = require("/apis/tact")
local turfu = require("/apis/turfu")
local storage = require("/apis/tpm/storage")
local drivers = require("/apis/tpm/drivers")

--- Fetch repository information.
---
--- @param url string Repository identifier (GitHub identifier, URL...).
--- @return table, string Repository driver (or nil), repository index (or error message).
function repository.fetch(url)
    if storage.cache[url] ~= nil then
        if not storage.isExpired(storage.cache[url].timestamp) then
            local driver_name = storage.cache[url].driver

            return drivers[driver_name], driver_name, storage.cache[url]
        end
    end

    local driver_name
    local driver

    for d_name, d_instance in pairs(drivers) do
        if d_instance.compatible(url) then
            driver_name = d_name
            driver = d_instance
        end
    end

    if driver == nil then
        return nil, "Unable to find a driver for this repository"
    end

    if not driver.exists(url) then
        return nil, "Repository does not exist"
    end

    local index, message = driver.fetchIndex(url)

    if index == nil then
        return nil, "Cannot fetch index: "..message
    end

    index.driver = driver_name
    storage.cache.url = index

    return driver, index
end

--- Fetch repository information from local store. If the repository is not present, fetch it from remote and format it
--- for the local store.
---
--- @param url string Repository identifier (GitHub identifier, URL...).
--- @return table, string Local repository index (or nil), error message (or nil).
function repository.fetchStore(url)
    if storage.store[url] ~= nil then
        return storage.store[url]
    end

    local driver, index = repository.fetch(url)

    if driver == nil then
        return nil, index
    end

    local localIndex = {}

    -- Copy index into localIndex
    for key, value in pairs(index) do
        localIndex[key] = value
    end

    localIndex.identifier = url
    localIndex.packages = {}
    localIndex.user_installed = false
end

--- (Internal) Add repository into the state. The dependencies are not checked.
---
--- @param index table Local repository index.
function repository.addUnchecked(index)
    storage.store[index.identifier] = index
end

--- Add repositories and their dependencies.
---
--- @params List of repositories identifiers (GitHub identifier, URL...).
--- @return table, string A turfu.Future object (or nil) eventually returning a table containing a tact.Transaction and an array of error messages.
function repository.add(...)
    storage.load()

    local initialRepos = {...}
    local errors = {}
    local actions = {}
    local completed = false
    local result

    local function getter(name)
        local driver, index = repository.fetch(name)

        if driver == nil then
            table.insert(errors, name..": "..index)
            return {}
        else
            return index.companions
        end
    end

    local function ignore(name)
        return storage.store[name] ~= nil
    end

    local resolver = deptree.Resolver(initialRepos, getter, ignore)

    local function poll()
        if completed then
            local name = table.remove(result)

            if name ~= nil then
               local repo, message = repository.fetchStore(name)

                if repo == nil then
                    table.insert(errors, name..": "..message)
                    return false
                end

                table.insert(actions, tact.Action(repo, repository.addUnchecked, repository.removeUnchecked))
            else
                name = table.remove(initialRepos)

                if name ~= nil then
                   local repo, message = repository.fetchStore(name)

                    if repo == nil then
                        table.insert(errors, name..": "..message)
                        return false
                    end

                    repo.user_installed = true

                    table.insert(actions, tact.Action(repo, repository.addUnchecked, repository.removeUnchecked))
                else
                    return true, {
                        transaction = tact.Transaction(actions, { beforeAll = storage.load, afterAll = storage.flush }),
                        errors = errors
                    }
                end
            end
        else
            completed, result = resolver.poll()
        end

        return false
    end

    return turfu.Future(poll)
end

--- (Internal) Remove repository from the state. The dependencies are not checked.
---
--- @param index table Local repository index.
function repository.removeUnchecked(index)
    storage.store[index.identifier] = nil
end

--- Remove repositories and their unused dependencies.
---
--- @params List of repositories identifiers (GitHub identifier, URL...).
--- @return table, string A turfu.Future object (or nil) eventually returning a table containing a tact.Transaction and an array of error messages.
function repository.remove(...)
    storage.load()

    local initialRepos = {...}
    local errors = {}
    local actions = {}
    local completed = false
    local result

    local function getter(name)
        local depending = {}

        -- Get the repos that have the removed repository as companions
        for repo_name, repo in pairs(storage.store) do
            for _, comp in ipairs(repo.companions) do
                if comp == name then
                    table.insert(depending, repo_name)
                    break
                end
            end
        end

        return depending
    end

    local function ignore(name)
        -- Do not ignore initialRepos
        for _, n in ipairs(initialRepos) do
            if n == name then
                return false
            end
        end

        return storage.store[name].user_installed
    end

    local resolver = deptree.Resolver(initialRepos, getter, ignore, true)

    local function poll()
        if completed then
            local name = table.remove(result)

            if name ~= nil then
                local repo, message = repository.fetchStore(name)

                if repo == nil then
                    table.insert(errors, name..": "..message)
                    return false
                end

                table.insert(actions, tact.Action(repo, repository.removeUnchecked, repository.addUnchecked))
            else
                return true, {
                    transaction = tact.Transaction(actions, { beforeAll = storage.load, afterAll = storage.flush }),
                    errors = errors
                }
            end
        else
            completed, result = resolver.poll()
        end

        return false
    end

    return turfu.Future(poll)
end

return repository