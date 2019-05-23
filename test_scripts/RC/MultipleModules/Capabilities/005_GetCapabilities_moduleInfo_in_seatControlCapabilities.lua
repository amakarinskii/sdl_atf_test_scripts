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
local customModules = { "SEAT", "CLIMATE" }
local seatControlCapabilities = {
  {
    moduleName = "Seat of Driver",
    moduleInfo = {
      moduleId = "S0A",
      location = {
        col = 0, row = 0, level = 0, colspan = 1, rowspan = 1, levelspan = 1
      },
      serviceArea = {
        col = 0, row = 0, level = 0, colspan = 1, rowspan = 1, levelspan = 1
      },
      allowMultipleAccess = true
    }
  },
  {
    moduleName = "Seat of Front Passenger",
    moduleInfo = {
      moduleId = "S0C",
      location = {
        col = 2, row = 0, level = 0, colspan = 1, rowspan = 1, levelspan = 1
      },
      serviceArea = {
        col = 2, row = 0, level = 0, colspan = 1, rowspan = 1, levelspan = 1
      },
      allowMultipleAccess = true
    }
  },
  {
    moduleName = "Seat of 2nd Raw Left Passenger",
    moduleInfo = {
      moduleId = "S1A",
      location = {
        col = 0, row = 1, level = 0, colspan = 1, rowspan = 1, levelspan = 1
      },
      serviceArea = {
        col = 0, row = 1, level = 0, colspan = 1, rowspan = 1, levelspan = 1
      },
      allowMultipleAccess = true
    }
  },
  {
    moduleName = "Seat of 2nd Raw Middle Passenger",
    moduleInfo = {
      moduleId = "S1B",
      location = {
        col = 1, row = 1, level = 0, colspan = 1, rowspan = 1, levelspan = 1
      },
      serviceArea = {
        col = 1, row = 1, level = 0, colspan = 1, rowspan = 1, levelspan = 1
      },
      allowMultipleAccess = true
    }
  },
  {
    moduleName = "Seat of 2nd Raw Right Passenger",
    moduleInfo = {
      moduleId = "S1C",
      location = {
        col = 2, row = 1, level = 0, colspan = 1, rowspan = 1, levelspan = 1
      },
      serviceArea = {
        col = 2, row = 1, level = 0, colspan = 1, rowspan = 1, levelspan = 1
      },
      allowMultipleAccess = true
    }
  }
}
local capabilityParams = {
  SEAT = seatControlCapabilities
}

--[[ Local Functions ]]
local function sendGetSystemCapability()
  local cid = common.getMobileSession():SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  common.getMobileSession():ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = {
      remoteControlCapability = {
        climateControlCapabilities = nil,
        radioControlCapabilities = nil,
        audioControlCapabilities = nil,
        seatControlCapabilities = seatControlCapabilities,
        hmiSettingsControlCapabilities = nil,
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
runner.Step("GetSystemCapability Positive Case for SEAT", sendGetSystemCapability)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
runner.Step("Restore HMI capabilities file", common.restoreHMICapabilities)
