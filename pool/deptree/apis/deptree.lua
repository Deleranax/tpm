-- DepTree library
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

local deptree = {}

--- Construct a new dependency resolver, that explores the dependency tree (using DFS) and resolves all the
--- dependencies from a root node.
---
--- The 'getter' function must handle names that matches multiple nodes (e.g. by requiring user input). It must also
--- handle unknown nodes (by returning empty table if the resolution should continue, nil if it must complete
--- immediately). The result of this function is cached by the resolver.
---
--- @param initialNodes table List of initial nodes' names.
--- @param getter function Dependencies getter, accepting a name and returning a list of names (string).
--- @param ignore function Node ignore (or nil if none should be ignored), accepting a name and returning a boolean (true if the node should be ignored, false otherwise).
--- @param addInitialNodes boolean Include initial nodes in the dependencies (true if they should be included, false otherwise)
--- @return table Resolver object.
function deptree.Resolver(initialNodes, getter, ignore, addInitialNodes)
    local Resolver = {}

    ignore = ignore or function(_) return false end

    local getter_cache = {} -- Getter function results
    local new_deps = initialNodes -- Dependencies to be resolved
    local pool = {} -- Resolved dependencies

    if addInitialNodes then
        pool = initialNodes
    end

    --- @return boolean Resolver state (true if complete, false otherwise).
    function Resolver.hasCompleted()
        return next(new_deps) == nil
    end

    --- Copy to the current dependency pool. The pool maybe incomplete if the resolver has not completed yet.
    ---
    --- @return table The dependency pool.
    function Resolver.currentPool()
        local result = {}

        for _, elem in ipairs(pool) do
            table.insert(result, elem)
        end

        return result
    end

    --- Attempt to resolve the dependencies.
    ---
    --- The resolver needs to be repeatedly polled until complete. This means that you can cancel or pause the
    --- resolution process and check the current pool (e.g. to display information to the user).
    ---
    --- @return boolean, table Resolver state (true if complete, false otherwise), result (or nil).
    function Resolver.poll()
        if Resolver.hasCompleted() then
            return true, pool
        end

        local name = table.remove(new_deps) -- The current node name

        -- Ignore if the dependencies has already been evaluated
        if getter_cache[name] == nil and not ignore(name) then
            local deps = getter(name)

            -- Return immediately if the getter returns nil
            if deps == nil then
                new_deps = {}
                return true, Resolver.currentPool()
            else
                getter_cache[name] = true

                for _, elem in ipairs(deps) do
                    table.insert(new_deps, elem)
                    table.insert(pool, elem)
                end
            end
        end

        return false, nil
    end

    return Resolver
end

return deptree