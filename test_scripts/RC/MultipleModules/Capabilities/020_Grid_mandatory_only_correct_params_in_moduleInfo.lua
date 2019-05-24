---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0221-multiple-modules.md
-- Description:
--  In case if SDL receives from HMI "GetCapabilities" response, where all modules capabilities contain "moduleInfo",
-- which includes "location" and "serviceArea" parameters with only mandatory parameters, SDL should resend these
-- capabilities in "GetSystemCapability" response to mobile
--
-- Preconditions:
-- 1) SDL and HMI are started
-- 2) HMI sent all modules capabilities with "moduleInfo" containing "location" and "serviceArea" having only
-- mandatory parameters to SDL
-- 3) Mobile is connected to SDL
-- 4) App is registered and activated
--
-- Steps:
-- 1) App sends "GetSystemCapability" request ("REMOTE_CONTROL")
--   Check:
--    SDL sends "GetSystemCapability" response with all modules RC capabilities containig "moduleInfo" with "location"
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
local customClimateCapabilities = {
  {
    moduleName = "Climate Driver Seat",
    moduleInfo = {
      moduleId = "C0A",
      location    = { col = 0, row = 0 },
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
local customRadioCapabilities = {
  {
    moduleName = "Radio",
    moduleInfo = {
      moduleId = "R0A",
      location    = { col = 0, row = 0 },
      serviceArea = { col = 0, row = 0 }
    }
  }
}
local customAudioCapabilities = {
  {
    moduleName = "Audio Driver Seat",
    moduleInfo = {
      moduleId = "A0A",
      location    = { col = 0, row = 0 },
      serviceArea = { col = 0, row = 0 }
    }
  },
  {
    moduleName = "Audio Front Passenger Seat",
    moduleInfo = {
      moduleId = "A0C",
      location    = { col = 2, row = 0 },
      serviceArea = { col = 2, row = 0 }
    }
  },
  {
    moduleName = "Audio 2nd Raw Left Seat",
    moduleInfo = {
      moduleId = "A1A",
      location    = { col = 0, row = 1 },
      serviceArea = { col = 0, row = 1 }
    }
  },
  {
    moduleName = "Audio 2nd Raw Middle Seat",
    moduleInfo = {
      moduleId = "A1B",
      location    = { col = 1, row = 1 },
      serviceArea = { col = 1, row = 1 }
    }
  },
  {
    moduleName = "Audio 2nd Raw Right Seat",
    moduleInfo = {
      moduleId = "A1C",
      location    = { col = 2, row = 1 },
      serviceArea = { col = 2, row = 1 }
    }
  },
  {
    moduleName = "Audio Upper Level Vehicle Interior",
    moduleInfo = {
      moduleId = "A0A+",        -- a position (NOT a SEAT) on the upper level
      location    = { col = 0, row = 0 },
      serviceArea = { col = 0, row = 0 }
    }
  }
}
local customSeatCapabilities = {
  {
    moduleName = "Seat of Driver",
    moduleInfo = {
      moduleId = "S0A",
      location    = { col = 0, row = 0 },
      serviceArea = { col = 0, row = 0 }
    }
  },
  {
    moduleName = "Seat of Front Passenger",
    moduleInfo = {
      moduleId = "S0C",
      location    = { col = 2, row = 0 },
      serviceArea = { col = 2, row = 0 }
    }
  },
  {
    moduleName = "Seat of 2nd Raw Left Passenger",
    moduleInfo = {
      moduleId = "S1A",
      location    = { col = 0, row = 1 },
      serviceArea = { col = 0, row = 1 }
    }
  },
  {
    moduleName = "Seat of 2nd Raw Middle Passenger",
    moduleInfo = {
      moduleId = "S1B",
      location    = { col = 1, row = 1 },
      serviceArea = { col = 1, row = 1 }
    }
  },
  {
    moduleName = "Seat of 2nd Raw Right Passenger",
    moduleInfo = {
      moduleId = "S1C",
      location    = { col = 2, row = 1 },
      serviceArea = { col = 2, row = 1 }
    }
  }
}
local customHmiSettingsCapabilities = {
  moduleName = "HmiSettings Driver Seat",
  moduleInfo = {
    moduleId = "H0A",
    location    = { col = 0, row = 0 },
    serviceArea = { col = 0, row = 0 }
  }
}
local customLightCapabilities = {
  moduleName = "Light Driver Seat",
  moduleInfo = {
    moduleId = "L0A",
    location    = { col = 0, row = 0 },
    serviceArea = { col = 0, row = 0 }
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
  CLIMATE      = customClimateCapabilities,
  RADIO        = customRadioCapabilities,
  AUDIO        = customAudioCapabilities,
  SEAT         = customSeatCapabilities,
  HMI_SETTINGS = customHmiSettingsCapabilities,
  LIGHT        = customLightCapabilities
}
local defaultClimateCapabilities     = common.getDefaultHmiCapabilitiesFromJson().climateControlCapabilities
local defaultRadioCapabilities       = common.getDefaultHmiCapabilitiesFromJson().radioControlCapabilities
local defaultAudioCapabilities       = common.getDefaultHmiCapabilitiesFromJson().audioControlCapabilities
local defaultSeatCapabilities        = common.getDefaultHmiCapabilitiesFromJson().seatControlCapabilities
local defaultHmiSettingsCapabilities = common.getDefaultHmiCapabilitiesFromJson().hmiSettingsControlCapabilities
local defaultLightCapabilities       = common.getDefaultHmiCapabilitiesFromJson().lightControlCapabilities

--[[ Local Functions ]]
local function sendGetSystemCapability()
  local cid = common.getMobileSession():SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  common.getMobileSession():ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = {
      remoteControlCapability = {
        climateControlCapabilities     = defaultClimateCapabilities,
        radioControlCapabilities       = defaultRadioCapabilities,
        audioControlCapabilities       = defaultAudioCapabilities,
        hmiSettingsControlCapabilities = defaultSeatCapabilities,
        seatControlCapabilities        = defaultHmiSettingsCapabilities,
        lightControlCapabilities       = defaultLightCapabilities
      }
    }
  })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Backup HMI capabilities file", common.backupHMICapabilities)
runner.Step("Update HMI capabilities file", common.updateDefaultCapabilities, { common.allModules })
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start, { capabilityParams })
runner.Step("RAI", common.registerAppWOPTU)
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
runner.Step("GetSystemCapability Mandatory only Grid parameters", sendGetSystemCapability)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
runner.Step("Restore HMI capabilities file", common.restoreHMICapabilities)
