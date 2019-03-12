---------------------------------------------------------------------------------------------------
-- Common actions module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local mobile = require("mobile_connection")
local tcp = require("tcp_connection")
local file_connection = require("file_connection")
local mobileSession = require("mobile_session")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local events = require("events")
local test = require("user_modules/dummy_connecttest")
local expectations = require('expectations')
local reporter = require("reporter")
local utils = require("user_modules/utils")

--[[ Module ]]
local m = {
  init = {},
  mobile = {},
  hmi = {},
  ptu = {},
  app = {},
  run = {},
  sdl = {},
  json = utils.json
}


--[[ Constants ]]
m.minTimeout = 500
m.timeout = 2000

--[[ Variables ]]
local hmiAppIds = {}
local originalValuesInSDLIni = {}

test.mobileConnections = {}
test.mobileSession = {}

--[[ Functions ]]

local function getMobConnectionFromSession(pMobSession)
  return pMobSession.mobile_session_impl.connection
end

local function getHmiAppIdKey(pAppId)
  local appParams = m.app.getParams(pAppId)
  local appId = appParams.fullAppID
  if not appId then appId = appParams.appID end

  local connection = getMobConnectionFromSession(m.mobile.getSession(pAppId))
  return utils.getDeviceName(connection.host, connection.port) .. tostring(appId)
end

local function MobRaiseEvent(self, pEvent, pEventName)
  if pEventName == nil then pEventName = "noname" end
    reporter.AddMessage(debug.getinfo(1, "n").name, pEventName)
    event_dispatcher:RaiseEvent(self, pEvent)
end

local function MobExpectEvent(self, pEvent, pEventName)
  if pEventName == nil then pEventName = "noname" end
  local ret = expectations.Expectation(pEventName, self)
  ret.event = pEvent
  event_dispatcher:AddEvent(self, pEvent, ret)
  test:AddExpectation(ret)
  return ret
end

local function prepareMobileConnectionsTable()
  if test.mobileConnection then
    if test.mobileConnection.connection then
      local defaultMobileConnection = test.mobileConnection
      defaultMobileConnection.RaiseEvent = MobRaiseEvent
      defaultMobileConnection.ExpectEvent = MobExpectEvent
      test.mobileConnections[1] = defaultMobileConnection
    end
  end
end

prepareMobileConnectionsTable()

local function getDefaultMobSessionConfig()
  local mobSesionConfig = {
    activateHeartbeat = false,
    sendHeartbeatToSDL = false,
    answerHeartbeatFromSDL = false,
    ignoreSDLHeartBeatACK = false
  }

  if config.defaultProtocolVersion > 2 then
    mobSesionConfig.activateHeartbeat = true
    mobSesionConfig.sendHeartbeatToSDL = true
    mobSesionConfig.answerHeartbeatFromSDL = true
    mobSesionConfig.ignoreSDLHeartBeatACK = true
  end
  return mobSesionConfig
end

--[[ @getPTUFromPTS: create policy table update table (PTU)
--! @parameters:
--! pTbl - table with policy table snapshot (PTS)
--! @return: table with PTU
--]]
local function getPTUFromPTS()
  local pTbl = {}
  local ptsFileName = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath") .. "/"
    .. commonFunctions:read_parameter_from_smart_device_link_ini("PathToSnapshot")
  if utils.isFileExist(ptsFileName) then

  print("------in getPTUFromPTS in IF -------")
    pTbl = utils.jsonFileToTable(ptsFileName)

  print("----------------pTbl ", pTbl)

  else
    utils.cprint(35, "PTS file was not found, PreloadedPT is used instead")
    local appConfigFolder = commonFunctions:read_parameter_from_smart_device_link_ini("AppConfigFolder")
    if appConfigFolder == nil or appConfigFolder == "" then
      appConfigFolder = commonPreconditions:GetPathToSDL()
    end
    local preloadedPT = commonFunctions:read_parameter_from_smart_device_link_ini("PreloadedPT")
    local ptsFile = appConfigFolder .. preloadedPT
    if utils.isFileExist(ptsFile) then
      pTbl = utils.jsonFileToTable(ptsFile)
    else
      utils.cprint(35, "PreloadedPT was not found, PTS is not created")
    end
  end
  if next(pTbl) ~= nil then
    pTbl.policy_table.consumer_friendly_messages.messages = nil
    pTbl.policy_table.device_data = nil
    pTbl.policy_table.module_meta = nil
    pTbl.policy_table.usage_and_error_counts = nil
    pTbl.policy_table.functional_groupings["DataConsent-2"].rpcs = utils.json.null
    pTbl.policy_table.module_config.preloaded_pt = nil
    pTbl.policy_table.module_config.preloaded_date = nil
  end
  return pTbl
