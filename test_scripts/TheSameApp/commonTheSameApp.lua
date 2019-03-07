---------------------------------------------------------------------------------------------------
-- Common module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local test = require("user_modules/dummy_connecttest")
local utils = require('user_modules/utils')
local actions = require('user_modules/sequences/actions')
local events = require("events")

--[[ General configuration parameters ]]
config.defaultProtocolVersion = 2

--[[ Module ]]
local common = actions

--[[ Proxy Functions ]]
common.getDeviceName = utils.getDeviceName
common.getDeviceMAC = utils.getDeviceMAC
common.cloneTable = utils.cloneTable
common.isTableContains = utils.isTableContains

--[[ Common Functions ]]
function common.start()
  local event = events.Event()
  event.matches = function(e1, e2) return e1 == e2 end
  common.init.SDL()
  :Do(function()
      common.init.HMI()
      :Do(function()
          common.init.HMI_onReady()
          :Do(function()
              common.hmi.getConnection():RaiseEvent(event, "Start event")
            end)
        end)
    end)
  return common.hmi.getConnection():ExpectEvent(event, "Start event")
end

function common.modifyPreloadedPt(modificationFunc)
  common.sdl.backupPreloadedPT()
  local pt = common.sdl.getPreloadedPT()
  modificationFunc(pt)
  common.sdl.setPreloadedPT(pt)
end

function common.connectMobDevice(pMobConnId, deviceInfo, isSDLAllowed)
  if isSDLAllowed == nil then isSDLAllowed = true end
  utils.addNetworkInterface(pMobConnId, deviceInfo.host)
  common.mobile.createConnection(pMobConnId, deviceInfo.host, deviceInfo.port)
  local mobConnectExp = common.mobile.connect(pMobConnId)
  if isSDLAllowed then
    mobConnectExp:Do(function()
        common.init.allowSDL()
      end)
  end
end

function common.deleteMobDevice(pMobConnId)
  -- common.mobile.disconnect(pMobConnId)
  -- common.mobile.deleteConnection(pMobConnId)
  utils.deleteNetworkInterface(pMobConnId)
end

function common.connectMobDevices(pDevices)
  for i = 1, #pDevices do
    common.connectMobDevice(i, pDevices[i])
  end
end

function common.clearMobDevices(pDevices)
  for i = 1, #pDevices do
    common.deleteMobDevice(i)
  end
end

function common.registerAppEx(pAppId, pAppParams, pMobConnId)
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
          }
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

function common.deactivateApp(pAppId, pNotifParams)
  common.getHMIConnection():SendNotification("BasicCommunication.OnAppDeactivated",
    { appID = common.getHMIAppId(pAppId)})
  common.mobile.getSession(pAppId):ExpectNotification("OnHMIStatus", pNotifParams)
end

function common.exitApp(pAppId)
common.getHMIConnection():SendNotification("BasicCommunication.OnExitApplication",
  { appID = common.getHMIAppId(pAppId), reason = "USER_EXIT"})
