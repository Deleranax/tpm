-- GitHub CCPM repository driver
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

local github = {}

local function get_file_url(url, path)
    return string.sub(url, 8) .."/".. path
end

--- Check URL compatibility.
---
--- @param url string Repository URL.
--- @return boolean Compatibility result (true if the URL can be used with this driver, false otherwise).
function github.compatible(url)
    if url == nil then
        return false
    else
        if string.find(url, "^file://.+") then
            return true
        else
            return false
        end
    end
end

--- Check if repository exists.
---
--- @param url string Repository URL.
--- @return boolean Repository existence (true if it exists, false otherwise, or nil if there is an error), the error message.
function github.exists(url)
    return fs.exists(get_file_url(url, "manifest.json"))
end

--- Fetch repository index.
---
--- @param url string Repository URL.
--- @return table, string Repository index (or nil), the error message.
function github.fetchIndex(url)
    local file, message = fs.open(get_file_url(url, "manifest.json"), "r")

    if file == nil then
        return nil, message
    else
        return textutils.unserializeJSON(file.readAll())
    end
end

--- Fetch package file.
---
--- @param url string Repository URL.
--- @param package string Package name.
--- @param path, string, File path.
--- @return string, string Package file content (or nil), the error message.
function github.fetchPackageFile(url, package, path)
    local file, message = fs.open(get_file_url(url, "pool/".. package .."/".. path), "r")

    if file == nil then
        return nil, message
    else
        return textutils.unserializeJSON(file.readAll())
    end
end

return github