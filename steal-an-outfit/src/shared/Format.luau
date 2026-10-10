--!strict
-- Number and time formatting for UI text.

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx" }

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

-- 950 -> "$950", 12345 -> "$12,345", 1530000 -> "$1.53M"
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
	local pattern = if scaled >= 100 then "%.1f" else "%.2f"
	return "$" .. trimZeros(string.format(pattern, scaled)) .. SUFFIXES[index]
end

-- 42 -> "0:42", 125 -> "2:05"
function Format.clock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

return Format
