-- Device Controller is a little more advanced than other types. 
-- It can create child devices, so it can be used for handling multiple physical devices.
-- E.g. when connecting to a hub, some cloud service or just when you want to represent a single physical device as multiple endpoints.
-- 
-- Basic knowledge of object-oriented programming (oop) is required. 
-- Learn more about oop: https://en.wikipedia.org/wiki/Object-oriented_programming 
-- Learn more about managing child devices: https://manuals.fibaro.com/home-center-3-quick-apps/
-- Author: Guillaume Waignier
-- Apache License 2.0

function QuickApp:onInit()
    self:debug("QuickApp:onInit")

    self:initializeProperties()

    -- Setup classes for child devices.
    -- Here you can assign how child instances will be created.
    -- If type is not defined, QuickAppChild will be used.
    self:initChildDevices({
        ["com.fibaro.hvacSystemAuto"] = NestThermostat,
        ["com.fibaro.temperatureSensor"] = NestThermostatTemperature,
        ["com.fibaro.humiditySensor"] = NestThermostatHumidity,
        ["com.fibaro.motionSensor"] = NestMotionPerson
    }) 

    -- Build device map
    self.devicesMap = {}
    self:trace("Child devices:")
    for id,device in pairs(self.childDevices)
    do
        local uid = device:getVariable("uid")
        if uid ~= ""
        then
            self.devicesMap[uid] = id
            local message = string.format("[%d] %s of type %s with UID %s", id, device.name, device.type, uid)
            self:trace(message)
        else
            local message = string.format("[%d] %s of type %s has no UID", id, device.name, device.type)
            self:error(message)
            api.delete('/devices/' .. id)
        end
    end

    --start
    self:mainLoop()
    if self.gcpProjectId ~= nil
    then
        self:pubSubHealthcheck()
    end
end

function QuickApp:initializeProperties()
    self.projectId = self:getVariable("projectId")
    assert(self.projectId ~= "", "projectId is not set")
    
    self.clientId = self:getVariable("clientId")
    assert(self.clientId ~= "", "clientId is not set")

    self.clientSecret = self:getVariable("clientSecret")
    assert(self.clientSecret ~= "", "clientSecret is not set")

    self.code = self:getVariable("code")
    assert(self.code ~= "", "code is not set")

    self.frequency = self:getVariable("frequency")
    assert(self.frequency ~= "", "frequency is not set")
    self.frequency = tonumber(self.frequency)
    assert(self.frequency ~= nil, "frequency is not a number")

    self.refreshToken = self:getVariable("refreshToken")
    if (self.refreshToken == "")
    then
      self:warning("set refresh token to null")
      self:setVariable("refreshToken", "")
    end

    self.gcpProjectId = self:getVariable("gcpProjectId")
    if (self.gcpProjectId == "")
    then
      self:warning("gcpProjectId is not set. Disable pubsub (no camera or dorbell support)")
      self.gcpProjectId = nil
    else
      self.subscription = self:getVariable("subscription")
      assert(self.subscription ~= "", "subscription is not set and is mandatory when gcpProjectId is set")
    end
    
    self.accessToken = nil

    self.step = "accessToken"
    if self.refreshToken == ""
    then
      self.step = "refreshToken"
    end

    self.maxLogDebugPubSub = 10

    QuickApp.http = net.HTTPClient({ timeout = 10000 })
    QuickApp.pubsub = net.HTTPClient({ timeout = 60000 })
end


function QuickApp:mainLoop()
    --login
    self:sendMailForRefreshToken()
    self:getRefreshToken()
    self:getAccessToken()

    --get Nest devices
    self:listNestDevice()

    fibaro.setTimeout(self.frequency * 1000, function()
        self:mainLoop()
    end)
end

-- Send a mail to request a new a new Refresh Token
function QuickApp:sendMailForRefreshToken()
    if (self.step ~= "mail")
    then
        return
    end
        
    local url = string.format("https://nestservices.google.com/partnerconnections/%s/auth?redirect_uri=https://www.google.com%%26access_type=offline%%26prompt=consent%%26client_id=%s%%26response_type=code%%26scope=https://www.googleapis.com/auth/sdm.service%%20https://www.googleapis.com/auth/pubsub",self.projectId, self.clientId)

    -- mail
    local mail = string.format("Need to refresh Nest Authentication code for quickApp %d. Please be sure to copy/paste the full URL in a web browser : %s", self.id, url:gsub("%%20","+"))
    fibaro.alert("email", {2}, mail)

    -- log
    local html = string.format("<html><body>Need to refresh Nest Authentication code for quickApp %d with <a href=\"%s\" target=\"_blank\">%s</a></body></html>", self.id, url:gsub("%%26","&"), url:gsub("%%26","&"))
    self:error(html)

    -- notification
    local m ={canBeDeleted=true,wasRead=false,priority="alert",type="GenericDeviceNotification",data={deviceId=tonumber(self.id),subType="DeviceNotConfigured",title="Nest Authentication Code",text=html}}
    api.post("/notificationCenter",m)

    self.step = "nothing"
