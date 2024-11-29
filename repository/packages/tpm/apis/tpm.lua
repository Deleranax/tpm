-- TPM Library
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

local repository = require("apis/tpm/repository")

local TPM_FOLDER = "/.tpm"
local REPOSITORIES_FILE = TPM_FOLDER.."/repositories.json"
local PACKAGES_FILE = TPM_FOLDER.."/packages.json"

local repositories = nil;
local packages = nil;

--- Load database from files.
local function loadDatabase()
    if repositories ~= nil then
        return
    end

    if not fs.exists(TPM_FOLDER) then
        repositories = {}
        packages = {}
        return
    end

    if fs.exists(REPOSITORIES_FILE) then
        local file = fs.open(REPOSITORIES_FILE, "r")

        if file == nil then
            repositories = {}
        else
            local r, message = repository.loadAll(file.readAll())
            file.close()

            if r == nil then
                error(message)
            end

            repositories = r
        end
    else
        repositories = {}
    end

    if fs.exists(PACKAGES_FILE) then
        local file = fs.open(PACKAGES_FILE, "r")

        if file == nil then
            packages = {}
        else
            -- TODO: Add unserialization error handling (backup file)
            packages = textutils.unserialize(file.readAll())
            file.close()
        end
    else
        packages = {}
    end
end

--- Save database to files.
local function saveDatabase()
    if not fs.exists(TPM_FOLDER) then
        fs.makeDir(TPM_FOLDER)
    end

    local file = fs.open(REPOSITORIES_FILE, "r")

    if file == nil then
        error("Unable to save repositories database ("..REPOSITORIES_FILE..")")
    else
        file.write(textutils.serialize(repositories.exportAll()))
        file.close()
    end

    local file = fs.open(PACKAGES_FILE, "r")

    if file == nil then
        error("Unable to save packages database ("..PACKAGES_FILE..")")
    else
        file.write(textutils.serialize(packages))
        file.close()
    end
end

--- Add a repository.
--- @return boolean, string true if it is successful, the message (if there is an error)
local function addRepository(url)
    local r, message = repository.create(url)

    if r == nil then
        return false, message
    end

    loadDatabase()

    for i, v in ipairs(repositories) do
        if v.getURL() == url then
            return false, "Repository already added"
        end
    end

    table.insert(repositories, r)

    saveDatabase()
end

-- TODO: Remove repository
-- TODO: update repository (with timestamp/auto)
-- TODO: compute dependency graph (only inside a repository)
-- TODO: download package (with repository disambiguation, file collision detection)
-- TODO: remove package (with repository disambiguation, warning when file missing)

return {repository = repository, addRepository = addRepository}