---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0221-multiple-modules.md
-- Description:
--  In case if SDL receives from HMI "GetCapabilities" response, where CLIMATE module capabilities contain
-- "moduleInfo" "location" mandatory parameter, SDL should send default CLIMATE module capabilities
-- in "GetSystemCapability" response to mobile
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) HMI sent CLIMATE module capabilities with "moduleInfo" containing incorrect "location"  mandatory parameter to SDL
-- 3) Mobile is connected to SDL
-- 4) App is registered and activated
--
-- Steps:
-- 1) App sends "GetSystemCapability" request ("REMOTE_CONTROL")
--   Check:
--    SDL sends "GetSystemCapability" response with LIGHT module capabilities containig "moduleInfo" with "location"
-- and "serviceArea" having only mandatory parameters to mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("test_scripts/RC/MultipleModules/commonRCMulModules")
local utils = require("user_modules/utils") -- testing purposes
common.tableToString = utils.tableToString  -- testing purposes

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local customModules = { "CLIMATE", }
local climateControlCapabilities = {
  {
    moduleName = "Climate Driver Seat",
    moduleInfo = {
      moduleId = "C0A",
        location    = { row = 0 },
        serviceArea = { col = 0, row = 0 }
    }
  },
  {
    moduleName = "Climate Front Passenger Seat",
    moduleInfo = {
      moduleId = "C0C",
        location    = { col = 2, row = 0 },
        serviceArea = { col = 2, row = 0 }
    }
  },
  {
    moduleName = "Climate 2nd Raw",
    moduleInfo = {
      moduleId = "C1A",
        location    = { col = 0, row = 1 },
        serviceArea = { col = 0, row = 1 }
    }
  }
}

local capabilityParams = {
  CLIMATE = climateControlCapabilities
}

--[[ Local Functions ]]
local function sendGetSystemCapability()
  local cid = common.getMobileSession():SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  common.getMobileSession():ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = {
      remoteControlCapability = {
        climateControlCapabilities = climateControlCapabilities,
        radioControlCapabilities = nil,
        audioControlCapabilities = nil,
        hmiSettingsControlCapabilities = nil,
        seatControlCapabilities = nil,
        lightControlCapabilities = nil,
        buttonCapabilities = nil
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
