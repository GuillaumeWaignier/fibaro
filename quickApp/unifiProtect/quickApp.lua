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
        ["com.fibaro.binarySensor"] = UnifiCamera,
    })

     -- Build device map
    self.devicesMap = {}
    self:trace("Child devices:")
    for id,device in pairs(self.childDevices)
    do
        local mac = device:getVariable("mac")
        if mac ~= ""
        then
            self.devicesMap[mac] = device
            local message = string.format("[%d] %s of type %s with UID %s", id, device.name, device.type, mac)
            self:trace(message)
        else
            local message = string.format("[%d] %s of type %s has no UID", id, device.name, device.type)
            self:error(message)
            api.delete('/devices/' .. id)
        end
    end

    self:mainLoop()
end

function QuickApp:initializeProperties()

    self.controller = self:getVariable("controller")
    assert(self.controller ~= "", "controller is not set")
    if string.sub(self.controller, -1) ~= "/" then
        self.controller = self.controller .. "/"
    end

    self.login = self:getVariable("login")
    assert(self.login ~= "", "login is not set")

    self.password = self:getVariable("password")
    assert(self.password ~= "", "password is not set")

    self.frequency = self:getVariable("frequency")
    assert(self.frequency ~= "", "frequency is not set")
    self.frequency = tonumber(self.frequency)
    assert(self.frequency ~= nil, "frequency is not a number")

    self.awaydelay = tonumber(self:getVariable("away delay"))
    if self.awaydelay == nil then
        self:debug("onInit(): away delay equals frequency")
        self.awaydelay = self.frequency
    end

    --self:setPresenceStatus("Unknown")
    self.token = nil
    self.http = net.HTTPClient({ timeout = 3000 })
end

-- main loop
function QuickApp:mainLoop()
    self:loginUnifi()
    
    self:listCamera()

    fibaro.setTimeout(self.frequency * 1000, function()
        self:mainLoop()
    end)
end

function QuickApp:loginUnifi()
    if self.token ~= nil
    then
        return
    end

    self.http:request(self.controller .. "api/auth/login", {
        options = {
            checkCertificate = false,
            method = 'POST',
            headers = {
                ['Content-Type'] = "application/json; charset=utf-8"
            },
            data = json.encode({
                ['username'] = self.login,
                ['password'] = self.password,
                ['rememberMe'] = true
            })
        },
        success = function(response)
            if response.status == 200 then
                self.token = response.headers['Set-Cookie']
                self.token = string.gsub(self.token, ";.*", "")
                self:debug("loginUnifi() succeed ")
            else
                self:error("loginUnifi() failed: ", json.encode(response.data))
            end
        end,
        error = function(error)
            self:error("loginUnifi() failed: ", json.encode(error))
        end
    })
end

function QuickApp:listCamera()
    if self.token == nil
    then
        return
    end

    self.http:request(self.controller .. "proxy/protect/api/bootstrap", {
        options = {
            checkCertificate = false,
            method = 'GET',
            headers = {
                 ['Cookie'] = self.token
            }
        },
        success = function(response)
            if response.status == 200
            then
                --self:trace("listCamera() succeed")
                local body = json.decode(response.data)
                local cameras = body['cameras']
                    
                for i, camera in ipairs(cameras)
                do
                    self:checkCamera(camera)
                end
            else
                self.token = nil
                self:error("checkMacUnifi() failed: ", json.encode(response.data))
            end
        end,
        error = function(error)
            self.token = nil
            self:error("checkMacUnifi() failed: ", json.encode(error))
        end
    })
end

function QuickApp:checkCamera(camera)
    --self:trace("checkCamera()", json.encode(camera))
    local mac = string.lower(camera['mac'])

    local device = self.devicesMap[mac]
    if device == nil
    then
        device = self:createChildDevice({name = mac,type = "com.fibaro.binarySensor"}, UnifiCamera)
        device:setVariable("mac", mac)
        self.devicesMap[mac] = device
        local message = string.format("Child device created: %s of type %s", device.id, device.type)
        self:trace(message)
    end

    local lastMotion = tonumber(camera['lastMotion']) / 1000

    if (lastMotion ~= nil) and ((os.time() - lastMotion) < self.awaydelay)
    then
        device:setPresenceStatus("Breached")
    else
        device:setPresenceStatus("Not breached")
    end
end



-----------------------------------------------------------------------------
--                  CHILDS                      -----------------------------
-----------------------------------------------------------------------------
class 'UnifiCamera' (QuickAppChild)

function UnifiCamera:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("UnifiCamera init")
end

function UnifiCamera:setPresenceStatus(status)
    --self:trace("setPresenceStatus() called: ", status)
    if status == "Not breached" then
        self:updateProperty('value', false)
    else
        self:updateProperty('value', true)
    end
    self:updateView("presenceStatus", "text", status)
end
