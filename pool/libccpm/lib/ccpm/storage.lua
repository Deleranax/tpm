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

-- Number of seconds after which the cache is invalidated
local CACHE_TTL = 300
local BASE_PATH = "/share/ccpm"
local STORE_FILE_PATH = BASE_PATH.."/store.json"
local INDEX_FILE_PATH = BASE_PATH.."/index.json"
local POOL_FILE_PATH = BASE_PATH.."/pool.json"

-- Storage
storage.store = {}
storage.index = {}
storage.pool = {}

--- Read the storage files.
---
--- @return boolean, string False if there is an error (true otherwise), array of error messages.
function storage.load()
    local messages = {}

    local file, message = fs.open(STORE_FILE_PATH, "r")

    if file then
        local content = file.readAll()
        file.close()

        storage.store, message = textutils.unserialize(content)

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

        storage.index, message = textutils.unserialize(content)

        if storage.index == nil then
            storage.index = {}
        end
    end

    messages["index"] = message

    file, message = fs.open(POOL_FILE_PATH, "r")

    if file then
        local content = file.readAll()
        file.close()

        storage.pool, message = textutils.unserialize(content)

        if storage.pool == nil then
            storage.pool = {}
        end
    end

    messages["pool"] = message

    return next(messages) == nil, messages
end

--- Write the storage files.
---
--- @return boolean, table False if there is an error (true otherwise), error message (or nil).
function storage.flush()
    local messages = {}

    local file, message = fs.open(STORE_FILE_PATH, "w")

    if file then

        for k,v in pairs(storage.store) do
            print(k..":"..textutils.serialize(v))
        end

        local ok, rtn = pcall(textutils.serialize, storage.store)

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
        local ok, rtn = pcall(textutils.serialize, storage.index)

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
        local ok, rtn = pcall(textutils.serialize, storage.pool)

        if ok then
            file.write(rtn)
            file.close()
        else
            message = rtn
        end
    end

    messages["pool"] = message

    return next(messages) == nil, messages
end

--- @return number Number of seconds since epoch.
function storage.epoch()
    return math.floor(os.epoch("utc") / 1000)
end

--- Check if a cache timestamp describes an expired cache.
---
--- @param timestamp number Cache timestamp (seconds since epoch).
--- @return boolean True if expired (false otherwise).
function storage.isExpired(timestamp)
    return (timestamp - storage.epoch()) > CACHE_TTL
end

return storage