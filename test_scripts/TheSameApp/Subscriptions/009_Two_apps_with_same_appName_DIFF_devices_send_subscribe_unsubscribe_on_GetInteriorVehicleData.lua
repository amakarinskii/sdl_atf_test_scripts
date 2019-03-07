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
  [1] = { appName = "Test Application", appID = "0001",  fullAppID = "0000001",  appHMIType = { "REMOTE_CONTROL" } },
  [2] = { appName = "Test Application", appID = "00022", fullAppID = "00000022", appHMIType = { "REMOTE_CONTROL" } }
}

local pReqPayload = {
  [1] = { moduleData = { moduleType = "RADIO" },   isSubscribed = true },
  [2] = { moduleData = { moduleType = "CLIMATE" }, isSubscribed = true }
}
local pReqPayloadNeg = {
  [1] = { moduleData = { moduleType = "RADIO" },   isSubscribed = false },
  [2] = { moduleData = { moduleType = "CLIMATE" }, isSubscribed = false }
}
local pRspPayload = {
  [1] = { moduleData = { moduleType = "RADIO" },   isSubscribed = true, success = true, resultCode = "SUCCESS" },
  [2] = { moduleData = { moduleType = "CLIMATE" }, isSubscribed = true, success = true, resultCode = "SUCCESS" }
}
local pRspPayloadNeg = {
  [1] = { moduleData = { moduleType = "RADIO" },   isSubscribed = false, success = true, resultCode = "SUCCESS" },
  [2] = { moduleData = { moduleType = "CLIMATE" }, isSubscribed = false, success = true, resultCode = "SUCCESS" }
}

local pNotificationPayload = {
  [1] = { moduleData = { moduleType = "RADIO", radioControlData = { radioEnable = true }}},
  [2] = { moduleData = { moduleType = "CLIMATE", climateControlData = { fanSpeed = 50 }}}
}

--[[ Local Functions ]]
local function modifyWayPointGroupInPT(pt)
  pt.policy_table.functional_groupings["DataConsent-2"].rpcs = common.json.null

  pt.policy_table.app_policies[appParams[1].fullAppID] = common.cloneTable(pt.policy_table.app_policies["default"])
  pt.policy_table.app_policies[appParams[1].fullAppID].groups     = { "Base-4", "RemoteControl" }
  pt.policy_table.app_policies[appParams[1].fullAppID].moduleType = { "RADIO", "CLIMATE" }
  pt.policy_table.app_policies[appParams[1].fullAppID].appHMIType = { "REMOTE_CONTROL" }
  pt.policy_table.app_policies[appParams[2].fullAppID] = common.cloneTable(pt.policy_table.app_policies["default"])
  pt.policy_table.app_policies[appParams[2].fullAppID].groups     = { "Base-4", "RemoteControl" }
  pt.policy_table.app_policies[appParams[2].fullAppID].moduleType = { "RADIO", "CLIMATE" }
  pt.policy_table.app_policies[appParams[2].fullAppID].appHMIType = { "REMOTE_CONTROL" }
end

local function getInteriorVehicleData(pAppId, pModuleType, pSubscribe, pIsAFirstApp)
  local pPayload
  if     pModuleType == "RADIO"   then pPayload = 1
  elseif pModuleType == "CLIMATE" then pPayload = 2
  end

  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("GetInteriorVehicleData", { moduleType = pModuleType, subscribe = pSubscribe })
  -- SDL -> HMI - should send this request only when 1st app get subscribed
  if pIsAFirstApp then
    common.hmi.getConnection():ExpectRequest("RC.GetInteriorVehicleData",
        { moduleType = pModuleType, subscribe = pSubscribe})
    :Do(function(_,data)
        common.hmi.getConnection():SendResponse( data.id, data.method, "SUCCESS", pReqPayload[pPayload] )
      end)
  end
    mobSession:ExpectResponse( cid, pRspPayload[pPayload] )
end

