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

local storage

-- Number of seconds after which the cache is invalidated
local CACHE_TTL = 300

-- Storage
storage.store = {}
storage.cache = {}

--- Read the storage files.
---
--- @return boolean, string State (false if there is an error, true otherwise), error message (or nil).
function storage.load()
    local file, message = fs.open("/.tpm-store", "r")

    if file then
        local content = file.readAll()
        file.close()

        storage.store, message = textutils.unserialize(content)

        if storage.store == nil then
            pcall(fs.move, "/.tpm-store", "/.tpm-store-backup")
            storage.store = {}
        end
    end

    file, message = fs.open("/.tpm-cache", "r")

    if file then
        local content = file.readAll()
        file.close()

        storage.cache, message = textutils.unserialize(content)

        if storage.cache == nil then
            storage.cache = {}
        end
    end

    return message == nil, message
end

--- Write the storage files.
---
--- @return boolean, string State (false if there is an error, true otherwise), error message (or nil).
function storage.flush()
    local file, message = fs.open("/.tpm-store", "w")

    if file then
        local ok, rtn = pcall(textutils.serialize, storage.store)

        if ok then
            file.write(rtn)
            file.close()
        else
            message = rtn
        end
    end

    file, message = fs.open("/.tpm-cache", "r")

    if file then
        local ok, rtn = pcall(textutils.serialize, storage.cache)

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
function storage.epoch()
    return math.floor(os.epoch("utc") / 1000)
end

--- Check if a cache timestamp describes an expired cache.
---
--- @param timestamp number Cache timestamp (seconds since epoch).
--- @return boolean Expiration state (true if expired, false otherwise).
function storage.isExpired(timestamp)
    return (timestamp - storage.epoch()) > CACHE_TTL
end

return storage