-- Transaction library
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

local tact = {}
local future = require("/apis/future")

--- Construct an Action object, that contains data, a confirm and cancel functions.
---
--- @param data any Action data.
--- @param confirm function Confirmation function, accepting the data (any) and returning anything (will be discarded).
--- @param cancel function Confirmation function, accepting the data (any) and returning anything (will be discarded).
--- @return table Action object.
function tact.Action(data, confirm, cancel)
    confirm = confirm or function(_) end
    cancel = cancel or function(_) end

    return {
        data = data,
        confirm = function() confirm(data) end,
        cancel = cancel or function() cancel(data) end
    }
end

--- Create a new transaction object that stores a list of actions to be executed atomically.
---
--- @param actions table Array of Actions.
--- @return table Transaction object.
function tact.Transaction(actions)
    local Transaction = {}

    local eventHandlers = {}

    --- Set the event handlers.
    ---
    --- The 'handlers' table stores functions to be executed when an event occurs. The functions must be stored with the key
    --- corresponding to the event name. It must accept the arguments as specified in the event list. The 'cancel' argument
    --- is a boolean indicating if the actions are cancelled. The events are:
    --- - beforeAll(cancel, n): Fired just before all n actions are confirmed or cancelled.
    --- - afterAll(cancel, n): Fired just after all n actions are confirmed or cancelled.
    --- - before(cancel, i, action): Fired before action number i is confirmed or cancelled.
    --- - after(cancel, i, action): Fired after action number i is confirmed or cancelled.
    ---
    --- @param handlers table Table of function to be executed when an event occurs.
    function Transaction.setHandler(handlers)
        eventHandlers.beforeAll = handlers.beforeAll or eventHandlers.beforeAll or function(_, _) end
        eventHandlers.afterAll = handlers.afterAll or eventHandlers.afterAll or function(_, _) end
        eventHandlers.before = handlers.before or eventHandlers.before or function(_, _, _) end
        eventHandlers.after = handlers.after or eventHandlers.after or function(_, _, _) end
    end

    --- Get all actions data.
    ---
    --- @return table Array of all actions' data.
    function Transaction.actions()
        local result = {}

        for _, elem in ipairs(actions) do
            table.insert(result, elem.data)
        end

        return result
    end

    --- Confirm all actions.
    function Transaction.execute(cancel)
        if cancel == nil then
            cancel = false
        end

        eventHandlers.beforeAll(cancel, table.getn(actions))

        for i, action in ipairs(actions) do
            eventHandlers.before(cancel, i, action)

            if cancel then
                action.cancel()
            else
                action.confirm()
            end

            eventHandlers.after(cancel, i, action)
        end

        eventHandlers.afterAll(false, table.getn(actions))
    end

    --- Confirm transaction.
    function Transaction.confirm()
        Transaction.execute(false)
    end

    --- Cancel transaction.
    function Transaction.cancel()
        Transaction.execute(true)
    end

    -- Set default handlers
    Transaction.setHandler({})

    return Transaction
end

--- Construct a future that will eventually return a transaction and a list of errors, with all the actions and errors that 'actionFactory' created.
---
--- @param actionFactory function Action factory, accepting nothing and returning true, a list of Actions and a list of errors (string) (or false, nil and nil if no Action can be created anymore).
function tact.FutureTransaction(actionFactory)
    if actionFactory == nil then
        error("attempt to create a FutureTransaction with a nil factory")
    end

    local actions = {}
    local errors = {}

    local function poll()
        local status, n_actions, n_errors = actionFactory()
        if status then
            for _, elem in ipairs(n_actions) do
                table.insert(actions, elem)
            end

            for _, elem in ipairs(n_errors) do
                table.insert(errors, elem)
            end

            return false
        else
            return true, { transaction = tact.Transaction(actions), errors = errors }
        end
    end

    return future.Future(poll)
end

return tact