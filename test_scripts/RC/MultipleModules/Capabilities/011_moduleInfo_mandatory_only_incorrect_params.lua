---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0221-multiple-modules.md
-- Description:
--  Mobile App receive all capabilities in response to its "GetSystemCapability" request
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) Mobile №1 is connected to SDL
-- 3) App1 sends is registered from Mobile №1
--
-- Steps:
-- 1) App sends "GetSystemCapability" request ("REMOTE_CONTROL")
--   Check:
--    SDL transfer RC capabilities to mobile
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
    moduleName = "Radio",
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
local defaultRadioCapabilities = common.getDefaultHmiCapabilitiesFromJson().radioControlCapabilities

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
runner.Step("GetSystemCapability Positive Case", sendGetSystemCapability)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
-- runner.Step("Restore HMI capabilities file", common.restoreHMICapabilities)
