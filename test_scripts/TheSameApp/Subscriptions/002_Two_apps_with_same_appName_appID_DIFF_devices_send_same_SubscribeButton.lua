---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0204-same-app-from-multiple-devices.md
-- Description: Registration of two mobile applications with the same appIDs and appNames which are match to the
-- nickname contained in PT from different mobiles.
--   Precondition:
-- 1) PT contains entity ( appID = 1, nicknames = "Test Application" )
-- 2) SDL and HMI are started
-- 3) Mobile №1 and №2 are connected to SDL
--   Steps:
-- 1) Mobile №1 sends RegisterAppInterface request (appID = 1, appName = "Test Application") to SDL
--   CheckSDL:
--     SDL sends RegisterAppInterface response( resultCode = SUCCESS  ) to Mobile №1
--     BasicCommunication.OnAppRegistered(...) notification to HMI
-- 2) Mobile №2 sends RegisterAppInterface request (appID = 1, appName = "Test Application") to SDL
--   CheckSDL:
--     SDL sends RegisterAppInterface response( resultCode = SUCCESS  ) to Mobile №2
--     BasicCommunication.OnAppRegistered(...) notification to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/TheSameApp/commonTheSameApp')
-- local json = require("modules/json")
-- local utils = require('user_modules/utils')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Data ]]
local devices = {
  [1] = { host = "1.0.0.1",         port = config.mobilePort },
  [2] = { host = "192.168.100.199", port = config.mobilePort }
}

local appParams = {
	[1] = { appName = "Test Application", appID = "0001",  fullAppID = "0000001" },
	[2] = { appName = "Test Application", appID = "00022", fullAppID = "00000022" }
}

--[[ Local Functions ]]
local function subscribeOnButton(pAppId, pButtonName)
  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("SubscribeButton", {buttonName = pButtonName})
    common.hmi.getConnection():ExpectNotification("Buttons.OnButtonSubscription",
        {name = pButtonName, isSubscribed = true, appID = common.app.getHMIId(pAppId) })
    mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
    mobSession:ExpectNotification("OnHashChange")
end

local function sendOnButtonEventPress(pAppId1, pAppId2, pButtonName, pNumberOfDevicesSubscribed)
  local mobSession1 = common.mobile.getSession(pAppId1)
  local mobSession2 = common.mobile.getSession(pAppId2)

  local pTime1, pTime2
  if     pNumberOfDevicesSubscribed == "one"  then pTime1 = 1; pTime2 = 0
  elseif pNumberOfDevicesSubscribed == "two"  then pTime1 = 1; pTime2 = 1
  elseif pNumberOfDevicesSubscribed == "none" then pTime1 = 0; pTime2 = 0
  end

  common.hmi.getConnection():SendNotification("Buttons.OnButtonEvent",
    {name = pButtonName, mode = "BUTTONDOWN", appID = common.app.getHMIId(pAppId1) })
  mobSession1:ExpectNotification("OnButtonEvent",{buttonName = pButtonName, buttonEventMode="BUTTONDOWN"}):Times(pTime1)
  mobSession2:ExpectNotification("OnButtonEvent",{buttonName = pButtonName, buttonEventMode="BUTTONDOWN"}):Times(pTime2)
  common.hmi.getConnection():SendNotification("Buttons.OnButtonPress",
    {name = pButtonName, mode = "LONG", appID = common.app.getHMIId(pAppId1)})
  mobSession1:ExpectNotification("OnButtonPress",{buttonName = pButtonName, buttonPressMode = "LONG"}):Times(pTime1)
  mobSession2:ExpectNotification("OnButtonPress",{buttonName = pButtonName, buttonPressMode = "LONG"}):Times(pTime2)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL and HMI", common.start)
runner.Step("Connect two mobile devices to SDL", common.connectMobDevices, {devices})
runner.Step("Register App1 from device 1", common.registerAppEx, {1, appParams[1], 1})
runner.Step("Register App2 from device 2", common.registerAppEx, {2, appParams[2], 2})

runner.Title("Test")
runner.Step("Activate App 1", common.app.activate, { 1 })
runner.Step("App 1 from Mobile 1 requests Subscribe on Ok",    subscribeOnButton,      {1, "OK" })
runner.Step("HMI send OnButtonEvent and OnButtonPress for OK", sendOnButtonEventPress, {1, 2, "OK", "one"})

runner.Step("Activate App 2", common.app.activate, { 2 })
runner.Step("App 1 from Mobile 1 requests Subscribe on Ok",    subscribeOnButton,      {2, "OK" })
runner.Step("HMI send OnButtonEvent and OnButtonPress for OK", sendOnButtonEventPress, {2, 1, "OK", "two"})

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
