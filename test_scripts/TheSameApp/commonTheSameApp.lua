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

function common.connectMobDevice(pMobConnId, deviceInfo)
	utils.addNetworkInterface(pMobConnId, deviceInfo.host)
	common.mobile.createConnection(pMobConnId, deviceInfo.host, deviceInfo.port)
	common.mobile.connect(pMobConnId)
end

function common.deleteMobDevice(pMobConnId)
	-- common.mobile.disconnect(pMobConnId)
	-- common.mobile.deleteConnection(pMobConnId)
	utils.deleteNetworkInterface(pMobConnId)
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
          -- common.hmi.getConnection():ExpectRequest("BasicCommunication.PolicyUpdate")
          --   :Do(function(_, d2)
          --     common.hmi.getConnection():SendResponse(d2.id, d2.method, "SUCCESS", { })
          --   end)
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

return common
