--##########################################################################--
--[[----------------------------------------------------------------------]]--
-- master_timer object
--[[----------------------------------------------------------------------]]--
--##########################################################################--
local master_timer = {}
master_timer.table = MASTER_TIMER
master_timer.start_time = 0
master_timer.is_stopped = false
master_timer.inactive_time = 0
master_timer.current_time = 0
master_timer.time_scale = 1

local master_timer_mt = { __index = master_timer }
function master_timer:new()
  local start_time = love.timer.getTime()
  
  return setmetatable({ start_time = start_time }, master_timer_mt)
end


------------------------------------------------------------------------------
function master_timer:start()
  self.is_stopped = false
end

------------------------------------------------------------------------------
function master_timer:stop()
  self.is_stopped = true
end

function master_timer:set_time_scale(scale)
  self.time_scale = scale
end

------------------------------------------------------------------------------
function master_timer:update(dt)
  if self.is_stopped == true then
    self.inactive_time = self.inactive_time + dt * self.time_scale
  end
  
  self.current_time = self.current_time + dt * self.time_scale
end


------------------------------------------------------------------------------
-- returns time active since game started
function master_timer:get_time()
  return self.current_time - self.start_time - self.inactive_time
end

return master_timer
