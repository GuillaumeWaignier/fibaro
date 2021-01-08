function QuickApp:setPresenceStatus(status)
    if status == "Away" then
        self:updateProperty('value', false)
    else
        self:updateProperty('value', true)
    end
    self:updateView("presenceStatus", "text", status)
end

function QuickApp:loginUnifi()
    if self.cookie == nil then
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
                    ['rememberMe'] = false
                })
            },
            success = function(response)
                if response.status == 200 then
                    self.cookie = response.headers['Set-Cookie']
                    self.cookie = string.gsub(self.cookie, ";.*", "")
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

function QuickApp:checkMacUnifi()
    local macInfo, lastSeen

    if self.cookie ~= nil then
        self.http:request(self.controller .. "proxy/network/api/s/" .. self.site .. "/stat/user/" .. self.mac, {
            options = {
                checkCertificate = false,
                method = 'GET',
                headers = {
                    ['Cookie'] = self.cookie
                }
            },
            success = function(response)
                if response.status == 200 then
                    local macInfo = json.decode(response.data)
                    --self:trace("checkMacUnifi() succeed", json.encode(response.data))

                    if macInfo['meta']['rc'] == "ok" then
                        local isWifiConnected = macInfo['data'][1]['ap_mac']
                        if isWifiConnected ~= nil then
                          self.lastSeen = os.time()
                        end
                    end
                else
                    self.cookie = nil
                    self:error("checkMacUnifi() failed: ", json.encode(response.data))
                end
            end,
            error = function(error)
                self.cookie = nil
                self:error("checkMacUnifi() failed: ", json.encode(error))
            end
        })
    end
end

function QuickApp:computePresence()
  local delayPresence = os.time() - self.lastSeen
  if ( delayPresence < self.awaydelay) then
    --self:trace("computePresence() home",self.lastSeen .. " / " .. delayPresence)
    self:setPresenceStatus("Home")
  else
    self:setPresenceStatus("Away")
    --self:trace("computePresence() Away",self.lastSeen .. " / " .. delayPresence)
  end
end

function QuickApp:mainLoop()
    self:loginUnifi()
    self:checkMacUnifi()
    self:computePresence()

    fibaro.setTimeout(self.frequency * 1000, function()
        self:mainLoop()
    end)
end

function QuickApp:onInit()
    self.controller = self:getVariable("controller")
    assert(self.controller ~= "", "controller is not set")
    if string.sub(self.controller, -1) ~= "/" then
        self.controller = self.controller .. "/"
    end

    self.site = self:getVariable("site")
    assert(self.site ~= "", "site is not set")

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
    assert(string.match(self.mac, '^[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]$') ~= nil, "mac address format is incorrect")

    self.awaydelay = tonumber(self:getVariable("away delay"))
    if self.awaydelay == nil then
        self:debug("onInit(): away delay equals frequency")
        self.awaydelay = 2 * self.frequency
    end

    self.lastSeen = 0
    self:setPresenceStatus("Unknown")
    self.cookie = nil
    self.http = net.HTTPClient({ timeout = 3000 })

    self:mainLoop()
end
