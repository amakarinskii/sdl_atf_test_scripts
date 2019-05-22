local commonRC = require('test_scripts/RC/commonRC')
local actions = require("user_modules/sequences/actions")
local hmi_values = require("user_modules/hmi_values")
local utils = require("user_modules/utils") -- testing purposes

local common = {}

common.registerAppWOPTU = actions.app.registerNoPTU
common.activateApp = actions.app.activate
common.allModules = commonRC.allModules
common.DEFAULT = commonRC.DEFAULT
common.getMobileSession = actions.getMobileSession

function common.buildHmiRcCapabilities(pCapabilities)
  local hmiCapabilities
  if pCapabilities then
    hmiCapabilities = commonRC.buildHmiRcCapabilities(pCapabilities)
    return hmiCapabilities
  end
end

function common.getRcCapabilities()
    local hmiCapabilities = hmi_values.getDefaultHMITable()
    local hmiRcCapabilities = hmiCapabilities.RC.GetCapabilities.params.remoteControlCapability
    local rcCapabilities = {}
    for moduleType, capabilitiesParamName in pairs(commonRC.capMap) do
        rcCapabilities[moduleType] = hmiRcCapabilities[capabilitiesParamName]
    end
    return rcCapabilities
end

function common.backupHMICapabilities()
  commonRC.backupHMICapabilities()
end

function common.restoreHMICapabilities()
  commonRC.restoreHMICapabilities()
end

function common.updateDefaultCapabilities(pDisabledModuleTypes)
  if pDisabledModuleTypes then
    commonRC.updateDefaultCapabilities(pDisabledModuleTypes)
  end
end

function common.preconditions()
  commonRC.preconditions(isPreloadedUpdate, pCountOfRCApps)
end

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

-- local function restorePreloadedPT()
--   local preloadedFile = commonFunctions:read_parameter_from_smart_device_link_ini("PreloadedPT")
--   commonPreconditions:RestoreFile(preloadedFile)
-- end

-- function common.postconditions()
--   actions.postconditions()
--   restorePreloadedPT()
-- end

function common.postconditions()
  commonRC.postconditions()
end

return common
