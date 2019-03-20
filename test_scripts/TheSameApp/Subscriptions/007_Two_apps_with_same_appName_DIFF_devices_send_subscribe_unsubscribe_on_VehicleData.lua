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

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Data ]]
local devices = {
  [1] = { host = "1.0.0.1",         port = config.mobilePort },
  [2] = { host = "192.168.100.199", port = config.mobilePort }
}

local appParams = {
	[1] = { appName = "Test Application", appID = "0001",  fullAppID = "0000001" },
	[2] = { appName = "Test Application 2", appID = "00022", fullAppID = "00000022" }
}

--[[ Local Functions ]]
local function modifyWayPointGroupInPT(pt)
  pt.policy_table.functional_groupings["DataConsent-2"].rpcs = common.json.null

  pt.policy_table.app_policies[appParams[1].fullAppID] = common.cloneTable(pt.policy_table.app_policies["default"])
  pt.policy_table.app_policies[appParams[1].fullAppID].groups = {"Base-4", "Location-1"}
  pt.policy_table.app_policies[appParams[2].fullAppID] = common.cloneTable(pt.policy_table.app_policies["default"])
  pt.policy_table.app_policies[appParams[2].fullAppID].groups = {"Base-4", "Location-1"}
end

local function sendSubscribeGPS(pAppId, pFirstApp)
  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("SubscribeVehicleData", { gps = true })
  if pFirstApp then
    common.hmi.getConnection():ExpectRequest("VehicleInfo.SubscribeVehicleData", { gps = true })
    :Do(function(_,data)
         common.hmi.getConnection():SendResponse( data.id, data.method, "SUCCESS" )
      end)
  end
    mobSession:ExpectResponse( cid, { success = true, resultCode = "SUCCESS" })
    mobSession:ExpectNotification( "OnHashChange" )
end

local function sendSubscribeGPSSpeed(pAppId, pFirstApp)
  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("SubscribeVehicleData", { speed = true, gps = true })
  if pFirstApp then
    common.hmi.getConnection():ExpectRequest(
                     "VehicleInfo.SubscribeVehicleData", { speed = true })
    :Do(function(_,data)
         common.hmi.getConnection():SendResponse( data.id, data.method, "SUCCESS" )
      end)
  end
    mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
    mobSession:ExpectNotification("OnHashChange")
end

local function sendOnVehicleData(pAppId1, pAppId2, pAppToBeNotified)
  local mobSession1 = common.mobile.getSession(pAppId1)
  local mobSession2 = common.mobile.getSession(pAppId2)
  local pTime1, pTime2
  local pNAS = pAppToBeNotified                    -- defines which app should get this notification

  if     pNAS == 0 then pTime1 = 0; pTime2 = 0
  elseif pNAS == 1 then pTime1 = 1; pTime2 = 0
  elseif pNAS == 2 then pTime1 = 0; pTime2 = 1
  end

  common.hmi.getConnection():SendNotification("VehicleInfo.OnVehicleData", { speed = 60.5 , {gps = {1.1, 1.1}} })
  mobSession1:ExpectNotification("OnVehicleData", { gps = {1.1, 1.1} } ):Times(pTime1)
  mobSession2:ExpectNotification("OnVehicleData", { speed = 60.5 } ):Times(pTime2)
end

local function sendUnsubscribeGPS(pAppId, pLastApp)
  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("UnsubscribeVehicleData", { gps = true })
  if pLastApp then
    common.hmi.getConnection():ExpectRequest(
                     "VehicleInfo.UnsubscribeVehicleData", { gps = true })
    :Do(function(_,data)
         common.hmi.getConnection():SendResponse( data.id, data.method, "SUCCESS" )
      end)
  end
    mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
    mobSession:ExpectNotification("OnHashChange")
end

local function sendUnsubscribeSpeed(pAppId)
  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("UnsubscribeVehicleData", { speed = true })
    common.hmi.getConnection():ExpectRequest("VehicleInfo.UnsubscribeVehicleData", { speed = true })
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
runner.Step("App1 from Mobile 1 requests SubscribeVehicleData", sendSubscribeGPS,      { 1, true })
runner.Step("Activate App 2", common.app.activate, { 2 })
runner.Step("App2 from Mobile 2 requests SubscribeVehicleData", sendSubscribeGPSSpeed, { 2, true })

runner.Title("Test")
runner.Step("App 2 from Mobile 2 unsubscribes from GPS", sendUnsubscribeGPS, { 2 })
runner.Step("HMI sends OnVehicleData - Apps 2 receives", sendOnVehicleData,  { 1, 2, 2 })
runner.Step("HMI sends OnVehicleData - Apps 1 receives", sendOnVehicleData,  { 1, 2, 1 })

runner.Step("App 1 from Mobile 1 unsubscribes from GPS", sendUnsubscribeGPS, { 1, true })
runner.Step("HMI sends OnVehicleData - Apps 2 receives", sendOnVehicleData,  { 1, 2, 2 })

runner.Step("App 2 from Mobile 2 unsubscribes from GPS", sendUnsubscribeSpeed, { 2 })
runner.Step("HMI sends OnVehicleData - Apps 1 and 2 do NOT receive", sendOnVehicleData, { 1, 2, 0 })

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
