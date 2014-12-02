-- PUMICE Copyright (C) 2009 Lars Rosengreen (-*-coding:iso-safe-unix-*-)
-- released as free software under the terms of MIT open source license

require "vector"

local v1 = vector(1, 0, 1)
local v2 = vector{1, 2, 3, 4, 5}
local v3 = vector(1, -2, 3, -4)
local v4 = vector(1, 2, 3, 0, 0, 6)
local v5 = vector(0, 2, 5, 0, 8, 0)

-- test new and __call
assert(v1.size == 3)
assert(v2.size == 5)
assert(v1.type == "vector")
assert(v2.elements[3] == 3)
assert(v1.elements[2] == nil)

-- test __index
assert(v1[1] == 1)
assert(v1[2] == 0)
assert(v2["size"] == 5)
assert(v2[10] == 0)

-- test __newindex
local v = vector(1,0,2,3)
v[1] = 0
v[3] = 5
v[8] = "toobig"
v[-1] = "toosmall"
v["justright"] = "yawn"
assert(v[1] == 0)
assert(rawget(v.elements, 1) == nil)
assert(v[3] == 5)
assert(rawget(v.elements, 3) == 5)
assert(v[8] == "toobig")
assert(rawget(v.elements, 8) == "toobig")
assert(v[-1] == "toosmall")
assert(rawget(v.elements, -1) == "toosmall")
assert(v["justright"] == "yawn")
assert(v.justright == "yawn")
assert(rawget(v.elements, "justright") == "yawn")

-- test __eq
assert((v1 == 3) == false)
assert((2 == v2) == false)
assert((v1 == {}) == false)
assert(({} == v3) == false)
assert((v1 == v2) == false)
assert((v2 == v1) == false)
assert((v3 == v3) == true)
assert((v1 == vector(1, 1, 1)) == false)

-- test __add, __sub, __mul, __div
assert(v1 + v1 == vector(2, 0, 2))
assert(v1 - vector(1, -1, 1) == vector(0, 1, 0))
assert(3 * v1 == vector(3, 0, 3))
assert(v1 * 3 == vector(3, 0, 3))
assert(vector(4, 4, 0, 4) / 2 == vector(2, 2, 0, 2))

-- test __tostring
assert(tostring(v1) == "(1, 0, 1)")

-- test copy
assert(v1:copy() == v1)
assert(v2:copy() == v2)
assert(v3:copy() == v3)
assert(v4:copy() == v4)
assert(v5:copy() == v5)

-- test map
assert(v1:map(function (e) return e * 2 end) == 2 * v1)
assert(v5:map(function(_, i) return i end) == vector(0, 2, 3, 0, 5, 0))
assert(vector(1,0,1,13,0,0.5):map(function(e, i) return i end) == vector(1, 0, 3, 4, 0, 6))

-- test dot
assert(vector.dot(v1,v1) == 2)
assert(vector.dot(v2, v2) == 55)
assert(vector.dot(v4, v4) == 50)
assert(vector.dot(v4, v5) == 19)

-- test norm
assert(vector.norm(v4) == math.sqrt(50))
assert(vector.norm(v4, 2) == math.sqrt(50))
assert(vector.norm(v4, 1) == 12)
assert(vector.norm(v4, 3) == 252^(1/3))
