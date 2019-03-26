---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0204-same-app-from-multiple-devices.md
-- Description: Two mobile applications with the same appNames from different mobiles do subscribing on the same button
-- and receive OnButtonEvent and OnButtonPress notifications.
--   Precondition:
-- 1) SDL and HMI are started
-- 2) Mobiles №1 and №2 are connected to SDL
--   Steps:
-- 1) Mobile №1 App1 requested Subscribe on "OK" button
--   Check SDL:
--     sends Buttons.SubscribeButton("OK", appId_1) to HMI
--     receives Buttons.SubscribeButton("SUCCESS") response from HMI
--     sends SubscribeButton("SUCCESS") response to Mobile №1
--     sends OnHashChange with updated hashId to Mobile №1
-- 2) HMI sent OnButtonEvent and OnButtonPress notifications for "OK" button
--   Check SDL:
--     sends OnButtonEvent("OK") and OnButtonPress("OK") notifications to Mobile №1
--     does NOT send OnButtonEvent and OnButtonPress to Mobile №2
-- 3) Mobile №2 App2 requested Subscribe on "OK" button
--   Check SDL:
--     sends Buttons.SubscribeButton("OK", appId_2) to HMI
--     receives Buttons.SubscribeButton ("SUCCESS") response from HMI
--     sends SubscribeButton("SUCCESS") response to Mobile №2
--     sends OnHashChange with updated hashId to Mobile №2
-- 4) HMI sent OnButtonEvent and OnButtonPress notifications for "OK" button
--   Check SDL:
--     sends OnButtonEvent("OK") and OnButtonPress("OK") notifications to Mobile №1 and to Mobile №2
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/TheSameApp/commonTheSameApp')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Data ]]
local devices = {
  [1] = { host = "1.0.0.1",         port = config.mobilePort },
  [2] = { host = "192.168.100.199", port = config.mobilePort }
}

local appParams = {
  [1] = { appName = "Test Application", appID = "0001",  fullAppID = "0000001", appHMIType = { "NAVIGATION" },
 },
  [2] = { appName = "Test Application", appID = "00022", fullAppID = "00000022" }
}

--[[ Local Functions ]]
local function sendOnButtonEventPress(pAppId1, pAppId2, pButtonName, pNumberOfDevicesSubscribed)
  local mobSession1 = common.mobile.getSession(pAppId1)
  local mobSession2 = common.mobile.getSession(pAppId2)
  local pTime = pNumberOfDevicesSubscribed
  local pTime2 = 0

  if pNumberOfDevicesSubscribed == 2 then pTime2 = 1 end

  common.hmi.getConnection():SendNotification("Buttons.OnButtonEvent",
    {name = pButtonName, mode = "BUTTONDOWN", appID = common.app.getHMIId(pAppId1) })
  mobSession1:ExpectNotification("OnButtonEvent",{buttonName = pButtonName, buttonEventMode="BUTTONDOWN"}):Times(pTime)
  mobSession2:ExpectNotification("OnButtonEvent",{buttonName = pButtonName, buttonEventMode="BUTTONDOWN"}):Times(pTime2)
  common.hmi.getConnection():SendNotification("Buttons.OnButtonPress",
    {name = pButtonName, mode = "LONG", appID = common.app.getHMIId(pAppId1)})
  mobSession1:ExpectNotification("OnButtonPress",{buttonName = pButtonName, buttonPressMode = "LONG"}):Times(pTime)
  mobSession2:ExpectNotification("OnButtonPress",{buttonName = pButtonName, buttonPressMode = "LONG"}):Times(pTime2)
end

local function hmiLeveltoLimited(pAppId)
 common.getHMIConnection(pAppId):SendNotification("BasicCommunication.OnAppDeactivated",
     { appID = common.getHMIAppId(pAppId) })
 common.getMobileSession(pAppId):ExpectNotification("OnHMIStatus",
   { hmiLevel = "LIMITED", audioStreamingState = "AUDIBLE", systemContext = "MAIN" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL and HMI", common.start)
runner.Step("Connect two mobile devices to SDL", common.connectMobDevices, {devices})
runner.Step("Register App1 from device 1", common.registerAppEx, {1, appParams[1], 1})
runner.Step("Register App2 from device 2", common.registerAppEx, {2, appParams[2], 2})

runner.Title("Test")
runner.Step("Activate App 2", common.app.activate, { 2 })
runner.Step("Send App 2 to LIMITED HMI level", hmiLeveltoLimited, { 2 })
runner.Step("Activate App 1", common.app.activate, { 1 })
runner.Step("App 1 from Mobile 1 requests Subscribe on Ok",  common.subscribeOnButton, {1, "OK" })
runner.Step("HMI send OnButtonEvent and OnButtonPress for OK", sendOnButtonEventPress, {1, 2, "OK", 1})

runner.Step("Send App 1 to LIMITED HMI level", hmiLeveltoLimited, { 1 })
runner.Step("Activate App 2", common.app.activate, { 2 })
runner.Step("App 2 from Mobile 2 requests Subscribe on Ok",  common.subscribeOnButton, {2, "OK" })
runner.Step("HMI send OnButtonEvent and OnButtonPress for OK", sendOnButtonEventPress, {2, 1, "OK", 2})

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
