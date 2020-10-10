-- Thermostat heat should handle actions: setThermostatMode, setHeatingThermostatSetpoint
-- Proeprties that should be updated:
-- * supportedThermostatModes - array of modes supported by the thermostat eg. {"Off", "Heat"}
-- * thermostatMode - current mode of the thermostat
-- * heatingThermostatSetpoint - set point for heating

-- handle action for mode change 
function QuickApp:setThermostatMode(mode)
    self:updateProperty("thermostatMode", mode)

    local modeNest = string.upper(mode)
    if modeNest == 'ECO' then
      --TODO
    else
      self.http:request("https://smartdevicemanagement.googleapis.com/v1/" .. self.thermostatId .. ":executeCommand" , {
        options = {
            checkCertificate = true,
            method = 'POST',
            headers = {
                 ['Content-Type'] = "application/json; charset=utf-8",
                 ['Authorization'] = self.accessToken
            },
            data = json.encode({
                    ['command'] = "sdm.devices.commands.ThermostatMode.SetMode",
                    ['params'] = {['mode'] = modeNest}
                })
        },
        success = function(response)
            if response.status == 200 then
                self:debug("setThermostatMode() succeed", json.encode(response.data))
            else
                self:error("setThermostatMode() failed: ", json.encode(response.data))
            end
        end,
        error = function(error)
            self:error("setThermostatMode() failed: ", json.encode(error))
        end
    })
    end
end

-- handle action for setting set point for heating
function QuickApp:setHeatingThermostatSetpoint(value) 
    self:updateProperty("heatingThermostatSetpoint", value)
    self.http:request("https://smartdevicemanagement.googleapis.com/v1/" .. self.thermostatId .. ":executeCommand" , {
        options = {
            checkCertificate = true,
            method = 'POST',
            headers = {
                 ['Content-Type'] = "application/json; charset=utf-8",
                 ['Authorization'] = self.accessToken
            },
            data = json.encode({
                    ['command'] = "sdm.devices.commands.ThermostatTemperatureSetpoint.SetHeat",
                    ['params'] = {['heatCelsius'] = value}
                })
        },
        success = function(response)
            if response.status == 200 then
                self:debug("setHeatingThermostatSetpoint() succeed", json.encode(response.data))
            else
                self:error("setHeatingThermostatSetpoint() failed: ", json.encode(response.data))
            end
        end,
        error = function(error)
            self:error("setHeatingThermostatSetpoint() failed: ", json.encode(error))
        end
    })
end

-- To update controls you can use method self:updateView(<component ID>, <component property>, <desired value>). Eg:  
-- self:updateView("slider", "value", "55") 
-- self:updateView("button1", "text", "MUTE") 
-- self:updateView("label", "text", "TURNED ON") 

-- This is QuickApp inital method. It is called right after your QuickApp starts (after each save or on gateway startup). 
-- Here you can set some default values, setup http connection or get QuickApp variables.
-- To learn more, please visit: 
--    * https://manuals.fibaro.com/home-center-3/
--    * https://manuals.fibaro.com/home-center-3-quick-apps/



-- Send a mail to request a new a new Refresh Token
function QuickApp:sendMailForRefreshToken()
    if self.authorizationCode ~= nil or self:getVariable("refreshToken") ~= "" then
        return
    end

    self:error("Need to refresh Nest Authorization Code")

    fibaro:call (2, "sendEmail", "Fibaro request link to google Nest", "https://nestservices.google.com/partnerconnections/" .. self.projectId .. "/auth?redirect_uri=https://www.google.com&access_type=offline&prompt=consent&client_id=" .. self.clientId .. "&response_type=code&scope=https://www.googleapis.com/auth/sdm.service")
end


function QuickApp:getRefreshToken()
    if self.authorizationCode == nil or self:getVariable("refreshToken") ~= "" then
        return
    end

    self:debug("Get Google refresh token")

    self.http:request("https://www.googleapis.com/oauth2/v4/token?client_id=" .. self.clientId .. "&client_secret=" .. self.clientSecret .. "&code=" .. self.authorizationCode .. "&grant_type=authorization_code&redirect_uri=https://www.google.com" , {
        options = {
            checkCertificate = true,
            method = 'POST',
            headers = {},
            data = nil
        },
        success = function(response)
            if response.status == 200 then
                body = json.decode(response.data)
                self.accessToken = "Bearer " .. body['access_token']
                self:setVariable("refreshToken", body['refresh_token'])
                self:debug("getRefreshToken() succeed")
                self:trace(self.accessToken .. "   " ..  self.refreshToken)
            else
                self:error("getRefreshToken() failed: ", response.status, response.data)
                self.authorizationCode=nil
            end
        end,
        error = function(error)
            self:error("getRefreshToken() failed: ", json.encode(error))
            self.authorizationCode=nil
        end
    })