common.mobile.getSession(pAppId):ExpectNotification("OnHMIStatus",
  { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN"})
end

function common.changeRegistrationSuccess(pAppId, pParams)
  local cid = common.mobile.getSession(pAppId):SendRPC("ChangeRegistration", pParams)

  common.hmi.getConnection():ExpectRequest("VR.ChangeRegistration", {
    language = pParams.language,
    vrSynonyms = pParams.vrSynonyms,
    appID = common.getHMIAppId(pAppId)
  })
  :Do(function(_, data)
     common.hmi.getConnection():SendResponse(data.id, data.method, "SUCCESS", {})
    end)

  common.hmi.getConnection():ExpectRequest("TTS.ChangeRegistration", {
    language = pParams.language,
    ttsName = pParams.ttsName,
    appID = common.getHMIAppId(pAppId)
  })
  :Do(function(_, data)
      common.hmi.getConnection():SendResponse(data.id, data.method, "SUCCESS", {})
    end)

  common.hmi.getConnection():ExpectRequest("UI.ChangeRegistration", {
    appName = pParams.appName,
    language = pParams.hmiDisplayLanguage,
    ngnMediaScreenAppName = pParams.ngnMediaScreenAppName,
    appID = common.app.getHMIId(pAppId)
  })
  :Do(function(_, data)
      common.hmi.getConnection():SendResponse(data.id, data.method, "SUCCESS", {})
    end)

  common.mobile.getSession(pAppId):ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

function common.mobile.disallowSDL(pMobConnId)
  if pMobConnId == nil then pMobConnId = 1 end
  local connection = common.mobile.getConnection(pMobConnId)
  local event = common.run.createEvent()
  common.hmi.getConnection():SendNotification("SDL.OnAllowSDLFunctionality", {
    allowed = false,
    source = "GUI",
    device = {
      id = utils.getDeviceMAC(connection.host, connection.port),
      name = utils.getDeviceName(connection.host, connection.port)
    }
  })
  common.run.runAfter(function() common.hmi.getConnection():RaiseEvent(event, "Disallow SDL event") end, 100)
  return common.hmi.getConnection():ExpectEvent(event, "Disallow SDL event")
end

function common.getSystemCapability(pAppId, pResultCode)
  local isSuccess = false
  if pResultCode == "SUCCESS" then
    isSuccess = true
  end

  local mobileSession = common.mobile.getSession(pAppId)
  local cid = mobileSession:SendRPC("GetSystemCapability", { systemCapabilityType = "NAVIGATION" })
  mobileSession:ExpectResponse(cid, {success = isSuccess, resultCode = pResultCode})
end

function common.sendLocation(pAppId, pResultCode)
  local isSuccess = false
  if pResultCode == "SUCCESS" then
    isSuccess = true
  end

  local mobileSession = common.mobile.getSession(pAppId)
  local corId = mobileSession:SendRPC("SendLocation", {
      longitudeDegrees = 1.1,
      latitudeDegrees = 1.1
    })
  if pResultCode == "SUCCESS" then
    common.hmi.getConnection():ExpectRequest("Navigation.SendLocation")
    :Do(function(_,data)
        common.hmi.getConnection():SendResponse(data.id, data.method, "SUCCESS", {})
      end)
  end
  mobileSession:ExpectResponse(corId, {success = isSuccess , resultCode = pResultCode})
end

function common.show(pAppId, pResultCode)
  local isSuccess = false
  if pResultCode == "SUCCESS" then
    isSuccess = true
  end

  local mobileSession = common.mobile.getSession(pAppId)
  local corId = mobileSession:SendRPC("Show", {mediaClock = "00:00:01", mainField1 = "Show1"})
  if pResultCode == "SUCCESS" then
    common.hmi.getConnection():ExpectRequest("UI.Show")
    :Do(function(_,data)
        common.hmi.getConnection():SendResponse(data.id, "UI.Show", "SUCCESS", {})
      end)
  end
  mobileSession:ExpectResponse(corId, { success = isSuccess, resultCode = pResultCode})
end

function common.funcGroupConsentForApp(pPrompts, pAppId)

  local function findFunctionalGroupId(pAllowedFunctions, pGroupName)
    for _, allowedFunc in pairs(pAllowedFunctions) do
      if allowedFunc.name == pGroupName then
        return allowedFunc.id
      end
    end
    return nil
  end

  local hmiAppID = nil
  if pAppId then
    hmiAppID = common.app.getHMIId(pAppId)
    if not hmiAppID then
      common.run.fail("Unknown mobile application number:" .. pAppId)
    end
  end

  local corId = common.hmi.getConnection():SendRequest("SDL.GetListOfPermissions", { appID = hmiAppID})
  common.hmi.getConnection():ExpectResponse(corId)
  :Do(function(_,data)
      local consentedFunctions = common.cloneTable(pPrompts)
      local allowedFunctions = data.result.allowedFunctions
      for _, promptItem in pairs(consentedFunctions) do
        local groupId = findFunctionalGroupId(allowedFunctions, promptItem.name)
        if not groupId then
          common.run.fail("Unknown user consent prompt:" .. promptItem.name)
          return
        end
        promptItem.id = groupId
      end

      common.hmi.getConnection():SendNotification("SDL.OnAppPermissionConsent",
        {
          appID = hmiAppID,
          source = "GUI",
          consentedFunctions = consentedFunctions
        })
    end)
end

return common
