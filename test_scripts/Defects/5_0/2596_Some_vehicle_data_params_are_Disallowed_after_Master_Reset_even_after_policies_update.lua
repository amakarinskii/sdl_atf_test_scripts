---------------------------------------------------------------------------------------------------
-- User story: https://github.com/SmartDeviceLink/sdl_core/issues/2596
--
-- Description:
-- Description of the particular CASE of requirement that is covered
-- and conditions that will be used
--
-- Preconditions: (if applicable)
--
-- Steps:
--
-- Expected result: 
-- SDL Defect:AppLink; Some vehicle data params are Disallowed after Master Reset even after policies update
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('user_modules/sequences/actions')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function testCase() 

end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment, start SDL, HMI", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")
runner.Step("Positive scenario", testCase)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
