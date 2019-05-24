---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0221-multiple-modules.md
-- Description:
--  In case if SDL receives from HMI "GetCapabilities" response, where AUDIO module capabilities contain
-- "moduleInfo" with one mandatory parameter omitted, SDL should send default AUDIO module capabilities
-- in "GetSystemCapability" response to mobile
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) HMI sent AUDIO module capabilities having one of mandatory parameter omitted to SDL
-- 3) Mobile is connected to SDL
-- 4) App is registered and activated
--
-- Steps:
-- 1) App sends "GetSystemCapability" request ("REMOTE_CONTROL")
--   Check:
--    SDL sends "GetSystemCapability" response with default AUDIO module capabilities to mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("test_scripts/RC/MultipleModules/commonRCMulModules")
local utils = require("user_modules/utils") -- testing purposes
common.tableToString = utils.tableToString  -- testing purposes

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
-- local customModules = { "CLIMATE", "RADIO", "SEAT", "HMI_SETTINGS", "LIGHT" }
local customAudioCapabilities = {
  {
    moduleName = "Audio Driver Seat",
    moduleInfo = {
      moduleId = "A0A",
      location    = { col = 0, row = 0 },
      serviceArea = { col = 0, row = 0 }
      allowMultipleAccess = true
    }
  },
  {
    moduleName = "Audio Front Passenger Seat",
    moduleInfo = {
    --  moduleId = "A0C",               -- omitted mandatory parameter
      location    = { col = 2, row = 0 },
      serviceArea = { col = 2, row = 0 }
      allowMultipleAccess = true
    }
  },
  {
    moduleName = "Audio Upper Level Vehicle Interior",
    moduleInfo = {
      moduleId = "A0A+",                -- a position (NOT a SEAT) on the upper level
      location    = { col = 0, row = 0, level = 1 },
      serviceArea = { col = 0, row = 0, level = 1 },
      allowMultipleAccess = true
    }
  }
}
local capabilityParams = {
  AUDIO = customAudioCapabilities
}
local defaultAudioCapabilities = common.getDefaultHmiCapabilitiesFromJson().audioControlCapabilities


--[[ Local Functions ]]
local function sendGetSystemCapability()
  local cid = common.getMobileSession():SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  common.getMobileSession():ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = {
      remoteControlCapability = {
        audioControlCapabilities = defaultAudioCapabilities
      }
    }
  })
end

--[[ Scenario ]]
runner.Title("Preconditions")
-- runner.Step("Backup HMI capabilities file", common.backupHMICapabilities)
-- runner.Step("Update HMI capabilities file", common.updateDefaultCapabilities, { common.allModules })
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start, { capabilityParams })
runner.Step("RAI", common.registerAppWOPTU)
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
runner.Step("GetSystemCapability Absent moduleInfo mandatory parameter", sendGetSystemCapability)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
-- runner.Step("Restore HMI capabilities file", common.restoreHMICapabilities)
