---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0204-same-app-from-multiple-devices.md
-- Description: Consent of two different mobile devices with registered the same mobile applications
-- Precondition:

-- In case:

-- SDL does:

---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/TheSameApp/commonTheSameApp')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Data ]]
local devices = {
  [1] = { host = "1.0.0.1", port = config.mobilePort },
  [2] = { host = "192.168.100.199", port = config.mobilePort }
}

local appParams = {
  [1] = {
    syncMsgVersion =
    {
      majorVersion = 5,
      minorVersion = 0
    },
    appName = "Test Application4",
    isMediaApplication = false,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "NAVIGATION" },
    appID = "0004",
    fullAppID = "0000004",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  },
  [2] = {
    syncMsgVersion =
    {
      majorVersion = 5,
      minorVersion = 0
    },
    appName = "Test Application5",
    isMediaApplication = false,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "NAVIGATION" },
    appID = "0005",
    fullAppID = "0000005",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  },
  [3] = {
    syncMsgVersion =
    {
      majorVersion = 5,
      minorVersion = 0
    },
    appName = "Test Application6",
    isMediaApplication = false,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "NAVIGATION" },
    appID = "0065",
    fullAppID = "0000065",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  },
}

local ptFuncGroup = {
  Group001 = {
    user_consent_prompt = "ConsentGroup001",
    rpcs = {
      SendLocation = {
        hmi_levels = {"BACKGROUND", "FULL", "LIMITED", "NONE"}
      }
    }
  }
}

--[[ Local Functions ]]
local function modificationOfPreloadedPT(pPolicyTable)
  local pt = pPolicyTable.policy_table

  for funcGroupName in pairs(pt.functional_groupings) do
    pt.functional_groupings[funcGroupName].rpcs["SendLocation"] = nil
  end

  pt.functional_groupings["DataConsent-2"].rpcs = common.json.null

  pt.functional_groupings["Group001"] = ptFuncGroup.Group001

  pt.app_policies[appParams[1].fullAppID] =
      common.cloneTable(pt.app_policies["default"])
  pt.app_policies[appParams[1].fullAppID].groups = {"Base-4", "Group001"}
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Prepare preloaded PT", common.modifyPreloadedPt, {modificationOfPreloadedPT})
runner.Step("Start SDL and HMI", common.start)
runner.Step("Connect two mobile devices to SDL", common.connectMobDevices, {devices})
runner.Step("Register App1 from device 1", common.registerAppEx, {1, appParams[1], 1})
runner.Step("Register App2 from device 1", common.registerAppEx, {2, appParams[2], 1})
runner.Step("Register App1 from device 1", common.registerAppEx, {3, appParams[1], 2})

runner.Title("Test")
runner.Step("Allow group Group001 for all App", common.funcGroupConsentForApp, {"ConsentGroup001",true})
runner.Step("Succeed SendLocation from App1 from device 1", common.sendLocation, {1, "SUCCESS"})
runner.Step("Succeed SendLocation from App2 from device 1", common.sendLocation, {2, "SUCCESS"})
runner.Step("Succeed SendLocation from App1 from device 2", common.sendLocation, {3, "SUCCESS"})

runner.Step("Register App2 from device 2", common.registerAppEx, {4, appParams[2], 2})
runner.Step("Succeed SendLocation from App2 from device 2", common.sendLocation, {4, "SUCCESS"})

runner.Step("Register App3 from device 2", common.registerAppEx, {5, appParams[3], 2})
runner.Step("Succeed SendLocation from App3 from device 2", common.sendLocation, {5, "SUCCESS"})

runner.Step("Allow group Group001 for all App", common.funcGroupConsentForApp, {"ConsentGroup001",false})
runner.Step("Disallowed SendLocation from App1 from device 1", common.sendLocation, {1, "DISALLOWED"})
runner.Step("Disallowed SendLocation from App2 from device 1", common.sendLocation, {2, "DISALLOWED"})
runner.Step("Disallowed SendLocation from App1 from device 2", common.sendLocation, {3, "DISALLOWED"})
runner.Step("Disallowed SendLocation from App2 from device 2", common.sendLocation, {4, "DISALLOWED"})
runner.Step("Disallowed SendLocation from App3 from device 2", common.sendLocation, {4, "DISALLOWED"})

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
