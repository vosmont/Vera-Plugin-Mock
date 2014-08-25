
-- ------------------------------------------------------------
-- Mock for local testing outside of Vera
-- ------------------------------------------------------------
-- Implements main core functions
-- See MicasaVerde wiki for more description
-- http://wiki.micasaverde.com/index.php/Luup_Lua_extensions
-- ------------------------------------------------------------
-- Changelog :
-- 0.0.3 Fix a bug on "luup.variable_set" with trigger and moduleId
--       Fix a bug on "VeraMock.run" with moduleId
-- 0.0.2 Add log level and some logs
--       Add "luup.inet.wget" and url management
--       Add action management
--       Fix a bug on "VeraMock.run" and add threadId
-- 0.0.1 First release
-- ------------------------------------------------------------

local VeraMock = {
	_DESCRIPTION = "Mock for local testing outside of Vera",
	_VERSION = "0.0.3"
}

-- *****************************************************
-- Vera core
-- *****************************************************

local _threads = {}
local _threadLastId = 0
local _triggers = {}
local _values = {}
local _services = {}
local _actions = {}
local _urls = {}

local function build_path (...)
	local path = ""
	--for i,v in ipairs(arg) do
	for i,v in ipairs({...}) do -- Lua 5.2
		path = path .. (i > 1 and ";" or "") .. tostring(v)
	end
	return path
end

local function get_device_name (deviceId)
	if (luup.devices[deviceId] == nil) then 
		return ""
	end
	local name = luup.devices[deviceId].description
	if (name ~= nil) then
		return name
	else
		return ""
	end
end

local luup = {
	version_branch = 1,
	version_major = 5,
	version_minor = 408,

	longitude = 2.294476,
	latitude = 48.858246,

	--devices = {["99"]={description="Dummy"}},
	devices = {},
	rooms = {}
 }

luup.log = function (x, level)
	if level == 1 then
		--print("ERROR \027[00;31m" .. x .. "\027[00m")
		print("ERROR " .. x)
	elseif level == 2 then
		print("WARN  " .. x)
	else
		print("INFO  " .. x)
	end
end

luup.task = function (message, status, description, handle)
	print("CORE  [luup.task] Task: " .. message .. " " .. status)
	return 1
end

luup.call_delay = function (function_name, seconds, data, thread)
	if (_G[function_name] == nil) then
		print("CORE  [luup.call_delay] Callback doesn't exist", 1)
		return false
	end
	print("CORE  [luup.call_delay] Call function '" .. function_name .. "' in " .. tostring(seconds) .. " seconds")
	_threadLastId = _threadLastId + 1
	local threadId = _threadLastId
	local newThread = coroutine.create(
		function (t0, function_name, seconds, data)
			while (os.clock() - t0 < seconds) do
				coroutine.yield(t0, function_name, seconds, data)
			end
			print("CORE  [luup.call_delay] Delay of " .. tostring(seconds) .. " seconds is reached: call function '" .. function_name .. "'")
			_G[function_name](data)
			print("CORE  <------- End thread #" .. tostring(threadId))
			return false
		end
	)
	-- Start new thread
	table.insert(_threads, {id=threadId , co=newThread})
	print("CORE  -------> Begin new thread #" .. tostring(threadId))
	coroutine.resume(newThread, os.clock(), function_name, seconds, data)
	return true
end

luup.call_timer = function (function_name, type, time, days, data)
	print("CORE  [luup.call_timer] Not implemented.")
end

luup.is_ready = function (device)
	print("CORE  [luup.is_ready] device #" .. tostring(device) .. "-'" .. get_device_name(device) .. "' is ready.")
	return true
end

luup.call_action = function (service, action, arguments, device)
	print("CORE  [luup.call_action] device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "'" .. 
							" - service:'" .. service .. "'" ..
							" - action:'" ..  action .. "'" ..
							" - arguments:'" .. tostring(arguments) .. "'")
	local callback = _actions[build_path(service, action)]
	if (callback ~= nil) then
		local res
		if (type(callback) == "function") then
			res = callback( arguments,device)
		elseif (type(callback) == "string") then
			res = _G[callback](arguments, device)
		end
		return 0, "", 0, res
	else
		return -1, "Action not found"
	end
