---------------------------------------------------------------------------------------------------
-- User story: Link to Github
-- Use case: Link to Github
--
-- Requirement summary:
-- Name(s) of requirement that is covered
-- Name(s) of additional non-functional requirement(s) if applicable
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
-- Expected SDL behaviour
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('user_modules/sequences/actions')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
-- if not applicable remove this section

--[[ Local Functions ]]
-- if not applicable remove this section
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
