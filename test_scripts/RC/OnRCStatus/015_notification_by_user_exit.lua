---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary:
-- [SDL_RC] TBD
--
-- Description:
-- In case:
-- 1) RC app is registered
-- 2) App allocates module
-- 3) USER_EXIT is performed from HMI
-- SDL must:
-- 1) Send OnRCStatus notifications to RC app and to HMI by app deallocates module by performing USER_EXIT form HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/RC/OnRCStatus/commonOnRCStatus')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function alocateModule(pModuleType)
  local pModuleStatus = common.setModuleStatus(common.getAllModules(), {{ }}, pModuleType)
  common.rpcAllowed(pModuleType, 1, "SetInteriorVehicleData")
  common.validateOnRCStatusForApp(1, pModuleStatus)
  common.validateOnRCStatusForHMI(1, { pModuleStatus })
end

local function userExit()
  local hmiAppId = common.getHMIAppId()
  common.getHMIConnection():SendNotification("BasicCommunication.OnExitApplication",
    { appID = hmiAppId, reason = "USER_EXIT" })
  common.getMobileSession(1):ExpectNotification("OnHMIStatus",
    { systemContext = "MAIN", hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE" })
  local pModuleStatus = {
    freeModules = common.getModulesArray(common.getAllModules()),
    allocatedModules = { }
  }
  common.validateOnRCStatusForApp(1, pModuleStatus)
  common.validateOnRCStatusForHMI(1, { pModuleStatus })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Register RC application", common.registerRCApplication)
runner.Step("Activate App", common.activateApp)
runner.Step("App allocates module CLIMATE", alocateModule, { "CLIMATE" })

runner.Title("Test")
runner.Step("OnRCStatus notification by user exit", userExit)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
