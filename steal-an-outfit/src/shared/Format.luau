--!strict
-- Number and time formatting for UI text.

local Format = {}

local SUFFIXES = { " тыс", " млн", " млрд", " трлн", " квдрлн", " квинт", " секст" }

local function trimZeros(text: string): string
	if string.find(text, ".", 1, true) == nil then
		return text
	end
	local trimmed = string.gsub(text, "0+$", "")
	trimmed = string.gsub(trimmed, "%.$", "")
	return trimmed
end

-- 1234567 -> "1,234,567"
function Format.commas(value: number): string
	local whole = tostring(math.floor(math.abs(value)))
	local formatted = string.reverse((string.gsub(string.reverse(whole), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return if value < 0 then "-" .. formatted else formatted
end

-- 950 -> "$950", 12345 -> "$12,345", 1530000 -> "$1.53 млн"
function Format.money(value: number): string
	local amount = math.floor(value + 0.5)
	if amount < 100000 then
		return "$" .. Format.commas(amount)
	end
	local scaled = amount
	local index = 0
	while scaled >= 1000 and index < #SUFFIXES do
		scaled /= 1000
		index += 1
	end
	local text = string.format(if scaled >= 100 then "%.1f" else "%.2f", scaled)
	-- 999.96 thousand rounds to "1000.0": move up to the next suffix instead of printing "$1000 тыс".
	if (tonumber(text) or 0) >= 1000 and index < #SUFFIXES then
		scaled /= 1000
		index += 1
		text = string.format("%.2f", scaled)
	end
	return "$" .. trimZeros(text) .. SUFFIXES[index]
end

-- string.upper only handles ASCII; this also uppercases Russian letters (а-я, ё).
function Format.upper(text: string): string
	local out = {}
	for _, code in utf8.codes(text) do
		local lowerLatin = code >= 0x61 and code <= 0x7A
		local lowerCyrillic = code >= 0x430 and code <= 0x44F
		if lowerLatin or lowerCyrillic then
			code -= 0x20
		elseif code == 0x451 then -- ё
			code = 0x401
		end
		table.insert(out, utf8.char(code))
	end
	return table.concat(out)
end

-- 1.24 -> "1.2", 3 -> "3" (for short countdowns)
function Format.seconds(value: number): string
	return string.format("%.1f", math.max(0, value))
end

-- 42 -> "0:42", 125 -> "2:05"
function Format.clock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

return Format
