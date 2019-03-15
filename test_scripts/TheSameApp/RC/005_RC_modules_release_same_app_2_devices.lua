---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0204-same-app-from-multiple-devices.md
-- Description: RC modules release in AUTO_ALLOW mode for the same applications that are registered
--  on two mobile devices

-- Precondition:
-- 1)SDL and HMI are started
-- 2)Mobile №1 and №2 are connected to SDL and are consented
-- 3)RC Application (HMI type = REMOTE_CONTROL) App1 is registered on Mobile №1 and Mobile №2
--   (two copies of one application)
--   App1 from Mobile №1 has hmiAppId_1 on HMI, App1 from Mobile №2 has hmiAppId_2 on HMI
--   App1 from Mobile №1 and App1 from Mobile №2 are activated sequentially
-- 4)Remote control settings are: allowed:true, mode: AUTO_ALLOW
-- 5)RC module RADIO allocated to App1 on Mobile №1
--   RC module CLIMATE allocated to App1 on Mobile №2
--   RC module LIGHT is free
-- In case:
-- 1)User exit Application App1 on Mobile №1
--   HMI sends BC.OnExitApplication(hmiAppId_1, reason = USER_EXIT) notification to SDL
-- 2)User exit Application App1 on Mobile №2
--   HMI sends BC.OnExitApplication(hmiAppId_2, reason = USER_EXIT) notification to SDL
-- SDL does:
-- 1)Send OnRCStatus(allocatedModules:(), freeModules: (RADIO, LIGHT)) notification to App1 on Mobile №1
--   Send OnRCStatus(allocatedModules:(CLIMATE), freeModules: (RADIO, LIGHT)) notification to App1 on Mobile №2
--   Send RC.OnRCStatus(appId: hmiAppId_1, allocatedModules:(), freeModules: (RADIO, LIGHT)) notification to HMI
--   Send RC.OnRCStatus(appId: hmiAppId_2, allocatedModules:(CLIMATE), freeModules: (RADIO, LIGHT)) notification to HMI
-- 2)Send OnRCStatus(allocatedModules:(), freeModules: (RADIO, CLIMATE, LIGHT)) notification to App1 on Mobile №1
--   Send OnRCStatus(allocatedModules:(), freeModules: (RADIO, CLIMATE, LIGHT)) notification to App1 on Mobile №2
--  Send RC.OnRCStatus(appId: hmiAppId_1, allocatedModules:(), freeModules: (RADIO, CLIMATE, LIGHT)) notification to HMI
--  Send RC.OnRCStatus(appId: hmiAppId_2, allocatedModules:(), freeModules: (RADIO, CLIMATE, LIGHT)) notification to HMI
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
    appName = "Test Application",
    isMediaApplication = false,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "REMOTE_CONTROL" },
    appID = "0001",
    fullAppID = "0000001",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  }
}

--[[ Local Functions ]]
local function modificationOfPreloadedPT(pPolicyTable)
  local pt = pPolicyTable.policy_table
  pt.functional_groupings["DataConsent-2"].rpcs = common.json.null

  local policyAppParams = common.cloneTable(pt.app_policies["default"])
  policyAppParams.AppHMIType = appParams[1].appHMIType
  policyAppParams.moduleType = { "RADIO", "CLIMATE", "LIGHT" }
  policyAppParams.groups = { "Base-4", "RemoteControl" }

  pt.app_policies[appParams[1].fullAppID] = policyAppParams
end

local function releaseModuleApp1Dev1()
  local pHmiExpDataTable = {
    [common.app.getHMIId(1)] = {allocatedModules = {}, freeModules = {"RADIO", "LIGHT"}, allowed = true},
    [common.app.getHMIId(2)] = {allocatedModules = {"CLIMATE"}, freeModules = {"RADIO", "LIGHT"}, allowed = true}
  }
  common.expectOnRCStatusOnHMI(pHmiExpDataTable)
  common.expectOnRCStatusOnMobile(1, {allocatedModules = {}, freeModules = {"RADIO", "LIGHT"}, allowed = true})
  common.expectOnRCStatusOnMobile(2, {allocatedModules = {"CLIMATE"}, freeModules = {"RADIO", "LIGHT"}, allowed = true})

  common.getHMIConnection():SendNotification("BasicCommunication.OnExitApplication",
    { appID = common.app.getHMIId(1), reason = "USER_EXIT" })
end

local function releaseModuleApp1Dev2()
  local pHmiExpDataTable = {
    [common.app.getHMIId(1)] = {allocatedModules = {}, freeModules = {"RADIO", "LIGHT", "CLIMATE"}, allowed = true},
    [common.app.getHMIId(2)] = {allocatedModules = {}, freeModules = {"RADIO", "LIGHT", "CLIMATE"}, allowed = true}
  }
  common.expectOnRCStatusOnHMI(pHmiExpDataTable)
  common.expectOnRCStatusOnMobile(1,
      {allocatedModules = {}, freeModules = {"RADIO", "LIGHT", "CLIMATE"}, allowed = true})
  common.expectOnRCStatusOnMobile(2,
      {allocatedModules = {}, freeModules = {"RADIO", "LIGHT", "CLIMATE"}, allowed = true})

  common.getHMIConnection():SendNotification("BasicCommunication.OnExitApplication",
    { appID = common.app.getHMIId(2), reason = "USER_EXIT" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Prepare preloaded PT", common.modifyPreloadedPt, {modificationOfPreloadedPT})
runner.Step("Start SDL and HMI", common.start)
runner.Step("Set AccessMode AUTO_DENY", common.defineRAMode, { true, "AUTO_DENY" })
runner.Step("Connect two mobile devices to SDL", common.connectMobDevices, {devices})
runner.Step("Register App1 from device 1", common.registerAppEx, {1, appParams[1], 1})
runner.Step("Register App1 from device 2", common.registerAppEx, {2, appParams[1], 2})
runner.Step("Activate App1 from Device 1", common.activateApp, {1})
runner.Step("App1 on Device 1 successfully allocates module RADIO", common.rpcAllowed, {1, "RADIO"})
runner.Step("Activate App1 from Device 2", common.activateApp, {2})
runner.Step("App1 on Device 2 successfully allocates module CLIMATE", common.rpcAllowed, {2, "CLIMATE"})

runner.Title("Test")
runner.Step("User exit Application App1 on Mobile №1", releaseModuleApp1Dev1)
runner.Step("User exit Application App1 on Mobile №2", releaseModuleApp1Dev2)

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
