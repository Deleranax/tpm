local tpm = require("lib.tpm")

local function showUsage()
    print("Usage: ")
    print("tpm update")
    print("tpm upgrade [-force]")
    print("tpm list <installed/available>")
    print("tpm show <installed/available> <program>")
    print("tpm install <program> [-force]")
    print("tpm reinstall <program> [-force]")
    print("tpm remove <program> [-force]")
end

local function clean(force)
    local dependencies = {}

    local count = 0

    for k, v in pairs(tpm.getInstalledPackages()) do
        if v.dependencies then
            for i, v2 in ipairs(v.dependencies) do
                dependencies[v2] = true
            end
        else
            v.dependencies = {}
        end
    end

    for k, v in pairs(tpm.getInstalledPackages()) do
        if v.installedAsDependency and not dependencies[k] then
            print(k .. " will be removed.")
            if tpm.remove(k, force) then
                count = count + 1
            end
        end
    end

    if count ~= 0 then
        count = count + clean(force)
    end

    return count
end

local args = { ... }

if #args >= 1 then
    if args[1] == "help" then
        showUsage()
    elseif args[1] == "update" then
        tpm.updateDatabase()
        local outdated = false
        for k, v in pairs(tpm.getInstalledPackages()) do
            if (tpm.get(k) == nil) then
                print(k .. " is no longer available, or the package was renamed.")
            elseif v.version ~= tpm.get(k)["version"] then
                print(k .. " needs update (v" .. v.version .. " -> v" .. tpm.get(k)["version"] .. ")")
                outdated = true
            end
        end
        if outdated then
            print("To update packets, run 'tpm upgrade'.")
        end
    elseif args[1] == "upgrade" then
        local update = 0
        local installed = 0
        for k, v in pairs(tpm.getInstalledPackages()) do
            if (tpm.get(k) == nil) then
                print(k .. " is no longer available, skipping.")
            elseif v.version ~= tpm.get(k)["version"] then
                update = update + 1
                print("\nUpdating " .. k .. "...")
                tpm.remove(k, true)
                installed = installed + tpm.install(k, args[2] == "-force") - 1
            end
        end
        if update == 0 then
            print("All packages are up to date.")
            return
        end
        print(update .. " upgraded, " .. installed .. " newly installed.")
    elseif args[1] == "clean" then
        local count = clean(args[2] == "-force")
        if count == 0 then
            print("No useless packages detected.")
        else
            print(count .. " removed.")
        end
    elseif args[1] == "install" then
        if not args[2] then
            printError("Invalid command. Run 'tpm help' to show usage.")
            return
        end
        local installed = tpm.install(args[2], false, args[3] == "-force")
        print("0 upgraded, " .. installed .. " newly installed.")
    elseif args[1] == "reinstall" then
        if not args[2] then
            printError("Invalid command. Run 'tpm help' to show usage.")
            return
        end
        local installed = 0
        if tpm.remove(args[2], true) then
            installed = tpm.install(args[2], false, args[3] == "-force") - 1
        end
        print("0 upgraded, " .. installed .. " newly installed.")
    elseif args[1] == "remove" then
        if not args[2] then
            printError("Invalid command. Run 'tpm help' to show usage.")
            return
        end
        tpm.remove(args[2], args[3] == "-force")
        print("Use 'tpm clean' to clean any useless dependency.")
    elseif args[1] == "show" then
        local pack
        if not args[3] then
            printError("Invalid command. Run 'tpm help' to show usage.")
            return
        end
        if args[2] == "remote" then
            pack = tpm.getPackage(args[3])
        elseif args[2] == "local" then
            pack = tpm.getInstalled(args[3])
        else
            printError("Invalid command. Run 'tpm help' to show usage.")
            return
        end

        if not pack then
            return
        end

        print("\nPackage: " .. pack.name)
        print("Version: " .. pack.version)
        print("Maintainer: " .. pack.maintainer)
        print("CCPM-Source: " .. pack.url)

        if pack.dependencies then
            if #(pack.dependencies) ~= 0 then
                print("Dependencies:")
                print(table.concat(pack.dependencies, ", "))
            end
        else
            pack.dependencies = {}
        end

        if pack.installedAsDependency then
            print("The package is flagged as dependency.")
        end

    elseif args[1] == "list" then
        if args[2] == "local" then
            tpm.reloadDatabase()
            print("\nInstalled packages:")
            print(table.concat(tpm.getInstalledList(), ", "))
        elseif args[2] == "remote" then
            tpm.reloadDatabase()
            print("\nAvailable packages:")
            print(table.concat(tpm.getPackageList(), ", "))
        else
            printError("Invalid command. Run 'tpm help' to show usage.")
        end
    else
        printError("Invalid command. Run 'tpm help' to show usage.")
    end
else
    printError("Invalid command. Run 'tpm help' to show usage.")
end