end


function QuickApp:getRefreshToken()
    if self.step ~= "refreshToken"
    then
        return
    end

    self:debug("Get Google refresh token")

    local url = string.format("https://www.googleapis.com/oauth2/v4/token?client_id=%s&client_secret=%s&code=%s&grant_type=authorization_code&redirect_uri=https://www.google.com", self.clientId, self.clientSecret, self.code)

    self.http:request(url , {
        options = {
            checkCertificate = true,
            method = 'POST',
            headers = {},
            data = nil
        },
        success = function(response)
            -- self:debug(json.encode(response))
            if response.status == 200 then
                body = json.decode(response.data)
                self.accessToken = "Bearer " .. body['access_token']
                self.refreshToken = body['refresh_token']
                self:setVariable("refreshToken", self.refreshToken)
                self.step = "device"
                self:debug("getRefreshToken() succeed")
                self:trace(self.accessToken .. "   " ..  self.refreshToken)
            else
                self:error("getRefreshToken() status is " .. response.status .. ": " .. response.data)
                self.step="mail"
            end
        end,
        error = function(error)
            self:error("getRefreshToken() failed: " .. json.encode(error))
            self.step="mail"
        end
    })
end

function QuickApp:getAccessToken()
    if self.step ~= "accessToken"
    then
        return
    end

    local url = string.format("https://www.googleapis.com/oauth2/v4/token?client_id=%s&client_secret=%s&refresh_token=%s&grant_type=refresh_token", self.clientId, self.clientSecret, self.refreshToken)
    self.http:request(url , {
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
                self.step = "device"
                --self:debug("getAccessToken() succeed " .. self.accessToken)
            elseif response.status >= 500 then
                self:error("getAccessToken() status is " .. response.status .. ": " .. response.data)
            else
                self:warning("getAccessToken() status is " .. response.status .. ": " .. response.data)
                self:setVariable("refreshToken", "")
                self.step = "refreshToken"
            end
        end,
        error = function(error)
            self:error("getAccessToken() failed: " .. json.encode(error))
        end
    })
end

function QuickApp:listNestDevice()
    if self.step ~= "device"
    then
        return
    end

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
                self:updateNestDevices(body)
            elseif response.status == 401 then
                self.step = "accessToken"
            else
                self:error("listNestDevice() status is " .. response.status .. ": " .. response.data)
            end
        end,
        error = function(error)
            self:error("listNestDevice() failed: " .. json.encode(error))
        end
    })
end

function QuickApp:updateNestDevices(body) 
  devices = body['devices']
  --self:debug("updateNestDevices()", json.encode(devices))

  for i, device in ipairs(devices) 
  do
    local name = device['name']
    if device['traits']['sdm.devices.traits.ThermostatTemperatureSetpoint'] ~= nil
    then
        local fibaroDevice = self:getOrCreateChildDevice(name, device, "com.fibaro.hvacSystemAuto")
        fibaroDevice:updateDevice(device)
    end
    if device['traits']['sdm.devices.traits.Temperature'] ~= nil
    then
         local fibaroDevice = self:getOrCreateChildDevice(name .. "Temperature", device, "com.fibaro.temperatureSensor")
        fibaroDevice:updateDevice(device)
    end
    if device['traits']['sdm.devices.traits.Humidity'] ~= nil
    then
         local fibaroDevice = self:getOrCreateChildDevice(name .. "Humidity", device, "com.fibaro.humiditySensor")
        fibaroDevice:updateDevice(device)
    end
  end
end
 
-- Get or create child device
function QuickApp:getOrCreateChildDevice(name, device, type)
  local id = self.devicesMap[name]
  if id 
  then
    return self.childDevices[id]
  else
    return self:createChild(name, device, type)
  end
end


-- Create fibaro child device
function QuickApp:createChild(name, device, type)
    local child = nil

    if type  == 'com.fibaro.hvacSystemAuto'
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.hvacSystemAuto"}, NestThermostat)
    elseif type == "com.fibaro.temperatureSensor"
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.temperatureSensor"}, NestThermostatTemperature)
    elseif type == "com.fibaro.humiditySensor"
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.humiditySensor"}, NestThermostatHumidity)
    elseif type == "com.fibaro.motionSensor"
    then
        child = self:createChildDevice({name = name,type = "com.fibaro.motionSensor"}, NestMotionPerson)
    end


    child:setVariable("uid", name)
    self.devicesMap[name] = child.id

    local message = string.format("Child device created: %s of type %s", child.id, child.type)
    self:trace(message)

    return child
end
