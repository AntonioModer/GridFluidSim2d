local vector2 = require("vector2")
local point = require("point")

local DSCALE = 32   -- in pixels per metre
local EPSILON = 0.0000001
local VECT_ZERO = vector2:new(0, 0)

--##########################################################################--
--[[----------------------------------------------------------------------]]--
-- steer object - a point that steers toward it's target
--[[----------------------------------------------------------------------]]--
--##########################################################################--
local steer = {}
steer.table = PHYS_STEER
steer.dscale = DSCALE
steer.point = nil
steer.target = nil
steer.max_force = 10
steer.max_vel = 30         -- meters/s
steer.slow_radius = 400     -- in pixels
steer.approach_factor = 1
steer.temp_vector = nil
steer.force_vector = nil
steer.temp_direction = nil

local steer_mt = { __index = steer }
function steer:new(pos)
  local steer = setmetatable({}, steer_mt)
  local pos = pos or VECT_ZERO
  
  steer.pos = vector2:new(pos.x, pos.y)
  steer.point = point:new(pos)
  steer.target = vector2:new(pos.x, pos.y)
  steer.temp_vector = vector2:new(0, 0)
  steer.force_vector = vector2:new(0, 0)
  steer.temp_direction = vector2:new(0, 0)
                        
  return steer
end

function steer:set_target(target)
  self.target:clone(target)
end

function steer:set_position(pos)
  self.point:set_position(pos)
end

function steer:set_force(f)  -- scalar
  self.max_force = f
end

function steer:set_max_speed(s)
  self.max_vel = s
end

function steer:set_radius(r)
  self.slow_radius = r
end

function steer:set_mass(m)
  self.point:set_mass(m)
end

function steer:set_dscale(s)
	self.dscale = s
	self.point:set_dscale(s)
end

function steer:set_approach_factor(f)
	self.approach_factor = f
end

function steer:get_position()
  return self.point:get_position()
end

------------------------------------------------------------------------------
function steer:_get_steer_force()
  local target = self.target
  local pos = self.point:get_position()
  local desired = self.temp_vector
  desired:set(target.x - pos.x, target.y - pos.y)
  desired = desired:unit_vector(desired)
  local dir = self.temp_direction
  dir:clone(desired)
  
  -- set length of desired vector
  local r = self.slow_radius
  local dist_sq = vector2:dist_sq(pos, target)
  if dist_sq < r * r then
    local factor = self.approach_factor * (math.sqrt(dist_sq) / r) * self.max_vel
    desired:set(desired.x * factor, desired.y * factor) 
  else
    desired:set(desired.x * self.max_vel, desired.y * self.max_vel)
  end
  
  local force = self.force_vector
  force:set(desired.x - self.point.vel.x, desired.y - self.point.vel.y)
  if force:mag_sq() > self.max_force * self.max_force then
    force:set(self.max_force * dir.x, self.max_force * dir.y)
  end
  
  return force
end

------------------------------------------------------------------------------
function steer:update(dt)
  if self.target then
    local force = self:_get_steer_force()
    self.point:add_force(force)
  end
  
  self.point:update(dt)
end

------------------------------------------------------------------------------
function steer:draw()
  lg.setColor(255,0,0,255)
  lg.setPoint(4, "smooth")
  lg.point(self.point.pos:get_vals())
  
  if self.target then
    lg.setColor(0,255,0,150)
    lg.point(self.target:get_vals())
    lg.circle("line", self.target.x, self.target.y, self.slow_radius)
  end
end

return steer
