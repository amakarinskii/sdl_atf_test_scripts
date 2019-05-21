local commonRC = require('test_scripts/RC/commonRC')
local actions = require("user_modules/sequences/actions")
local hmi_values = require("user_modules/hmi_values")

local common = {}

common.registerAppWOPTU = actions.app.registerNoPTU
common.activateApp = actions.app.activate

function common.getDefaultRcCapabilities()
	local hmiCapabilities = hmi_values.getDefaultHMITable()
	local hmiRcCapabilities = hmiCapabilities.RC.GetCapabilities.params.remoteControlCapability
	local rcCapabilities = {}
	for moduleType, capabilitiesParamName in pairs(commonRC.capMap) do
		rcCapabilities[moduleType] = hmiRcCapabilities[capabilitiesParamName]
	end
	return rcCapabilities
end

function common.start(pRcCapabilities)
	local hmiCapabilities
	if pRcCapabilities then
		hmiCapabilities = commonRC.buildHmiRcCapabilities(pRcCapabilities)
	end
	return actions.start(hmiCapabilities)
end

return common
