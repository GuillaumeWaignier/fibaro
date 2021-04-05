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

    if thermostatMode == "OFF" then
        self:updateProperty("thermostatMode", "Off")
    elseif thermostatModeEco == 'MANUAL_ECO' then
        self:updateProperty("thermostatMode", "Eco")
    elseif thermostatMode == "HEAT" then
        self:updateProperty("thermostatMode", "Heat")
    else
      self:error("updateMode() failed", "Unknown mode " .. thermostatMode .. " / " .. thermostatModeEco)
    end
end

-- handle action for mode change 
function NestThermostat:setThermostatMode(mode)
    self:debug("update mode " .. mode)
    
    local modeNest = string.upper(mode)
    if modeNest == 'ECO' then
        self:callNestApi("sdm.devices.commands.ThermostatMode.SetMode",
            "mode",
            "HEAT",
            function()
                self:callNestApi("sdm.devices.commands.ThermostatEco.SetMode",
                    "mode",
                    "MANUAL_ECO",
                    function()
                        self:updateProperty("thermostatMode", mode)
                    end
                )
            end
        )
    elseif mode == 'Off' then
        self:callNestApi("sdm.devices.commands.ThermostatMode.SetMode",
            "mode",
            "OFF",
            function()
                 self:updateProperty("thermostatMode", mode)
            end
        )
    elseif mode == 'Heat' then
        self:callNestApi("sdm.devices.commands.ThermostatMode.SetMode",
            "mode",
            "HEAT",
            function()
                self:callNestApi("sdm.devices.commands.ThermostatEco.SetMode",
                    "mode",
                    "OFF",
                    function()
                        self:updateProperty("thermostatMode", mode)
                    end
                )
            end
        )
    else
        self:error("Unknow mode " .. mode)
    end
end

-- handle action for setting set point for heating
function NestThermostat:setHeatingThermostatSetpoint(value)
    self:callNestApi("sdm.devices.commands.ThermostatTemperatureSetpoint.SetHeat",
        "heatCelsius",
        value,
        function()
            self:updateProperty("heatingThermostatSetpoint", value)
        end
    )
end

-- Call Nest API
function NestThermostat:callNestApi(command, key, value, callback)
    local message = string.format("%s (%s:%s)", command, key, value)
    local url = string.format("https://smartdevicemanagement.googleapis.com/v1/%s:executeCommand", self:getVariable("uid"))

    self.parent.http:request(url, {
        options = {
            checkCertificate = true,
            method = 'POST',
            headers = {
                 ['Content-Type'] = "application/json; charset=utf-8",
                 ['Authorization'] = self.parent.accessToken
            },
            data = json.encode({
                    ['command'] = command,
                    ['params'] = {[key] = value}
                })
        },
        success = function(response)
            if response.status == 200 then
                self:debug("callNestApi() success " .. message)
                callback()
            else
                self:error("callNestApi() " .. message .. " status is " .. response.status .. ": ", json.encode(response.data))
            end
        end,
        error = function(error)
            self:error("callNestApi() " .. message .." failed: ", json.encode(error))
        end
    })
end
