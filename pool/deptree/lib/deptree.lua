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

local turfu = require("turfu")
local ctable = require("commons.table")
local util = require("commons.util")

--- Check if there is dependency constraint violation in a node pool.
---
--- The constraints are: All nodes' dependencies should be present AND all nodes must either be pinned or have dependent
--- nodes.
---
--- A node can be represented by anything as long as it's not nil, and that "getDependencies" and "isPinned" recognize
--- it.
---
--- The "getDependencies" function is responsible for handling the unknown nodes (as this function will be called with
--- every node in the tree). However, the function should always return a table, even if the node is unknown (returning
--- an empty table is fine).
---
--- @param pool table List of all the nodes in the tree.
--- @param getDependencies function Dependencies getter, accepting a node and returning its dependencies as a list of nodes.
--- @param isPinned function Predicate, accepting a node and returning true if it should be kept in the tree even when no other nodes depends on it.
--- @return table A turfu.Future object, eventually returning false if there is at least one constraint violation (true otherwise).
function deptree.check(pool, getDependencies, isPinned)

    local get = util.cacheFn(getDependencies)
    local pin = util.cacheFn(isPinned)

    local index
    local flag = true

    local function poll()
        local node

        if index < 1 then
            index = nil
        end

        index, node = next(pool, index)

        if index == nil then
            if flag then

                -- We finished to check the parents with missing children, we can now check orphans
                flag = false
            else

                -- We can return true
                return true, true
            end

            return false
        end

        -- We alternate between removing nodes with missing children and removing orphans
        if flag then

            -- Check the dependencies
            for _, dep in ipairs(get(node)) do

                -- Check if it is in the pool
                if not ctable.find(pool, dep) then

                    -- If one of the dependencies is missing, return false
                    return true, false
                end
            end
        else
            -- Check if it is pinned
            if not (pin(node)) then
                local hasParent = false

                -- Check all the nodes
                for _, par in ipairs(pool) do

                    -- Check if it has node as a dependency
                    if ctable.find(get(par), node) then
                        hasParent = true
                        break
                    end
                end

                if not hasParent then

                    -- If it is orphan, return false
                    return true, false
                end
            end
        end
    end

    return turfu.Future(poll)
end

--- Resolve dependency tree related constraint violations by addition in a node pool.
---
--- The constraints are: All nodes' dependencies should be present AND all nodes must either be pinned or have dependent
--- nodes.
---
--- A node can be represented by anything as long as it's not nil, and that "getDependencies" recognizes it.
---
--- The "getDependencies" function is responsible for handling the unknown nodes (as this function will be called with
--- every node in the tree). However, the function should always return a table, even if the node is unknown (returning
--- an empty table is fine).
---
--- @param brokenPool table List of all the nodes in the tree.
--- @param getDependencies function Dependencies getter, accepting a node and returning its dependencies as a list of nodes.
--- @return table A turfu.Future object, eventually returning a list of nodes to be added to resolve constraint violations.
function deptree.expand(brokenPool, getDependencies)

    local get = util.cacheFn(getDependencies)

    local queue = {}
    local pool = {}
    local additions = {}

    ctable.insertAll(queue, brokenPool)

    local function poll()
        local node = table.remove(queue)

        -- If it's the last, return
        if node == nil then
            return true, additions
        end

        -- Add it to the pool
        ctable.insertUnique(pool, node)

        -- Add the dependencies to the additions
        for _, dep in ipairs(get(node)) do

            -- Check if it's not already present in the pool
            if not ctable.find(pool, dep) then

                -- Add it to the additions
                table.insert(additions, dep)

                -- Add it to the queue (to check for dependencies)
                table.insert(queue, dep)
            end
        end

        return false
    end

    return turfu.Future(poll)
end

--- Resolve dependency tree related constraint violations by deletion in a node pool.
---
--- The constraints are: All nodes' dependencies should be present AND all nodes must either be pinned or have dependent
--- nodes.
---
--- A node can be represented by anything as long as it's not nil, and that "getDependencies" and "isPinned" recognize
--- it.
---
--- The "getDependencies" function is responsible for handling the unknown nodes (as this function will be called with
--- every node in the tree). However, the function should always return a table, even if the node is unknown (returning
--- an empty table is fine).
---
--- @param brokenPool table List of all the nodes in the tree.
--- @param getDependencies function Dependencies getter, accepting a node and returning its dependencies as a list of nodes.
--- @param isPinned function Predicate, accepting a node and returning true if it should be kept in the tree even when no other nodes depends on it.
--- @return table A turfu.Future object, eventually returning a list of nodes to be removed to resolve constraint violations.
function deptree.shrink(brokenPool, getDependencies, isPinned)

    local get = util.cacheFn(getDependencies)
    local pin = util.cacheFn(isPinned)

    local index
    local flag = true
    local changed = false
    local pool = {}
    local deletions = {}

    ctable.insertAll(pool, brokenPool)

    local function poll()
        local node

        if index < 1 then
            index = nil
        end

        index, node = next(pool, index)

        if index == nil then
            if flag then

                -- We finished to remove the parents with missing children, we can now remove orphans
                flag = false
            elseif not changed then

                -- If no changes were made, we can return
                return true, deletions
            else

                -- If changes were made, we repeat the whole process
                flag = true
                changed = false
            end

            return false
        end

        -- We alternate between removing nodes with missing children and removing orphans
        if flag then

            -- Check the dependencies
            for _, dep in ipairs(get(node)) do

                -- Check if it is in the pool
                if not ctable.find(pool, dep) then

                    -- If one of the dependencies is missing, remove the node
                    ctable.removeValue(pool, node)
                    table.insert(deletions, node)
                    index = index - 1
                    changed = true
                    break
                end
            end
        else
            -- Check if it is pinned
            if not (pin(node)) then
                local hasParent = false

                -- Check all the nodes
                for _, par in ipairs(pool) do

                    -- Check if it has node as a dependency
                    if ctable.find(get(par), node) then
                        hasParent = true
                        break
                    end
                end

                if not hasParent then

                    -- If it is orphan, remove then node
                    ctable.removeValue(pool, node)
                    table.insert(deletions, node)
                    index = index - 1
                    changed = true
                end
            end
        end
    end

    return turfu.Future(poll)
end

return deptree