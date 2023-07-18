-----------------------------------------------------------------------------
--                  NEST THERMOSTAT                                        --
--                  type: com.fibaro.humiditySensor                        --
-----------------------------------------------------------------------------

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