end

function QuickApp:getAccessToken()
    if self:getVariable("refreshToken") == nil or self.accessToken ~= nil then
        return
    end

    self.http:request("https://www.googleapis.com/oauth2/v4/token?client_id=" .. self.clientId .. "&client_secret=" .. self.clientSecret .. "&refresh_token=" .. self:getVariable("refreshToken") .. "&grant_type=refresh_token" , {
        options = {
            checkCertificate = true,
            method = 'POST',
            headers = {},
            data = nil
        },
        success = function(response)
            if response.status == 200 then
                body = json.decode(response.data)
                self.accessToken = "Bearer " .. body['access_token']
                self:debug("getAccessToken() succeed")
                --self:trace(self.accessToken)
            else
                self:error("getAccessToken() failed: ", json.encode(response.data))
                self:setVariable("refreshToken", "")
            end
        end,
        error = function(error)
            self:error("getAccessToken() failed: ", json.encode(error))
            self:setVariable("refreshToken", "")
        end
    })
end

function QuickApp:updateMode(device) 
       thermostatMode = device['traits']['sdm.devices.traits.ThermostatMode']['mode']
       thermostatModeEco = device['traits']['sdm.devices.traits.ThermostatEco']['mode']

       if thermostatModeEco == 'MANUAL_ECO' then
         self:updateProperty("thermostatMode", "Eco")
       elseif thermostatMode == "HEAT" then
         self:updateProperty("thermostatMode", "Heat")
       elseif thermostatMode == "OFF" then
         self:updateProperty("thermostatMode", "Off")
       else
         self:error("updateMode() failed", "Unknown mode " .. thermostatMode .. " / " .. thermostatModeEco)
       end
end

function QuickApp:findThermostat(body)
  devices = body['devices']

  for i, device in ipairs(devices) do
    if device['type'] == 'sdm.devices.types.THERMOSTAT' then
       self.thermostatId = device['name']
       self:updateMode(device)
       self:updateProperty("heatingThermostatSetpoint", device['traits']['sdm.devices.traits.ThermostatTemperatureSetpoint']['heatCelsius'])
       --self:debug("findThermostat() success", self.thermostatId)
    end
  end
end


function QuickApp:updateThermostatInfo()
    if self.accessToken == nil then
        return
    end

    --self:debug("updateThermostatInfo")

    self.http:request("https://smartdevicemanagement.googleapis.com/v1/enterprises/" .. self.projectId .. "/devices" , {
        options = {
            checkCertificate = true,
            method = 'GET',
            headers = {
                 ['Content-Type'] = "application/json; charset=utf-8",
                 ['Authorization'] = self.accessToken
            },
            data = nil
        },
        success = function(response)
            if response.status == 200 then
                body = json.decode(response.data)
                --self:debug("updateThermostatInfo() succeed", json.encode(response.data))
                self:findThermostat(body)
            else
                self:error("updateThermostatInfo() failed: ", json.encode(response.data))
                self.accessToken=nil
            end
        end,
        error = function(error)
            self:error("updateThermostatInfo() failed: ", json.encode(error))
            self.accessToken=nil
        end
    })
end



function QuickApp:mainLoop()

    --login
    self:sendMailForRefreshToken()
    self:getRefreshToken()
    self:getAccessToken()

    --get thermostat
    self:updateThermostatInfo()

    fibaro.setTimeout(self.frequency * 1000, function()
        self:mainLoop()
    end)
end


function QuickApp:onInit()
    self:debug("onInit")

    self.projectId = self:getVariable("projectId")
    assert(self.projectId ~= "", "projectId is not set")
    
    self.clientId = self:getVariable("clientId")
    assert(self.clientId ~= "", "clientId is not set")

    self.clientSecret = self:getVariable("clientSecret")
    assert(self.clientSecret ~= "", "clientSecret is not set")

    self.authorizationCode = self:getVariable("code")
    assert(self.authorizationCode ~= "", "code is not set")

    self.frequency = self:getVariable("frequency")
    assert(self.frequency ~= "", "frequency is not set")
    self.frequency = tonumber(self.frequency)
    assert(self.frequency ~= nil, "frequency is not a number")

    self.accessToken = nil
    self.refreshToken = nil
    self.thermostatId = nil


    -- set supported modes for thermostat
    self:updateProperty("supportedThermostatModes", {"Off", "Heat", "Eco"})

    -- setup default values
    self:updateProperty("thermostatMode", "Off")
    self:updateProperty("heatingThermostatSetpoint", 10)

    self.http = net.HTTPClient({ timeout = 3000 })

    self:mainLoop()

end
