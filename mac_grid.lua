local mac_cell = require("mac_cell")
local bbox = require("bbox")

local pumice_vector = require("pumice/vector")
local pumice_matrix = require("pumice/matrix")
local pumice_isolv = require("pumice/isolv")

local T_FLUID = 0
local T_AIR = 1
local T_SOLID = 2
local T_OBJECT = 3

local UP        = 1
local UPRIGHT   = 2
local RIGHT     = 3
local DOWNRIGHT = 4
local DOWN      = 5
local DOWNLEFT  = 6
local LEFT      = 7
local UPLEFT    = 8

--##########################################################################--
--[[----------------------------------------------------------------------]]--
-- mac_grid object
--[[----------------------------------------------------------------------]]--
--##########################################################################--
local mac_grid = {}
mac_grid.table = 'mac_grid'
mac_grid.debug = true
mac_grid.bbox = nil
mac_grid.cell_width = 30
mac_grid.cell_height = mac_grid.cell_width
mac_grid.active_cells = nil
mac_grid.free_cells = nil
mac_grid.free_chain_tables = nil
mac_grid.num_initial_free_cells = 1000
mac_grid.num_initial_free_chain_tables = 1000
mac_grid.marker_particles = nil
mac_grid.max_hash_value = 2^16

-- debug
mac_grid.mx = 0
mac_grid.my = 0

mac_grid.min_time_step = (1/60) / 5
mac_grid.max_time_step = (1/60) * 3
mac_grid.cfl_scale = 1
mac_grid.current_frame = 0
mac_grid.is_initialized = false

mac_grid.gravity_force = nil

-- temp tables
mac_grid.temp_fluid_cell_table = nil
mac_grid.temp_fluid_cell_hash = nil

-- pressure matrix equations
mac_grid.pressure_matrix = nil
mac_grid.free_pressure_matrix_rows = nil
mac_grid.pressure_matrix_vector = nil
mac_grid.pressure_matrix_solution_vector = nil
mac_grid.num_initial_pressure_matrix_rows = 1000
mac_grid.fluid_density = 10
mac_grid.air_density = 10
mac_grid.atmospheric_pressure = 0

local mac_grid_mt = { __index = mac_grid }
function mac_grid:new()
  local mac_grid = setmetatable({}, mac_grid_mt)
  mac_grid:_initialize_cell_tables()
  mac_grid:_initialize_pressure_matrix_equations()
  
  mac_grid.temp_fluid_cell_table = {}
  mac_grid.temp_fluid_cell_hash = {}
  
  return mac_grid
end

function mac_grid:set_time_step_range(min, max)
  self.min_time_step, self.max_time_step = min, max
end

function mac_grid:set_cfl_scale(scale)
  self.cfl_scale = scale
end

function mac_grid:set_bounds(x, y, width, height)
  self.bbox = bbox:new(x, y, width, height)
end

function mac_grid:set_gravity_force(gx, gy, gz)
  local gz = gz or 0
  self.gravity_force = {x = gx, y = gy, z = gz}
end

function mac_grid:set_mouse_position(mx, my)
  self.mx, self.my = mx, my
end

function mac_grid:reset()
  table.clear(self.marker_particles)
  self:_clear_cell_tables()
  self.current_frame = 0
  self.is_initialized = false
end


