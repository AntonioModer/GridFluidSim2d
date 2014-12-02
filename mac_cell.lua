
--##########################################################################--
--[[----------------------------------------------------------------------]]--
-- mac_cell object
--[[----------------------------------------------------------------------]]--
--##########################################################################--
local mac_cell = {}
mac_cell.table = 'mac_cell'
mac_cell.parent_grid = nil
mac_cell.i = nil
mac_cell.j = nil
mac_cell.k = nil
mac_cell.velocity_x = nil
mac_cell.velocity_y = nil
mac_cell.new_velocity_x = nil
mac_cell.new_velocity_y = nil
mac_cell.pressure = 0
mac_cell.type = nil
mac_cell.layer = nil
mac_cell.neighbours = nil

local mac_cell_mt = { __index = mac_cell }
function mac_cell:new(parent_grid)
  local mac_cell = setmetatable({}, mac_cell_mt)
  
  mac_cell.parent_grid = parent_grid
  mac_cell.neighbours = {}
  
  return mac_cell
end

function mac_cell:initialize(i, j, k)
  self.i, self.j, self.k = i, j ,k
  self.velocity_x = 0
  self.velocity_y = 0
  self.new_velocity_x = 0
  self.new_velocity_y = 0
  self.pressure = 0
  self.size = self.parent_grid:get_cell_size()
  self.type = nil
  self.layer = -1
  table.clear(self.neighbours)
  
  -- debugging
  local rads = math.random() * 3.14159 * 2
  local dx, dy = math.cos(rads), math.sin(rads)
  local len = math.random() * 500
  
  --self.velocity_x = dx*len
  --self.velocity_y = dy*len
  
end

------------------------------------------------------------------------------
function mac_cell:update(dt)
end

------------------------------------------------------------------------------
function mac_cell:draw()
end

return mac_cell



