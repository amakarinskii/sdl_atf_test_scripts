---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0221-multiple-modules.md
-- Description:
--  Mobile App receive capabilities only for LIGHT module in response to
--  "GetSystemCapability"(systemCapabilityType = "REMOTE_CONTROL") request
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) HMI sent only LIGHT module capabilities to SDL
-- 3) Mobile is connected to SDL
-- 4) App is registered and activated
--
-- Steps:
-- 1) App sends "GetSystemCapability"("REMOTE_CONTROL") request
--   Check:
--    SDL sends "GetSystemCapability" response with LIGHT module capabilities to mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("test_scripts/RC/MultipleModules/commonRCMulModules")
local utils = require("user_modules/utils") -- testing purposes
common.tableToString = utils.tableToString  -- testing purposes

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local customModules = { "LIGHT" }
local lightControlCapabilities = {
  moduleName = "Light Driver Seat",
   moduleInfo = {
    moduleId = "H0A",
    location = {
      col = 0, row = 0, level = 0, colspan = 1, rowspan = 1, levelspan = 1
    },
    serviceArea = {
      col = 0, row = 0, level = 0, colspan = 3, rowspan = 2, levelspan = 1
    },
    allowMultipleAccess = true
  },
  supportedLights = (function()
    local lights = { "FRONT_LEFT_HIGH_BEAM", "FRONT_RIGHT_HIGH_BEAM", "FRONT_LEFT_LOW_BEAM",
      "FRONT_RIGHT_LOW_BEAM", "FRONT_LEFT_PARKING_LIGHT", "FRONT_RIGHT_PARKING_LIGHT",
      "FRONT_LEFT_FOG_LIGHT", "FRONT_RIGHT_FOG_LIGHT", "FRONT_LEFT_DAYTIME_RUNNING_LIGHT",
      "FRONT_RIGHT_DAYTIME_RUNNING_LIGHT", "FRONT_LEFT_TURN_LIGHT", "FRONT_RIGHT_TURN_LIGHT",
      "REAR_LEFT_FOG_LIGHT", "REAR_RIGHT_FOG_LIGHT", "REAR_LEFT_TAIL_LIGHT", "REAR_RIGHT_TAIL_LIGHT",
      "REAR_LEFT_BRAKE_LIGHT", "REAR_RIGHT_BRAKE_LIGHT", "REAR_LEFT_TURN_LIGHT", "REAR_RIGHT_TURN_LIGHT",
      "REAR_REGISTRATION_PLATE_LIGHT", "HIGH_BEAMS", "LOW_BEAMS", "FOG_LIGHTS", "RUNNING_LIGHTS",
      "PARKING_LIGHTS", "BRAKE_LIGHTS", "REAR_REVERSING_LIGHTS", "SIDE_MARKER_LIGHTS", "LEFT_TURN_LIGHTS",
      "RIGHT_TURN_LIGHTS", "HAZARD_LIGHTS", "AMBIENT_LIGHTS", "OVERHEAD_LIGHTS", "READING_LIGHTS",
      "TRUNK_LIGHTS", "EXTERIOR_FRONT_LIGHTS", "EXTERIOR_REAR_LIGHTS", "EXTERIOR_LEFT_LIGHTS",
      "EXTERIOR_RIGHT_LIGHTS", "REAR_CARGO_LIGHTS", "REAR_TRUCK_BED_LIGHTS", "REAR_TRAILER_LIGHTS",
      "LEFT_SPOT_LIGHTS", "RIGHT_SPOT_LIGHTS", "LEFT_PUDDLE_LIGHTS", "RIGHT_PUDDLE_LIGHTS",
      "EXTERIOR_ALL_LIGHTS" }
  local out = { }
  for _, name in pairs(lights) do
    local item = {
      name = name,
      densityAvailable = true,
      statusAvailable = true,
      rgbColorSpaceAvailable = true
    }
    table.insert(out, item)
  end
  return out
  end)()
}
local capabilityParams = {
  LIGHT = lightControlCapabilities
}

--[[ Local Functions ]]
local function sendGetSystemCapability()
  local cid = common.getMobileSession():SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  common.getMobileSession():ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = {
      remoteControlCapability = {
        lightControlCapabilities = lightControlCapabilities
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
runner.Step("GetSystemCapability Positive Case for LIGHT", sendGetSystemCapability)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
runner.Step("Restore HMI capabilities file", common.restoreHMICapabilities)
