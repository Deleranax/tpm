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

local tpm = {}
local deptree = require("/apis/deptree")
local tact = require("/apis/tact")
local drivers = {}

local CACHE_TTL = 300

-- Storage
local store = {}
local cache = {}

-- Load the drivers
for _, elem in ipairs(fs.find("/apis/tpm/drivers/*")) do
    local name = string.sub(1, -4, fs.name(elem))
    drivers[name] = require(elem)
end

-- Added to make it compatible with onlineRequire
if next(drivers) == nil then
    drivers["github"] = require("/apis/tpm/drivers/github")
end

--- Read the storage files.
---
--- @return boolean, string State (false if there is an error, true otherwise), error message (or nil).
local function load()
    local file, message = fs.open("/.tpm-store", "r")

    if file then
        local content = file.readAll()
        file.close()

        store, message = textutils.unserialize(content)

        if store == nil then
            pcall(fs.move, "/.tpm-store", "/.tpm-store-backup")
            store = {}
        end
    end

    file, message = fs.open("/.tpm-cache", "r")

    if file then
        local content = file.readAll()
        file.close()

        cache, message = textutils.unserialize(content)

        if cache == nil then
            cache = {}
        end
    end

    return message == nil, message
end

--- Write the storage files.
---
--- @return boolean, string State (false if there is an error, true otherwise), error message (or nil).
local function flush()
    local file, message = fs.open("/.tpm-store", "w")

    if file then
        local ok, rtn = pcall(textutils.serialize, store)

        if ok then
            file.write(rtn)
            file.close()
        else
            message = rtn
        end
    end

    file, message = fs.open("/.tpm-cache", "r")

    if file then
        local ok, rtn = pcall(textutils.serialize, cache)

        if ok then
            file.write(rtn)
            file.close()
        else
            message = rtn
        end
    end

    return message == nil, message
end

--- @return number Number of seconds since epoch.
local function epoch()
    return math.floor(os.epoch("utc") / 1000)
end

--- Fetch repository information.
---
--- @param url string Repository identifier (GitHub identifier, URL...).
--- @return table, string Repository driver (or nil), repository index (or error message).
local function fetchRepository(url)
    if cache[url] ~= nil then
        if (epoch() - cache[url]) < CACHE_TTL then
            local driver_name = cache[url].driver

            return drivers[driver_name], driver_name, cache[url]
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

    index["driver"] = driver_name
    cache["url"] = index

    return driver, index
end

--- Add a repository.
---
--- @params List of repositories identifiers (GitHub identifier, URL...).
--- @return table, string A FutureTransaction object (or nil), error message (or nil).
function tpm.addRepositories(...)
    load()

    local errors = {}

    local function getter(name)
        local driver, index = fetchRepository(name)

        if driver == nil then
            table.insert(errors, index)
            return {}
        else
            return index["companions"]
        end
    end

    local function ignore(name)
        return store[name] ~= nil
    end

    local resolver = deptree.Resolver(..., getter, ignore)

    local result
    local completed = false

    local function confirm(name)
        local _, index = fetchRepository(name)

        local localIndex = {}

        -- Copy index into localIndex
        for key, value in pairs(index) do
            localIndex[key] = value
        end

        localIndex.packages = {}
        localIndex.user_installed = false

        store[name] = localIndex
    end

    local function confirmUserInstalled(name)
        confirm(name)

        store[name].user_installed = true
    end

    local function actionFactory()
        if completed then
            if next(errors) ~= nil then
                return true, {}, errors
            end

            local repository = table.remove(result)

            if repository ~= nil then
                local action = tact.Action(repository, confirm)

                return true, { action }, {}
            else
                repository = table.remove(arg)

                if repository ~= nil then
                    local action = tact.Action(repository, confirmUserInstalled)

                    return true, { action }, {}
                else
                    return false
                end
            end
        end

        completed, result = resolver.poll()

        return true, {}, {}
    end

    return tact.FutureTransaction(actionFactory, { beforeAll = load, afterAll = flush })
end

return tpm