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
-- local capabilityParams = {}
-- for _, v in pairs(common.allModules) do capabilityParams[v] = common.DEFAULT end -- HMI has all posible RC capabilities
local customModules = { "RADIO", "CLIMATE" }
local rcCapabilities = common.getRcCapabilities()

local radioControlCapabilities = {
  {
    moduleName = "Radio",
    moduleInfo = {
      moduleId = "R0A"
    }
  }
}
local climateControlCapabilities = rcCapabilities["CLIMATE"]

local capabilityParams = {
  RADIO = radioControlCapabilities,
  CLIMATE = common.DEFAULT,
}

--[[ Local Functions ]]
local function sendGetSystemCapability()
  -- print("rcCapabilities = ", common.tableToString(rcCapabilities["RADIO"]))
  local cid = common.getMobileSession():SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  common.getMobileSession():ExpectResponse(cid, {
      success = true,
      resultCode = "SUCCESS",
      systemCapability = {
        remoteControlCapability = {
          climateControlCapabilities = climateControlCapabilities,
          radioControlCapabilities = radioControlCapabilities,
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
