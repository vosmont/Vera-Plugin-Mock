
-- ------------------------------------------------------------
-- Mock for local testing outside of Vera
-- ------------------------------------------------------------
-- Implements main core functions
-- See MicasaVerde wiki for more description
-- http://wiki.micasaverde.com/index.php/Luup_Lua_extensions
-- ------------------------------------------------------------
-- Homepage : https://github.com/vosmont/Vera-Plugin-Mock
-- ------------------------------------------------------------
-- Changelog :
-- 0.0.7 Add "luup.call_timer"
-- 0.0.6 Add some service actions
--       Add response callback for luup.inet.wget
--       Add threadId and timestamps in log
--       Add reset threads
-- 0.0.5 Add LUA interpreter version verification
--       Add some new reset functions
--       Add last update on "luup.variable_get"
--       Use json.lua
-- 0.0.4 Add verbosity level
--       Fix a bug on no handling of error in threads
--       Convert value in String in luup.variable_set
-- 0.0.3 Fix a bug on "luup.variable_set" with trigger and moduleId
--       Fix a bug on "VeraMock.run" with moduleId
-- 0.0.2 Add log level and some logs
--       Add "luup.inet.wget" and url management
--       Add action management
--       Fix a bug on "VeraMock.run" and add threadId
-- 0.0.1 First release
-- ------------------------------------------------------------

print("")
print("[VeraMock] LUA interpreter: " .. _VERSION)
assert(_VERSION == "Lua 5.1", "Vera LUA core is in version 5.1")
print("")

local json = require("json")

local VeraMock = {
	_DESCRIPTION = "Mock for local testing outside of Vera",
	_VERSION = "0.0.6",
	verbosity = 0
}

-- *****************************************************
-- Vera core
-- *****************************************************

