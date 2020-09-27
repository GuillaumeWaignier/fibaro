-- Binary sensor type have no actions to handle
-- To update binary sensor state, update property "value" with boolean
-- Eg. self:updateProperty("value", true) will set sensor to breached state

-- To update controls you can use method self:updateView(<component ID>, <component property>, <desired value>). Eg:  
-- self:updateView("slider", "value", "55") 
-- self:updateView("button1", "text", "MUTE") 
-- self:updateView("label", "text", "TURNED ON") 

-- This is QuickApp inital method. It is called right after your QuickApp starts (after each save or on gateway startup). 
-- Here you can set some default values, setup http connection or get QuickApp variables.
-- To learn more, please visit: 
--    * https://manuals.fibaro.com/home-center-3/
--    * https://manuals.fibaro.com/home-center-3-quick-apps/
function QuickApp:setPresenceStatus(status)
    --self:trace("setPresenceStatus() called: ", status)
    if status == "Not breached" then
        self:updateProperty('value', false)
    else
        self:updateProperty('value', true)
    end
    self:updateView("presenceStatus", "text", status)
end


function QuickApp:checkMacUnifi()
    local body, cameras, lastMotion

    if self.token ~= nil then
        self.http:request(self.controller .. "api/bootstrap", {
            options = {
                checkCertificate = false,
                method = 'GET',
                headers = {
                    ['Authorization'] = self.token
                }
            },
            success = function(response)
                if response.status == 200 then
                    --self:trace("checkMacUnifi() succeed")
                    body = json.decode(response.data)
                    cameras = body['cameras']
                    
                    for i, camera in ipairs(cameras) do
                      if string.lower(camera['mac']) == self.mac then
                        lastMotion = tonumber(camera['lastMotion']) / 1000
                        if (lastMotion ~= nil) and ((os.time() - lastMotion) < self.awaydelay) then
                            self:setPresenceStatus("Breached")
                        else
                            self:setPresenceStatus("Not breached")
                        end
                      end
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
end


function QuickApp:loginUnifi()
    if self.token == nil then
        self.http:request(self.controller .. "api/auth", {
            options = {
                checkCertificate = false,
                method = 'POST',
                headers = {
                    ['Content-Type'] = "application/json; charset=utf-8"
                },
                data = json.encode({
                    ['username'] = self.login,
                    ['password'] = self.password
                })
            },
            success = function(response)
                if response.status == 200 then
                    self.token = "Bearer " .. response.headers['Authorization']
                    self:debug("loginUnifi() succeed")
                else
                    self:error("loginUnifi() failed: ", json.encode(response.data))
                end
            end,
            error = function(error)
                self:error("loginUnifi() failed: ", json.encode(error))
            end
        })
    end
end


function QuickApp:mainLoop()
    self:loginUnifi()
    
    self:checkMacUnifi()

    fibaro.setTimeout(self.frequency * 1000, function()
        self:mainLoop()
    end)
end

function QuickApp:onInit()
    self:debug("onInit")
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

    self.mac = string.lower(self:getVariable("mac"))
    assert(self.mac ~= "", "mac is not set")

    self.awaydelay = tonumber(self:getVariable("away delay"))
    if self.awaydelay == nil then
        self:debug("onInit(): away delay equals frequency")
        self.awaydelay = self.frequency
    end

    self:setPresenceStatus("Unknown")
    self.token = nil
    self.http = net.HTTPClient({ timeout = 3000 })

    self:mainLoop()
end
