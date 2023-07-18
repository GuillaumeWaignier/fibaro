-----------------------------------------------------------------------------
--                  NEST CAMERA (doorBeel, Hub, ...)                       --
--                  type: com.fibaro.motionSensor                          --
-----------------------------------------------------------------------------

-- Trigger only on person motion

class 'NestMotionPerson' (QuickAppChild)

function NestMotionPerson:__init(device)
    QuickAppChild.__init(self, device) 
    self:trace("NestMotionPerson init")

    self.lastMotion = 0
    self:mainLoop()
end

-- main loop
function NestMotionPerson:mainLoop()
    self:refresh()

    fibaro.setTimeout(10 * 1000, function()
        self:mainLoop()
    end)
end

function NestMotionPerson:updateDevice(body)
    --self:debug("updateDevice " .. self.id .. " with body " .. json.encode(body))

    local offset = os.time() - os.time(os.date("!*t"))
    
    local date_string = body['timestamp']
    local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)%.%d+Z"
    local year, month, day, hour, min, sec = date_string:match(pattern)
    local eventTime = os.time({year = year, month = month, day = day, hour = hour, min = min, sec = sec}) + offset

    if eventTime > self.lastMotion
    then
        self.lastMotion = eventTime
        self:refresh()
    end
end

function NestMotionPerson:refresh()
    local delta = os.time(os.date("!*t")) - self.lastMotion

    --self:debug("refresh()", "Duration since last motion " .. delta .. " seconds")

    if (delta < 60)
    then
       self:updateProperty('value', true)
       self:updateView("presenceStatus", "text", "Breached")
    else
       self:updateProperty('value', false)
       self:updateView("presenceStatus", "text", "Not breached")
    end
end
