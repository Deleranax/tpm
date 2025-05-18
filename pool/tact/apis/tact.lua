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

--- Construct an Action object, that contains data, a confirm and cancel functions.
---
--- @param data any Action data.
--- @param apply function Application function, accepting the data (any) and returning anything (will be discarded).
--- @param rollback function Rollback function, accepting the data (any) and returning anything (will be discarded).
--- @return table Action object.
function tact.Action(data, apply, rollback)
    apply = apply or function(_) end
    rollback = rollback or function(_) end

    return {
        data = data,
        confirm = function() apply(data) end,
        cancel = rollback or function() rollback(data) end
    }
end

--- Create a new transaction object that stores a list of actions to be executed atomically.
---
--- A transaction can be applied by calling apply (which call the apply function of each action). If errors are raised
--- during the application, the transaction can be rolled back by calling rollback (which execute the rollback function
--- of each action).
---
--- @param actions table Array of Actions.
--- @param eventHandlers table Table of function to be executed when an event occurs.
--- @return table Transaction object.
function tact.Transaction(actions, eventHandlers)
    local Transaction = {}

    local errors = {}

    --- Set the event handlers.
    ---
    --- The 'handlers' table stores functions to be called when an event occurs. The functions must be stored with the
    --- key corresponding to the event name. It must accept the arguments as specified in the event list. The 'rollback'
    --- argument is a boolean indicating if the actions are rolled back. The events are:
    --- - beforeAll(rollback, n): Fired just before all n actions are applied or rolled back.
    --- - afterAll(rollback, n): Fired just after all n actions are applied or rolled back.
    --- - before(rollback, i, action): Fired before action number i is applied or rolled back.
    --- - after(rollback, i, action): Fired after action number i is applied or rolled back.
    ---
    --- @param handlers table Table of function to be executed when an event occurs.
    function Transaction.setHandlers(handlers)
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

    --- Execute all actions.
    ---
    --- @param rollback boolean Roll back state (true if the action should be rolled back, false or nil otherwise).
    function Transaction.execute(rollback)
        if rollback == nil then
            rollback = false
        end

        eventHandlers.beforeAll(rollback, table.getn(actions))

        for i, action in ipairs(actions) do
            eventHandlers.before(rollback, i, action)

            local fnc = action.apply

            if rollback then
                fnc = action.rollback
            end

            local ok, err = pcall(fnc)

            if not ok then
                table.insert(errors, { action = action, error = err })
            end

            eventHandlers.after(rollback, i, action)
        end

        eventHandlers.afterAll(false, table.getn(actions))
    end

    --- Apply transaction.
    ---
    --- @return table Array of tables containing an action and the error that was raised during the application.
    function Transaction.apply()
        errors = {}
        Transaction.execute(false)
        return errors
    end

    --- Roll back transaction.
    ---
    --- @return table Array of tables containing an action and the error that was raised during the roll back.
    function Transaction.rollback()
        errors = {}
        Transaction.execute(true)
        return errors
    end

    -- Set default handlers
    Transaction.setHandlers({})

    return Transaction
end

return tact