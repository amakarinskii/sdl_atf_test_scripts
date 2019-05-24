---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0221-multiple-modules.md
-- Description:
--  In case if SDL receives from HMI "GetCapabilities" response, where HMI_SETTINGS module capabilities contain
-- "moduleInfo" with incorrect "serviceArea" mandatory parameter, SDL should send default HMI_SETTINGS module
-- capabilities in "GetSystemCapability" response to mobile
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) HMI sent HMI_SETTINGS module capabilities with "moduleInfo" containing incorrect "location"  mandatory parameter
--    to SDL
-- 3) Mobile is connected to SDL
-- 4) App is registered and activated
--
-- Steps:
-- 1) App sends "GetSystemCapability" request ("REMOTE_CONTROL")
--   Check:
--    SDL sends "GetSystemCapability" response with HMI_SETTINGS module capabilities containig "moduleInfo" with
--    "location" and "serviceArea" having only mandatory parameters to mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("test_scripts/RC/MultipleModules/commonRCMulModules")
local utils = require("user_modules/utils") -- testing purposes
common.tableToString = utils.tableToString  -- testing purposes

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local customModules = { "CLIMATE", "RADIO", "AUDIO", "SEAT", "LIGHT" }
local customHmiSettingsCapabilities = {
  moduleName = "HmiSettings Driver Seat",
  moduleInfo = {
    moduleId = "H0A",
      location    = { col = 0,        row = 0 },
      serviceArea = { col = "string", row = 0 },          --invalid value of "col"
  }
}
local capabilityParams = {
  HMI_SETTINGS = customHmiSettingsCapabilities
}
local defaultHmiSettingsCapabilities = common.getDefaultHmiCapabilitiesFromJson().hmiSettingsControlCapabilities

--[[ Local Functions ]]
local function sendGetSystemCapability()
  local cid = common.getMobileSession():SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  common.getMobileSession():ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = {
      remoteControlCapability = {
        hmiSettingsControlCapabilities = defaultHmiSettingsCapabilities
      }
    }
  })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Backup HMI capabilities file", common.backupHMICapabilities)
runner.Step("Update HMI capabilities file", common.updateDefaultCapabilities, { customModules })
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start, { capabilityParams })
runner.Step("RAI", common.registerAppWOPTU)
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
runner.Step("GetSystemCapability Positive Case", sendGetSystemCapability)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
runner.Step("Restore HMI capabilities file", common.restoreHMICapabilities)
