package.path = "../?.lua;" .. package.path

local VeraMock = require("core.vera")
require("lib.luaunit")

-- Devices initialisation
VeraMock.add_device(1, {description="Device1"})
VeraMock.add_device(2, {description="Device2"})
VeraMock.add_device(4, {description="Device3"}) 

TestCoreVera = {}

	function TestCoreVera:setUp()
		--print("==>")
	end

	function TestCoreVera:tearDown()
		--print("<==")
		print("")
	end

	-- ****************************************************************************************
	-- luup.device_supports_service
	-- ****************************************************************************************

	function TestCoreVera:test_device_supports_service_ok ()
		luup.variable_set("urn:upnp-org:serviceId:ServiceSupported", "Variable", "MyNewValue", 1)
		assertEquals(luup.device_supports_service("urn:upnp-org:serviceId:ServiceSupported", 1), true, "The device supports the service")
	end

	function TestCoreVera:test_device_supports_service_ko ()
		assertEquals(luup.device_supports_service("urn:upnp-org:serviceId:ServiceNotSupported", 1), false, "The device doesn't support the service")
	end

	-- ****************************************************************************************
	-- luup.variable_watch
	-- ****************************************************************************************

	function TestCoreVera:test_variable_watch()
		expect(3)
		VeraMock.resetValues()
		luup.variable_watch(
			wrapAnonymousCallback(function (lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
				assertEquals(lul_value_new, "MyNewValueDevice1", "Variable has changed for first device (first watcher)")
			end),
			"urn:upnp-org:serviceId:Service1", "Variable1", 1
		)
		luup.variable_watch(
			wrapAnonymousCallback(function (lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
				assertEquals(lul_value_new, "MyNewValueDevice1", "Variable has changed for first device (second watcher)")
			end),
			"urn:upnp-org:serviceId:Service1", "Variable1", 1
		)
		luup.variable_watch(
			wrapAnonymousCallback(function (lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
				assertEquals(lul_value_new, "MyNewValueDevice2", "Variable has changed for second device")
			end),
			"urn:upnp-org:serviceId:Service1", "Variable1", 2
		)
		luup.variable_set("urn:upnp-org:serviceId:Service1", "Variable1", "MyNewValueDevice1", 1)
		luup.variable_set("urn:upnp-org:serviceId:Service1", "Variable1", "MyNewValueDevice2", 2)
	end

	-- ****************************************************************************************
	-- luup.call_delay
	-- ****************************************************************************************

	function TestCoreVera:test_call_delay()
		expect(2)
		luup.call_delay(
			wrapAnonymousCallback(function (data)
				assertEquals(data, "myData1", "First function called correctly")
			end),
			2, "myData1"
		)
		luup.call_delay(
			wrapAnonymousCallback(function (data)
				assertEquals(data, "myData2", "Second function called correctly")
			end),
			1, "myData2"
		)
		VeraMock.run()
	end

	-- ****************************************************************************************
	-- luup.inet.wget
	-- ****************************************************************************************

	function TestCoreVera:test_inet_wget_ok()
		VeraMock.add_url("http://localhost/myUrl", "MyResponse")
		local res, response = luup.inet.wget("http://localhost/myUrl")
		assertEquals(res, 0, "The URL returns a response")
		assertEquals(response, "MyResponse", "The response is correct")
	end

	function TestCoreVera:test_inet_wget_ko()
		local res, response = luup.inet.wget("http://localhost/unknownUrl")
		assertEquals(res, 404, "The URL is not found")
		assertEquals(response, "Not found", "The error message is correct")
	end

	-- ****************************************************************************************
	-- luup.call_action
	-- ****************************************************************************************

	function TestCoreVera:test_call_action_ok()
		VeraMock.add_action(
			"urn:upnp-org:serviceId:Service1", "Action1",
			function (arguments, device)
				if (arguments.newValue ~= nil) then
					luup.variable_set("urn:upnp-org:serviceId:Service1", "Variable2", arguments.newValue, device)
				end
			end
		)
		local error, error_msg = luup.call_action("urn:upnp-org:serviceId:Service1", "Action1", {newValue = "MyNewValue2"}, 1)
		assertEquals(error, 0, "The action is executed")
		assertEquals(luup.variable_get("urn:upnp-org:serviceId:Service1", "Variable2", 1), "MyNewValue2", "The action result is correct")
	end

	function TestCoreVera:test_call_action_ko()
		local error, error_msg = luup.call_action("urn:upnp-org:serviceId:Service1", "Action2", {newValue = "MyNewValue2"}, 1)
		assertEquals(error, -1, "The action is not executed")
		assertEquals(error_msg, "Action not found", "The error message is correct")
	end

-- run all tests
LuaUnit:run()