-- cells = {{i1, j1, k1}, {i2, j2, k2}, ...}
function mac_grid:set_initial_fluid_cells(cells)
  if self.is_initialized then 
    self:reset()
  end
  
  local markers = self.marker_particles
  for i=1,#cells do
    local c = cells[i]
    if not self:_is_cell_in_grid(c[1], c[2], c[3]) then
      local i, j, k = c[1], c[2], c[3]
      markers[#markers + 1] = self:_get_marker_particle_from_cell_index(i, j, k)
    end
  end
  
  self.is_initialized = true
end

function mac_grid:set_initial_marker_particles(particles)
  if self.is_initialized then 
    self:reset()
  end

  local markers = self.marker_particles
  for i=1,#particles do
    markers[i] = particles[i]
  end
  
  self.is_initialized = true
end

function mac_grid:_get_marker_particle_from_cell_index(i, j, k)
  local x, y, z = self:get_cell_position_at_index(i, j, k)
  x = x + 0.5 * self.cell_width
  y = y + 0.5 * self.cell_width
  
  local m = {x = x, y = y, z = z}  
  return m
end

function mac_grid:_insert_cell(i, j, k)
  local h = self:get_cell_hash(i, j, k)
  local cells = self.active_cells
  if not cells[h] then
    cells[h] = self:_get_new_chain_table()
  end
  
  local c = self:_get_new_cell()
  c:initialize(i, j, k)
  cells[h][#cells[h] + 1] = c
  
  return c
end

function mac_grid:_get_new_cell()
  if #self.free_cells == 0 then
    self.free_cells[1] = mac_cell:new(self)
  end
  
  local cell = self.free_cells[#self.free_cells]
  self.free_cells[#self.free_cells] = nil
  return cell
end

function mac_grid:_get_new_chain_table()
  if #self.free_chain_tables == 0 then
    self.free_chain_tables[1] = mac_cell:new(self)
  end
  
  local chain = self.free_chain_tables[#self.free_chain_tables]
  self.free_chain_tables[#self.free_chain_tables] = nil
  return chain
end

function mac_grid:_initialize_cell_tables()
  self.active_cells = {}
  self.free_cells = {}
  self.free_chain_tables = {}
  self.marker_particles = {}
  
  for i=1,self.num_initial_free_cells do
    self.free_cells[i] = mac_cell:new(self)
  end
  
  for i=1,self.num_initial_free_chain_tables do
    self.free_chain_tables[i] = {}
  end
end

function mac_grid:set_cell_size(size)
  self.cell_width = size
  self.cell_height = size
end

function mac_grid:get_cell_size()
  return self.cell_width
end

function mac_grid:_clear_cell_tables()
  for hash,chain in pairs(self.active_cells) do
    self.active_cells[hash] = nil
    for i=1,#chain do
      self.free_cells[#self.free_cells+1] = chain[i]
      chain[i] = nil
      self.free_chain_tables[#self.free_chain_tables+1] = chain
    end
  end
end

function mac_grid:get_cell_index_at_position(x, y)
  local inv = 1 / self.cell_width
  local i, j, k = math.floor(x * inv), math.floor(y * inv), 0
  return i, j, k
end

function mac_grid:get_cell_position_at_index(i, j, k)
  local k = k or 0
  local size = self.cell_width
  return i * size, j * size, k * size
end

function mac_grid:get_cell_at_index(i, j, k)
  local k = k or 0

  local h = self:get_cell_hash(i, j, k)
  if self.active_cells[h] then
    local chain = self.active_cells[h]
    for idx=1,#chain do
      local cell = chain[idx]
      if cell.i == i and cell.j == j and cell.k == k then
        return cell
      end
    end
  end
  
  return false
end

function mac_grid:get_cell_hash(i, j, k)
  local k = k or 0
  return (541*i + 79*j + 31*k) % self.max_hash_value + 1
end

function mac_grid:_is_cell_in_grid(i, j, k)
  local h = self:get_cell_hash(i, j, k)
  if self.active_cells[h] then
    local chain = self.active_cells[h]
    for idx=1,#chain do
      local cell = chain[idx]
      if cell.i == i and cell.j == j and cell.k == k then
        return true
      end
    end
  end
  
  return false
end

function mac_grid:_is_cell_in_bounds(cell)
  if not self.bbox then
    return true
  end
  local px, py = self:get_cell_position_at_index(cell.i, cell.j, cell.k)
  px = px + 0.5 * self.cell_width
  py = py + 0.5 * self.cell_width
  return self.bbox:contains_coordinate(px, py)
end

function mac_grid:_is_point_in_bounds(x, y)
  if not self.bbox then
    return true
  end
  
  return self.bbox:contains_coordinate(x, y)
end

function mac_grid:_is_cell_index_in_bounds(i, j, k)
  if not self.bbox then
    return true
  end

  local px, py = self:get_cell_position_at_index(i, j, k)
  px = px + 0.5 * self.cell_width
  py = py + 0.5 * self.cell_width
  
  return self.bbox:contains_coordinate(px, py)
end

------------------------------------------------------------------------------
function mac_grid:_initialize_cell_layer_values(value)
  local cells = self.active_cells
  for h,chain in pairs(cells) do
    for i=1,#chain do
      chain[i].layer = value
    end
  end
end

function mac_grid:_update_cells_containing_fluid()
  local markers = self.marker_particles
  for i=1,#markers do
    local m = markers[i]
    local i, j, k = self:get_cell_index_at_position(m.x, m.y)
    
    if not self:_is_cell_in_grid(i, j, k) then
      if self:_is_cell_index_in_bounds(i, j, k) then
        local cell = self:_insert_cell(i, j, k)
        cell.type = T_FLUID
        cell.layer = 0
      end
    else
      local cell = self:get_cell_at_index(i, j, k)
      if cell and cell.type ~= T_OBJECT then
        cell.layer = 0
        
        if self:_is_cell_index_in_bounds(i, j, k) then
          cell.type = T_FLUID
        else
          cell.type = T_SOLID
        end
      end
    end
    
  end
end

function mac_grid:_remove_unused_cells()
  local cells = self.active_cells
  for h,chain in pairs(cells) do
    for i=#chain,1,-1 do
      if chain[i].layer == -1 then
        local cell = table.remove(chain, i)
        self.free_cells[#self.free_cells+1] = cell
      end
    end
    
    if #chain == 0 then
      cells[h] = nil
      self.free_chain_tables[#self.free_chain_tables + 1] = chain
    end
  end
end

function mac_grid:_update_buffer_cells()
  local buffer = math.max(2, math.ceil(self.cfl_scale))
  local cells = self.active_cells
  local cell_list = {}
  
  for b=1,buffer do
    table.clear(cell_list)
    for h,chain in pairs(cells) do
      for j=1,#chain do
        cell_list[#cell_list+1] = chain[j]
      end
    end
    
    
    for j=1,#cell_list do
      local c = cell_list[j]
      if c.layer == b - 1 and (c.type == T_FLUID or c.type == T_AIR) then
        local ci, cj = c.i, c.j
        for row_idx=ci-1,ci+1 do
          for col_idx=cj-1,cj+1 do
            if not (row_idx == ci and col_idx == cj) then
              
              if self:_is_cell_in_grid(row_idx, col_idx, 0) then
                local n = self:get_cell_at_index(row_idx, col_idx, 0)
                if n.layer == -1 and (n.type ~= T_SOLID or n.type ~= T_OBJECT) then
                  n.layer = b
                  
                  if self:_is_cell_in_bounds(n) then
                    n.type = T_AIR
                  else
                    n.type = T_SOLID
                  end
                end
              else
                local n = self:_insert_cell(row_idx, col_idx, 0)
                n.layer = b
                if self:_is_cell_in_bounds(n) then
                  n.type = T_AIR
                else
                  n.type = T_SOLID
                end
              end
            
            end
          end
        end
        
        
      end
    end
  end
  
end

function mac_grid:_set_cell_neighbours(cell)
  local i, j = cell.i, cell.j
  local neighbours = cell.neighbours
  table.clear(neighbours)
  
  if self:_is_cell_in_grid(i, j-1, 0) then
    neighbours[UP] = self:get_cell_at_index(i, j-1, 0)
  end
  if self:_is_cell_in_grid(i+1, j-1, 0) then
    neighbours[UPRIGHT] = self:get_cell_at_index(i+1, j-1, 0) 
  end
  if self:_is_cell_in_grid(i+1, j, 0) then
    neighbours[RIGHT] = self:get_cell_at_index(i+1, j, 0)
  end
  if self:_is_cell_in_grid(i+1, j+1, 0) then
    neighbours[DOWNRIGHT] = self:get_cell_at_index(i+1, j+1, 0)
  end
  if self:_is_cell_in_grid(i, j+1, 0) then
    neighbours[DOWN] = self:get_cell_at_index(i, j+1, 0)
  end
  if self:_is_cell_in_grid(i-1, j+1, 0) then
    neighbours[DOWNLEFT] = self:get_cell_at_index(i-1, j+1, 0)
  end
  if self:_is_cell_in_grid(i-1, j, 0) then
    neighbours[LEFT] = self:get_cell_at_index(i-1, j, 0)
  end
  if self:_is_cell_in_grid(i-1, j-1, 0) then
    neighbours[UPLEFT] = self:get_cell_at_index(i-1, j-1, 0)
  end
end

function mac_grid:_update_cell_neighbours()
  local cells = self.active_cells
  for h,chain in pairs(cells) do
    for i=1,#chain do
      self:_set_cell_neighbours(chain[i])
    end
  end
end

function mac_grid:_update_dynamic_grid()
  self:_initialize_cell_layer_values(-1)
  self:_update_cells_containing_fluid()
  self:_update_buffer_cells()
  self:_remove_unused_cells()
  self:_update_cell_neighbours()
end

function mac_grid:_get_maximum_cell_velocity()
  local cells = self.active_cells
  
  local max_speed = 0
  local max_vx = 0
  local max_vy = 0
  for h,chain in pairs(cells) do
    for i=1,#chain do
      local vx, vy = chain[i].velocity_x, chain[i].velocity_y
      if vx*vx + vy*vy > max_speed * max_speed then
        max_speed = math.sqrt(vx*vx + vy*vy)
        max_vy, max_vy = vx, vy
      end
    end
  end
  
  return max_speed
end

function mac_grid:_get_velocity_at_position(x, y)
  local i, j = self:get_cell_index_at_position(x, y)
  local cx, cy = self:get_cell_position_at_index(i, j)
  local cell = self:get_cell_at_index(i, j)
  local size = self.cell_width
  local inv_size = 1/size
  
  if not cell then
    return 0, 0 
  end
  
  --[[
  local nbs = cell.neighbours
  
  -- velocity x interpolation
  local p1x, p1y 
  local v1, v2, v3, v4 = 0, 0, 0, 0
  local vx
  
  if y < cy + 0.5 * size then
    p1x, p1y = cx, cy - 0.5*size
                     
   if nbs[UP]      then v1 = nbs[UP].velocity_x end
   if nbs[UPRIGHT] then v2 = nbs[UPRIGHT].velocity_x end
   if nbs[RIGHT]   then v3 = nbs[RIGHT].velocity_x end
   if cell         then v4 = cell.velocity_x end
  else
    p1x, p1y = cx, cy + 0.5*size
                     
   if cell           then v1 = cell.velocity_x end
   if nbs[RIGHT]     then v2 = nbs[RIGHT].velocity_x end
   if nbs[DOWNRIGHT] then v3 = nbs[DOWNRIGHT].velocity_x end
   if nbs[DOWN]      then v4 = nbs[DOWN].velocity_x end
  end
  
  local rx = (x - p1x) * inv_size
  local ry = (y - p1y) * inv_size
  local hx1 = v1 + rx * (v2 - v1)
  local hx2 = v4 + rx * (v3 - v4)
  vx = hx1 + ry * (hx2 - hx1)
  
  -- velocity y interpolation
  local p1x, p1y
  local v1, v2, v3, v4 = 0, 0, 0, 0
  local vy
  
  if x < cx + 0.5 * size then
    p1x, p1y = cx - 0.5*size, cy
                     
    if nbs[LEFT]     then v1 = nbs[LEFT].velocity_y end
    if cell          then v2 = cell.velocity_y end
    if nbs[DOWN]     then v3 = nbs[DOWN].velocity_y end
    if nbs[DOWNLEFT] then v4 = nbs[DOWNLEFT].velocity_y end
  else
    p1x, p1y = cx + 0.5*size, cy
                     
    if cell           then v1 = cell.velocity_y end
    if nbs[RIGHT]     then v2 = nbs[RIGHT].velocity_y end
    if nbs[DOWNRIGHT] then v3 = nbs[DOWNRIGHT].velocity_y end
    if nbs[DOWN]      then v4 = nbs[DOWN].velocity_y end
  end
  
  local rx = (x - p1x) * inv_size
  local ry = (y - p1y) * inv_size
  local hx1 = v1 + rx * (v2 - v1)
  local hx2 = v4 + rx * (v3 - v4)
  vy = hx1 + ry * (hx2 - hx1)
  
  ]]--
  
  local nbs = cell.neighbours
  
  -- top left corner
  local p1_x1, p1_x2 = 0, 0
  p1_x1 = cell.velocity_x
  if nbs[UP] then p1_x2 = nbs[UP].velocity_x end
  
  local p1_y1, p1_y2 = 0, 0
  p1_y1 = cell.velocity_y
  if nbs[LEFT] then p1_y2 = nbs[LEFT].velocity_y end
  
  local p1x = 0.5 * (p1_x1 + p1_x2)
  local p1y = 0.5 * (p1_y1 + p1_y2)
  
  -- top right corner
  local p2_x1, p2_x2 = 0, 0
  if nbs[UPRIGHT] then p2_x1 = nbs[UPRIGHT].velocity_x end
  if nbs[RIGHT] then p2_x2 = nbs[RIGHT].velocity_x end
  
  local p2_y1, p2_y2 = 0, 0
  p2_y1 = cell.velocity_y
  if nbs[RIGHT] then p2_y2  = nbs[RIGHT].velocity_y end
  
  local p2x = 0.5 * (p2_x1 + p2_x2)
  local p2y = 0.5 * (p2_y1 + p2_y2)
  
  -- bottom right corner
  local p3_x1, p3_x2 = 0, 0
  if nbs[RIGHT] then p3_x1 = nbs[RIGHT].velocity_x end
  if nbs[DOWNRIGHT] then p3_x2 = nbs[DOWNRIGHT].velocity_x end
  
  local p3_y1, p3_y2 = 0, 0
  if nbs[DOWNRIGHT] then p3_y1 = nbs[DOWNRIGHT].velocity_y end
  if nbs[DOWN] then p3_y2 = nbs[DOWN].velocity_y end
  
  local p3x = 0.5 * (p3_x1 + p3_x2)
  local p3y = 0.5 * (p3_y1 + p3_y2)
  
  -- bottom left corner
  local p4_x1, p4_x2 = 0, 0
  p4_x1 = cell.velocity_x
  if nbs[DOWN] then p4_x2 = nbs[DOWN].velocity_x end
  
  local p4_y1, p4_y2 = 0, 0
  if nbs[DOWN] then p4_y1 = nbs[DOWN].velocity_y end
  if nbs[DOWNLEFT] then p4_y2 = nbs[DOWNLEFT].velocity_y end
  
  local p4x = 0.5 * (p4_x1 + p4_x2)
  local p4y = 0.5 * (p4_y1 + p4_y2)
  
  -- bi linear interpolation for x
  local inv_size = 1 / self.cell_width
  local rh = (x - cx) * inv_size
  local rv = (y - cy) * inv_size
  local h1 = p1x + rh * (p2x - p1x)
  local h2 = p4x + rh * (p3x - p4x)
  local vx = h1 + rv * (h2 - h1)
  
  -- bi linear interpolation for y
  local h1 = p1y + rh * (p2y - p1y)
  local h2 = p4y + rh * (p3y - p4y)
  local vy = h1 + rv * (h2 - h1)
  
  return vx, vy
end

function mac_grid:_calculate_next_time_step()
  local h = self.cell_width
  local maxv = self:_get_maximum_cell_velocity()
  
  if maxv == 0 then
    return self.max_time_step
  end
  
  local dt = self.cfl_scale * (h / maxv)
  
  dt = math.min(dt, self.max_time_step)
  dt = math.max(dt, self.min_time_step)
  
  return dt
end

function mac_grid:_trace_particle(x, y, dt)
  local vx1, vy1 = self:_get_velocity_at_position(x, y)
  local vx2, vy2 = self:_get_velocity_at_position(x + 0.5*vx1*dt, y + 0.5*vy1*dt)
  
  return x + vx2*dt, y + vy2*dt
end

function mac_grid:_apply_convection_to_velocity_field(dt)
  local cells = self.active_cells
  local size = self.cell_width
  
  -- convect
  for h,chain in pairs(cells) do
    for i=1,#chain do
      local cell = chain[i]
      local cx, cy = self:get_cell_position_at_index(cell.i, cell.j, 0)
      
      -- convect x velocity
      local px, py = self:_trace_particle(cx, cy + 0.5 * size, -dt)
      local vx, vy = self:_get_velocity_at_position(px, py)

      cell.new_velocity_x = vx
      
      -- convect y velocity
      local px, py = self:_trace_particle(cx + 0.5 * size, cy, -dt)
      local vx, vy = self:_get_velocity_at_position(px, py)
      cell.new_velocity_y = vy
    end
  end
  
  -- update velocity to new velocity values
  for h,chain in pairs(cells) do
    for i=1,#chain do
      local cell = chain[i]
      cell.velocity_x = cell.new_velocity_x
      cell.velocity_y = cell.new_velocity_y
      cell.new_velocity_x = 0
      cell.new_velocity_y = 0
    end
  end
  
end

function mac_grid:_apply_circular_force_to_fluid_cells(dt, radius, w, dir)
  local r = radius
  local width = w
  local min_force = 0
  local max_force = 100
  local mindsq = (r - width)^2
  local maxdsq = (r + width)^2
  
  local cells = self.active_cells
  for h,chain in pairs(cells) do
    for i=1,#chain do
      if chain[i].type == T_FLUID then
        local cell = chain[i]
        local cx, cy = self:get_cell_position_at_index(cell.i, cell.j)
        cx = cx + 0.5 * self.cell_width
        cy = cy + 0.5 * self.cell_height
        
        if cx*cx + cy*cy > mindsq and cx*cx + cy*cy < maxdsq then
      
          local dist = math.sqrt(cx*cx + cy*cy)
          local dirx, diry = dir*(-cy/dist), dir*(cx/dist)
          local factor
          if dist < r + width and dist > r then
            factor = (dist - r) / width
          else
            factor = (r - dist) / width
          end
          local fmag = min_force + factor * (max_force - min_force)
          local fx, fy = dirx * fmag, diry * fmag
        
          local cell_right = cell.neighbours[RIGHT]
          local cell_down = cell.neighbours[DOWN]
          
          cell.velocity_x = cell.velocity_x + fx * dt
          cell.velocity_y = cell.velocity_y + fy * dt
          
          if cell_right then
            cell_right.velocity_x = cell_right.velocity_x + fx * dt
          end
          
          if cell_down then
            cell_down.velocity_y = cell_down.velocity_y + fy * dt
          end
        end
        
      end
    end
  end
  
end

function mac_grid:_apply_gravity_force_to_fluid_cells(dt)
  if not self.gravity_force then return end
  
  local force = self.gravity_force
  local cells = self.active_cells
  for h,chain in pairs(cells) do
    for i=1,#chain do
      if chain[i].type == T_FLUID then
        local cell = chain[i]
        local cell_right = cell.neighbours[RIGHT]
        local cell_down = cell.neighbours[DOWN]
        
        cell.velocity_x = cell.velocity_x + force.x * dt
        cell.velocity_y = cell.velocity_y + force.y * dt
        
        if cell_right and cell_right.type == T_AIR then
          cell_right.velocity_x = cell_right.velocity_x + force.x * dt
        end
        
        if cell_down and cell_down.type == T_AIR then
          cell_down.velocity_y = cell_down.velocity_y + force.y * dt
        end
        
      end
    end
  end
end

function mac_grid:_initialize_pressure_matrix_equations()
  self.pressure_matrix = {}
  self.free_pressure_matrix_rows = {}
  self.pressure_matrix_vector = {}
  self.pressure_matrix_solution_vector = {}
  
  for i=1,self.num_initial_pressure_matrix_rows do
    self.free_pressure_matrix_rows[i] = {}
  end
end

function mac_grid:_get_empty_pressure_matrix_tables(num_equations)
  local free = self.free_pressure_matrix_rows
  local matrix = self.pressure_matrix
  local vector = self.pressure_matrix_vector
  
  -- clear system
  for i=#matrix,1,-1 do
    local row = matrix[i]
    for idx,c in pairs(row) do
      row[idx] = nil
    end
    matrix[i] = nil
    free[#free+1] = row
  end
  
  table.clear(vector)
  
  -- fill matrix with enough rows
  for i=1,num_equations do
    if #free == 0 then
      for i=1,100 do
        free[#free + 1] = {}
      end
    end
    matrix[i] = free[#free]
    free[#free] = nil
    
    for j=1,num_equations do
      matrix[i][j] = 0
    end
  end
  
  return matrix, vector
end

function mac_grid:_construct_pressure_equations(dt, fluid_cells)
  local matrix, vector = self:_get_empty_pressure_matrix_tables(#fluid_cells)
  local index_by_cell = self.temp_fluid_cell_hash
  table.clear_hash(index_by_cell)
  
  for i=1,#fluid_cells do
    index_by_cell[fluid_cells[i]] = i
  end
  
  -- construct system of equations
  for i=1,#fluid_cells do
    local cell = fluid_cells[i]
    local row = matrix[i]
    
    -- matrix row
    local non_solid_count = 0
    local air_count = 0
    for dir,n in pairs(cell.neighbours) do
      if dir % 2 == 1 then
        if n.type ~= T_SOLID then
          non_solid_count = non_solid_count + 1
          
          if n.type == T_FLUID then
            local nidx = index_by_cell[n]
            row[nidx] = 1
          end
          
          if n.type == T_AIR then
            air_count = air_count + 1
          end
        end
      end
    end
    row[i] = -non_solid_count
    
    -- vector value
    local vx_min, vx_max = 0, 0
    local vy_min, vy_max = 0, 0
    if cell.neighbours[LEFT].type ~= T_SOLID then
      vx_min = cell.velocity_x
    end
    if cell.neighbours[RIGHT].type ~= T_SOLID then
      vx_max = cell.neighbours[RIGHT].velocity_x
    end
    if cell.neighbours[UP].type ~= T_SOLID then
      vy_min = cell.velocity_y
    end
    if cell.neighbours[DOWN].type ~= T_SOLID then
      vy_max = cell.neighbours[DOWN].velocity_y
    end
    
    local size = self.cell_width
    local div_vector_field = ((vx_max - vx_min) + (vy_max - vy_min)) / size
    local fluid_density = self.fluid_density
    local atm = self.atmospheric_pressure
    
    vector[i] = ((fluid_density*size)/dt)*div_vector_field - air_count*atm
  end
  
  return matrix, vector
end

function mac_grid:_solve_pressure_equations(matrix, vector)
  local solution = self.pressure_matrix_solution_vector
  table.clear(solution)
  
  p_matrix = pumice_matrix(matrix)
  p_vector = pumice_vector(vector)
  local isolv = pumice_isolv.cg(p_matrix, p_vector, 0.000001)
  for i=1,#isolv.elements do
    solution[i] = isolv.elements[i]
  end

  return solution
end

function mac_grid:_update_fluid_velocities_from_fluid_pressure(dt, fluid_cells)

  local fluid_density = self.fluid_density
  local air_density = self.air_density
  local atm = self.atmospheric_pressure
  local size = self.cell_width
  for i=1,#fluid_cells do
    cell = fluid_cells[i]
    local cell_right = cell.neighbours[RIGHT]
    local cell_left = cell.neighbours[LEFT]
    local cell_up = cell.neighbours[UP]
    local cell_down = cell.neighbours[DOWN]
    
    if cell_left.type == T_FLUID or cell_left.type == T_AIR then
      local density
      if     cell_left.type == T_FLUID then
        density = fluid_density
      elseif cell_left.type == T_AIR then
        density = air_density
      end
      local p1 = cell.pressure
      local p2 = cell_left.pressure
      
      cell.velocity_x = cell.velocity_x - (dt/(density*size)) * ((p1 - p2) / size)
    end
    
    if cell_up.type == T_FLUID or cell_up.type == T_AIR then
      local density
      if     cell_up.type == T_FLUID then
        density = fluid_density
      elseif cell_up.type == T_AIR then
        density = air_density
      end
      local p1 = cell.pressure
      local p2 = cell_up.pressure
      
      cell.velocity_y = cell.velocity_y - (dt/(density*size)) * ((p1 - p2) / size)
    end
    
    if cell_right.type == T_AIR then
      local density = air_density
      local p1 = cell_right.pressure
      local p2 = cell.pressure
 
      cell_right.velocity_x = cell_right.velocity_x - (dt/(density*size)) * ((p1 - p2) / size)
    end
    
    if cell_down.type == T_AIR then
      local density = air_density
      local p1 = cell_down.pressure
      local p2 = cell.pressure
 
      cell_down.velocity_y = cell_down.velocity_y - (dt/(density*size)) * ((p1 - p2) / size)
    end
    
  end

end

function mac_grid:_extrapolate_fluid_velocities_into_surrounding_cells()
  local cells = self.active_cells
  for h,chain in pairs(cells) do
    for i=1,#chain do
      if chain[i].type == T_FLUID then
        chain[i].layer = 0
      else
        chain[i].layer = -1
      end
    end
  end
  
  for b=1,math.max(2,self.cfl_scale) do
    for h,chain in pairs(cells) do
      for i=1,#chain do
        local cell = chain[i]
        if cell.layer == -1 then
         
          local neighbour_condition = false
          for dir,ncell in pairs(cell.neighbours) do
            if dir % 2 == 1 then
              if ncell.layer == b-1 then
                neighbour_condition = true
                break
              end
            end
          end
          
          if neighbour_condition then
            local avg_vx = 0
            local avg_vy = 0
            local vx_count = 0
            local vy_count = 0
            local is_x_not_fluid, is_y_not_fluid = false, false
            if cell.neighbours[LEFT] and cell.neighbours[LEFT].type ~= T_FLUID then
              is_x_not_fluid = true
            end
            if cell.neighbours[UP] and cell.neighbours[UP].type ~= T_FLUID then
              is_y_not_fluid = true
            end
            
            if is_x_not_fluid or is_y_not_fluid then
              for dir,ncell in pairs(cell.neighbours) do
                if dir % 2 == 1 then
                  if ncell.layer == b-1 then
                    avg_vx = avg_vx + ncell.velocity_x
                    avg_vy = avg_vy + ncell.velocity_y
                    vx_count = vx_count + 1
                    vy_count = vy_count + 1
                  end
                end
              end
            end
            
            if vx_count > 0 then
              avg_vx = avg_vx / vx_count
            end
            if vy_count > 0 then
              avg_vy = avg_vy / vy_count
            end
            
            if is_x_not_fluid then
              cell.velocity_x = avg_vx
            end
            if is_y_not_fluid then
              cell.velocity_y = avg_vy
            end
            
            cell.layer = b
          end
        
        end
      end
    end
  end
end

function mac_grid:_set_velocity_of_solid_cells()
  local cells = self.active_cells
  for h,chain in pairs(cells) do
    for i=1,#chain do
      local cell = chain[i]
      if cell.type == T_SOLID then
        
        if cell.velocity_x > 0 then
          cell.velocity_x = 0
        end
        if cell.velocity_y > 0 then
          cell.velocity_y = 0
        end
        if cell.neighbours[RIGHT] and cell.neighbours[RIGHT].velocity_x < 0 then
          cell.neighbours[RIGHT].velocity_x = 0
        end
        if cell.neighbours[DOWN] and cell.neighbours[DOWN].velocity_y < 0 then
          cell.neighbours[DOWN].velocity_y = 0
        end
      
      end
    end
  end
end

function mac_grid:_apply_pressure_to_velocity_field(dt)
  local fluid_cells = self.temp_fluid_cell_table
  table.clear(fluid_cells)
  
  local cells = self.active_cells
  for h,chain in pairs(cells) do
    for i=1,#chain do 
      if chain[i].type == T_FLUID then
        fluid_cells[#fluid_cells + 1] = chain[i]
      end
    end
  end
  print(#fluid_cells)
  
  if #fluid_cells == 0 then
    return
  end

  local matrix, vector = self:_construct_pressure_equations(dt, fluid_cells)
  local pressure_solution = self:_solve_pressure_equations(matrix, vector)
  
  for i=1,#fluid_cells do
    fluid_cells[i].pressure = pressure_solution[i]
  end
  
  for h,chain in pairs(cells) do
    for i=1,#chain do 
      if chain[i].type == T_AIR then
        chain[i].pressure = self.atmospheric_pressure
      elseif chain[i].type == T_SOLID then
        chain[i].pressure = 0
      end
    end
  end
  
  self:_update_fluid_velocities_from_fluid_pressure(dt, fluid_cells)
  self:_extrapolate_fluid_velocities_into_surrounding_cells()
  self:_set_velocity_of_solid_cells()
  
  -- debugging divergence
  local total = 0
  local count = 0
  local cells = self.active_cells
  for h,chain in pairs(cells) do
    for i=1,#chain do
      if chain[i].type == T_FLUID then
        local cell = chain[i]
        local cell_right = chain[i].neighbours[RIGHT]
        local cell_down = chain[i].neighbours[DOWN]
        
        local v1x = cell_right.velocity_x
        local v2x = cell.velocity_x
        local v1y = cell_down.velocity_y
        local v2y = cell.velocity_y
        local size = self.cell_width
        
        total = total + math.abs((v1x-v2x)/size + (v1y-v2y)/size)
        count = count + 1
      end
    end
  end
  print(total/count)
  
end

function mac_grid:_advance_marker_particles(dt)
  local markers = self.marker_particles
  for i=1,#markers do
    local m = markers[i]
    local x, y = self:_trace_particle(m.x, m.y, dt)
    if self:_is_point_in_bounds(x, y) then
      m.x, m.y = x, y
    end
  end
end

local total_time = 0
function mac_grid:update(dt)
  
  if not self.is_initialized then return end

  local start_time = love.timer.getTime()

  -- simulation loop
  local num_steps = 0
  local time_left = dt
  while time_left > 0 do
    self:_update_dynamic_grid()
  
    local time_step = self:_calculate_next_time_step()
    if time_left - time_step < 0 then
      time_step = time_left
    end
    time_left = time_left - time_step
    num_steps = num_steps + 1
    
    self:_apply_convection_to_velocity_field(time_step)
    self:_apply_gravity_force_to_fluid_cells(time_step)
    --self:_apply_circular_force_to_fluid_cells(time_step, 120, 20, 1)
    --self:_apply_circular_force_to_fluid_cells(time_step, 230, 20, -1)
    self:_apply_pressure_to_velocity_field(time_step)
    self:_advance_marker_particles(time_step)
  end
  
  local end_time = love.timer.getTime()
  total_time = total_time + end_time - start_time
  
  --print(self.current_frame, num_steps, end_time - start_time, total_time)
  
  self.current_frame = self.current_frame + 1
  
end

function mac_grid:_draw_velocity_field()
  
  local maxs = self:_get_maximum_cell_velocity()
  local len = 0.5 * self.cell_width
  local size = self.cell_width
  
  lg.setColor(0, 0, 255, 255)
  lg.setLineWidth(1)

  for h,chain in pairs(self.active_cells) do
    for i=1,#chain do
      local c = chain[i]
      local x, y = self:get_cell_position_at_index(c.i, c.j)
      x, y = x + 0.5 * size, y + 0.5 * size
      
      local vx, vy = cell.velocity_x, cell.velocity_y
      local mag = math.sqrt(vx*vx + vy*vy)
      if mag > 0 then
        vx, vy = vx/mag, vy/mag
        local r = mag / maxs
        lg.line(x, y, x + r*vx*len, y + r*vy*len)
      end
    end
  end

end

------------------------------------------------------------------------------
function mac_grid:draw()
  if not self.debug then return end
  
  --[[
  local size = self.cell_width
  local mx, my = self.mx, self.my
  local i, j = self:get_cell_index_at_position(mx, my)
  local x, y = self:get_cell_position_at_index(i, j)
  
  lg.setColor(0, 0, 255, 255)
  lg.setLineWidth(1)
  lg.rectangle("line", x, y, size, size)
  ]]--
  
  --[[
  local cell = self:get_cell_at_index(i, j)
  if cell then
    for _,n in pairs(cell.neighbours) do
      lg.setColor(0, 0, 0, 255)
      local x, y = self:get_cell_position_at_index(n.i, n.j)
      lg.rectangle("line", x, y, size, size)
    end
  end
  ]]--
  
  local markers = self.marker_particles
  lg.setPointSize(3)
  lg.setColor(0, 50, 255, 50)
  for i=1,#markers do
    local m = markers[i]
    --lg.point(m.x, m.y)
    lg.circle("fill", m.x, m.y, 5)
  end
  
  
  local cells = self.active_cells
  lg.setLineWidth(1)
  local size = grid:get_cell_size()
  for h,chain in pairs(cells) do
    for i=1,#chain do
      lg.setColor(0, 0, 255, 50)
    
      local c = chain[i]
      local x, y = grid:get_cell_position_at_index(c.i, c.j)
      lg.rectangle("line", x, y, size, size)
      
      if c.type == 0 then
        lg.setColor(0, 0, 255, 50)
      elseif c.type == 1 then
        lg.setColor(0, 255, 0, 50)
      elseif c.type == 2 then
        lg.setColor(0, 0, 0, 50)
      end
      
      lg.rectangle("fill", x, y, size, size)
      
    end
  end
  
  
  --[[
  local mx, my = self.mx, self.my
  local i, j = self:get_cell_index_at_position(mx, my)
  local cell = self:get_cell_at_index(i, j)
  
  if cell then
    local vx, vy = self:_get_velocity_at_position(mx, my)
    lg.line(mx, my, mx + vx, my + vy)
  end
  ]]--
  
  --self:_draw_velocity_field()
  
  
  if self.bbox then
    lg.setColor(0, 0, 0, 255)
    self.bbox:draw()
  end
  
end

return mac_grid

