end

--[[ Functions of run submodule ]]

function m.run.createEvent()
  local event = events.Event()
  event.matches = function(e1, e2) return e1 == e2 end
  return event
end

function m.run.runAfter(pFunc, pTimeOut)
  RUN_AFTER(pFunc, pTimeOut)
end

--[[ @wait: delay test step for specific timeout
--! @parameters:
--! pTimeOut - time to wait in ms
--! @return: none
--]]
function m.run.wait(pTimeOut)
  if not pTimeOut then pTimeOut = m.timeout end
  local event = m.run.createEvent()
  m.hmi.getConnection():ExpectEvent(event, "Delayed event"):Timeout(pTimeOut + 60000)
  m.run.runAfter(function() m.hmi.getConnection():RaiseEvent(event, "Delayed event") end, pTimeOut)
end

--[[ Functions of init submodule ]]

function m.init.SDL()
  test:runSDL()
  local ret = commonFunctions:waitForSDLStart(test)
  ret:Do(function()
      utils.cprint(35, "SDL started")
    end)
  return ret
end

function m.init.HMI()
  local ret = test:initHMI()
  ret:Do(function()
      utils.cprint(35, "HMI initialized")
    end)
  return ret
end

function m.init.HMI_onReady()
  local ret = test:initHMI_onReady()
  ret:Do(function()
      utils.cprint(35, "HMI is ready")
    end)
  return ret
end

function m.init.connectMobile()
  return m.mobile.connect()
end

function m.init.allowSDL()
  local ret = m.mobile.allowSDL()
  ret:Do(function()
      utils.cprint(35, "SDL allowed")
    end)
  return ret
end

--[[ Functions of hmi submodule ]]

function m.hmi.getConnection()
  return test.hmiConnection
end

--[[ Functions of mobile submodule ]]

function m.mobile.createConnection(pMobConnId, pMobConnHost, pMobConnPort)
  if pMobConnId == nil then pMobConnId = 1 end
  local filename = "mobile" .. pMobConnId .. ".out"
  local tcpConnection = tcp.Connection(pMobConnHost, pMobConnPort)
  local fileConnection = file_connection.FileConnection(filename, tcpConnection)
  local connection = mobile.MobileConnection(fileConnection)
  connection.RaiseEvent = MobRaiseEvent
  connection.ExpectEvent = MobExpectEvent
  connection.host = pMobConnHost
  connection.port = pMobConnPort
  event_dispatcher:AddConnection(connection)
  test.mobileConnections[pMobConnId] = connection
end

function m.mobile.connect(pMobConnId)
  if pMobConnId == nil then pMobConnId = 1 end
  local connection = m.mobile.getConnection(pMobConnId)

  connection:ExpectEvent(events.disconnectedEvent, "Disconnected")
  :Pin()
  :Times(AnyNumber())
  :Do(function()
      utils.cprint(35, "Mobile #" .. pMobConnId .. " disconnected")
    end)

  local ret = connection:ExpectEvent(events.connectedEvent, "Connected")
  ret:Do(function()
    utils.cprint(35, "Mobile #" .. pMobConnId .. " connected")
  end)
  connection:Connect()
  return ret
end

