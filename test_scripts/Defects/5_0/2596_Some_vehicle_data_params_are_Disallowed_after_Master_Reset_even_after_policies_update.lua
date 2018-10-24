---------------------------------------------------------------------------------------------------
-- User story: https://github.com/SmartDeviceLink/sdl_core/issues/2596
--
-- Description:
-- Some vehicle data params are Disallowed after Master Reset even after policies update (1586634)
--
-- Expected result: 
-- SDL Defect:AppLink; Some vehicle data params are Disallowed after Master Reset even after 
-- policies update
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('user_modules/sequences/actions')
local utils = require('user_modules/utils')
local test = require("user_modules/dummy_connecttest")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function ptuFunc(tbl)
	tbl.policy_table.app_policies["0000001"].groups = {"Base-4", "Location-1", "DrivingCharacteristics-3", "VehicleInfo-3", "Emergency-1"}
end

local function serviceStart()
	common.getMobileSession():StartService(7)
end

local function masterReset() 
	common.getHMIConnection():SendNotification("BasicCommunication.OnExitAllApplications",
		{ reason = "MASTER_RESET" })

	common.getMobileSession():ExpectNotification("OnAppInterfaceUnregistered", 
		{ reason = "MASTER_RESET" })

	common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppUnregistered", 
		{ unexpectedDisconnect = false })

	utils.wait(2000)
end

local function cleanMobileSession()
	test.mobileSession = {}
end

local function getVehicleDataDisallowed()
	local CorIdGetVehicleDataVD = common.getMobileSession():SendRPC("GetVehicleData", { prndl = true })
	
	common.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData"):Times(0)

	common.getMobileSession():ExpectResponse(CorIdGetVehicleDataVD, { success = false, resultCode = "DISALLOWED" })
end

local function getVehicleDataAllowed()
	local CorIdGetVehicleDataVD = common.getMobileSession():SendRPC("GetVehicleData", { prndl = true })
	
	common.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData", { prndl = true })
		:Do(function(_, data)
	    	common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {} )
	    end)

	common.getMobileSession():ExpectResponse(CorIdGetVehicleDataVD, { success = true, resultCode = "SUCCESS" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI", common.registerApp)
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
runner.Step("Get Vehicle Data disallowed", getVehicleDataDisallowed)
runner.Step("PTU", common.policyTableUpdate, { ptuFunc })
runner.Step("Get Vehicle Data allowed", getVehicleDataAllowed)
runner.Step("Master Reset", masterReset)
runner.Step("Clean Mobile session", cleanMobileSession)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI", common.registerApp)
runner.Step("Activate App", common.activateApp)
runner.Step("Get Vehicle Data disallowed", getVehicleDataDisallowed)
runner.Step("PTU", common.policyTableUpdate, { ptuFunc })
runner.Step("Get Vehicle Data allowed", getVehicleDataAllowed)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
