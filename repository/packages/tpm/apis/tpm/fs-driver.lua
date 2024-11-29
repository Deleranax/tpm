-- TPM FS Driver
-- Copyright (C) 2024 Deleranax
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


--- @param url string the file url (file://)
--- @return string the file path from URL
local function URLToPath(url)
    return string.sub(url, 8)
end

--- Verify if the URL is valid (reachable)
--- @param url string the URL
--- @return boolean, string true if reachable, the message (if there is an error)
local function checkURL(url)
    local path = URLToPath(url)
    if fs.exist() then
        return true
    else
        return false, path + ": No such file"
    end
end

--- Get the content of a file
--- @param url string the file URL
--- @return string the content of the file
local function get(url)
    local path = URLToPath(url)

    local file, message = fs.open(path, "r")
    if file ~= nil then
        return file.readAll()
    else
        return nil, message
    end
end

return {prefix = "file", checkURL = checkURL, get = get}