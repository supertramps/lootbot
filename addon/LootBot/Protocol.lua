-- No networking, disk writes, input automation, or external libraries.
LootBotProtocol = {}
local P = LootBotProtocol

function P.adler32(data)
    local a, b = 1, 0
    for i = 1, #data do
        a = (a + data:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

local function uint(value, bytes)
    local result = ""
    for i = bytes - 1, 0, -1 do
        result = result .. string.char(math.floor(value / 256 ^ i) % 256)
    end
    return result
end

local function quote(value)
    return '"' .. tostring(value):gsub('[%z\1-\31\\"]', function(c)
        return string.format('\\u%04x', c:byte())
    end) .. '"'
end

function P.packet(event)
    local body = '[' .. quote(event.id) .. ',' .. quote(event.player) .. ',' ..
        event.itemId .. ',' .. event.quality .. ',' .. event.quantity .. ',' ..
        quote(event.itemName) .. ',' .. event.timestamp .. ',' .. tostring(event.test) .. ',' ..
        quote(event.kind or 'loot') .. ',' .. (event.level or 0) .. ']'
    -- Long translated item names fall back to an ID, without splitting UTF-8.
    if #body > 246 and event.itemName ~= "" then
        local shorter = {}
        for k, v in pairs(event) do shorter[k] = v end
        shorter.itemName = ""
        return P.packet(shorter)
    end
    if #body > 246 then return nil end
    local data = "LB02" .. uint(#body, 2) .. body
    return data .. uint(P.adler32(data), 4) .. string.rep('\0', 246 - #body)
end

function P.canonical(name, realm)
    if not name or name == '' then return '' end
    if not name:find('-', 1, true) then name = name .. '-' .. realm end
    return (name:gsub('%s', ''))
end

local function escapeField(value)
    return tostring(value):gsub('[%%%z\1-\31]', function(c) return string.format('%%%02X', c:byte()) end)
end
function P.wire(event)
    local fields = { 'E', event.id, event.kind or 'loot', event.timestamp, event.itemId,
        event.quality, event.quantity, event.level or 0, event.test and '1' or '0', event.itemName }
    for i, value in ipairs(fields) do fields[i] = escapeField(value) end
    local data = table.concat(fields, '\t')
    if #data > 230 then fields[10] = ''; data = table.concat(fields, '\t') end
    if #data > 230 then return nil end
    return data
end
function P.parseWire(data, player, now)
    if type(data) ~= 'string' or #data > 230 then return nil end
    local f = {}
    for value in (data .. '\t'):gmatch('(.-)\t') do
        f[#f + 1] = value:gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex,16)) end)
    end
    if #f ~= 10 or f[1] ~= 'E' or #f[2] > 100 or not f[2]:match('^[%w%-]+$') then return nil end
    if f[3] ~= 'loot' and f[3] ~= 'level' then return nil end
    for _, i in ipairs({4,5,6,7,8}) do
        f[i] = tonumber(f[i])
        if not f[i] or f[i] ~= math.floor(f[i]) then return nil end
    end
    if f[4] < now - 30*86400 or f[4] > now + 120 or f[5] < 0 or f[5] > 10000000 or
        f[6] < -1 or f[6] > 8 or f[7] < 0 or f[7] > 1000000 or (f[9] ~= '0' and f[9] ~= '1') or
        f[10]:find('[%z\1-\31]') then return nil end
    if f[3] == 'loot' and (f[5] == 0 or f[7] == 0 or f[8] ~= 0) then return nil end
    if f[3] == 'level' and (f[8] < 10 or f[8] > 200 or f[8] % 10 ~= 0 or f[5] ~= 0) then return nil end
    return { id=f[2], kind=f[3], timestamp=f[4], itemId=f[5], quality=f[6], quantity=f[7],
        level=f[8], test=f[9]=='1', itemName=f[10], player=player }
end

-- Build patterns from the client's translated loot templates, including %1$s.
function P.templatePattern(template)
    local out, kinds, i = '^', {}, 1
    while i <= #template do
        local rest = template:sub(i)
        local token, kind = rest:match('^(%%%d+%$([sd]))')
        if not token then token, kind = rest:match('^(%%([sd]))') end
        if token then
            out = out .. (kind == 'd' and '(%d+)' or '(.-)')
            kinds[#kinds + 1] = kind
            i = i + #token
        elseif rest:sub(1, 2) == '%%' then
            out = out .. '%%'
            i = i + 2
        else
            local c = template:sub(i, i)
            if c:find('[%^%$%(%)%%%.%[%]%*%+%-%?]') then c = '%' .. c end
            out = out .. c
            i = i + 1
        end
    end
    return out .. '$', kinds
end

function P.selfLoot(message, templates)
    for _, template in ipairs(templates) do
        local pattern, kinds = P.templatePattern(template)
        local values = { message:match(pattern) }
        if #values > 0 then
            local quantity = 1
            for i, kind in ipairs(kinds) do
                if kind == 'd' then quantity = tonumber(values[i]) or 1 end
            end
            return quantity
        end
    end
end
