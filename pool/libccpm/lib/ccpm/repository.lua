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

local repository = {}

local deptree = require("deptree")
local tact = require("tact")
local turfu = require("turfu")
local tamed = require("tamed")
local ctable = require("commons.table")
local storage = require("ccpm.storage")
local drivers = require("ccpm.drivers")

local cache = {}

--- Fetch repository information.
---
--- @param url string Repository identifier (GitHub identifier, URL...).
--- @return table, string Repository driver (or nil), repository index (or error message).
function repository.fetch(url)

    -- Return the cached version if available and not expired
    if cache[url] ~= nil then
        if not storage.isExpired(cache[url].update_timestamp) then
            return drivers[cache[url].driver], cache[url]
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
    index.update_timestamp = storage.epoch()
    cache[url] = index

    return driver, index
end

--- Get repository information from local store. If the repository is not present, fetch it from remote and format it
--- for the local store.
---
--- @param url string Repository identifier (GitHub identifier, URL...).
--- @return table, string Local repository index (or nil), error message (or nil).
function repository.fetchAndStore(url)
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
    localIndex.user_installed = false

    return localIndex
end

--- (Internal) Add repository into the state. The dependencies are not checked.
---
--- @param index table Local repository index.
function repository.addUnchecked(index)
    if (index ~= nil and index.identifier ~= nil) then
        for k, v in pairs(index.packages) do
            print("["..k.."] = "..tostring(v))
        end
        storage.store[index.identifier] = index
    end
end

--- Add repositories and their dependencies.
---
--- IMPORTANT: Do not modify the open and close handlers of the transaction. They are used, respectively, to load and
--- flush the store. Only do so if you know what you do, or if you want to do a "dry run" (by removing the close handler
--- responsible for flushing the store).
---
--- @params List of repositories identifiers (GitHub identifier, URL...).
--- @return table, string A turfu.Future object (or nil) eventually returning a table containing a tact.Transaction and an array of error messages.
function repository.add(...)
    storage.load()

    local addedRepos = {...}
    local pool = repository.find()
    local errors = {}
    local actions = {}
    local result

    ctable.insertAll(pool, addedRepos)

    local function getDeps(name)
        local driver, index = repository.fetch(name)

        if driver == nil then
            table.insert(errors, name..": "..index)
            return {}
        else
            return index.companions
        end
    end

    local future = deptree.expand(pool, getDeps)

    local function poll()
        if future.isPending() then
            future.poll()
            result = future.result()
        else
            local name = table.remove(result)

            if name ~= nil then
                local repo, message = repository.fetchAndStore(name)

                if repo == nil then
                    table.insert(errors, name..": "..message)
                    return false
                end

                table.insert(actions, tact.Action(repo, repository.addUnchecked, repository.removeUnchecked))
            else
                name = table.remove(addedRepos)

                if name ~= nil then
                    local repo, message = repository.fetchAndStore(name)

                    if repo == nil then
                        table.insert(errors, name..": "..message)
                        return false
                    end

                    repo.user_installed = true

                    table.insert(actions, tact.Action(repo, repository.addUnchecked, repository.removeUnchecked))
                else
                    return true, {
                        transaction = tact.Transaction(actions, { open = storage.load, close = storage.flush }),
                        errors = errors
                    }
                end
            end
        end

        return false
    end

    return turfu.Future(poll)
end

--- (Internal) Remove repository from the state. The dependencies are not checked.
---
--- @param index table Local repository index.
function repository.removeUnchecked(index)
    if (index ~= nil and index.identifier ~= nil) then
        storage.store[index.identifier] = nil
    end
end

--- Remove repositories and their unused dependencies.
---
--- IMPORTANT: Do not modify the open and close handlers of the transaction. They are used, respectively, to load and
--- flush the store. Only do so if you know what you do, or if you want to do a "dry run" (by removing the close handler
--- responsible for flushing the store).
---
--- @params List of repositories identifiers (GitHub identifier, URL...).
--- @return table, string A turfu.Future object (or nil) eventually returning a table containing a tact.Transaction and an array of error messages.
function repository.remove(...)
    storage.load()

    local removedRepos = {...}
    local pool = repository.find()
    local errors = {}
    local actions = {}
    local result

    ctable.removeAll(pool, removedRepos)

    local function getDeps(name)
        return storage.store[name].companions
    end

    local function isPinned(name)
        return storage.store[name].user_installed
    end

    local future = deptree.shrink(pool, getDeps, isPinned)

    local function poll()
        if future.isPending() then
            future.poll()
            result = future.result()
        else
            local name = table.remove(result)

            if name ~= nil then
                local repo, message = repository.fetchAndStore(name)

                if repo == nil then
                    table.insert(errors, name..": "..message)
                    return false
                end

                table.insert(actions, tact.Action(repo, repository.removeUnchecked, repository.addUnchecked))
            else
                name = table.remove(removedRepos)

                if name ~= nil then
                    local repo, message = repository.fetchAndStore(name)

                    if repo == nil then
                        table.insert(errors, name..": "..message)
                        return false
                    end

                    table.insert(actions, tact.Action(repo, repository.removeUnchecked, repository.addUnchecked))
                else
                    return true, {
                        transaction = tact.Transaction(actions, { open = storage.load, close = storage.flush }),
                        errors = errors
                    }
                end
            end
        end

        return false
    end

    return turfu.Future(poll)
end

--- List installed repositories corresponding to a pattern.
---
--- @param pattern string Repository identifier with wildcard.
--- @return table Array of repository identifiers.
function repository.find(pattern)
    local result = {}

    local wildcard = tamed.Wildcard(pattern)

    for repo_name, _ in pairs(storage.store) do
        if wildcard.matches(repo_name) then
            table.insert(result, repo_name)
        end
    end

    return result
end

return repository