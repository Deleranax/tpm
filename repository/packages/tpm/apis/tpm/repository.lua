-- TPM Repository Manager
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

local sha256 = require("apis/sha256")
local httpDriver = require("apis/tpm/http-driver")
local fsDriver = require("apis/tpm/fs-driver")

local drivers = {fsDriver, httpDriver}

--- @param url string url of a repository
--- @return table, string corresponding driver or nil, message (if there is an error)
local function getDriver(url)
    local proto = string.match(url, "[^:]*")
    local driver = nil

    for i, v in ipairs(drivers) do
        if v.prefix == proto then
            driver = v
            break
        end
    end

    if driver == nil then
        return nil, proto..": No driver for this protocol"
    end

    return driver
end

--- Construct Repository table.
--- @param index table repository index
--- @param driver? the driver to use
--- @return table, string Repository table or nil, message (if there is an error)
local function load(index, driver)
    local driver = driver
    local message

    if driver == null then
        driver, message = getDriver(index.url);
    end

    if driver == nil then
        return nil, message
    end

    return {
        --- @return string the repository URL
        getURL = function()
            return index.url
        end,

        --- @return string repository name
        getName = function()
            return index.name
        end,

        --- @return number current repository timestamp (last modification on remote)
        getTimestamp = function()
            return index.timestamp
        end,

        --- @return table packages list
        getPackagesList = function()
            local rtn = {}
            for k, _ in pairs(index.packages) do
                table.insert(rtn, k)
            end
            return rtn
        end,

        --- @return boolean, string true if remote repository changed since last update or nil (if there is an error), message (if there is an error)
        checkForUpdate = function()
            local content, message = driver.get(url.."/timestamp")

            if content ~= nil then
                local ts = tonumber(content)
                return ts > index.timestamp
            else
                return nil, message
            end
        end,

        --- Update the repository index.
        --- @return boolean, string true if the repository was updated, message (if there is an error)
        update = function()
            local content, message = driver.get(url.."/index.json")

            if content ~= nil then
                local ni = textutils.unserializeJSON(data)

                if ni == nil then
                    return false, "Unreadable index"
                else
                    index = ni
                    return true
                end
            else
                return false, message
            end
        end,

        --- @return table repository data
        export = function()
            return index
        end,

        --- Construct a Package table by name.
        --- @return table Package table if the name is correct, nil otherwise
        getPackage = function(name)
            if index.packages[name] == nil then
                return nil
            end

            local package = index.packages[name]

            return {
                --- Compute files collision (files in the package that already exist).
                --- @return table list of the files (path) with collisions
                getFileCollisions = function()
                    local collisions = {}
                    for _, v in ipairs(package.files) do
                        if (fs.exists(v)) then
                            table.insert(collisions, v)
                        end
                    end

                    return collisions
                end,

                --- @return number number of files
                getFileNumber = function()
                    table.getn(package.files)
                end,

                --- Download a file of the package.
                --- @param i number the index of the file
                --- @param replace boolean should the file be erased (if it already exists)
                --- @return boolean, string, boolean, string true if it was downloaded, the path of the file, true if it was replaced, message (it was not downloaded)
                downloadFile = function(i, replace)
                    local path = package.files[i].path
                    local replaced = false

                    if fs.exists(path) then
                        if replace then
                            replaced = true
                        else
                            return false, path, false, path..": File already exists"
                        end
                    end

                    local content, message = driver.get(url.."/index.json")

                    if content == nil then
                        return false, path, replaced, message
                    end

                    local file = fs.open(path, "w")

                    if file == nil then
                        return false, path, replaced, path..": Cannot open file"
                    end

                    file.write(content)
                    file.close()

                    return true, path, replaced
                end,

                --- Verify that a local file's hash matches remote.
                --- @param i number the index of the file
                --- @return boolean, boolean, string true if the hash matches, true if the hash was computed, message (if there is an error)
                verifyFile = function(i)
                    local path = package.files[i].path
                    local digest = package.files[i].digest

                    if not fs.exists(path) then
                        return false, false, path..": No such file"
                    end

                    local file = fs.open(path, "r")

                    if file == nil then
                        return false, false, path..": Cannot open file"
                    end

                    local content = file.readAll()

                    return sha256.digest() == content, true
                end,

                --- @return table package data (shallow copy)
                export = function()
                    local temp = textutils.serializeJSON(package)
                    return textutils.unserializeJSON(temp)
                end
            }
        end
    }
end

--- Construct Repository table by validating provided URL.
--- @param url string repository URL
--- @return table, string repository table or nil (if there is an error), message (if there is an error)
local function create(url)
    local driver, message = getDriver(url);

    if driver == nil then
        return nil, message
    end

    local ok, message = driver.checkURL(url)

    if not ok then
        return nil, message
    else
        if string.sub(url, -1) == "/" then
            url = string.sub(url, 1, -2)
        end

        local content, message = driver.get(url.."/index.json")

        if content == nil then
            return nil, message
        else
            local index = textutils.unserializeJSON(content)
            index.url = url
            return load(index, driver)
        end
    end
end

--- Construct all Repository tables.
--- @param data string the serialized Repository tables
--- @return table, string list of Repository table or nil, message (if there is an error)
local function loadAll(data)
    local list = textutils.unserializeJSON(data)
    local rtn = {}

    if list == nil then
        return nil, "Unable to unserialize data"
    end

    for _, v in ipairs(list) do
        local r, message = load(v)

        if r == nil then
            return nil, message
        end

        table.insert(rtn, r)
    end

    rtn.exportAll = function()
        local rt2 = {}
        for _, v in ipairs(rtn) do
            table.insert(rt2, v.export())
        end
        return rt2
    end

    return rtn
end

return {getDriver = getDriver, create = create, load = load, loadAll = loadAll}