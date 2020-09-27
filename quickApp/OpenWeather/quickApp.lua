-- Sample plugin for handling data from https://openweathermap.org/
-- How to generate appid: https://openweathermap.org/appid
-- To setup this plugin fill proper location id in locationId variable and  API key in APIKey variable

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


-- posible conditions: "unknown", "clear", "rain", "snow", "storm", "cloudy", "fog"
function QuickApp:setCondition(condition)
    --self:debug("condition", condition)
    self:updateView("labelCondition", "text", condition)

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
        self:updateProperty("ConditionCode", conditionCode)
        self:updateProperty("WeatherCondition", condition)
    end
end

function QuickApp:fetchWeatherData()
    local address = string.format("https://api.openweathermap.org/data/2.5/weather?lat=%s&lon=%s&units=%s&appid=%s", self.lat, self.long, self.unit, self.key)
    --self:debug("connecting:", address)

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
    if data.main and data.main.temp
    then    
        self:updateProperty("Temperature", data.main.temp)
        self:updateView("labelTemperature", "text", tostring(data.main.temp) .. " C")
    end

    if data.main and data.main.humidity
    then    
        self:updateProperty("Humidity", data.main.humidity)
        self:updateView("labelHumidity", "text", tostring(data.main.humidity) .. " %")
    end

    if data.wind and data.wind.speed
    then
        self:updateProperty("Wind", data.wind.speed * 3.6)
        self:updateView("labelWind", "text", tostring(data.wind.speed * 3.6) .. " km/h")
    end

    if data.weather and data.weather[1] and data.weather[1].main
    then    
        self:setCondition(data.weather[1].main)
    end
end

-- main loop
function QuickApp:mainLoop()
    self:fetchWeatherData()
    
    fibaro.setTimeout( self.delay * 1000, function() 
        self:mainLoop()    
    end)
end

function QuickApp:onInit()
    self:debug("onInit")

    assert(self:getVariable("locationId") ~= "", "locationId is not set (see Fibaro API GET /panels/location/")
    self:getHCLocation(self:getVariable("locationId"))


    -- APIKey is required by openweathermap
    self.key = self:getVariable("APIKey")
    assert(self.key ~= "", "OpenWeather API key (APIKey) is not set")

    self.unit = self:getVariable("unit")
    assert(self.unit ~= "", "unit is not set")

    self.delay = tonumber(self:getVariable("delay"))
    assert(self.delay ~= "", "delay is not set")

    self.http = net.HTTPClient({timeout=3000})
    self:mainLoop()
end
