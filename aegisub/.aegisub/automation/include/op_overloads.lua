--[[
	These are small operator overloads for general use in Lua, mainly to my likings.

	Written by FichteFoll; thanks to Sleepy_Coder
	2012-12-24
]]

local STR, NUM, BOOL, NIL = {}, {}, {}, {}
STR = getmetatable('')

-- ("hello")[2] -> e
STR.__index
	= function (self, key)
		if type(key) == 'number' then
			if key < 1 or key > self:len() then
				error(("Attempt to get index %d which is not in the range of the string's length"):format(key), 2)
			end
			return self:sub(key, key)
		end
		return string[key]
	end

-- str = "heeeello"; str[3] = "is" -> "heisello" || DOES NOT WORK!
STR.__newindex =
	function (self, key, value)
		value = tostring(value)
		if type(key) == 'number' and type(value) == 'string' then
			if key < 1 or key > self:len() then
				error(("Attempt to set index %d which is not in the range of the string's length"):format(key), 2)
			end
			-- seems like strings are not referenced ...
			self = self:sub(1, key-1) .. value .. self:sub(key+value:len(), -1)
			-- print(("new value: %s; key: %d"):format(self, key))
			return self
		end
	end

-- string * num -> string.rep
STR.__mul =
	function (op1, op2)
		return type(op2) == 'number' and op1:rep(op2) or error("Invalid type for arithmetic on string", 2)
	end

-- string % table -> string.format
STR.__mod =
	function (op1, op2)

		if type(op2) == 'table' then
			if #op2 > 0 then
				-- make `nil` to string
				for k,v in pairs(op2) do
					if v == nil then op2[k] = "nil"; end
				end
				return op1:format(unpack(op2)) -- sadly I can not forward errors happening here
			else
				error("Format table is empty", 2)
			end
		else
			return op1:format(op2 == nil and "nil" or op2)
		end
	end

-- #string -> count chars
STR.__len =
	function (self)
		return self:len()
	end

-- e.g. num = 1234.5; num:floor()
NUM.__index = math

-- rarely useful
BOOL.__index = BOOL

-- a wrapper for boolean tests
BOOL.b2n =
	function (bool)
		return type(bool) ~= 'boolean' and bool or (bool and 1 or 0)
	end

-- various arithmetics on booleans by converting `false` to `0` and `true` to `1`.
-- `nil` will be converted to `0` as well, btw.
BOOL.__add =
	function (op1, op2)
		-- op2.b2n() won't work because it is possible that one of these ops is not a boolean
		return BOOL.b2n(op1) + BOOL.b2n(op2)
	end

BOOL.__sub =
	function (op1, op2)
		return BOOL.b2n(op1) - BOOL.b2n(op2)
	end

BOOL.__mul =
	function (op1, op2)
		return BOOL.b2n(op1) * BOOL.b2n(op2)
	end

BOOL.__div =
	function (op1, op2)
		return BOOL.b2n(op1) / BOOL.b2n(op2)
	end

BOOL.__pow =
	function (op1, op2)
		return BOOL.b2n(op1) ^ BOOL.b2n(op2)
	end

BOOL.__unm =
	function (self)
		return not self
	end

-- copy BOOL's functions over to NIL and remove a few values
for key, val in pairs(BOOL) do
	NIL[key] = val
end
NIL.b2n = nil
NIL.__unm = nil

-- nil[3] -> nil (no error) - is this behaviour useful?
NIL.__index = NIL

-- Apparently, Aegisub does not provide the debug module ...
-- if debug then
-- 	debug.setmetatable(   0, NUM )
-- 	debug.setmetatable(true, BOOL)
-- 	debug.setmetatable( nil, NIL )
-- end
