package.path = "../?.lua;" .. package.path
local VeraMock = require("core.vera")

-- Declare your devices
VeraMock:addDevice(1, {description="Device1"})

-- ------------------------------------------------------
-- Begin of your script
-- ------------------------------------------------------

function myWatcherFunction(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	luup.log("New value for Device1 : " .. tostring(lul_value_new))
end

luup.variable_watch("myWatcherFunction", "urn:upnp-org:serviceId:Service1", "Variable1", 1)
 
luup.variable_set("urn:upnp-org:serviceId:Service1", "Variable1", "MyNewValue1", 1)

-- ------------------------------------------------------
-- End of your script
-- ------------------------------------------------------

-- Run the mock until all events are processed
VeraMock:run()
