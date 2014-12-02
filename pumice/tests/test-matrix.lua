-- PUMICE Copyright (C) 2009 Lars Rosengreen (-*-coding:iso-safe-unix-*-)
-- released as free software under the terms of MIT open source license

require "vector"
require "matrix"

local M1 = matrix{{1,2},{3,4},{5,6}}
local M2 = matrix{{1, 0, 3}}
local M3 = matrix{{0, 0, 0,}, {0, 0, 0}}
local M4 = matrix{{1,2,3},{4,5,6},{7,8,9}}
local M5 = matrix[[1 2 1; 2 1 1; 2 3 1]]
local M6 = matrix[[4 -2 4 2; -2 10 -2 -7; 4 -2 8 4; 2 -7 4 7]]

-- test new and __call
assert(M1.rows == 3)
assert(M2.columns == 3)
assert(M1.type == "matrix")
assert(#M3.vectors == 2)
assert(M3.vectors[2][2] == 0)
assert(M1.vectors[1][2] == 2) 
local M5 = matrix[[1 2 3; 4 5 6; 7 8 9]]
assert(M4 == M5)

-- test __index
assert(M1[2] == vector(3,4))
assert(M2[1] == vector(1, 0, 3))
assert(M3[3] == nil)
assert(M2[1][1] == 1)
assert(M2[1][2] == 0)
assert(M3["rows"] == 2)

-- test __newindex
local M = matrix.new(3, 4)
M[1][2] = 8
M[3][4] = 0
M[2] = vector(1, 2, 3, 4)
M[2][8] = "out of range"
M[8] = "toobig"
M[-1] = "toosmall"
M["justright"] = "yawn"
assert(M[1][2] == 8)
assert(rawget(M.vectors, 1)[2] == 8)
assert(M[3][4] == 0)
assert(rawget(M.vectors, 3)[4] == 0)
assert(M.vectors[2].elements[8] == "out of range")
assert(M[8] == "toobig")
assert(rawget(M, 8) == nil)
assert(M[-1] == "toosmall")
assert(rawget(M.vectors, -1) == "toosmall")
assert(M["justright"] == "yawn")
assert(rawget(M.vectors, "justright") == "yawn")

-- test __eq
assert((M1 == 3) == false)
assert((2 == M2) == false)
assert((M1 == {}) == false)
assert((M1 == M2) == false)
assert((M2 == M1) == false)
assert((M3 == matrix.new(2, 3)) == true)
assert((M1 == M1) == true)

-- test __add, __sub
assert(M1 + M1 == matrix{{2, 4}, {6, 8}, {10, 12}})
assert(M1 + matrix{{1, 0}, {0, 5}, {0, 9}} == matrix{{2, 2}, {3, 9}, {5, 15}})
assert(M2 - M2 == matrix.new(1, 3))
assert(matrix.new(4) - matrix.new(4) == matrix.new(4))

-- test __mul
assert(3 * M4 == matrix{{3, 6, 9}, {12, 15, 18}, {21, 24, 27}})
assert(M4 * 4 == matrix{{4, 8, 12}, {16, 20, 24}, {28, 32, 36}})
assert(M4 * vector(1, 2, 3) == vector(14, 32, 50))
assert(M2 * vector(1, 0 ,3) == vector(10))
assert(M1 * vector(1,1) == vector(3, 7, 11))
assert(M4 * M4 == matrix{{30, 36, 42}, {66, 81, 96}, {102, 126, 150}})
assert(M1 * matrix{{1, 2, 3}, {4, 0, -8}} == matrix{{9, 2, -13}, {19, 6, -23}, {29, 10, -33}})
assert(M2 * matrix{{1}, {0}, {3}} == matrix{{10}})

-- test __div
assert(M2/3 == matrix{{1/3, 0, 1}})
assert(M3/10 == M3)

-- test lu
local P1, L1, U1 = matrix.lu(M5)
assert(P1 * L1 * U1 == M5)

-- test cholesky
assert(matrix.cholesky(M6) == matrix[[2 -1 2 1; 0 3 0 -2; 0 0 2 1; 0 0 0 1]])

-- test id
assert(matrix.id(1) == matrix[[1]])
assert(matrix.id(3) == matrix[[1 0 0; 0 1 0; 0 0 1]])
