-----------------------------------------------------------------------------
--                  NEST THERMOSTAT             -----------------------------
-----------------------------------------------------------------------------
class 'NestThermostat' (QuickAppChild)

-- __init is a constructor for this class. All new classes must have it.
function NestThermostat:__init(device)
    -- You should not insert code before QuickAppChild.__init. 
    QuickAppChild.__init(self, device) 

    self:trace("NestThermostat init")

    -- set supported modes for thermostat
    self:updateProperty("supportedThermostatModes", {"Off", "Heat", "Eco"})

    -- setup default values
    self:updateProperty("thermostatMode", "Off")
    self:updateProperty("heatingThermostatSetpoint", 8)
end

function NestThermostat:updateDevice(body)
    --self:debug("updateDevice " .. self.id .. " with body " .. json.encode(body))
    
    self:updateMode(body)
    local temp = body['traits']['sdm.devices.traits.ThermostatTemperatureSetpoint']['heatCelsius']
    self:updateProperty("heatingThermostatSetpoint", temp)
end

function NestThermostat:updateMode(body) 
    thermostatMode = body['traits']['sdm.devices.traits.ThermostatMode']['mode']
    thermostatModeEco = body['traits']['sdm.devices.traits.ThermostatEco']['mode']

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

-- handle action for mode change 
function NestThermostat:setThermostatMode(mode)
    self:debug("update mode " .. mode)
    

    local modeNest = string.upper(mode)
    if modeNest == 'ECO' then
      --TODO
    else
      self.parent.http:request("https://smartdevicemanagement.googleapis.com/v1/" .. self:getVariable("uid") .. ":executeCommand" , {
        options = {
            checkCertificate = true,
            method = 'POST',
            headers = {
                 ['Content-Type'] = "application/json; charset=utf-8",
                 ['Authorization'] = self.parent.accessToken
            },
            data = json.encode({
                    ['command'] = "sdm.devices.commands.ThermostatMode.SetMode",
                    ['params'] = {['mode'] = modeNest}
                })
        },
        success = function(response)
            if response.status == 200 then
                self:debug("setThermostatMode() succeed", json.encode(response.data))
                self:updateProperty("thermostatMode", mode)
            else
                self:error("setThermostatMode() status is " .. response.status .. ": ", json.encode(response.data))
            end
        end,
        error = function(error)
            self:error("setThermostatMode() failed: ", json.encode(error))
        end
    })
    end
end

-- handle action for setting set point for heating
function NestThermostat:setHeatingThermostatSetpoint(value) 
    self.parent.http:request("https://smartdevicemanagement.googleapis.com/v1/" .. self:getVariable("uid") .. ":executeCommand" , {
        options = {
            checkCertificate = true,
            method = 'POST',
            headers = {
                 ['Content-Type'] = "application/json; charset=utf-8",
                 ['Authorization'] = self.parent.accessToken
            },
            data = json.encode({
                    ['command'] = "sdm.devices.commands.ThermostatTemperatureSetpoint.SetHeat",
                    ['params'] = {['heatCelsius'] = value}
                })
        },
        success = function(response)
            if response.status == 200 then
                self:debug("setHeatingThermostatSetpoint() succeed", json.encode(response.data))
                self:updateProperty("heatingThermostatSetpoint", value)
            else
                self:error("setHeatingThermostatSetpoint() status is " .. response.status .. ": ", json.encode(response.data))
            end
        end,
        error = function(error)
            self:error("setHeatingThermostatSetpoint() failed: ", json.encode(error))
        end
    })
end
