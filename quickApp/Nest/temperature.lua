-----------------------------------------------------------------------------
--                  NEST THERMOSTAT                                        --
--                  type: com.fibaro.temperatureSensor                     --
-----------------------------------------------------------------------------

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
