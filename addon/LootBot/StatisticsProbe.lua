-- Manual beta API check. Reads only this character and never sends data.
LootBotStatisticsProbe = {}
local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end
local function text(value)
    if not readable(value) then return nil end
    if type(value)=='string' then return value:sub(1,2048) end
    if type(value)=='number' then return tostring(value) end
end
function LootBotStatisticsProbe.Capture()
    local snapshot={capturedAt=GetServerTime(),player=UnitName('player'),guid=UnitGUID('player'),entries={},populated=0}
    local version,build,_,interface=GetBuildInfo()
    snapshot.version=version; snapshot.build=build; snapshot.interface=interface
    LootBotDB=LootBotDB or {}
    LootBotDB.statisticsProbe=snapshot
    for _,name in ipairs({'GetStatisticsCategoryList','GetCategoryNumAchievements','GetAchievementInfo','GetStatistic'}) do
        if type(_G[name])~='function' then snapshot.error='Missing API: '..name; return snapshot end
    end
    local ok,categories=pcall(GetStatisticsCategoryList)
    if not ok or not readable(categories) or type(categories)~='table' then
        snapshot.error='Statistics categories are not readable.'; return snapshot
    end
    local seen={}
    for _,category in ipairs(categories) do
        if readable(category) and type(category)=='number' then
            local categoryName
            if type(GetCategoryInfo)=='function' then
                local success,name=pcall(GetCategoryInfo,category)
                if success then categoryName=text(name) end
            end
            local success,count=pcall(GetCategoryNumAchievements,category)
            if success and readable(count) and type(count)=='number' then
                for index=1,math.min(count,500) do
                    -- This is the same enumeration used by Blizzard's Forever
                    -- StatisticsFrame: quantity, skip, statID = GetStatistic(category,index).
                    local valueOk,value,skip,rawId=pcall(GetStatistic,category,index)
                    local id=valueOk and tonumber(text(rawId)) or nil
                    if id and not seen[id] and #snapshot.entries<1500 then
                        seen[id]=true
                        local infoOk,_,name=pcall(GetAchievementInfo,id)
                        local display=text(value)
                        local status=(display and display~='' and display~='--') and 'available' or 'unknown'
                        if status=='available' then snapshot.populated=snapshot.populated+1 end
                        snapshot.entries[#snapshot.entries+1]={id=id,name=infoOk and text(name) or nil,category=category,
                            categoryName=categoryName,value=display,numericValue=display and tonumber(display) or nil,
                            hidden=readable(skip) and skip==true or false,status=status}
                    end
                end
            end
        end
    end
    return snapshot
end