local _threads = {}
local _threadLastId = 0
local _threadCurrentId = 0
local _triggers = {}
local _values = {}
local _lastUpdates = {}
local _services = {}
local _actions = {}
local _urls = {}
local _startTime = os.time()

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
			--VeraMock:log("ERROR \027[00;31m" .. x .. "\027[00m")
			VeraMock:log("ERROR " .. x, 1)
		elseif level == 2 then
			VeraMock:log("WARN  " .. x, 2)
		else
			VeraMock:log("INFO  " .. x, 3)
		end
	end

	luup.task = function (message, status, description, handle)
		VeraMock:log("CORE  [luup.task] Module: '" .. description .. "' - State: '" .. message .. "' - Status: " .. status, 1)
		return 1
	end

	luup.call_delay = function (function_name, seconds, data, thread)
		if (_G[function_name] == nil) then
			VeraMock:log("CORE  [luup.call_delay] Callback doesn't exist", 1)
			return false
		end
		VeraMock:log("CORE  [luup.call_delay] Call function '" .. function_name .. "' in " .. tostring(seconds) .. " seconds with parameter '" .. tostring(data) .. "'", 4)
		_threadLastId = _threadLastId + 1
		local threadId = _threadLastId
		local newThread = coroutine.create(
			function (t0, function_name, seconds, data)
				while (os.clock() - t0 < seconds) do
					coroutine.yield(t0, function_name, seconds, data)
				end
				_threadCurrentId = threadId
				VeraMock:log("CORE  [luup.call_delay] Delay of " .. tostring(seconds) .. " seconds is reached: call function '" .. function_name .. "' with parameter '" .. tostring(data) .. "'", 4)
				_G[function_name](data)
				_threadCurrentId = 0
				VeraMock:log("CORE  <------- Thread #" .. tostring(threadId) .. " finished", 4)
				return false
			end
		)
		-- Start new thread
		table.insert(_threads, {id=threadId , co=newThread})
		VeraMock:log("CORE  -------> Thread #" .. tostring(threadId) .. " created", 4)
		coroutine.resume(newThread, os.clock(), function_name, seconds, data)
		return true
	end

	luup.call_timer = function (function_name, timer_type, time, days, data)
		local path = build_path(timer_type, time, days)
		if (_triggers[path] == nil) then
			_triggers[path] = {}
		end
		VeraMock:log("CORE  [luup.call_timer] Register timer" ..
								" - type:'" .. tostring(timer_type) .. "'" .. 
								" - time:'" .. tostring(time) .. "'" ..
								" - days:'" ..  tostring(days) .. "'" ..
								" - data:'" .. tostring(data) .. "'" ..
								" - callback function:'" .. function_name .. "'", 4)
		if (type(_G[function_name]) == "function") then
			table.insert(_triggers[path], wrapAnonymousCallback(function ()
				VeraMock:log("CORE  [luup.call_timer] Call '" .. function_name .. "' with data '" .. data .. "'", 1)
				_G[function_name](data)
			end))
		else
			VeraMock:log("CORE  [luup.call_timer] '" .. function_name .. "' is not a function", 1)
		end
	end

	luup.is_ready = function (device)
		VeraMock:log("CORE  [luup.is_ready] device #" .. tostring(device) .. "-'" .. get_device_name(device) .. "' is ready", 4)
		return true
	end

	luup.call_action = function (service, action, arguments, device)
		VeraMock:log("CORE  [luup.call_action] device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "'" .. 
											" - service:'" .. service .. "'" ..
											" - action:'" ..  action .. "'" ..
											" - arguments:'" .. json.encode(arguments) .. "'", 4)
		local callback = _actions[build_path(service, action)]
		if (callback ~= nil) then
			local res
			if (type(callback) == "function") then
				res = callback(arguments, device)
			elseif (type(callback) == "string") then
				res = _G[callback](arguments, device)
			end
			return 0, "", 0, res
		else
			return -1, "Action not found"
		end
	end

	luup.variable_get = function (service, variable, device)
		local path = build_path(service, variable, device)
		local value = _values[path]
		local lastUpdate = _lastUpdates[path] or 0
		VeraMock:log("CORE  [luup.variable_get] device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "'" ..
											" - service:'" .. service .. "'" ..
											" - variable:'" ..  variable .. "'" ..
											" - value:'" .. tostring(value) .. "'", 4)
		return value, lastUpdate
	end

	luup.variable_set = function (service, variable, value, device)
		local path = build_path(service, variable, device)
		local oldValue = _values[path]
		value = tostring(value) -- In Vera, values are always String
		_values[path] = value
		_lastUpdates[path] = os.time()
		_services[build_path(service, device)] = true
		VeraMock:log("CORE  [luup.variable_set] device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "'" .. 
											" - service:'" .. service .. "'" ..
											" - variable:'" ..  variable .. "'" ..
											" - value:'" .. tostring(oldValue) .. "' => '" .. tostring(value) .. "'", 4)
		-- triggers
		local triggers = _triggers[path]
		if (triggers ~= nil) then
			for i, function_name in ipairs(triggers) do
				VeraMock:log("CORE  [luup.variable_set] Call watcher function '" .. function_name .. "'", 4)
				_G[function_name](device, service, variable, oldValue, value)
			end
		end
	end

	luup.variable_watch = function (function_name, service, variable, device)
		local path = build_path(service, variable, device)
		if (_triggers[path] == nil) then
			_triggers[path] = {}
		end
		VeraMock:log("CORE  [luup.variable_watch] Register watch" ..
								" - device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "'" .. 
								" - service:'" .. service .. "'" ..
								" - variable:'" ..  variable .. "'" ..
								" - callback function:'" .. function_name .. "'", 4)
		if (type(_G[function_name]) == "function") then
			table.insert(_triggers[path], function_name)
		else
			VeraMock:log("CORE  [luup.variable_watch] '" .. function_name .. "' is not a function", 1)
		end
	end

	luup.device_supports_service = function (service, device)
		if (_services[build_path(service, device)]) then
			VeraMock:log("CORE  [luup.device_supports_service] Device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "' supports service '" .. service .. "'", 4)
			return true
		else
			VeraMock:log("CORE  [luup.device_supports_service] Device:#" .. tostring(device) .. "-'" .. get_device_name(device) .. "' doesn't support service '" .. service .. "'", 4)
			return false
		end
	end

	luup.inet = {
		wget = function (url, timeout, username, password)
			local requestUrl = ""
			local i = url:find("?")
			if (i ~= nil) then
				requestUrl = url:sub(i + 1)
				url = url:sub(1, i - 1)
			end
			local response = _urls[url]
			if (response ~= nil) then
				if (type(response) == "function") then
					VeraMock:log("CORE  [luup.inet.wget] url '" .. url .. " is ready. Call function with requestUrl '" .. requestUrl .. "'", 4)
					return response(requestUrl)
				else
					VeraMock:log("CORE  [luup.inet.wget] url '" .. url .. " is ready", 4)
					return 0, response
				end
			else
				VeraMock:log("CORE  [luup.inet.wget] url '" .. url .. " is unknown", 4)
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

	-- Init
	function VeraMock:init (lul_device)
		luup.lul_device = lul_device
		luup.variable_set( "", "id", lul_device, lul_device)
	end

	-- Add a device
	function VeraMock:addDevice (id, device, acceptDuplicates)
		if (type(id) == "table") then
			-- The device ID is not passed
			device = id
			local isFound = false
			if not acceptDuplicates then
				for i, existingDevice in ipairs(luup.devices) do
					if (existingDevice.description == device.description) then
						isFound = true
						id = i
					end
				end
			end
			if not isFound then
				id = table.getn(luup.devices) + 1
			end
		end
		assert("table" == type(device), "The device is not defined")
		if (device.description == nil) then
			device.description = "not defined"
		end
		if (self.verbosity >= 1) then
			print("[VeraMock:addDevice] Add device #" .. tostring(id) .. "-'" .. tostring(device.description) .. "'")
		end
		luup.devices[id] = device
	end

	-- Add a room
	function VeraMock:addRoom (id, room)
		if (self.verbosity >= 1) then
			print("[VeraMock:addRoom] Add room #" .. tostring(id) .. "-'" .. tostring(room.name) .. "'")
		end
		luup.rooms[id] = room
	end

	-- Add an action
	function VeraMock:addAction (service, action, callback)
		if (self.verbosity >= 1) then
			print("[VeraMock:addAction] Service '" .. service .. "' - Add action '" .. action .. "'")
		end
		_actions[build_path(service, action)] = callback
	end

	-- Add an URL
	function VeraMock:addUrl (url, response)
		if (self.verbosity >= 1) then
			print("[VeraMock:addUrl] Add URL '" .. url .. "'")
		end
		_urls[url] = response
	end

	-- Sets the verbosity level
	function VeraMock:setVerbosity (lvl)
		self.verbosity = lvl or 0
		assert("number" == type(self.verbosity), ("bad argument #1 to 'setVerbosity' (number expected, got %s)"):format(type(self.verbosity)))
	end

	-- Log message depending verbosity level
	function VeraMock:log (message, lvl)
		assert("string" == type(message))
		lvl = lvl or 1
		if (self.verbosity >= lvl) then
			local elapsedTime = os.difftime(os.time() - _startTime)
			local formatedTime = string.format("%02d:%02d", math.floor(elapsedTime / 60), (elapsedTime % 60))
			local formatedThreadId = string.format("%03d", _threadCurrentId)
			print("[VeraMock] " .. formatedThreadId .. "-" .. formatedTime .. "-" .. message)
		end
	end

	-- Run until all triggers are launched
	function VeraMock:run ()
		self:log("BEGIN - Run until all triggers are launched", 1)
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
					if (res ~="cannot resume dead coroutine") then
						-- Thread finished in error
						self:log(res, 1)
						error(res)
					end
					break
				end
			end
		end
		self:log("END - Run is done", 1)
		assert(table.getn(_threads) == 0, "ERROR - At least one thread remain")
	end

	-- Reset device values
	function VeraMock:resetValues ()
		self:log("Reset device values", 1)
		_values = {}
		_lastUpdates = {}
	end

	-- Reset triggers
	function VeraMock:resetTriggers ()
		self:log("Reset triggers", 1)
		_triggers = {}
	end

	-- Reset mock
	function VeraMock:reset ()
		_startTime = os.time()
		self:log("Reset VeraMock", 1)
		self:resetValues()
		self:resetTriggers()
		_threadLastId = 0
		_threadCurrentId = 0
		if (table.getn(_threads) > 0) then
			self:log("WARNING - " .. tostring(table.getn(_threads)) .. " thread(s) remain from previous run", 1)
			self:log("Reset threads", 1)
			_threads = {}
		end
	end

	-- Trigger timer
	function VeraMock:triggerTimer (timerType, time, days)
		local path = build_path(timerType, time, days)
		-- Triggers linked to this timer
		local triggers = _triggers[path]
		if (triggers ~= nil) then
			for i, function_name in ipairs(triggers) do
				self:log("triggerTimer - Call watcher function '" .. function_name .. "'", 50)
				local watcherFunction = _G[function_name]
				if (type(watcherFunction) == "function") then
					watcherFunction(data)
				else
					luup.log("triggerTimer - '" .. function_name .. "' is not a function", 2)
				end
			end
		else
			luup.log("No callback linked to this event", 1)
		end
	end

-- *****************************************************
-- Initialisations
-- *****************************************************

-- SwitchPower action
local SID_SwitchPower = "urn:upnp-org:serviceId:SwitchPower1"
VeraMock:addAction(
	SID_SwitchPower, "SetTarget",
	function (arguments, device)
		luup.variable_set(SID_SwitchPower, "Status", arguments.NewTarget, device)
	end
)

-- Multiswitch actions
local SID_MultiSwitch = "urn:dcineco-com:serviceId:MSwitch1"
local function setMultiswitchStatus(arguments, device)
	for key, status in pairs(arguments) do
		local buttonId = tonumber(string.match(key, "%d+"))
		luup.variable_set(SID_MultiSwitch, "Status" .. buttonId, status, device)
	end
end
VeraMock:addAction(SID_MultiSwitch, "SetStatus1", setMultiswitchStatus)
VeraMock:addAction(SID_MultiSwitch, "SetStatus2", setMultiswitchStatus)
VeraMock:addAction(SID_MultiSwitch, "SetStatus3", setMultiswitchStatus)
VeraMock:addAction(SID_MultiSwitch, "SetStatus4", setMultiswitchStatus)
VeraMock:addAction(SID_MultiSwitch, "SetStatus5", setMultiswitchStatus)
VeraMock:addAction(SID_MultiSwitch, "SetStatus6", setMultiswitchStatus)
VeraMock:addAction(SID_MultiSwitch, "SetStatus7", setMultiswitchStatus)
VeraMock:addAction(SID_MultiSwitch, "SetStatus8", setMultiswitchStatus)

VeraMock:setVerbosity(1)

return VeraMock