function m.mobile.disconnect(pMobConnId)
  if pMobConnId == nil then pMobConnId = 1 end
  local connection = m.mobile.getConnection(pMobConnId)
  local sessions = m.mobile.getApps(pMobConnId)
  for _, id in ipairs(sessions) do
    m.mobile.deleteSession(id)
  end
  -- remove pinned mobile disconnect expectation
  connection:Close()
end

function m.mobile.deleteConnection(pMobConnId)
  if pMobConnId == nil then pMobConnId = 1 end
  local connection = m.mobile.getConnection(pMobConnId)
  event_dispatcher:DeleteConnection(connection)
  test.mobileConnections[pMobConnId] = nil
end

function m.mobile.getConnection(pMobConnId)
  if pMobConnId == nil then pMobConnId = 1 end
  return test.mobileConnections[pMobConnId]
end

function m.mobile.allowSDL(pMobConnId)
  if pMobConnId == nil then pMobConnId = 1 end
  local connection = m.mobile.getConnection(pMobConnId)
  local event = m.run.createEvent()
  m.hmi.getConnection():SendNotification("SDL.OnAllowSDLFunctionality", {
    allowed = true,
    source = "GUI",
    device = {
      id = utils.getDeviceMAC(connection.host, connection.port),
      name = utils.getDeviceName(connection.host, connection.port)
    }
  })
  m.run.runAfter(function() m.hmi.getConnection():RaiseEvent(event, "Allow SDL event") end, 100)
  return m.hmi.getConnection():ExpectEvent(event, "Allow SDL event")
end

function m.mobile.getSession(pAppId)
  if pAppId == nil then pAppId = 1 end
  return test.mobileSession[pAppId]
end

function m.mobile.createSession(pAppId, pMobConnId, pMobSesionConfig)
  if pAppId == nil then pAppId = 1 end
  if pMobConnId == nil then pMobConnId = 1 end
  if pMobSesionConfig == nil then pMobSesionConfig = getDefaultMobSessionConfig() end

  local session = mobileSession.MobileSession(test, test.mobileConnections[pMobConnId])
  for k, v in pairs(pMobSesionConfig) do
    session[k] = v
  end

  test.mobileSession[pAppId] = session
  return session
end

function m.mobile.deleteSession(pAppId)
  if pAppId == nil then pAppId = 1 end
  m.mobile.getSession(pAppId):Stop()
  :Do(function()
      test.mobileSession[pAppId] = nil
    end)
end

function m.mobile.getApps(pMobConnId)
  local mobileSessions = {}

  for idx, mobSession in pairs(test.mobileSession) do
    if pMobConnId == nil
      or getMobConnectionFromSession(mobSession) == test.mobileConnections[pMobConnId] then
        mobileSessions[idx] = mobSession
    end
  end

  return mobileSessions
end

function m.mobile.getAppsCount(pMobConnId)
  local sesions = m.mobile.getApps(pMobConnId)
  local count = 0
  for _, _ in pairs(sesions) do
    count = count + 1
  end
 return count
end

--[[ Functions of ptu submodule ]]

function m.ptu.getAppData(pAppId)
  return {
    keep_context = false,
    steal_focus = false,
    priority = "NONE",
    default_hmi = "NONE",
    groups = { "Base-4", "Location-1" },
    AppHMIType = m.app.getParams(pAppId).appHMIType
  }
end

