------------------------------------------------------------------------
--- @file allreduce.lua
--- @brief (allreduce) utility.
--- Utility functions for the allreduce_header structs 
--- Includes:
--- - allreduce constants
--- - allreduce header utility
--- - Definition of allreduce packets
------------------------------------------------------------------------

--[[
-- Use this file as template when implementing a new protocol (to implement all mandatory stuff)
-- Replace all occurrences of allreduce with your protocol (e.g. sctp)
-- Remove unnecessary comments in this file (comments inbetween [[...]]
-- Necessary changes to other files:
-- - packet.lua: if the header has a length member, adapt packetSetLength; 
-- 				 if the packet has a checksum, adapt createStack (loop at end of function) and packetCalculateChecksums
-- - proto/proto.lua: add allreduce.lua to the list so it gets loaded
--]]
local ffi = require "ffi"
require "utils"
require "proto.template"
local initHeader = initHeader

local ntoh, hton = ntoh, hton
local ntoh16, hton16 = ntoh16, hton16
local bswap = bswap
local bswap16 = bswap16
local bor, band, bnot, rshift, lshift= bit.bor, bit.band, bit.bnot, bit.rshift, bit.lshift
local istype = ffi.istype
local format = string.format

---------------------------------------------------------------------------
---- allreduce constants 
---------------------------------------------------------------------------

local ALLREDUCE_DATA_LENGTH = 32

--- allreduce protocol constants
local allreduce = {}

---------------------------------------------------------------------------
---- allreduce header
---------------------------------------------------------------------------

allreduce.headerFormat = [[
	union ip4_address dst;
	uint32_t id;
	uint16_t nodes_reduced;
	uint16_t nodes;
	uint32_t children;
	union ip4_address switch_addr;
	uint8_t operator_bypass_pad_mc;
	uint8_t misc2;
	uint8_t next_children_slice;
	uint8_t dont_wait_multicast;
	uint32_t data[32];
]]

-- header length = 4 + 4 + 2 +2 + 4 + 4 +1+ 1+ 1+ 1+ (4*32) = 152

--- Variable sized member
allreduce.headerVariableMember = nil

--- Module for allreduce_address struct
local allreduceHeader = initHeader()
allreduceHeader.__index = allreduceHeader

-- DST IP

--- Set the dst ip.
--- @param int XYZ of the allreduce header as A bit integer.
function allreduceHeader:setDst(int)
	int = int or 0
	self.dst:set(int)
end

--- get the dst ip.
--- @param int dst ip of the allreduce header as A bit integer.
function allreduceHeader:getDst(int)
	self.dst:get()
end

--- Set the dst ip.
--- @param int XYZ of the allreduce header as A bit integer.
function allreduceHeader:setDstString(str)
	int = int or 0
	self.dst:setString(str)
end

--- Retrieve the XYZ as string.
--- @return XYZ as string.
function allreduceHeader:getDstString()
	return self.dst:getString()
end

-- SWITCH ADDR

--- Set the dst ip.
--- @param int XYZ of the allreduce header as A bit integer.
function allreduceHeader:setSwitchAddr(int)
	int = int or 0
	self.switch_addr:set(int)
end

--- get the dst ip.
--- @param int dst ip of the allreduce header as A bit integer.
function allreduceHeader:getSwitchAddr(int)
	self.switch_addr:get()
end

--- Set the dst ip.
--- @param int XYZ of the allreduce header as A bit integer.
function allreduceHeader:setSwitchAddrString(str)
	int = int or 0
	self.switch_addr:setString(str)
end

--- Retrieve the XYZ as string.
--- @return XYZ as string.
function allreduceHeader:getSwitchAddrString()
	return self.switch_addr:getString()
end

--- Set the id
--- @param int id
function allreduceHeader:setId(int)
	int = int or 0
	self.id = hton(int)
end

--- Retrieve the id number.
--- @return id number as 32 bit unsigned int in lua Number format
function allreduceHeader:getId()
	return (hton(self.id))
end

--- Retrieve the sequence number.
--- @return Sequence number in string format.
function allreduceHeader:getIdString()
	return tostring(self:getId())
end

--- Set the identification.
--- @param int ID of the ip header as 16 bit integer.
function allreduceHeader:setNodesReduced(int)
	int = int or 0 
	self.nodes_reduced = hton16(int)
end

--- Retrieve the identification.
--- @return ID as 16 bit integer.
function allreduceHeader:getNodesReduced()
	return hton16(self.nodes_reduced)
end

--- Retrieve the identification.
--- @return ID as string.
function allreduceHeader:getNodesReducedString()
	return self:getNodesReduced()
end

--- Set the identification.
--- @param int ID of the ip header as 16 bit integer.
function allreduceHeader:setNodes(int)
	int = int or 0 
	self.nodes = hton16(int)
end

--- Retrieve the identification.
--- @return ID as 16 bit integer.
function allreduceHeader:getNodes()
	return hton16(self.nodes)
end

--- Retrieve the identification.
--- @return ID as string.
function allreduceHeader:getNodesString()
	return self:getNodes()
end

function allreduceHeader:setOperatorBypassMc(int)
	int = int or 0 
	self.operator_bypass_pad_mc = int
end

function allreduceHeader:getOperatorBypassMc(int)
	return self.operator_bypass_pad_mc
end

function allreduceHeader:getOperatorBypassMcString(int)
	return self:getOperatorBypassMc()
end

-- even though lua indexes start at 0, since the underlying data is c...

function allreduceHeader:setDataValue(index, value)
	value = value or 0
	self.data[index] = hton(value)
end

function allreduceHeader:setData(data)
	--print("")
	-- 0 or the one we set
	if not data then
		for i = 1, ALLREDUCE_DATA_LENGTH do
			self.data[i - 1] = hton(0);
	    end
	else 
		for i, x in ipairs(data) do
			--print("index " .. i .. " " .. x)
			self.data[i - 1] = hton(x)
		end
		-- self.data[0] = 1
	end
end

-- TODO maybe the name has to be changed
function allreduceHeader:getData()
	return self.data
end

function allreduceHeader:addToAllData(value)

	for i = 1 , ALLREDUCE_DATA_LENGTH do
		self.data[i - 1] = hton(hton(self.data[i-1]) + value)
	end
end


function allreduceHeader:aggregateData(pkt, id)
	
	-- also set the packet id while we aggregated (might be faster?)
	self:setId(id)

	print("Values before sum: " ..  hton(self.data[1-1]) .. " " .. hton(pkt.data[1 - 1]) .. " " .. id)
	for i = 1 , ALLREDUCE_DATA_LENGTH do	
		self.data[i - 1] = hton(hton(self.data[i-1]) + hton(pkt.data[i - 1]) + id)
	end
end

function allreduceHeader:printData()
	print("Data Values:")
	for i = 1, ALLREDUCE_DATA_LENGTH do
		print(i-1 .. " -> " .. hton(self.data[i-1])) -- 24 bits shifted? why?
	end
end

--- Set all members of the allreduce header.
--- Per default, all members are set to default values specified in the respective set function.
--- Optional named arguments can be used to set a member to a user-provided value.
--- @param args Table of named arguments. Available arguments: all
--- @param pre prefix for namedArgs. Default 'allreduce'.
--- @code
--- fill() -- only default values
--- fill{ allreduceDst="1.1.1.1" } -- all members are set to default values with the exception of allreduceXYZ, ...
--- @endcode
function allreduceHeader:fill(args, pre)
	args = args or {}
	pre = pre or "allreduce"

	-- thing we set to 0 always
	-- do i need hton?-
	self.children = 0
	self.misc2 = 0
	self.next_children_slice = 0
	self.dont_wait_multicast = 0

	self:setId(args[pre .. "Id"])
	self:setNodesReduced(args[pre .. "NodesReduced"])
	self:setNodes(args[pre .. "Nodes"])
	self:setOperatorBypassMc(args[pre .. "OperatorBypassMc"])

	local switch_addr = pre .. "SwitchAddress"
	local dst = pre .. "Dst"
	args[switch_addr] = args[switch_addr] or "0.0.0.0"
	args[dst] = args[dst] or "192.168.1.2"
	
	-- if for some reason the address is in 'union ip4_address' format, cope with it
	if type(args[switch_addr]) == "string" then
		self:setSwitchAddrString(args[switch_addr])
	else
		self:setSwitchAddr(args[switch_addr])
	end

	if type(args[dst]) == "string" then
		self:setDstString(args[dst])
	else
		self:setDst(args[dst])
	end

	self:setData(args[pre .. "Data"])

end

--- Retrieve the values of all members.
--- @param pre prefix for namedArgs. Default 'allreduce'.
--- @return Table of named arguments. For a list of arguments see "See also".
--- @see allreduceHeader:fill
function allreduceHeader:get(pre)
	pre = pre or "allreduce"

	local args = {}

	args[pre .. "Dst"] = self:getDstString()
	args[pre .. "SwitchAddress"] = self:getSwitchAddrString()
	args[pre .. "Id"] = self:getId()
	args[pre .. "NodesReduced"] = self:getNodesReduced()
	args[pre .. "Nodes"] = self:getNodes()
	args[pre .. "OperatorBypassMc"] = self:getOperatorBypassMc()
	args[pre .. "Data"] = self:getData()

	return args
end

--- Retrieve the values of all members.
--- @return Values in string format.
function allreduceHeader:getString()
	local pkt_str = "ALLREDUCE "
	local data_str = "\nData Values: \n"
	for key, value in pairs(self:get("")) do
		if key ~= "Data" then
			pkt_str =  pkt_str .. " " .. key .. " > " .. value .. " |"
		else 
			for i = 1, ALLREDUCE_DATA_LENGTH do
				data_str = data_str .. (i-1 .. ":" .. hton(self.data[i-1]) .. " ") 
				-- split it a bit
				if i % 16 == 0 then
					data_str = data_str .. "\n"
				end
			end
		end
	end
	return pkt_str .. data_str
end	

--- Resolve which header comes after this one (in a packet)
--- For instance: in tcp/udp based on the ports
--- This function must exist and is only used when get/dump is executed on 
--- an unknown (mbuf not yet casted to e.g. tcpv6 packet) packet (mbuf)
--- @return String next header (e.g. 'eth', 'ip4', nil)
function allreduceHeader:resolveNextHeader()
	-- not sure i need something here
	return nil
end	

--- Change the default values for namedArguments (for fill/get)
--- This can be used to for instance calculate a length value based on the total packet length
--- See proto/ip4.setDefaultNamedArgs as an example
--- This function must exist and is only used by packet.fill
--- @param pre The prefix used for the namedArgs, e.g. 'allreduce'
--- @param namedArgs Table of named arguments (see See more)
--- @param nextHeader The header following after this header in a packet
--- @param accumulatedLength The so far accumulated length for previous headers in a packet
--- @return Table of namedArgs
--- @see allreduceHeader:fill
function allreduceHeader:setDefaultNamedArgs(pre, namedArgs, nextHeader, accumulatedLength)
	return namedArgs
end


------------------------------------------------------------------------
---- Metatypes
------------------------------------------------------------------------

allreduce.metatype = allreduceHeader

return allreduce