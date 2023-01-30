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
    self:updateProperty("supportedThermostatModes", {})

    -- setup default values
    self:updateProperty("thermostatMode", "Off")
    self:updateProperty("heatingThermostatSetpoint", 8)
    self:updateProperty("log", "")
end

function NestThermostat:updateDevice(body)
    --self:debug("updateDevice " .. self.id .. " with body " .. json.encode(body))
    
    self:updateMode(body)
    self:updateTemperatureSetPoint(body)
    self:updateHvacStatus(body)
end

function NestThermostat:updateMode(body) 
    self:updateAvailableModes(body)

    thermostatMode = body['traits']['sdm.devices.traits.ThermostatMode']['mode']
    thermostatModeEco = body['traits']['sdm.devices.traits.ThermostatEco']['mode']

    if thermostatMode == "OFF" then
        self:updateProperty("thermostatMode", "Off")
    elseif thermostatModeEco == 'MANUAL_ECO' then
        self:updateProperty("thermostatMode", "Eco")
    elseif thermostatMode == "HEAT" then
        self:updateProperty("thermostatMode", "Heat")
    elseif thermostatMode == "COOL" then
        self:updateProperty("thermostatMode", "Cool")
    elseif thermostatMode == "HEATCOOL" then
        self:updateProperty("thermostatMode", "Auto")
    else
      self:error("updateMode() failed", "Unknown mode " .. thermostatMode .. " / " .. thermostatModeEco)
    end
end

function NestThermostat:updateAvailableModes(body)
    local thermostatAvailableMode = body['traits']['sdm.devices.traits.ThermostatMode']['availableModes']
    local thermostatAvailableModeEco = body['traits']['sdm.devices.traits.ThermostatEco']['availableModes']

    local index=1
    local supportedThermostatModes = {}

    for i,mode in ipairs(thermostatAvailableMode)
    do
      if mode == "OFF"
      then
        supportedThermostatModes[index] = "Off"
        index = index+1
      end
      if mode == "HEAT"
      then
        supportedThermostatModes[index] = "Heat"
        index = index+1
      end
      if mode == "COOL"
      then
        supportedThermostatModes[index] = "Cool"
        index = index+1
      end
      if mode == "HEATCOOL"
      then
        supportedThermostatModes[index] = "Auto"
        index = index+1
      end
    end
    for i,mode in ipairs(thermostatAvailableModeEco)
    do
      if mode == "MANUAL_ECO"
      then
        supportedThermostatModes[index] = "Eco"
        index = index+1
      end
    end
    self:updateProperty("supportedThermostatModes", supportedThermostatModes)
end

function NestThermostat:updateTemperatureSetPoint(body)
    if body['traits']['sdm.devices.traits.ThermostatTemperatureSetpoint']['heatCelsius'] ~= nil
    then
      local temp = body['traits']['sdm.devices.traits.ThermostatTemperatureSetpoint']['heatCelsius']
      local roundedValue = math.ceil(temp * 10) / 10
      self:updateProperty("heatingThermostatSetpoint", roundedValue)
    end

    if body['traits']['sdm.devices.traits.ThermostatTemperatureSetpoint']['coolCelsius'] ~= nil
    then
      local temp = body['traits']['sdm.devices.traits.ThermostatTemperatureSetpoint']['coolCelsius']
      local roundedValue = math.ceil(temp * 10) / 10
      self:updateProperty("coolingThermostatSetpoint", roundedValue)
    end

    if (self.properties.thermostatMode == "Eco")
    then
      if body['traits']['sdm.devices.traits.ThermostatEco']['heatCelsius'] ~= nil
      then
        local temp = body['traits']['sdm.devices.traits.ThermostatEco']['heatCelsius']
        local roundedValue = math.ceil(temp * 10) / 10
        self:updateProperty("heatingThermostatSetpoint", roundedValue)
      end
      if body['traits']['sdm.devices.traits.ThermostatEco']['coolCelsius'] ~= nil
      then
        local temp = body['traits']['sdm.devices.traits.ThermostatEco']['coolCelsius']
        local roundedValue = math.ceil(temp * 10) / 10
        self:updateProperty("coolingThermostatSetpoint", roundedValue)
      end
    end
end

function NestThermostat:updateHvacStatus(body)
    if body['traits']['sdm.devices.traits.ThermostatHvac'] ~= nil
    then
      local status = body['traits']['sdm.devices.traits.ThermostatHvac']['status']
      self:updateProperty("log", status)
    else
      self:updateProperty("log", "")
    end
end

