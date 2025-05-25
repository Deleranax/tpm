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

local PATH_TABLE = {
    ["ccpm"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/libccpm/lib/ccpm/init.lua",
    ["ccpm.repository"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/libccpm/lib/ccpm/repository.lua",
    ["ccpm.package"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/libccpm/lib/ccpm/package.lua",
    ["ccpm.storage"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/libccpm/lib/ccpm/storage.lua",
    ["ccpm.drivers"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/libccpm/lib/ccpm/drivers.lua",
    ["ccpm.drivers.github"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/libccpm-driver-github/lib/ccpm/drivers/github.lua",
    ["crypt.sha256"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/crypt/lib/crypt/sha256.lua",
    ["deptree"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/deptree/lib/deptree.lua",
    ["tact"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/tact/lib/tact.lua",
    ["turfu"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/turfu/lib/turfu.lua",
    ["tamed"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/tamed/lib/tamed.lua",
    ["commons.table"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/commons/lib/commons/table.lua",
    ["commons.util"] = "https://raw.githubusercontent.com/Deleranax/ccpm/main/pool/commons/lib/commons/util.lua",
}

local function onlineRequire(path)
    local url = PATH_TABLE[path]

    if url == nil then
        return nil, "no remote "..path
    end
    write("Downloading "..path.."... ")

    local response, message = http.get(url)

    if response == nil then
        error("Cannot download "..path..": "..message)
    end

    print("Done.")

    return load(response.readAll(), path, "t", _ENV)
end

table.insert(package.loaders, onlineRequire)

local function resolveFuture(future)
    repeat
        future.poll()
        write(".")
        sleep(0.1)
    until future.isAvailable()
end

local function resolveDeps(future)
    print()
    write("Resolving dependencies")

    resolveFuture(future)

    print(" Done.")

    local result = future.result()

    if next(result.errors) then
        for _, err in ipairs(result.errors) do
            print(err)
        end

        error()
    end

    return result
end

local function doTrsact(installing, single, multiple, result)

    local trsact = result.transaction

    print()

    write("You are about to ")
    if installing then
        write("install")
    else
        write("remove")
    end
    write(" the following ")
    if #trsact.actions() > 1 then
        write(multiple)
    else
        write(single)
    end
    print(":")

    for _, item in ipairs(trsact.actions()) do
        local name = item.identifier or item.name
        print("- "..name)
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
            write("Deleting "..n.." ")
        else
            write("Installing "..n.." ")
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
            write("Removing "..name.."...")
        else
            write("Installing "..name.."...")
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

    trsact.setHandlers({ beforeAll = beforeAll, before = before, afterAll = afterAll, after = after })

    local ok, errors = trsact.apply()

    if not ok then
        print("Errors:")
        for _, err in ipairs(errors) do
            print(err.error)
        end

        error()
    end
end

local ccpm = require("ccpm")

local future = ccpm.repository.add("Deleranax/ccpm")

local result = resolveDeps(future)

doTrsact(true, "repository", "repositories", result)

write("Building index")

resolveFuture(ccpm.package.buildIndex())

print(" Done.")

future = ccpm.package.add("ccpm")

result = resolveDeps(future)

doTrsact(true, "package", "packages", result)

future = ccpm.package.remove("tamed")

result = resolveDeps(future)

doTrsact(false, "package", "packages", result)