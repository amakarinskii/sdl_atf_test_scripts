---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0204-same-app-from-multiple-devices.md
-- Description:
-- Check of sending RPC on different functional groups by two mobile applications having the same appIDs
-- and same appNames from different mobile devises.
--
-- Preconditions:
-- 1) Create new custom functional group TestGroup_1 which contains AddCommand RPC (FULL, BACKGROUND, LIMITED, NONE)
--    and does not contain AddSubMenu;
-- 2) Set this group for application with appID = 1
-- 3) SDL and HMI are started
-- 4) Mobile №1 and №2 are connected to SDL
-- 5) Mobile №1 and №2 are registered successfully
--
-- Steps:
-- 1) Mobile №1 sent AddCommand RPC
--   Check:
--    SDL resends AddCommand RPC to HMI for Mobile №1 app1
-- 2) Mobile №1 sent AddSubMenu RPC
--   Check:
--    SDL sends response RPC( resultCode = "DISALLOWED" ) to Mobile №1
-- 3) Mobile №2 sent AddCommand RPC
--   Check:
--    SDL resends AddCommand RPC to HMI for Mobile №2 app2
-- 4) Mobile №2 sent AddSubMenu RPC
--   Check:
--    SDL sends response RPC( resultCode = "DISALLOWED" ) to Mobile №2
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
	[1] = { appName = "Test Application", appID = "0001", fullAppID = "0000001" },
	[2] = { appName = "Test Application", appID = "0001", fullAppID = "0000001" }
}

local TestGroup_1 = { rpcs = { AddCommand = { hmi_levels = { "BACKGROUND", "FULL", "LIMITED", "NONE" } } } }

local addCommandParams = { cmdID = 111, menuParams = {menuName = "Play"} }
local addSubMenuParams = { menuID = 222, menuName = "Test" }

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
end

local function sendRPCPositive(pAppId, pPrefix, pRPCName, pRPCParams)
  local cid = common.mobile.getSession(pAppId):SendRPC(pRPCName, pRPCParams)
      common.hmi.getConnection():ExpectRequest(pPrefix..pRPCName, pRPCParams)
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
runner.Step("Register App1 from device 1", common.registerAppEx, {1, appParams[1], 1})
runner.Step("Register App2 from device 2", common.registerAppEx, {2, appParams[2], 2})

runner.Title("Test")
runner.Step("App1 sends 'AddCommand' RPC from Mobile 1, SUCCESS",    sendRPCPositive,
              { 1, "UI.", "AddCommand", addCommandParams })
runner.Step("App1 sends 'AddSubMenu' RPC from Mobile 1, DISALLOWED", sendRPCNegative,
              { 1, "AddSubMenu", addSubMenuParams })
runner.Step("App2 sends 'AddCommand' RPC from Mobile 2, SUCCESS",    sendRPCPositive,
              { 2, "UI.", "AddCommand", addCommandParams })
runner.Step("App2 sends 'AddSubMenu' RPC from Mobile 2, DISALLOWED", sendRPCNegative,
              { 2, "AddSubMenu", addSubMenuParams })

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