function m.ptu.policyTableUpdate(pPTUpdateFunc, pExpNotificationFunc)
  if pExpNotificationFunc then
    pExpNotificationFunc()
  end
  local ptsFileName = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath") .. "/"
    .. commonFunctions:read_parameter_from_smart_device_link_ini("PathToSnapshot")
  local ptuFileName = os.tmpname()
  local requestId = m.hmi.getConnection():SendRequest("SDL.GetURLS", { service = 7 })
  m.hmi.getConnection():ExpectResponse(requestId)
  :Do(function()
      m.hmi.getConnection():SendNotification("BasicCommunication.OnSystemRequest",
        { requestType = "PROPRIETARY", fileName = ptsFileName })
      local ptuTable = getPTUFromPTS()
      for i, _ in pairs(m.mobile. ()) do
        ptuTable.policy_table.app_policies[m.app.getParams(i).fullAppID] = m.ptu.getAppData(i)
      end
      if pPTUpdateFunc then
        pPTUpdateFunc(ptuTable)
      end
      utils.tableToJsonFile(ptuTable, ptuFileName)
      local event = m.run.createEvent()
      m.hmi.getConnection():ExpectEvent(event, "PTU event")
      for id, _ in pairs(m.mobile.getApps()) do
        m.mobile.getSession(id):ExpectNotification("OnSystemRequest", { requestType = "PROPRIETARY" })
        :Do(function()
            if not pExpNotificationFunc then
               m.hmi.getConnection():ExpectRequest("VehicleInfo.GetVehicleData", { odometer = true })
               m.hmi.getConnection():ExpectNotification("SDL.OnStatusUpdate", { status = "UP_TO_DATE" })
            end
            utils.cprint(35, "App ".. id .. " was used for PTU")
            m.hmi.getConnection():RaiseEvent(event, "PTU event")
            local corIdSystemRequest = m.mobile.getSession(id):SendRPC("SystemRequest", {
              requestType = "PROPRIETARY" }, ptuFileName)
            m.hmi.getConnection():ExpectRequest("BasicCommunication.SystemRequest")
            :Do(function(_, d3)
                m.hmi.getConnection():SendResponse(d3.id, "BasicCommunication.SystemRequest", "SUCCESS", { })
                m.hmi.getConnection():SendNotification("SDL.OnReceivedPolicyUpdate", { policyfile = d3.params.fileName })
              end)
            m.mobile.getSession(id):ExpectResponse(corIdSystemRequest, { success = true, resultCode = "SUCCESS" })
            :Do(function() os.remove(ptuFileName) end)
          end)
        :Times(AtMost(1))
      end
    end)
end

--[[ Functions of app submodule ]]

