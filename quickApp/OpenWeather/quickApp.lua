-- Device Controller is a little more advanced than other types. 
-- It can create child devices, so it can be used for handling multiple physical devices.
-- E.g. when connecting to a hub, some cloud service or just when you want to represent a single physical device as multiple endpoints.
-- 
-- Basic knowledge of object-oriented programming (oop) is required. 
-- Learn more about oop: https://en.wikipedia.org/wiki/Object-oriented_programming 
-- Learn more about managing child devices: https://manuals.fibaro.com/home-center-3-quick-apps/

function QuickApp:onInit()
    self:debug("QuickApp:onInit")

    self:initializeProperties()

    self:initChildDevices({
        ["com.fibaro.weather"] = OpenWeatherMap,
        ["com.fibaro.temperatureSensor"] = OpenWeatherMapTemperature,
        ["com.fibaro.humiditySensor"] = OpenWeatherMapHumidity,
        ["com.fibaro.windSensor"] = OpenWeatherMapWind,
        ["com.fibaro.multilevelSensor"] = OpenWeatherMapPressure,
    })

    self:retrieveChild()
    self:completeChild()
   
    self:mainLoop()
end

function QuickApp:initializeProperties()

    assert(self:getVariable("locationId") ~= "", "locationId is not set (see Fibaro API GET /panels/location/")
    self:getHCLocation(self:getVariable("locationId"))

    -- APIKey is required by openweathermap
    self.key = self:getVariable("APIKey")
    assert(self.key ~= "", "OpenWeather API key (APIKey) is not set")

    self.unit = self:getVariable("unit")
    assert(self.unit ~= "", "unit is not set")

    self.frequency = tonumber(self:getVariable("frequency"))
    assert(self.frequency ~= "", "frequency is not set")
    self.frequency = tonumber(self.frequency)
    assert(self.frequency ~= nil, "frequency is not a number")

    self.http = net.HTTPClient({timeout=1000})
end

function QuickApp:getHCLocation(locationId)
    local location = api.get("/panels/location/" .. locationId)

    if location
    then 
        self:debug("Configured location:", location.name)
        self.lat = location.latitude
        self.long = location.longitude
    else 
        self:error("Location with provided id (", locationId ,") doesn't exist (see Fibaro API GET /panels/location/)")
    end
end

-- Retrieve existing childs
function QuickApp:retrieveChild()
    self.devicesMap = {}
    self:trace("Child devices:")
    for id,device in pairs(self.childDevices)
    do
        local uid = device:getVariable("uid")
        if uid ~= ""
        then
            self.devicesMap[uid] = self.childDevices[id]
            local message = string.format("[%d] %s of type %s with UID %s", id, device.name, device.type, uid)
            self:trace(message)
        else
            local message = string.format("[%d] %s of type %s has no UID", id, device.name, device.type)
            self:error(message)
            api.delete('/devices/' .. id)
        end
    end
end

-- Create childs if needed
function QuickApp:completeChild()
    local child = nil
    
    local name = "weather"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.weather"}, OpenWeatherMap)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
    end

    local name = "temperature"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.temperatureSensor"}, OpenWeatherMapTemperature)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
    end

    local name = "humidity"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.humiditySensor"}, OpenWeatherMapHumidity)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
    end 

    local name = "wind"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.windSensor"}, OpenWeatherMapWind)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
        child:updateProperty("unit", "km/h")
    end

    local name = "pressure"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.multilevelSensor"}, OpenWeatherMapPressure)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
        child:updateProperty("unit", "hPa")
    end

     local name = "uvi"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.multilevelSensor"}, OpenWeatherMapPressure)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
        child:updateProperty("unit", "uv")
    end
end

-- main loop
function QuickApp:mainLoop()
    self:fetchWeatherData()

    fibaro.setTimeout(self.frequency * 1000, function()
        self:mainLoop()
    end)
end


function QuickApp:fetchWeatherData()
    local address = string.format("https://api.openweathermap.org/data/2.5/onecall?lat=%s&lon=%s&exclude=minutely,hourly,daily&units=%s&appid=%s", self.lat, self.long, self.unit, self.key)

    self.http:request(address, {
        options={
            method = 'GET'
        },
        success = function(response)
            --print(response.data)
            local data = json.decode(response.data)
            if data
            then
                self:onWatherDataReceived(data)
            end
        end,
        error = function(error)
            self:error('error: ' .. json.encode(error))
        end
    })   
end

-- parse response
function QuickApp:onWatherDataReceived(data)
    if data.current == nil
    then
        return
    end

    if data.current.temp
    then
        self.devicesMap["weather"]:updateProperty("Temperature", data.current.temp)
        self.devicesMap["temperature"]:updateProperty("value", data.current.temp)
    end

    if data.current.humidity
    then    
        self.devicesMap["weather"]:updateProperty("Humidity", data.current.humidity)
        self.devicesMap["humidity"]:updateProperty("value", data.current.humidity)
    end

    if data.current.wind_speed
    then
        self.devicesMap["weather"]:updateProperty("Wind", data.current.wind_speed * 3.6)
        self.devicesMap["wind"]:updateProperty("value", data.current.wind_speed * 3.6)
    end

    if data.current.pressure
    then
        self.devicesMap["pressure"]:updateProperty("value", data.current.pressure)
    end

    if data.current.uvi
    then
        self.devicesMap["uvi"]:updateProperty("value", data.current.uvi)
    end

    if data.current.weather and data.current.weather[1] and data.current.weather[1].main
    then    
        self:setCondition(data.current.weather[1].main)
    end
end

-- posible conditions: "unknown", "clear", "rain", "snow", "storm", "cloudy", "fog"
function QuickApp:setCondition(condition)
    --self:debug("condition", condition)
    -- self:updateView("labelCondition", "text", condition)

    -- map conditions from openweathermap into hc confitions 
    local conditionsMap = {
        Clear = "clear",
        Clouds = "cloudy",
        Thunderstorm = "storm",
        Snow = "snow",
        Rain = "rain",
        Drizzle = "rain",
        Mist = "fog"
    }
    local hcCondition = conditionsMap[condition]
    
    -- falbback if condidiotn wasn't found 
    if hcCondition == nil
    then
        hcCondition = "unknown"
    end

    local conditionCodes = { 
        unknown = 3200,
        clear = 32,
        rain = 40,
        snow = 38,
        storm = 666,
        cloudy = 30,
        fog = 20
    }

    local conditionCode = conditionCodes[hcCondition]
    
    if conditionCode
    then
        self.devicesMap["weather"]:updateProperty("ConditionCode", conditionCode)
        self.devicesMap["weather"]:updateProperty("WeatherCondition", condition)
    end
end


-----------------------------------------------------------------------------
--                  CHILDS                      -----------------------------
-----------------------------------------------------------------------------
-- Weather
class 'OpenWeatherMap' (QuickAppChild)

function OpenWeatherMap:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("OpenWeatherMap init")
end

-- Temperature sensor
class 'OpenWeatherMapTemperature' (QuickAppChild)

function OpenWeatherMapTemperature:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("OpenWeatherMapTemperature init")
end

-- Humidity sensor
class 'OpenWeatherMapHumidity' (QuickAppChild)

function OpenWeatherMapHumidity:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("OpenWeatherMapHumidity init")
end

-- Wind sensor
class 'OpenWeatherMapWind' (QuickAppChild)

function OpenWeatherMapWind:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("OpenWeatherMapWind init")
end

-- Pressure sensor
class 'OpenWeatherMapPressure' (QuickAppChild)

function OpenWeatherMapPressure:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("OpenWeatherMapPressure init")
end