-- handle action for mode change 
function NestThermostat:setThermostatMode(mode)
    self:debug("update mode " .. mode)
    
    if mode == 'Eco' then
        self:callNestApi("sdm.devices.commands.ThermostatMode.SetMode",
            {['mode'] = "HEAT"},
            function()
                self:callNestApi("sdm.devices.commands.ThermostatEco.SetMode",
                    {['mode'] = "MANUAL_ECO"},
                    function()
                        self:updateProperty("thermostatMode", mode)
                    end
                )
            end
        )
    elseif mode == 'Off' then
        self:callNestApi("sdm.devices.commands.ThermostatMode.SetMode",
            {['mode'] = "OFF"},
            function()
                 self:updateProperty("thermostatMode", mode)
            end
        )
    elseif mode == 'Heat' then
        self:callNestApi("sdm.devices.commands.ThermostatMode.SetMode",
            {['mode'] = "HEAT"},
            function()
                self:callNestApi("sdm.devices.commands.ThermostatEco.SetMode",
                    {['mode'] = "OFF"},
                    function()
                        self:updateProperty("thermostatMode", mode)
                    end
                )
            end
        )
    elseif mode == 'Cool' then
        self:callNestApi("sdm.devices.commands.ThermostatMode.SetMode",
            {['mode'] = "COOL"},
            function()
                self:callNestApi("sdm.devices.commands.ThermostatEco.SetMode",
                    {['mode'] = "OFF"},
                    function()
                        self:updateProperty("thermostatMode", mode)
                    end
                )
            end
        )
    elseif mode == 'Auto' then
        self:callNestApi("sdm.devices.commands.ThermostatMode.SetMode",
            {['mode'] = "HEATCOOL"},
            function()
                self:callNestApi("sdm.devices.commands.ThermostatEco.SetMode",
                    {['mode'] = "OFF"},
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
function NestThermostat:setHeatingThermostatSetpoint(value, scale)
    self:debug("update temperature " .. value .. ", scale " .. scale .. ", with mode " .. self.properties.thermostatMode)

    --When the setpoint scale is in Fahrenheit, convert the value to Celsius
    local degreesC = value
    if (scale ~= nil) and (scale == 'F')
    then
        degreesC = (degreesC - 32) * 5 / 9
        self:debug(string.format('Converting %.3f\176F to %.3f\176C', value, degreesC))
    end

    local roundedValue = math.ceil(degreesC * 10) / 10

    if (self.properties.thermostatMode == "Heat")
    then
      self:callNestApi("sdm.devices.commands.ThermostatTemperatureSetpoint.SetHeat",
          {['heatCelsius'] = roundedValue},
          function()
              self:updateProperty("heatingThermostatSetpoint", roundedValue)
          end
      )
    elseif (self.properties.thermostatMode == "Auto")
    then
      self:callNestApi("sdm.devices.commands.ThermostatTemperatureSetpoint.SetRange",
          {['heatCelsius'] = roundedValue, ['coolCelsius'] = self.properties.coolingThermostatSetpoint},
          function()
              self:updateProperty("heatingThermostatSetpoint", roundedValue)
          end
      )
    end
end

-- handle action for setting set point for cooling
function NestThermostat:setCoolingThermostatSetpoint(value, scale)
    self:debug("update temperature " .. value .. ", scale " .. scale .. ", with mode " .. self.properties.thermostatMode)

    --When the setpoint scale is in Fahrenheit, convert the value to Celsius
    local degreesC = value
    if (scale ~= nil) and (scale == 'F')
    then
        degreesC = (degreesC - 32) * 5 / 9
        self:debug(string.format('Converting %.3f\176F to %.3f\176C', value, degreesC))
    end

    local roundedValue = math.ceil(degreesC * 10) / 10

    if (self.properties.thermostatMode == "Cool")
    then
      self:callNestApi("sdm.devices.commands.ThermostatTemperatureSetpoint.SetCool",
          {['coolCelsius'] = roundedValue},
          function()
              self:updateProperty("coolingThermostatSetpoint", roundedValue)
          end
      )
    elseif (self.properties.thermostatMode == "Auto")
    then
      self:callNestApi("sdm.devices.commands.ThermostatTemperatureSetpoint.SetRange",
          {['heatCelsius'] = self.properties.heatingThermostatSetpoint, ['coolCelsius'] = roundedValue},
          function()
              self:updateProperty("coolingThermostatSetpoint", roundedValue)
          end
      )
    end
end

-- Call Nest API
function NestThermostat:callNestApi(command, params, callback)
    local message = string.format("%s (%s)", command, json.encode(params))
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
                    ['params'] = params
                })
        },
        success = function(response)
            if response.status == 200 then
                self:debug("callNestApi() success " .. message)
                callback()
            else
                self:error("callNestApi() " .. message .. " status is " .. response.status .. ": " ..  response.data)
            end
        end,
        error = function(error)
            self:error("callNestApi() " .. message .." failed: " .. json.encode(error))
        end
    })
end


-- Temperature sensor type have no actions to handle
class 'NestThermostatTemperature' (QuickAppChild)

function NestThermostatTemperature:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("NestThermostatTemperature init")
end

function NestThermostatTemperature:updateDevice(body)
    -- self:debug("updateDevice " .. self.id .. " with body " .. json.encode(body))
    local temp = body['traits']['sdm.devices.traits.Temperature']['ambientTemperatureCelsius']
    self:updateProperty("value", temp)
end

class 'NestThermostatHumidity' (QuickAppChild)

-- __init is a constructor for this class. All new classes must have it.
function NestThermostatHumidity:__init(device)
    -- You should not insert code before QuickAppChild.__init. 
    QuickAppChild.__init(self, device) 
    self:trace("NestThermostatHumidity init")
end

function NestThermostatHumidity:updateDevice(body)
    local temp = body['traits']['sdm.devices.traits.Humidity']['ambientHumidityPercent']
    self:updateProperty("value", temp)
end