local function registerApp(pAppId, pMobConnId, hasPTU)
  if not pAppId then pAppId = 1 end
  if not pMobConnId then pMobConnId = 1 end
  local session = m.mobile.createSession(pAppId, pMobConnId)
  session:StartService(7)
  :Do(function()
      local corId = session:SendRPC("RegisterAppInterface", m.app.getParams(pAppId))
      m.hmi.getConnection():ExpectNotification("BasicCommunication.OnAppRegistered",
        { application = { appName = m.app.getParams(pAppId).appName } })
      :Do(function(_, d1)
          m.app.setHMIId(d1.params.application.appID, pAppId)
          if hasPTU then
            m.hmi.getConnection():ExpectRequest("BasicCommunication.PolicyUpdate")
              :Do(function(_, d2)
                m.hmi.getConnection():SendResponse(d2.id, d2.method, "SUCCESS", { })
              end)
          end
        end)
      session:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          session:ExpectNotification("OnHMIStatus",
            { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
          session:ExpectNotification("OnPermissionsChange")
          :Times(AnyNumber())
        end)
    end)
end

function m.app.register(pAppId, pMobConnId)
  registerApp(pAppId, pMobConnId, true)
end

function m.app.registerNoPTU(pAppId, pMobConnId)
  registerApp(pAppId, pMobConnId, false)
end

function m.app.activate(pAppId)
  if not pAppId then pAppId = 1 end
  local requestId = m.hmi.getConnection():SendRequest("SDL.ActivateApp", { appID = m.app.getHMIId(pAppId) })
  m.hmi.getConnection():ExpectResponse(requestId)
  local params = m.app.getParams(pAppId)
  local audioStreamingState = "NOT_AUDIBLE"
  if params.isMediaApplication or
      utils.isTableContains(params.appHMIType, "NAVIGATION") or
      utils.isTableContains(params.appHMIType, "COMMUNICATION") then
    audioStreamingState = "AUDIBLE"
  end
  m.mobile.getSession(pAppId):ExpectNotification("OnHMIStatus",
    { hmiLevel = "FULL", audioStreamingState = audioStreamingState, systemContext = "MAIN" })
  m.run.wait()
end

function m.app.unRegister(pAppId)
  if pAppId == nil then pAppId = 1 end
  local session = m.mobile.getSession(pAppId)
  local cid = session:SendRPC("UnregisterAppInterface", {})
  session:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  :Do(function()
      m.mobile.deleteSession(pAppId)
    end)
  m.hmi.getConnection():ExpectNotification("BasicCommunication.OnAppUnregistered",
    { unexpectedDisconnect = false, appID = m.app.getHMIId(pAppId) })
  :Do(function()
      m.app.setHMIId(nil, pAppId)
    end)
end

function m.app.getParams(pAppId)
  if not pAppId then pAppId = 1 end
  return config["application" .. pAppId].registerAppInterfaceParams
end

function m.app.getHMIIds()
  return hmiAppIds
end

function m.app.getHMIId(pAppId)
  if not pAppId then pAppId = 1 end
  return hmiAppIds[getHmiAppIdKey(pAppId)]
end

function m.app.setHMIId(pHMIAppId, pAppId)
  if not pAppId then pAppId = 1 end
  hmiAppIds[getHmiAppIdKey(pAppId)] = pHMIAppId
end

function m.app.deleteHMIId(pAppId)
  hmiAppIds[getHmiAppIdKey(pAppId)] = nil
end

--[[ Functions of sdl submodule ]]

function m.sdl.getPathToFileInStorage(pFileName, pAppId)
  if not pAppId then pAppId = 1 end
  return commonPreconditions:GetPathToSDL() .. "storage/" .. m.app.getParams( pAppId ).fullAppID .. "_"
    .. utils.getDeviceMAC() .. "/" .. pFileName
end

function m.sdl.getSDLIniParameter(pParamName)
  return commonFunctions:read_parameter_from_smart_device_link_ini(pParamName)
end

--[[ @setSDLConfigParameter: change original value of parameter in SDL .ini file
--! @parameters:
--! pParamName - name of the parameter
--! pParamValue - value to be set
--! @return: none
--]]
function m.sdl.setSDLIniParameter(pParamName, pParamValue)
  originalValuesInSDLIni[pParamName] = m.sdl.getSDLIniParameter(pParamName)
  commonFunctions:write_parameter_to_smart_device_link_ini(pParamName, pParamValue)
end

--[[ @restoreSDLConfigParameters: restore original values of parameters in SDL .ini file
--! @parameters: none
--! @return: none
--]]
function m.sdl.restoreSDLIniParameters()
  for pParamName, pParamValue in pairs(originalValuesInSDLIni) do
    commonFunctions:write_parameter_to_smart_device_link_ini(pParamName, pParamValue)
  end
end

function m.sdl.getPreloadedPTPath()
  if not m.sdl.preloadedPTPath then
    local preloadedPTName = m.sdl.getSDLIniParameter("PreloadedPT")
    m.sdl.preloadedPTPath = commonPreconditions:GetPathToSDL() .. preloadedPTName
  end
  return m.sdl.preloadedPTPath
end

function m.sdl.backupPreloadedPT()
  if not m.sdl.isPreloadedPTBackuped then
    commonPreconditions:BackupFile(m.sdl.getSDLIniParameter("PreloadedPT"))
    m.sdl.isPreloadedPTBackuped = true
  end
end

function m.sdl.restorePreloadedPT()
  if m.sdl.isPreloadedPTBackuped then
    commonPreconditions:RestoreFile(m.sdl.getSDLIniParameter("PreloadedPT"))
  end
end

function m.sdl.getPreloadedPT()
  return utils.jsonFileToTable(m.sdl.getPreloadedPTPath())
end

function m.sdl.setPreloadedPT(pPreloadedPTTable)
  m.sdl.backupPreloadedPT()
  utils.tableToJsonFile(pPreloadedPTTable, m.sdl.getPreloadedPTPath())
end

--[[ Functions of ATF extension ]]

function event_dispatcher:DeleteConnection(connection)
  --ToDo: Implement
end

--[[ @ExpectRequest: register expectation for request on HMI connection
--! @parameters:
--! pName - name of the request
--! ... - expected data
--! @return: Expectation object
--]]
function test.hmiConnection:ExpectRequest(pName, ...)
  local event = events.Event()
  event.matches = function(_, data) return data.method == pName end
  local args = table.pack(...)
  local ret = expectations.Expectation("HMI call " .. pName, self)
  if #args > 0 then
    ret:ValidIf(function(e, data)
        local arguments
        if e.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[e.occurences]
        end
        reporter.AddMessage("EXPECT_HMICALL",
          { ["Id"] = data.id, ["name"] = tostring(pName),["Type"] = "EXPECTED_RESULT" }, arguments)
        reporter.AddMessage("EXPECT_HMICALL",
          { ["Id"] = data.id, ["name"] = tostring(pName),["Type"] = "AVAILABLE_RESULT" }, data.params)
        return compareValues(arguments, data.params, "params")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(self, event, ret)
  test:AddExpectation(ret)
  return ret
end

--[[ @ExpectNotification: register expectation for notification on HMI connection
--! @parameters:
--! pName - name of the notification
--! ... - expected data
--! @return: Expectation object
--]]
function test.hmiConnection:ExpectNotification(pName, ...)
  local event = events.Event()
  event.matches = function(_, data) return data.method == pName end
  local args = table.pack(...)
  local ret = expectations.Expectation("HMI notification " .. pName, self)
  if #args > 0 then
    ret:ValidIf(function(e, data)
        local arguments
        if e.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[e.occurences]
        end
        local cid = test.notification_counter
        test.notification_counter = test.notification_counter + 1
        reporter.AddMessage("EXPECT_HMINOTIFICATION",
          { ["Id"] = cid, ["name"] = tostring(pName), ["Type"] = "EXPECTED_RESULT" }, arguments)
        reporter.AddMessage("EXPECT_HMINOTIFICATION",
          { ["Id"] = cid, ["name"] = tostring(pName), ["Type"] = "AVAILABLE_RESULT" }, data.params)
        return compareValues(arguments, data.params, "params")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(self, event, ret)
  test:AddExpectation(ret)
  return ret
end

--[[ @ExpectResponse: register expectation for notification on HMI connection
--! @parameters:
--! pName - name of the notification
--! ... - expected data
--! @return: Expectation object
--]]
function test.hmiConnection:ExpectResponse(pId, ...)
  local event = events.Event()
  event.matches = function(_, data) return data.id == pId end
  local args = table.pack(...)
  local ret = expectations.Expectation("HMI response " .. pId, self)
  if #args > 0 then
    ret:ValidIf(function(e, data)
        local arguments
        if e.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[e.occurences]
        end
        reporter.AddMessage("EXPECT_HMIRESPONSE", { ["Id"] = data.id, ["Type"] = "EXPECTED_RESULT" }, arguments)
        reporter.AddMessage("EXPECT_HMIRESPONSE", { ["Id"] = data.id, ["Type"] = "AVAILABLE_RESULT" }, data.result)
        return compareValues(arguments, data, "data")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(self, event, ret)
  test:AddExpectation(ret)
  return ret
end

function test.hmiConnection:RaiseEvent(pEvent, pEventName)
  if pEventName == nil then pEventName = "noname" end
  reporter.AddMessage(debug.getinfo(1, "n").name, pEventName)
  event_dispatcher:RaiseEvent(self, pEvent)
end

function test.hmiConnection:ExpectEvent(pEvent, pEventName)
  if pEventName == nil then pEventName = "noname" end
  local ret = expectations.Expectation(pEventName, self)
  ret.event = pEvent
  event_dispatcher:AddEvent(self, pEvent, ret)
  test:AddExpectation(ret)
  return ret
end

--[[ Functions to support backward compatibility with old scripts ]]

--[[ @getConfigAppParams: return app's configuration from defined in config file
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: application identifier from configuration file
--]]
m.getConfigAppParams = m.app.getParams

--[[ @getAppDataForPTU: provide application data for PTU
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
m.getAppDataForPTU = m.ptu.getAppData

--[[ @policyTableUpdate: perform PTU
--! @parameters:
--! pPTUpdateFunc - function with additional updates (optional)
--! pExpNotificationFunc - function with specific expectations (optional)
--! @return: none
--]]
m.policyTableUpdate = m.ptu.policyTableUpdate

--[[ @registerApp: register mobile application
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
m.registerApp = m.app.register

--[[ @registerAppWOPTU: register mobile application and do not perform PTU
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
m.registerAppWOPTU = m.app.registerNoPTU

--[[ @activateApp: activate application
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
m.activateApp = m.app.activate

--[[ @start: starting sequence: starting of SDL, initialization of HMI, connect mobile
--! @parameters:
--! pHMIParams - table with parameters for HMI initialization
--! @return: Start event expectation
--]]
function m.start(pHMIParams)
  local event = m.run.createEvent()
  m.init.SDL()
  :Do(function()
      m.init.HMI()
      :Do(function()
          m.init.HMI_onReady()
          :Do(function()
              m.init.connectMobile()
              :Do(function()
                  m.init.allowSDL()
                  :Do(function()
                      m.hmi.getConnection():RaiseEvent(event, "Start event")
                    end)
                end)
            end)
        end)
    end)
  return m.hmi.getConnection():ExpectEvent(event, "Start event")
end

--[[ @preconditions: precondition steps
--! @parameters: none
--! @return: none
--]]
function m.preconditions()
  commonFunctions:SDLForceStop()
  commonSteps:DeletePolicyTable()
  commonSteps:DeleteLogsFiles()
end

--[[ @postconditions: postcondition steps
--! @parameters: none
--! @return: none
--]]
function m.postconditions()
  StopSDL()
  m.sdl.restoreSDLIniParameters()
  m.sdl.restorePreloadedPT()
end

--[[ @getMobileSession: get mobile session
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: mobile session object
--]]
function m.getMobileSession(pAppId, pMobConnId)
  if not pAppId then pAppId = 1 end
  local session = m.mobile.getSession(pAppId)
  if not session then
    session = m.mobile.createSession(pAppId, pMobConnId)
  end
  return session
end

--[[ @getMobileConnection: return Mobile connection object
--! @parameters: none
--! @return: Mobile connection object
--]]
m.getMobileConnection = m.mobile.getConnection

--[[ @getAppsCount: provide count of registered applications
--! @parameters: none
--! @return: count of apps
--]]
m.getAppsCount = m.mobile.getAppsCount

--[[ @getHMIConnection: return HMI connection object
--! @parameters: none
--! @return: HMI connection object
--]]
m.getHMIConnection = m.hmi.getConnection

--[[ @getHMIAppId: get HMI application identifier
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: application identifier
--]]
m.getHMIAppId = m.app.getHMIId

--[[ @setHMIAppId: set HMI application identifier
--! @parameters:
--! pHMIAppId - HMI application identifier
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
m.setHMIAppId = m.app.setHMIId

--[[ @getHMIAppIds: return array of all HMI application identifiers
--! @parameters: none
--! @return: array of all HMI application identifiers
--]]
m.getHMIAppIds = m.app.getHMIIds

--[[ @deleteHMIAppId: remove HMI application identifier
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
m.deleteHMIAppId = m.app.deleteHMIId

--[[ @getPathToFileInStorage: full path to file in storage folder
--! @parameters:
--! @pFileName - file name
--! @pAppId - application number (1, 2, etc.)
--! @return: path
--]]
m.getPathToFileInStorage = m.sdl.getPathToFileInStorage

--[[ @setSDLConfigParameter: change original value of parameter in SDL .ini file
--! @parameters:
--! pParamName - name of the parameter
--! pParamValue - value to be set
--! @return: none
--]]
m.setSDLIniParameter = m.sdl.setSDLIniParameter

--[[ @restoreSDLConfigParameters: restore original values of parameters in SDL .ini file
--! @parameters: none
--! @return: none
--]]
m.restoreSDLIniParameters = m.sdl.restoreSDLIniParameters

return m
