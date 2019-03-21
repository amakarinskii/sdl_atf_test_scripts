---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0204-same-app-from-multiple-devices.md
--   Description:
-- Two mobile applications with the same appNames and different appIds from different mobiles send
-- SubscribeVehicleData requests and receive OnVehicleData notifications.
--   Precondition:
-- 1) SDL and HMI are started
-- 2) Mobiles №1 and №2 are connected to SDL
--   Steps:
-- 1) Mobile №1 App1 requested Subscribe on VehicleData("gps")
--   Check SDL:
--     send VeicleInfo.SubscribeVehicleData (appId_1, "gps" = true) to HMI
--     receives VeicleInfo.SubscribeVehicleData("SUCCESS") response from HMI
--     sends SubscribeVehicleData("SUCCESS") response to Mobile №1
--     sends OnHashChange with updated hashId to Mobile №1
-- 2) HMI sent OnVehicleData("gps") notification
--   Check SDL:
--     sends OnVehicleData("gps") notification to Mobile №1
--     does NOT send OnVehicleData to Mobile №2
-- 3) Mobile №2 App2 requested Subscribe on VehicleData("speed", "gps")
--   Check SDL:
--     sends VeicleInfo.SubscribeVehicleData (appId_1, "speed" = true) to HMI
--     receives VeicleInfo.SubscribeVehicleData("SUCCESS") response from HMI
--     sends SubscribeVehicleData("SUCCESS") response to Mobile №2
--     sends OnHashChange with updated hashId to Mobile №2
-- 4) HMI sent OnVehicleData("speed") notification
--   Check SDL:
--     sends OnVehicleData("speed") notification to Mobile №2
--     does NOT send OnVehicleData to Mobile №1
-- 5) HMI sent OnVehicleData("speed", "gps") notification
--   Check SDL:
--     sends OnVehicleData("speed") notification to Mobile №1
--     sends OnVehicleData("speed", "gps") notification to Mobile №2
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
  [2] = { appName = "Test Application", appID = "00022", fullAppID = "00000022" }
}

--[[ Local Functions ]]
local function modifyWayPointGroupInPT(pt)
  pt.policy_table.functional_groupings["DataConsent-2"].rpcs = common.json.null

  pt.policy_table.app_policies[appParams[1].fullAppID] = common.cloneTable(pt.policy_table.app_policies["default"])
  pt.policy_table.app_policies[appParams[1].fullAppID].groups = {"Base-4", "Location-1"}
  pt.policy_table.app_policies[appParams[2].fullAppID] = common.cloneTable(pt.policy_table.app_policies["default"])
  pt.policy_table.app_policies[appParams[2].fullAppID].groups = {"Base-4", "Location-1"}
end

local function sendSubscribeVehicleData1(pAppId, pFirstApp)
  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("SubscribeVehicleData", { speed = true })
  if pFirstApp then
    common.hmi.getConnection():ExpectRequest("VehicleInfo.SubscribeVehicleData", { speed = true })
    :Do(function(_,data)
         common.hmi.getConnection():SendResponse( data.id, data.method, "SUCCESS" )
      end)
  end
    mobSession:ExpectResponse( cid, { success = true, resultCode = "SUCCESS" })
    mobSession:ExpectNotification( "OnHashChange" )
end

local function sendSubscribeVehicleData2(pAppId, pFirstApp)
  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("SubscribeVehicleData", { speed = true, gps = true })
  if pFirstApp then
    common.hmi.getConnection():ExpectRequest(
                     "VehicleInfo.SubscribeVehicleData", { gps = true })
    :Do(function(_,data)
         common.hmi.getConnection():SendResponse( data.id, data.method, "SUCCESS" )
      end)
  end
    mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
    mobSession:ExpectNotification("OnHashChange")
end

local function sendOnVehicleData1(pAppId1, pAppId2, pNumberOfAppsSubscribed, pData)
  local mobSession1 = common.mobile.getSession(pAppId1)
  local mobSession2 = common.mobile.getSession(pAppId2)
  local pTime1, pTime2
  local pNAS = pNumberOfAppsSubscribed               -- defines how many apps should get this notification

  if     pNAS == 0 then pTime1 = 0; pTime2 = 0
  elseif pNAS == 1 then pTime1 = 1; pTime2 = 0
  elseif pNAS == 2 then pTime1 = 1; pTime2 = 1 end

  if "gps" == pData then
    common.hmi.getConnection():SendNotification("VehicleInfo.OnVehicleData",  {gps = {1.1, 1.1}} )
    mobSession1:ExpectNotification("OnVehicleData", {gps = {1.1, 1.1}} ):Times(pTime1)
    mobSession2:ExpectNotification("OnVehicleData", {gps = {1.1, 1.1}} ):Times(pTime2)
  else
    common.hmi.getConnection():SendNotification("VehicleInfo.OnVehicleData",  { speed = 60.5 } )
    mobSession1:ExpectNotification("OnVehicleData", { speed = 60.5 } ):Times(pTime1)
    mobSession2:ExpectNotification("OnVehicleData", { speed = 60.5 } ):Times(pTime2)
  end
end

local function sendOnVehicleData2(pAppId1, pAppId2, pNumberOfAppsSubscribed)
  local mobSession1 = common.mobile.getSession(pAppId1)
  local mobSession2 = common.mobile.getSession(pAppId2)
  local pTime1, pTime2
  local pNAS = pNumberOfAppsSubscribed               -- defines how many apps should get this notification

  if     pNAS == 0 then pTime1 = 0; pTime2 = 0
  elseif pNAS == 1 then pTime1 = 1; pTime2 = 0
  elseif pNAS == 2 then pTime1 = 1; pTime2 = 1 end

  common.hmi.getConnection():SendNotification("VehicleInfo.OnVehicleData", { speed = 60.5 , {gps = {1.1, 1.1}} })
  mobSession1:ExpectNotification("OnVehicleData",{ speed = 60.5 }):Times(pTime1)
  mobSession2:ExpectNotification("OnVehicleData",{ speed = 60.5 , gps = {1.1, 1.1} }):Times(pTime2)
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

runner.Title("Test")
runner.Step("App1 from Mobile 1 requests SubscribeVehicleData", sendSubscribeVehicleData1, { 1, true })
runner.Step("HMI sends OnVehicleData - App 1 receives",         sendOnVehicleData1, { 1, 2, 1, "speed" })

runner.Step("Activate App 2", common.app.activate, { 2 })
runner.Step("App2 from Mobile 2 requests SubscribeVehicleData", sendSubscribeVehicleData2, { 2, true })
runner.Step("HMI sends OnVehicleData - App 2 receives",         sendOnVehicleData1, { 2, 1, 1, "gps" })
runner.Step("HMI sends OnVehicleData - Apps 1 and 2 receive",   sendOnVehicleData2, { 1, 2, 2 })

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
