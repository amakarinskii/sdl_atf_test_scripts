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
local json = require("modules/json")
local utils = require('user_modules/utils')

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

local TestGroup_1 = {
  rpcs = {
    AddCommand   = { hmi_levels = { "FULL" }},
    AddSubMenu   = { hmi_levels = { "BACKGROUND", "LIMITED" }},
    SendLocation = { hmi_levels = { "NONE" }}
  }
}
local TestGroup_2 = {
  rpcs = {
    AddCommand   = { hmi_levels = { "NONE" }},
    AddSubMenu   = { hmi_levels = { "BACKGROUND", "LIMITED" }},
    SendLocation = { hmi_levels = { "FULL" }}
  }
}
local locationParams      = { locationName = "Location Name", longitudeDegrees = 1.1, latitudeDegrees = 1.1 }
local addCommandParams    = { cmdID  = 111, menuParams = {menuName = "Play"}}
local addSubMenuParams    = { menuID = 222, menuName   = "Test" }
local reqAddSubmenuParams = { menuID = 222, menuParams = {menuName = "Test"} }

--[[ Local Functions ]]
local function createNewGroup(pAppId, pTestGroupName, pTestGroup, pPolicyTable)
  local pt = pPolicyTable

  pt.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
  pt.policy_table.functional_groupings[pTestGroupName] = pTestGroup
  pt.policy_table.app_policies[pAppId] = utils.cloneTable(pt.policy_table.app_policies.default)
  pt.policy_table.app_policies[pAppId].groups = { pTestGroupName, "Notifications-RC" }
end

local function modificationOfPreloadedPT(pPolicyTable)
  createNewGroup( appParams[1].fullAppID, "TestGroup_1", TestGroup_1, pPolicyTable)
  createNewGroup( appParams[2].fullAppID, "TestGroup_2", TestGroup_2, pPolicyTable)
end

local function sendRPCPositive(pAppId, pPrefix, pRPCName, pRPCParams, pRequestParams)
  local cid = common.mobile.getSession(pAppId):SendRPC(pRPCName, pRPCParams)
      common.hmi.getConnection():ExpectRequest(pPrefix..pRPCName, pRequestParams)
  :Do(function(_, data)
       common.hmi.getConnection():SendResponse(data.id, data.method, "SUCCESS", {})
      end)
  common.mobile.getSession(pAppId):ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

local function sendRPCNegative(pAppId, pRPCName, pRPCParameters)
  local cid = common.mobile.getSession(pAppId):SendRPC(pRPCName, pRPCParameters)
  common.mobile.getSession(pAppId):ExpectResponse(cid, { success = false, resultCode = "DISALLOWED" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Prepare preloaded PT", common.modifyPreloadedPt, {modificationOfPreloadedPT})
runner.Step("Start SDL and HMI", common.start)
runner.Step("Connect two mobile devices to SDL", common.connectMobDevices, {devices})
runner.Step("Register App1 from device 1", common.registerAppEx, { 1, appParams[1], 1 })
runner.Step("Register App2 from device 2", common.registerAppEx, { 2, appParams[2], 2 })

runner.Title("Test")
runner.Step("App1 sends 'SendLocation' RPC from Mobile 1, SUCCESS",    sendRPCPositive,
              { 1, "Navigation.", "SendLocation", locationParams, locationParams })
runner.Step("App1 sends 'AddCommand' RPC from Mobile 1, DISALLOWED",   sendRPCNegative,
              { 1, "AddCommand", addCommandParams })

runner.Step("Activate App 1", common.app.activate, { 1 })
runner.Step("App1 sends 'AddCommand' RPC from Mobile 1, SUCCESS",      sendRPCPositive,
              { 1, "UI.", "AddCommand", addCommandParams, addCommandParams })
runner.Step("App1 sends 'SendLocation' RPC from Mobile 1, DISALLOWED", sendRPCNegative,
              { 1, "SendLocation", locationParams })

runner.Step("App2 sends 'AddCommand' RPC from Mobile 2, SUCCESS",      sendRPCPositive,
              { 2, "UI.", "AddCommand", addCommandParams, addCommandParams })
runner.Step("App2 sends 'SendLocation' RPC from Mobile 2, DISALLOWED", sendRPCNegative,
              { 2, "SendLocation", locationParams })

runner.Step("Activate App 2", common.app.activate, { 2 })
runner.Step("App1 sends 'AddSubMenu' RPC from Mobile 1, SUCCESS",      sendRPCPositive,
              { 1, "UI.", "AddSubMenu", addSubMenuParams, reqAddSubmenuParams})
runner.Step("App1 sends 'SendLocation' RPC from Mobile 1, DISALLOWED", sendRPCNegative,
              { 1, "SendLocation", locationParams })
runner.Step("App2 sends 'SendLocation' RPC from Mobile 2, SUCCESS",    sendRPCPositive,
              { 2, "Navigation.", "SendLocation", locationParams, locationParams })
runner.Step("App2 sends 'AddCommand' RPC from Mobile 2, DISALLOWED",   sendRPCNegative,
              { 2, "AddCommand", addCommandParams })

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
