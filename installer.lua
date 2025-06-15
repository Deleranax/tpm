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

-- Download the driver
write("Downloading GitHub driver... ")
local response, message = http.get("https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/libccpm-driver-github/ccpm/drivers/github.lua")

if response == nil then
    printError("Error!")
    error("Cannot download GitHub driver: ".. message)
end

print("Done.")

-- Load driver
write("Loading driver... ")
local ok, driver = pcall(load(response.readAll(), "ccpm.drivers.github", "t", _ENV))

if not ok then
    printError("Error!")
    error("Unable to load driver: ".. driver)
end
print("Done.")

-- Fetch index
write("Fetching index... ")
local index, msg = driver.fetchIndex("Deleranax/ccpm")

if msg then
    printError("Error!")
    error("Unable to fetch index: ".. msg)
end

local function onlineRequire(path)
    local _path = string.lower(string.gsub(path, "%.", "/"))
    local url

    for package, manifest in pairs(index.packages) do
        for file, _ in pairs(manifest.files) do
            local _file = string.lower(file)
            if _path ..".lua" == _file or _path .."/init.lua" == _file then
                url = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/".. package .."/".. file
                break
            end
        end
    end

    if url == nil then
        return nil, "no remote ".. path
    end
    write("Downloading ".. path .."... ")

    local response, message = http.get(url)

    if response == nil then
        printError("Error!")
        error("Cannot download ".. path ..": ".. message)
    end

    print("Done.")

    return load(response.readAll(), path, "t", _ENV)
end

table.insert(package.loaders, onlineRequire)

local ccpm = require("ccpm")
local spinny = require("spinny")

local function executeFuture(future)
    local spinner = spinny.dot0(term)

    repeat
        spinner.progress()
        future.poll()
        sleep(0.05)
    until future.isAvailable()

    spinner.go()
end

local function resolveDeps(future)
    print()
    write("Resolving dependencies ")

    executeFuture(future)

    print("Done.")

    local result = future.result()

    if next(result[2]) then
        for _, err in ipairs(result[2]) do
            print(err)
        end

        error()
    end

    return result[1]
end

local function doTrsct(installing, single, multiple, trsct)

    print()

    write("You are about to ")
    if installing then
        write("install")
    else
        write("remove")
    end
    write(" the following ")
    if #trsct.actions() > 1 then
        write(multiple)
    else
        write(single)
    end
    print(":")

    for _, item in ipairs(trsct.actions()) do
        local name = item.identifier or item.name
        print("- ".. name)
    end

    print()
    print("Press any key to continue...")

    read()

    local function beforeAll(rollback, n)
        if rollback then
            print("There was errors during transaction. Roll backing...")
            print()
        end

        if rollback == installing then
            write("Deleting ".. n .." ")
        else
            write("Installing ".. n .." ")
        end

        if n > 1 then
            write(multiple)
        else
            write(single)
        end
        print("...")
    end

    local function afterAll(_, _, errors)
        if errors then
            print("Completed with errors!\n")
        else
           print("Completed!\n")
        end
    end

    local function before(rollback, _, item)
        local name = item.identifier or item.name

        if rollback == installing then
            write("Removing ".. name .."...")
        else
            write("Installing ".. name .."...")
        end
        sleep(0.1)
    end

    local function after(_, _, _, error)
        if error then
            print(" Error!")
        else
            print(" Done.")
        end
    end

    trsct.setHandlers({ beforeAll = beforeAll, before = before, afterAll = afterAll, after = after })

    local ok, errors = trsct.apply()

    if not ok then
        print("Errors:")
        for _, err in ipairs(errors) do
            print(err.error)
        end

        error()
    end
end

local future = ccpm.repository.add("Deleranax/ccpm")

local result = resolveDeps(future)

doTrsct(true, "repository", "repositories", result)

write("Building index ")

executeFuture(ccpm.package.buildIndex())

print("Done.")

future = ccpm.package.add("ccpm")

result = resolveDeps(future)

doTrsct(true, "package", "packages", result)

future = ccpm.package.remove("tamed")

result = resolveDeps(future)

doTrsct(false, "package", "packages", result)