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

local storage = {}

local CACHE_TTL = 300 -- Number of seconds after which the cache is invalidated
local STORAGE_TTL = 5 -- Number of seconds after which the storage is invalidated
local BASE_PATH = "/share/ccpm"
local STORE_FILE_PATH = BASE_PATH.."/store.json"
local INDEX_FILE_PATH = BASE_PATH.."/index.json"
local POOL_FILE_PATH = BASE_PATH.."/pool.json"

-- Storage
local timestamp = 0

storage.store = {}
storage.index = {}
storage.pool = {}

--- Read the storage files.
---
--- @return boolean, string False if there is an error (true otherwise), array of error messages.
function storage.load()

    -- Return if the storage is not expired
    if not storage.storageIsExpired(timestamp) then
        return true
    end

    local messages = {}

    local file, message = fs.open(STORE_FILE_PATH, "r")

    if file then
        local content = file.readAll()
        file.close()

        storage.store, message = textutils.unserializeJSON(content)

        if storage.store == nil then
            pcall(fs.move, STORE_FILE_PATH, STORE_FILE_PATH..".backup."..os.epoch())
            storage.store = {}
        end
    end

    messages["store"] = message

    file, message = fs.open(INDEX_FILE_PATH, "r")

    if file then
        local content = file.readAll()
        file.close()

        storage.index, message = textutils.unserializeJSON(content)

        if storage.index == nil then
            storage.index = {}
        end
    end

    messages["index"] = message

    file, message = fs.open(POOL_FILE_PATH, "r")

    if file then
        local content = file.readAll()
        file.close()

        storage.pool, message = textutils.unserializeJSON(content)

        if storage.pool == nil then
            storage.pool = {}
        end
    end

    messages["pool"] = message

    local ok = next(messages) == nil

    if ok then
        timestamp = storage.epoch()
    end

    return ok, messages
end


--- Read the storage files (can raise error).
function storage.unprotectedLoad()
    local ok, messages = storage.load()

    if not ok then
        local msg = ""

        for k, v in pairs(messages) do
            msg = msg ..k..": "..v.."\n"
        end

        error(msg)
    end
end

--- Write the storage files.
---
--- @return boolean, table False if there is an error (true otherwise), error message (or nil).
function storage.flush()
    local messages = {}

    local file, message = fs.open(STORE_FILE_PATH, "w")

    if file then

        local ok, rtn = pcall(textutils.serializeJSON, storage.store)

        if ok then
            file.write(rtn)
            file.close()
        else
            message = rtn
        end
    end

    messages["store"] = message

    file, message = fs.open(INDEX_FILE_PATH, "w")

    if file then
        local ok, rtn = pcall(textutils.serializeJSON, storage.index)

        if ok then
            file.write(rtn)
            file.close()
        else
            message = rtn
        end
    end

    messages["index"] = message

    file, message = fs.open(POOL_FILE_PATH, "w")

    if file then
        local ok, rtn = pcall(textutils.serializeJSON, storage.pool)

        if ok then
            file.write(rtn)
            file.close()
        else
            message = rtn
        end
    end

    messages["pool"] = message

    local ok = next(messages) == nil

    if ok then
        timestamp = storage.epoch()
    end

    return ok, messages
end

--- Write the storage files (can raise error).
function storage.unprotectedFlush()
    local ok, messages = storage.flush()

    if not ok then
        local msg = ""

        for k, v in pairs(messages) do
            msg = msg ..k..": "..v.."\n"
        end

        error(msg)
    end
end

--- @return number Number of seconds since epoch.
function storage.epoch()
    return math.floor(os.epoch("utc") / 1000)
end

--- Check if a cache timestamp describes an expired cache.
---
--- @param time number Cache timestamp (seconds since epoch).
--- @return boolean True if expired (false otherwise).
function storage.cacheIsExpired(time)
    return (time - storage.epoch()) > CACHE_TTL
end

--- Check if a storage timestamp describes an expired storage.
---
--- @param time number Storage timestamp (seconds since epoch).
--- @return boolean True if expired (false otherwise).
function storage.storageIsExpired(time)
    return (time - storage.epoch()) > STORAGE_TTL
end

return storage