local function unsubscribeVehicleData(pAppId, pModuleType, pSubscribe, pIsLastApp)
  local pPayload
  if     pModuleType == "RADIO"   then pPayload = 1
  elseif pModuleType == "CLIMATE" then pPayload = 2
  end

  local mobSession = common.mobile.getSession(pAppId)
  local cid = mobSession:SendRPC("GetInteriorVehicleData", { moduleType = pModuleType, subscribe = pSubscribe })
  -- SDL -> HMI - should send this request only when 1st app get subscribed
  if pIsLastApp then
    common.hmi.getConnection():ExpectRequest("RC.GetInteriorVehicleData",
        { moduleType = pModuleType, subscribe = pSubscribe})
    :Do(function(_,data)
        common.hmi.getConnection():SendResponse( data.id, data.method, "SUCCESS", pReqPayloadNeg[pPayload] )
      end)
  end
    mobSession:ExpectResponse( cid, pRspPayloadNeg[pPayload] )
end

local function onInteriorVehicleData(pAppId1, pAppId2, pNumberOfAppsSubscribed, pModuleType)
  local pPayload
  if     pModuleType == "RADIO"   then pPayload = 1
  elseif pModuleType == "CLIMATE" then pPayload = 2
  end

  local mobSession1 = common.mobile.getSession(pAppId1)
  local mobSession2 = common.mobile.getSession(pAppId2)
  local pTime1, pTime2
  local pTime = pNumberOfAppsSubscribed                         -- defines how many apps should get this notification

  if     pTime == 0 then pTime1 = 0; pTime2 = 0
  elseif pTime == 1 then pTime1 = 1; pTime2 = 0
  elseif pTime == 2 then pTime1 = 1; pTime2 = 1 end

  common.hmi.getConnection():SendNotification("RC.OnInteriorVehicleData", pNotificationPayload[pPayload] )
  mobSession1:ExpectNotification("OnInteriorVehicleData", pNotificationPayload[pPayload] ):Times( pTime1 )
  mobSession2:ExpectNotification("OnInteriorVehicleData", pNotificationPayload[pPayload] ):Times( pTime2 )
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
runner.Step("App1 from Mobile 1 subscribes for RADIO",   getInteriorVehicleData, { 1, "RADIO",   true, "1st_app" })
runner.Step("App1 from Mobile 1 subscribes for CLIMATE", getInteriorVehicleData, { 1, "CLIMATE", true, "1st_app" })
runner.Step("Activate App 2", common.app.activate, { 2 })
runner.Step("App2 from Mobile 2 subscribes for RADIO",   getInteriorVehicleData, { 2, "RADIO",   true })
runner.Step("App2 from Mobile 2 subscribes for CLIMATE", getInteriorVehicleData, { 2, "CLIMATE", true })

runner.Title("Test")
runner.Step("HMI sends RADIO VehicleData - App 2 receive",    onInteriorVehicleData, { 2, 1, 2, "RADIO" }) --extra check
runner.Step("App1 from Mobile 1 unsubscribes from RADIO",    unsubscribeVehicleData, { 1, "RADIO", false })
runner.Step("HMI sends RADIO VehicleData - App 2 receive",    onInteriorVehicleData, { 2, 1, 1, "RADIO" })

runner.Step("App2 from Mobile 2 unsubscribes from CLIMATE",  unsubscribeVehicleData, { 2, "CLIMATE", false })
runner.Step("HMI sends CLIMATE VehicleData - App 1 receive",  onInteriorVehicleData, { 1, 2, 1, "CLIMATE" })

runner.Step("App1 from Mobile 1 unsubscribes from CLIMATE",  unsubscribeVehicleData, { 1, "CLIMATE", false, "last_app"})
runner.Step("HMI sends CLIMATE VehicleData - NOONE receives", onInteriorVehicleData, { 1, 2, 0, "CLIMATE" })

runner.Step("App2 from Mobile 2 unsubscribes from RADIO",    unsubscribeVehicleData, { 2, "RADIO",   false, "last_app"})
runner.Step("HMI sends RADIO VehicleData - NOONE receives",   onInteriorVehicleData, { 2, 1, 0, "RADIO" })

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
