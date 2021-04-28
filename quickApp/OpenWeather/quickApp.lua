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
        self:setCondition(data.current.weather[1])
    end
end


function QuickApp:setCondition(condition)
    -- self:debug("condition", json.encode(condition))
    
    local key = condition.id .. string.sub(condition.icon, 3)
    local code = QuickApp.codes[key]

    self.devicesMap["weather"]:updateProperty("ConditionCode", code)
    self.devicesMap["weather"]:updateProperty("WeatherCondition", string.lower(condition.main))
end

QuickApp.codes = {
    -- clear
    ["800d"] = 32,
    ["800n"] = 31,
    -- clouds
    ["801d"] = 28, ["802d"] = 28, ["803d"] = 26, ["804d"] = 26,
    ["801n"] = 27, ["802n"] = 27, ["803n"] = 26, ["804n"] = 26,
    -- atmosphere
    ["701d"] = 20, ["711d"] = 20, ["721d"] = 20, ["731d"] = 2, ["741d"] = 20,
    ["751d"] = 24, ["761d"] = 24, ["762d"] = 24, ["771d"] = 24, ["781d"] = 1,
    ["701n"] = 20, ["711n"] = 20, ["721n"] = 20, ["731n"] = 2, ["741n"] = 20,
    ["751n"] = 24, ["761n"] = 24, ["762n"] = 24, ["771n"] = 24, ["781n"] = 1,
    -- snow
    ["600d"] = 41,["601d"] = 16, ["602d"] = 13, ["611d"] = 7, ["612d"] = 7, ["613d"] = 7,
    ["615d"] = 7, ["616d"] = 7, ["620d"] = 7, ["621d"] = 7, ["622d"] = 7,
    ["600n"] = 41, ["601n"] = 16, ["602n"] = 13, ["611n"] = 7, ["612n"] = 7, ["613n"] = 7, 
    ["615n"] = 7, ["616n"] = 7, ["620n"] = 7, ["621n"] = 7, ["622n"] = 7,
    -- rain
    ["500d"] = 11, ["501d"] = 11, ["502d"] = 11, ["503d"] = 11, ["504d"] = 11,
    ["511d"] = 7, ["520d"] = 11, ["521d"] = 11, ["522d"] = 11, ["531d"] = 11,
    ["500n"] = 11, ["501n"] = 11, ["502n"] = 11, ["503n"] = 11, ["504n"] = 11,
    ["511n"] = 7, ["520n"] = 11, ["521n"] = 11, ["522n"] = 11, ["531n"] = 11,
    -- drizzle
    ["300d"] = 9, ["301d"] = 9, ["302d"] = 9, ["310d"] = 9, ["311d"] = 9,
    ["312d"] = 9, ["313d"] = 9, ["314d"] = 9, ["321d"] = 9,
    ["300n"] = 9, ["301n"] = 9, ["302n"] = 9, ["310n"] = 9, ["311n"] = 9,
    ["312n"] = 9, ["313n"] = 9, ["314n"] = 9, ["321n"] = 9,
    -- thunderstorm
    ["200d"] = 6, ["201d"] = 6, ["202d"] = 6, ["210d"] = 4, ["211d"] = 4,
    ["212d"] = 37, ["221d"] = 37, ["230d"] = 35, ["231d"] = 35, ["232d"] = 35,
    ["200n"] = 6, ["201n"] = 6, ["202n"] = 6, ["210n"] = 4, ["211n"] = 4, 
    ["212n"] = 37, ["221n"] = 37, ["230n"] = 35, ["231n"] = 35, ["232n"] = 35,
}

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


