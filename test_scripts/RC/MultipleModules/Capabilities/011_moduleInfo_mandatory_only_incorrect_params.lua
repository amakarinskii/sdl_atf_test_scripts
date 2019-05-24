  ---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0221-multiple-modules.md
-- Description:
--  In case if SDL receives from HMI "GetCapabilities" response, where CLIMATE and RADIO modules capabilities contain
-- "moduleInfo" with some mandatory parameter having invalid values, SDL should send default CLIMATE and RADIO modules
-- capabilities in "GetSystemCapability" response to mobile
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) HMI sent CLIMATE and RADIO modules capabilities with two invalid mandatory parameters to SDL
-- 3) Mobile is connected to SDL
-- 4) App is registered and activated
--
-- Steps:
-- 1) App sends "GetSystemCapability" request ("REMOTE_CONTROL")
--   Check:
--    SDL sends "GetSystemCapability" response with default CLIMATE and RADIO modules capabilities to mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("test_scripts/RC/MultipleModules/commonRCMulModules")
local utils = require("user_modules/utils") -- testing purposes
common.tableToString = utils.tableToString  -- testing purposes

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
-- local customModules = { "AUDIO", "SEAT", "HMI_SETTINGS", "LIGHT" }
local tooLongString = "qwqqweweerrtetrerereregegggdfggfjhjghgfhfhgfhgfhgfhhhgfhhfhrrtrggfhfhgfhgfhgfhfhghrthrhthhdfghdfghfgh"
local customClimateCapabilities = {
  {
    moduleName = "Climate Driver Seat",
    moduleInfo = {
      moduleId = "C0A"
    }
  },
  {
    moduleName = "Climate Front Passenger Seat",
    moduleInfo = {
      moduleId = true                    --invalid value
    }
  },
  {
    moduleName = "Climate 2nd Raw",
    moduleInfo = {
      moduleId = "C1A"
    }
  }
}
local customRadioCapabilities = {
  {
    moduleName = "Radio Driver Seat",
    moduleInfo = {
      moduleId = tooLongString           --invalid value
    }
  }
}
local capabilityParams = {
  CLIMATE = customClimateCapabilities,
  RADIO = customRadioCapabilities,
}

local defaultClimateCapabilities = common.getDefaultHmiCapabilitiesFromJson().climateControlCapabilities
local defaultRadioCapabilities   = common.getDefaultHmiCapabilitiesFromJson().radioControlCapabilities

--[[ Local Functions ]]
local function sendGetSystemCapability()
  local cid = common.getMobileSession():SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  common.getMobileSession():ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = {
      remoteControlCapability = {
        climateControlCapabilities = defaultClimateCapabilities,
        radioControlCapabilities = defaultRadioCapabilities
      }
    }
  })
end

--[[ Scenario ]]
runner.Title("Preconditions")
-- runner.Step("Backup HMI capabilities file", common.backupHMICapabilities)
-- runner.Step("Update HMI capabilities file", common.updateDefaultCapabilities, { customModules })
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start, { capabilityParams })
runner.Step("RAI", common.registerAppWOPTU)
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
runner.Step("GetSystemCapability Incorrect moduleInfo mandatory parameter", sendGetSystemCapability)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
-- runner.Step("Restore HMI capabilities file", common.restoreHMICapabilities)
