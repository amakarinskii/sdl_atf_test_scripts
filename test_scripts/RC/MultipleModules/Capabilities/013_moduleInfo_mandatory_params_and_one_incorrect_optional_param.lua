---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0221-multiple-modules.md
-- Description:
--  In case if SDL receives from HMI "GetCapabilities" response, where SEAT module capabilities contain
-- "moduleInfo" with incorrect one of non-mandatory parameter, SDL should send default SEAT module capabilities
-- in "GetSystemCapability" response to mobile
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) HMI sent SEAT module capabilities having one incorrect non-mandatory parameter to SDL
-- 3) Mobile is connected to SDL
-- 4) App is registered and activated
--
-- Steps:
-- 1) App sends "GetSystemCapability" request ("REMOTE_CONTROL")
--   Check:
--    SDL sends "GetSystemCapability" response with default SEAT module capabilities to mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("test_scripts/RC/MultipleModules/commonRCMulModules")
local utils = require("user_modules/utils") -- testing purposes
common.tableToString = utils.tableToString  -- testing purposes

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local customModules = { "CLIMATE", "RADIO", "AUDIO", "HMI_SETTINGS", "LIGHT" }
local customSeatCapabilities = {
  {
    moduleName = "Seat of Driver",
    moduleInfo = {
      moduleId = "S0A",
      location    = "string",                --invalid value
      serviceArea = { col = 0, row = 0 },
      allowMultipleAccess = true
    }
  },
  {
    moduleName = "Seat of Front Passenger",
    moduleInfo = {
      moduleId = "S0C"
    }
  }
}
local capabilityParams = {
  SEAT = customSeatCapabilities
}
local defaultSeatCapabilities = common.getDefaultHmiCapabilitiesFromJson().seatControlCapabilities

--[[ Local Functions ]]
local function sendGetSystemCapability()
  local cid = common.getMobileSession():SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  common.getMobileSession():ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = {
      remoteControlCapability = {
        seatControlCapabilities = defaultSeatCapabilities
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
runner.Step("GetSystemCapability Incorrect optional Grid parameter", sendGetSystemCapability)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
runner.Step("Restore HMI capabilities file", common.restoreHMICapabilities)