end

luup.variable_get = function (service, variable, device)
	local value = _values[build_path(service, variable, device)]
	print("CORE  [luup.variable_get] device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "'" ..
							" - service:'" .. service .. "'" ..
							" - variable:'" ..  variable .. "'" ..
							" - value:'" .. tostring(value) .. "'")
	return value
end;

luup.variable_set = function (service, variable, value, device)
	local path = build_path(service, variable, device)
	local oldValue = _values[path]
	_values[path] = value
	_services[build_path(service, device)] = true
	print("CORE  [luup.variable_set] device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "'" .. 
							" - service:'" .. service .. "'" ..
							" - variable:'" ..  variable .. "'" ..
							" - value:'" .. tostring(oldValue) .. "' => '" .. tostring(value) .. "'")
	-- triggers
	local triggers = _triggers[path]
	if (triggers ~= nil) then
		for i, function_name in ipairs(triggers) do
			print("CORE  [luup.variable_set] Call watcher function '" .. function_name .. "'")
			if (type(_G[function_name]) == "function") then
				_G[function_name](device, service, variable, oldValue, value)
			else
				luup.log("CORE  [luup.variable_set] '" .. function_name .. "' is not a function", 1)
			end
		end
	end
end

luup.variable_watch = function (function_name, service, variable, device)
	local path = build_path(service, variable, device)
	if (_triggers[path] == nil) then
		_triggers[path] = {}
	end
	print("CORE  [luup.variable_watch] Register watch - device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "'" .. 
							" - service:'" .. service .. "'" ..
							" - variable:'" ..  variable .. "'" ..
							" - callback function:'" .. function_name .. "'")
	table.insert(_triggers[path], function_name)
end

luup.device_supports_service = function (service, device)
	if (_services[build_path(service, device)]) then
		print("CORE  [luup.device_supports_service] Device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "' supports service '" .. service .. "'")
		return true
	else
		print("CORE  [luup.device_supports_service] Device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "' doesn't support service '" .. service .. "'")
		return false
	end
end

luup.inet = {
	wget = function (url, timeout, username, password)
		if (_urls[url] ~= nil) then
			print("CORE  [luup.inet.wget] url '" .. url .. " is ready.")
			return 0, _urls[url]
		else
			print("CORE  [luup.inet.wget] url '" .. url .. " is unknown.")
			return 404, "Not found"
		end
	end
}

_G.luup = luup

-- *****************************************************
-- Tools
-- *****************************************************

local _callbackIndex = 0

function wrapAnonymousCallback(callback)
	_callbackIndex = _callbackIndex + 1
	local callbackName = "anonymousCallback" .. tostring(_callbackIndex)
	_G[callbackName] = callback
	return callbackName
end

-- *****************************************************
-- VeraMock module
-- *****************************************************

VeraMock.init = function (lul_device)
	luup.lul_device = lul_device

	luup.variable_set( "", "id", lul_device, lul_device)
end

VeraMock.add_device = function (id, device)
	if (type(id) == "table") then
		-- The device ID is not passed
		device = id
		id = table.getn(luup.devices) + 1
	end
	luup.devices[id] = device
	luup.log("[VeraMock.add_device] Add device #" .. tostring(id) .. "-'" .. get_device_name(id) .. "'")
end

VeraMock.add_room = function (id, room)
	luup.rooms[id] = room
end

VeraMock.add_action = function (service, action, callback)
	_actions[build_path(service, action)] = callback
end

VeraMock.add_url = function (url, response)
	_urls[url] = response
end

VeraMock.run = function ()
	while true do
		local n = table.getn(_threads)
		if (n == 0) then
			-- No more threads to run
			break
		end
		for i = 1, n do
			local status, res = coroutine.resume(_threads[i].co)
			if not status then
				-- Thread finished its task
				table.remove(_threads, i)
				break
			end
		end
	end
end

VeraMock.resetValues = function ()
	_values = {}
end

return VeraMock
