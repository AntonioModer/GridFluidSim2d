--C:\Users\Ryan\Downloads\ffmpeg\bin\ffmpeg.exe -framerate 30 -i 0%05d.png -c:v libx264 -r 30 -pix_fmt yuv420p out.mp4

lg = love.graphics
lk = love.keyboard
require("table_utils")
vector2 = require("vector2")
camera2d = require("camera2d")
mac_grid = require("mac_grid")

function love.keypressed(key)
  if key == "escape" then
    love.event.push("quit")
  end
  
  if key == "1" then
    FREEZE = not FREEZE
  end
end

function love.mousepressed(x, y, button)
  if button == "l" then
    local mpos = camera:get_pos()
    local i, j, k = grid:get_cell_index_at_position(x + mpos.x, y + mpos.y)
    
    --[[
    local size = 5
    for ii = i-size,i+size do
      for jj = j-size,j+size do
        cells[#cells+1] = {ii, jj, k}
      end
    end
    
    grid:reset()
    grid:set_initial_fluid_cells(cells)
    ]]--
    
    
    local r = 40
    local n = 50
    for i=1,n do
      local angle = math.random() * 2 * 3.14159
      local len = math.sqrt(math.random()) * r
      cells[#cells+1] = {x=math.sin(angle)*len + x + mpos.x, 
                    y=math.cos(angle)*len + y + mpos.y, z = 0}
    end
    
    
    --[[
    local n = 8000
    local border = 100
    for i=1,n do
      local x = math.random(-0.5*SCR_WIDTH + border, 0.5*SCR_WIDTH - border)
      local y = math.random(-0.5*SCR_HEIGHT + border, 0.5*SCR_HEIGHT - border)
      cells[#cells+1] = {x=x, y=y, z=0}
    end
    ]]--
    
    grid:set_initial_marker_particles(cells)
    
    grid:update(1/60)
  end
end

function love.load()
  SCR_WIDTH = lg.getWidth()
  SCR_HEIGHT = lg.getHeight()
  FREEZE = false
  camera = camera2d:new(vector2:new(0, 0))
  
  cells = {}
  
  grid = mac_grid:new()
  grid:set_cell_size(1)
  grid:set_cfl_scale(1)
  grid:set_time_step_range(1/10000, 1/30)
  grid:set_gravity_force(0, 500, 0)
  grid:set_bounds(0, -250, 500, 500)
  grid:update(1/60)
  
  frame_count = 0
  
  --love.mousepressed(0, 0, "l")
end

function love.update(dt)
  if lk.isDown("lctrl") then
    dt = dt / 8
  end

  -- camera update
  local cpos = camera:get_center()
  local target = vector2:new(cpos.x, cpos.y)
  local tx, ty = 0, 0
  local speed = 1000
  if lk.isDown("w", "up") then
    ty = ty - speed * dt
  end
  if lk.isDown("a", "left") then
    tx = tx - speed * dt
  end
  if lk.isDown("s", "down") then
    ty = ty + speed * dt
  end
  if lk.isDown("d", "right") then
    tx = tx + speed * dt
  end
  target.x, target.y = target.x + tx, target.y + ty
  camera:set_target(target, true)
  camera:update(dt)
  
  if FREEZE then return end

  local mx, my = love.mouse.getPosition()
  local mpos = camera:get_pos()
  grid:set_mouse_position(mx + mpos.x, my + mpos.y)
  
  if dt > (1/60) then
    dt = (1/60)
  end
  grid:update(1/30)
end

function love.draw()
  lg.setBackgroundColor(255, 255, 255, 255)
  lg.setPointStyle("rough")

  camera:set()

  -- axis
  
  lg.setColor(0, 0, 0, 255)
  lg.setLineWidth(2)
  local len = 100
  lg.line(0, 0, 100, 0)
  lg.line(0, 0, 0, 100)
  
  grid:draw()
  
  camera:unset()
  
  lg.setColor(255, 0, 0, 255)
  --lg.print("FPS "..love.timer.getFPS(), 10, 10)
  
  --[[
  local filename = string.format("%06d.png", frame_count);
  local imgdata = love.graphics.newScreenshot()
  imgdata:encode(filename)
  
  frame_count = frame_count + 1
  ]]--
end
















