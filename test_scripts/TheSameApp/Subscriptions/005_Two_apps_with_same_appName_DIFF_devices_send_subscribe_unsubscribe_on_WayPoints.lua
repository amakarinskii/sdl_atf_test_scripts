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

local wayPointsGroup = {
  rpcs = {
    GetWayPoints         = { hmi_levels = {"BACKGROUND", "FULL", "LIMITED"} },
    SubscribeWayPoints   = { hmi_levels = {"BACKGROUND", "FULL", "LIMITED"} },
    UnsubscribeWayPoints = { hmi_levels = {"BACKGROUND", "FULL", "LIMITED"} },
    OnWayPointChange     = { hmi_levels = {"BACKGROUND", "FULL", "LIMITED"} }
  }
}

local pWayPoints = { locationName = "Location Name", coordinate = { latitudeDegrees = 1.1, longitudeDegrees = 1.1 }}

--[[ Local Functions ]]
local function modifyWayPointGroupInPT(pt)
  pt.policy_table.functional_groupings["DataConsent-2"].rpcs = common.json.null

  pt.policy_table.functional_groupings["WayPoints"] = wayPointsGroup
  pt.policy_table.app_policies[appParams[1].fullAppID] = common.cloneTable(pt.policy_table.app_policies["default"])
  pt.policy_table.app_policies[appParams[1].fullAppID].groups = {"Base-4", "WayPoints"}
  pt.policy_table.app_policies[appParams[2].fullAppID] = common.cloneTable(pt.policy_table.app_policies["default"])
  pt.policy_table.app_policies[appParams[2].fullAppID].groups = {"Base-4", "WayPoints"}
end

local function sendSubscribeWayPoints(pAppId, pIsAFirstApp)
  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("SubscribeWayPoints", {})
  if pIsAFirstApp then                                                          -- SDL -> HMI - should send this request
    common.hmi.getConnection():ExpectRequest("Navigation.SubscribeWayPoints")   -- only when 1st app get subscribed
    :Do(function(_,data)
         common.hmi.getConnection():SendResponse(data.id, data.method, "SUCCESS", {})
      end)
  end
    mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
    mobSession:ExpectNotification("OnHashChange")
end

local function sendOnWayPointChange(pAppId1, pAppId2, pNumberOfAppsSubscribed)
  local mobSession1 = common.mobile.getSession(pAppId1)
  local mobSession2 = common.mobile.getSession(pAppId2)
  local pTime1, pTime2
  local pTime = pNumberOfAppsSubscribed               -- defines how many apps should get this notification

  if     pTime == 0 then pTime1 = 0; pTime2 = 0
  elseif pTime == 1 then pTime1 = 1; pTime2 = 0
  elseif pTime == 2 then pTime1 = 1; pTime2 = 1 end

  common.hmi.getConnection():SendNotification("Navigation.OnWayPointChange", { wayPoints = {pWayPoints} })
  mobSession1:ExpectNotification("OnWayPointChange",{ wayPoints = {pWayPoints} }):Times(pTime1)
  mobSession2:ExpectNotification("OnWayPointChange",{ wayPoints = {pWayPoints} }):Times(pTime2)
end

local function sendUnsubscribeWayPoints(pAppId)
  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("UnsubscribeWayPoints", {})
    common.hmi.getConnection():ExpectRequest("Navigation.UnsubscribeWayPoints")
    :Do(function(_,data)
         common.hmi.getConnection():SendResponse(data.id, data.method, "SUCCESS",{})
      end)
    mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
    mobSession:ExpectNotification("OnHashChange")
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Prepare preloaded PT", common.modifyPreloadedPt, {modifyWayPointGroupInPT})
runner.Step("Start SDL and HMI", common.start)
runner.Step("Connect two mobile devices to SDL", common.connectMobDevices, {devices})
runner.Step("Register App1 from device 1", common.registerAppEx, { 1, appParams[1], 1 })
runner.Step("Register App2 from device 2", common.registerAppEx, { 2, appParams[2], 2 })
runner.Step("Activate App 1", common.app.activate, { 1 })
runner.Step("App1 from Mobile 1 requests SubscribeWayPoints", sendSubscribeWayPoints, { 1, true })
runner.Step("Activate App 2", common.app.activate, { 2 })
runner.Step("App2 from Mobile 2 requests SubscribeWayPoints", sendSubscribeWayPoints, { 2 })

runner.Title("Test")
runner.Step("HMI sends OnWayPointChange - App 1 and 2 receive",    sendOnWayPointChange, { 2, 1, 2 })

runner.Step("Activate App 1", common.app.activate, { 1 })
runner.Step("App 1 from Mobile 1 unsubscribes from WayPoints", sendUnsubscribeWayPoints, { 1 })
runner.Step("HMI sends OnWayPointChange - App 1 does NOT receive", sendOnWayPointChange, { 2, 1, 1 })

runner.Step("Activate App 2", common.app.activate, { 2 })
runner.Step("App 2 from Mobile 2 unsubscribes from WayPoints",     sendUnsubscribeWayPoints, { 2 })
runner.Step("HMI sends OnWayPointChange - App 1 and 2 do NOT receive", sendOnWayPointChange, { 2, 1, 0 })

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
