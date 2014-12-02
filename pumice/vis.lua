-- PUMICE Copyright (C) 2009 Lars Rosengreen (-*-coding:iso-safe-unix-*-)
-- released as free software under the terms of MIT open source license
--
-- Create a png image of a matrix.
-- may or may not be suitable for framing


require "matrix"
require "gd"

vis = {}


-- Create a grayscale image of the elements of a matrix, and save it
-- as a png to a file. Zero elements are white, the lagest elements are black
function vis.bw(M, filename)
   local rows, columns = M:size()
   local rows, columns = rows + pixelSize - 1, columns + pixelSize - 1
   local min, max = M:min(), M:max()
   local range = max - min 
   local scale = 255 / range
   local img = assert(gd.createTrueColor(rows, columns))
   local white = img:colorAllocate(255, 255, 255)
   img:filledRectangle(0, 0, rows - 1, columns - 1, white)
   for i, v in M:vects() do
      for j, e in v:elts() do
         local shade = 255 - math.floor((e - min) * scale)
         assert(shade >= 0 and shade <= 255)
         shade = img:colorAllocate(shade, shade, shade)
         img:setPixel(i, j,  shade)
      end
   end
   img:png(filename)
end


function vis.fc(M, filename)
   local rows, columns = M:size()
   local min, max = M:min(), M:max()
   local range = max - min 
   local scale = 360 / range
   local img = assert(gd.createTrueColor(rows, columns))
   local white = img:colorAllocate(255, 255, 255)
   img:filledRectangle(0, 0, rows - 1, columns - 1, white)
   for i, v in M:vects() do
      for j, e in v:elts() do
         local r, g, b = HSVtoRGB(e * scale, 1, .8)
         hue = img:colorAllocate(r, g, b)
         img:setPixel(i - 1, j - 1,  hue)
      end
   end
   img:png(filename)
end


function vis.mask(M, fname, pixelSize, maskColor)
   pixelSize = pixelSize or 1
   maskColor = maskColor or {0, 0, 0}
   local rows, columns = M:size()
   local img = gd.create(rows + pixelSize -1, columns + pixelSize - 1)
   local background = img:colorAllocateAlpha(255, 255, 255, 127)
   local mask = img:colorAllocateAlpha(maskColor[1], 
                                       maskColor[2], 
                                       maskColor[3], 0)
   for i, v in M:vects() do
      for j, e in v:elts() do
         img:filledRectangle(i - 1, j - 1, i + pixelSize - 1, j + pixelSize - 1, mask)
      end
   end
   img:png(fname)
end


function vis.reduce(M, scale)
   local rows, columns = M:size()
   local scaledRows, scaledColumns = math.ceil(rows * scale), math.ceil(columns * scale)
   local R = matrix.new(scaledRows, scaledColumns)
   for i, v in M:vects() do
      for j, e in v:elts() do
         local ir = math.floor((i - 1) / rows * scaledRows) + 1
         local jr = math.floor((j - 1) / columns * scaledColumns + 1)
         e = e + R[ir][jr]
         R[ir][jr] = e
      end
   end
   return R
end


local function HSVtoRGB(h, s, v)
   local r, g, b
   local hi = math.floor(h / 60) % 6
   local f = h/60 - math.floor(h/60)
   local p = v * (1-s)
   local q = v * (1 - f * s)
   local t = v * (1 - (1- f) * s)
   if hi == 0 then
      r, g, b = v, t, p
   elseif hi == 1 then
      r, g, b = q, v, p
   elseif hi == 2 then
      r, g, b = p, v, t
   elseif hi == 3 then
      r, g, b = p, q, v
   elseif hi == 4 then
      r, g, b = t, p, v
   else 
      r, g, b = v, p, q
   end
   return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end
