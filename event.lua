--[[
	utrain
	Events

	Module:
		Returns a function that will construct a new event.

	Events' functions:
		[listener] connect([function] callback)
			Creates a new listener with the callback. Returns the listener.

		[array or nil] wait()
			Yields the current thread until the event is fired.
			It will return any values passed from :fire() as an array.
			If there is none, it will return nil.

		[nil] fire(...)
			Calls the callback of all of the listeners. It will pass the argument
			given to fire to them directly. The callbacks are ran asynchronously.

		[nil] disable()
			Disables the event from being used. It will automatically disconnect any
			listeners. Additionally, any functions called besides "isDisabled" will error.

		[boolean] isDisabled()
			Returns true if the event is disabled.

	Listeners' functions:
		[nil] disconnect()
			Disconnects the listener from the event.

		[boolean] isDisconnected()
			Returns true if the event was disconnected.
]]

local function insertInGap(list, value)
	local function helper(oldKey)
		local newKey = next(list, oldKey)
		oldKey = oldKey or 0

		if newKey == nil then list[oldKey + 1] = value return oldKey + 1 end
		if type(newKey) ~= "number" then error("Got a mixed table or dictionary as argument #1 (expected array).") end
		if newKey - 1 ~= oldKey then list[newKey - 1] = value return newKey - 1 end

		return helper(newKey)
	end

	return helper()
end

return function()
	local listeners = {}
	local disabled = false

	local interface = {}

	interface.connect = function(callback)
		if disabled then error("Cannot connect to a disabled event.", 2) end
		local listener = {}

		local listernerDisconnected = false
		local location = insertInGap(listeners, listener)

		listener.callback = callback

		listener.disconnect = function()
			if listernerDisconnected then error("Cannot disconnect a disconnected listener", 2) end

			listernerDisconnected = true
			listeners[location] = nil
		end

		listener.isDisabled = function()
			return listernerDisconnected
		end

		return listener
	end

	interface.wait = function()
		if disabled then error("Cannot wait for a disabled event.", 2) end

		local thread = coroutine.running()

		local returnArgs
		local waitListener
		waitListener = interface.connect(function(...)
			if ... ~= nil then returnArgs = {...} end
			waitListener.disconnect()

			local status = coroutine.status(thread)
			if status == "suspended" then
				coroutine.resume(thread)
			else
				print("WARNING: had callback to resume corountine."
				.." However, corountine's status was "..status..".")
			end
		end)

		coroutine.yield(thread)
		return returnArgs
	end

	interface.fire = function(...)
		if disabled then error("Cannot fire a disabled event.", 2) end

		for _, listener in next, listeners do
			coroutine.wrap(listener.callback)(...)
		end
	end

	interface.disable = function()
		if disabled then error("Cannot disable a disabled event.", 2) end

		disabled = true

		for _, listener in next, listeners do
			listener.disconnect()
		end
	end

	interface.isDisabled = function()
		return disabled
	end

	return interface
end