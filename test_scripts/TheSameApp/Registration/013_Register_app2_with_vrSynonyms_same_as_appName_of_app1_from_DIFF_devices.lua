---------------------------------------------------------------------------------------------------
--   Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0204-same-app-from-multiple-devices.md
--   Description:
-- Two mobile applications with the same vrSysnonyms and different appIDs and appNames, are registering from different
-- mobile devices. Check if there was sent an OnAppRegistered notification containing the same vrSysnonyms field for
-- both applications
--   Precondition:
-- 1) SDL and HMI are started
-- 2) Mobile №1 and №2 are connected to SDL
--   In case:
-- 1) Mobile №1 sends RegisterAppInterface request (with all mandatories) with appID = 1, appName = "Test Application"
--    and vrSynonyms = "vrApp" to SDL
-- 2) SDL sends RegisterAppInterface(resultCode = SUCCESS) response to Mobile №1
-- 3) SDL sends OnAppRegistered(application.appName = "Test Application", vrSysnonyms = "vrApp") notification to HMI
-- 4) Mobile №2 sends RegisterAppInterface request (with all mandatories) with appID = 1, appName = "Test Application 2"
--    and vrSynonyms = "vrApp" to SDL
--   SDL does:
-- 1) Send RegisterAppInterface(resultCode = SUCCESS) response to Mobile №2
-- 2) SDL sends OnAppRegistered(application.appName = "Test Application 2", vrSysnonyms = "vrApp") notification to HMI
--    from Mobile №2
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
  [1] = { appName = "Test Application",   appID = "0001",  fullAppID = "0000001",  vrSynonyms = {"vrApp"} },
  [2] = { appName = "Test Application 2", appID = "00022", fullAppID = "00000022", vrSynonyms = {"Test Application"} }
}

--[[ Local Functions ]]
local function registerAppEx(pAppId, pAppParams, pMobConnId)
  local appParams = common.app.getParams(pAppId)
  for k, v in pairs(pAppParams) do
    appParams[k] = v
  end

  local session = common.mobile.createSession(pAppId, pMobConnId)
  session:StartService(7)
  :Do(function()
      local corId = session:SendRPC("RegisterAppInterface", appParams)
      local connection = session.mobile_session_impl.connection
      common.hmi.getConnection():ExpectNotification("BasicCommunication.OnAppRegistered",
        {
          application = {
            appName = appParams.appName,
            deviceInfo = {
              name = common.getDeviceName(connection.host, connection.port),
              id = common.getDeviceMAC(connection.host, connection.port)
            }
          },
          vrSynonyms = appParams.vrSynonyms
        })
      :Do(function(_, d1)
        common.app.setHMIId(d1.params.application.appID, pAppId)
        end)
      session:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          session:ExpectNotification("OnHMIStatus",
            { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
          session:ExpectNotification("OnPermissionsChange")
        end)
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL and HMI", common.start)
runner.Step("Connect two mobile devices to SDL", common.connectMobDevices, {devices})

runner.Title("Test")
runner.Step("Register App1 from device 1", registerAppEx, {1, appParams[1], 1})
runner.Step("Register App2 from device 2", registerAppEx, {2, appParams[2], 2})

runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
