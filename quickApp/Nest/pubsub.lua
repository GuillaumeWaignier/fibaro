-----------------------------------------------------------------------------
--                  LISTEN NEST EVENT                                      --
--                  required for motion sensor                             --
-----------------------------------------------------------------------------



-- PubSub Event
function QuickApp:getPubSubEvent()
    if self.step == "nothing"
    then
        return
    end
    if self.step ~= "device"
    then
        fibaro.setTimeout(self.frequency * 1000, function()
            self:getPubSubEvent()
        end)
        return
    end

    self.pubsub:request("https://pubsub.googleapis.com/v1/projects/" .. self.gcpProjectId .. "/subscriptions/" .. self.subscription .. ":pull" , {
        options = {
            checkCertificate = true,
            method = 'POST',
            headers = {
                 ['Content-Type'] = "application/json; charset=utf-8",
                 ['Authorization'] = self.accessToken
            },
            data = json.encode({
                    ['maxMessages'] = 200
                })
        },
        success = function(response)
            if response.status == 200 then
                body = json.decode(response.data)
                self:updatePubSubEvent(body)
                fibaro.setTimeout(500, function()
                    self:getPubSubEvent()
                end)
            else
                self:error("getPubSubEvent() status is " .. response.status .. ": " .. response.data)
                fibaro.setTimeout(5000, function()
                    self:getPubSubEvent()
                end)
            end
        end,
        error = function(error)
            self:error("getPubSubEvent() failed: " .. json.encode(error))
            fibaro.setTimeout(5000, function()
                self:getPubSubEvent()
            end)
        end
    })
end

function QuickApp:updatePubSubEvent(body)
  messages = body['receivedMessages']
  --self:debug("updatePubSubEvent()", json.encode(messages))

  if messages == nil
  then
    return
  end

  local messageCount = 0
  local acksIds = {}

  for i, message in ipairs(messages)
  do
    local encodedData = message['message']['data']
    local dataString = self:base64_decode(encodedData)
    local data = json.decode(dataString)
    local event = ""
    local date = nil
    local name = nil

    messageCount = messageCount + 1
    acksIds[messageCount] = message['ackId']

    if data['resourceUpdate'] ~= nil and data['resourceUpdate']['events'] ~= nil
    then
      event = data['resourceUpdate']['events']
      name = data['resourceUpdate']['name']
    end

    if event['sdm.devices.events.CameraPerson.Person'] ~= nil
    then
      local fibaroDevice = self:getOrCreateChildDevice(name .. "Motion", data, "com.fibaro.motionSensor")
      fibaroDevice:updateDevice(data)
    elseif event['sdm.devices.events.DoorbellChime.Chime'] ~= nil
    then
      local fibaroDevice = self:getOrCreateChildDevice(name .. "Chime", data, "com.fibaro.motionSensor")
      fibaroDevice:updateDevice(data)
    end
  end

  if messageCount > 0
  then
      self:acknowledge(acksIds)
  end
end



function QuickApp:base64_decode(input)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    input = string.gsub(input, '[^'..b..'=]', '')
    input = string.gsub(input, '=', string.char(0))
    input = string.gsub(input, '.', function(x)
        if (x == string.char(0)) then return '' end
        local r, f = '', (b:find(x)-1)
        for i = 6, 1, -1 do
            r = r..(f % 2 ^ i - f % 2 ^ (i-1) > 0 and '1' or '0')
        end
        return r;
    end)
    input = string.gsub(input, '%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end)

    return input
end

function QuickApp:acknowledge(acksIds)
    self.pubsub:request("https://pubsub.googleapis.com/v1/projects/" .. self.gcpProjectId .. "/subscriptions/" .. self.subscription .. ":acknowledge" , {
        options = {
            checkCertificate = true,
            method = 'POST',
            headers = {
                 ['Content-Type'] = "application/json; charset=utf-8",
                 ['Authorization'] = self.accessToken
            },
            data = json.encode({
                    ['ackIds'] = acksIds
                })
        },
        success = function(response)
            if response.status == 200 then
                if self.maxLogDebugPubSub > 0
                then
                    self:debug("acknowledge OK for " .. #acksIds .. " events")
                    self.maxLogDebugPubSub = self.maxLogDebugPubSub - 1
                elseif self.maxLogDebugPubSub == 0
                then
                    self:debug("next acknowledge will not be logged")
                    self.maxLogDebugPubSub = self.maxLogDebugPubSub - 1
                end
            else
                self:error("acknowledge() for " .. #acksIds .. " events, status is " .. response.status .. ": " .. response.data)
            end
        end,
        error = function(error)
            self:error("acknowledge() for " .. #acksIds .. " events failed: " .. json.encode(error))
        end
    })
end
