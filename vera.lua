module("core.vera", package.seeall)
_VERSION = "0.0.1"
_COPYRIGHT = "Mark Watkins (C) 2013"

local function build_variable_path( service, variable)
	local path = ""
	if ( service ~= nil ) and ( service ~= "") then
		path = path .. service .. ":"
	end

	path = path .. variable
	return path
end


_G.luup = {

	version_branch = 1;
	version_major = 5;
	version_minor = 408;

	longitude = -0.12750;
	latitude = 51.50722;

	devices = {};

	variable_get = 		function( service, variable, device )
							return luup.devices[device][build_variable_path(service, variable)]
						end;

	variable_set = 		function( service, variable, value, device )
							if (luup.devices[device] == nil) then luup.devices[device] = {} end

							luup.devices[device][build_variable_path(service, variable)] = value
						end;

	log	=				function(x)
							print(x)
						end;
	task = 				function(message, status, description, handle)
							luup.log( "TASK: " .. message .. " " .. status)
						end;
	call_timer =		function( function_name, _type, _time, days, data )
						end;
}

function init(lul_device)
	luup.lul_device = lul_device

	luup.variable_set( "", "id", lul_device, lul_device)
end
