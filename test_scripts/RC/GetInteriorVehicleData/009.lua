---------------------------------------------------------------------------------------------------
-- RPC: GetInteriorVehicleData
-- Script: 009
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local commonRC = require('test_scripts/RC/commonRC')
local runner = require('user_modules/script_runner')
local json = require('modules/json')
local commonTestCases = require('user_modules/shared_testcases/commonTestCases')

--[[ Local Functions ]]
local function step(module_type, self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleData", {
		moduleDescription =	{
			moduleType = module_type
		},
		subscribe = true
	})

	EXPECT_HMICALL("RC.GetInteriorVehicleData", {})
	:Times(0)

	EXPECT_RESPONSE(cid, { success = false, resultCode = "DISALLOWED" })

	commonTestCases:DelayedExp(commonRC.timeout)
end

local function ptu_update_func(tbl)
	tbl.policy_table.app_policies[config.application1.registerAppInterfaceParams.appID].moduleType = nil
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI, PTU", commonRC.rai_ptu, { ptu_update_func })
runner.Title("Test")
runner.Step("GetInteriorVehicleData_CLIMATE", step, {"CLIMATE"})
runner.Step("GetInteriorVehicleData_RADIO", step, {"RADIO"})
runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
