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
        ["com.fibaro.weather"] = Weather,
        ["com.fibaro.temperatureSensor"] = WeatherTemperature,
        ["com.fibaro.humiditySensor"] = WeatherHumidity,
        ["com.fibaro.windSensor"] = WeatherWind,
        ["com.fibaro.multilevelSensor"] = WeatherPressure,
    })

    self:retrieveChild()
    self:completeChild()
   
    self:mainLoop()
end

function QuickApp:initializeProperties()

    assert(self:getVariable("locationId") ~= "", "locationId is not set (see Fibaro API GET /panels/location/")
    self:getHCLocation(self:getVariable("locationId"))

    -- APIKey is required by weatherapi.com
    self.key = self:getVariable("APIKey")
    assert(self.key ~= "", "weatherapi.com API key (APIKey) is not set")

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
        self.lat = location.latitude
        self.long = location.longitude
        self:debug("Configured location:", location.name .. " (" .. location.latitude .. "," .. location.longitude .. ')' )
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
        child = self:createChildDevice({name = name,type = "com.fibaro.weather"}, WeatherMap)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
    end

    local name = "temperature"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.temperatureSensor"}, WeatherTemperature)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
    end

    local name = "humidity"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.humiditySensor"}, WeatherHumidity)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
    end 

    local name = "wind"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.windSensor"}, WeatherWind)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
        child:updateProperty("unit", "km/h")
    end

    local name = "pressure"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.multilevelSensor"}, WeatherPressure)
        self.devicesMap[name] = child
        child:setVariable("uid", name)
        child:updateProperty("unit", "hPa") 
    end

     local name = "uvi"
    if self.devicesMap[name] == nil
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.multilevelSensor"}, WeatherPressure)
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
    local address = string.format("https://api.weatherapi.com/v1/current.json?q=%s,%s&key=%s", self.lat, self.long, self.key)

    self.http:request(address, {
        options={
            method = 'GET',
            headers = {
                ['accept'] = "application/json"
            },
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
    if data == nil and data.current == nil
    then
        return
    end

    if data.current.temp_c
    then
        self.devicesMap["weather"]:updateProperty("Temperature", data.current.temp_c)
        self.devicesMap["temperature"]:updateProperty("value", data.current.temp_c)
    end

    if data.current.humidity
    then    
        self.devicesMap["weather"]:updateProperty("Humidity", data.current.humidity)
        self.devicesMap["humidity"]:updateProperty("value", data.current.humidity)
    end

    if data.current.wind_kph
    then
        self.devicesMap["weather"]:updateProperty("Wind", data.current.wind_kph)
        self.devicesMap["wind"]:updateProperty("value", data.current.wind_kph)
    end

    if data.current.pressure_mb
    then
        self.devicesMap["pressure"]:updateProperty("value", data.current.pressure_mb)
    end

    if data.current.uv
    then
        self.devicesMap["uvi"]:updateProperty("value", data.current.uv)
    end

    if data.current.condition and data.current.condition.code
    then    
        self:setCondition(data.current.condition)
    end
end


function QuickApp:setCondition(condition)
    local currentTime = os.date("%H:%M")
    local sunset = fibaro.getValue(1, "sunsetHour")
    local sunrise = fibaro.getValue(1, "sunriseHour")
   
    -- check if it is day or night
    local suffix = "n"
    if currentTime >= sunrise and currentTime < sunset then
        suffix = "d"
    end
       
    local key = condition.code .. suffix
    local code = QuickApp.codes[key]

    --self:debug("condition: " .. key .. " ,code: " .. code .. " text: " .. condition.text)

    self.devicesMap["weather"]:updateProperty("ConditionCode", code)
    self.devicesMap["weather"]:updateProperty("WeatherCondition", string.lower(condition.text))
end

QuickApp.codes = {
    -- clear
    ["1000d"] = 32,
    ["1000n"] = 31,
    -- clouds
    ["1003d"] = 28, ["1006d"] = 26, ["1009d"] = 26,
    ["1003n"] = 27, ["1006n"] = 26, ["1009n"] = 26,
    -- atmosphere
    ["1030d"] = 20, ["1147d"] = 20, ["1135d"] = 20,
    ["1030n"] = 20, ["1147n"] = 20, ["1135n"] = 20,
    -- snow
    ["1066d"] = 41, ["1210d"] = 41, ["1213d"] = 41,  ["1216d"] = 16, ["1219d"] = 16, ["1222d"] = 13, ["1225d"] = 13, 
    ["1252d"] = 7, ["1249d"] = 7, ["1204d"] = 7, ["1207d"] = 7,
    ["1069d"] = 7, ["1114d"] = 15, ["1117d"] = 15, ["1255d"] = 7, ["1258d"] = 7,
    ["1237d"] = 8, ["1261d"] = 8, ["1264d"] = 8,
    ["1066n"] = 41, ["1210n"] = 41, ["1213n"] = 41,  ["1216n"] = 16, ["1219n"] = 16, ["1222n"] = 13, ["1225n"] = 13, 
    ["1252n"] = 7, ["1249n"] = 7, ["1204n"] = 7, ["1207n"] = 7, 
    ["1069n"] = 7, ["1114n"] = 15, ["1117n"] = 15, ["1255n"] = 7, ["1258n"] = 7,
    ["1237n"] = 8, ["1261n"] = 8, ["1264n"] = 8,
    -- rain
    ["1063d"] = 11, ["1180d"] = 11, ["1183d"] = 11, ["1186d"] = 11, ["1189d"] = 11, ["1192d"] = 11, ["1195d"] = 11,
    ["1198d"] = 7, ["1201d"] = 7, ["1240d"] = 11, ["1243d"] = 11, ["1246d"] = 11,
    ["1063n"] = 11, ["1180n"] = 11, ["1183n"] = 11, ["1186n"] = 11, ["1189n"] = 11, ["1192n"] = 11, ["1195n"] = 11,
    ["1198n"] = 7, ["1201n"] = 7, ["1240n"] = 11, ["1243n"] = 11, ["1246n"] = 11,
    -- drizzle
    ["1072d"] = 9, ["1150d"] = 9, ["1153d"] = 9, ["1168d"] = 9, ["1171d"] = 9,
    ["312d"] = 9, ["313d"] = 9, ["314d"] = 9, ["321d"] = 9,
    ["1072n"] = 9, ["1150n"] = 9, ["1153n"] = 9, ["1168n"] = 9, ["1171n"] = 9,
    ["312n"] = 9, ["313n"] = 9, ["314n"] = 9, ["321n"] = 9,
    -- thunderstorm
    ["1087d"] = 35, ["1273d"] = 4, ["1276d"] = 4, ["1279d"] = 4, ["1282d"] = 4,
    ["212d"] = 37, ["221d"] = 37, ["230d"] = 35, ["231d"] = 35, ["232d"] = 35,
    ["1087n"] = 35, ["1273n"] = 4, ["1276n"] = 4, ["1279n"] = 4, ["1282n"] = 4, 
    ["212n"] = 37, ["221n"] = 37, ["230n"] = 35, ["231n"] = 35, ["232n"] = 35,
}

-----------------------------------------------------------------------------
--                  CHILDS                      -----------------------------
-----------------------------------------------------------------------------
-- Weather
class 'Weather' (QuickAppChild)

function Weather:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("Weather init")
end

-- Temperature sensor
class 'WeatherTemperature' (QuickAppChild)

function WeatherTemperature:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("WeatherTemperature init")
end

-- Humidity sensor
class 'WeatherHumidity' (QuickAppChild)

function WeatherHumidity:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("WeatherHumidity init")
end

-- Wind sensor
class 'WeatherWind' (QuickAppChild)

function WeatherWind:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("WeatherWind init")
end

-- Pressure sensor
class 'WeatherPressure' (QuickAppChild)

function WeatherPressure:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("WeatherPressure init")
end


