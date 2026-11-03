-- Typeset pages: real guild figures are separate from fictional local colour.
LootBotNewspaperEdition={}
local N=LootBotNewspaperEdition
local MONDAY,WEEK=345600,604800
local function short(name) return name:match('^[^-]+') or name end
local function numeric(v) return type(v)=='number' and v==v and v>=0 and v<=1e15 end
function N.Money(copper)
    copper=math.floor(copper)
    return string.format('%dg %ds %dc',math.floor(copper/10000),math.floor(copper/100)%100,copper%100)
end
function N.Date(timestamp)
    local formatter=date or (os and os.date)
    return formatter and formatter('!%d %B %Y',timestamp):gsub('^!','') or ('Edition '..tostring(timestamp))
end
local function rows(records,id,absolute)
    local out={}
    for name,r in pairs(records) do
        local a,b=r.start[id],r.finish[id]
        if numeric(b) and (absolute or (numeric(a) and b>=a)) then
            local value=absolute and b or b-a
            if value>0 then out[#out+1]={name=short(name),fullName=name,value=value} end
        end
    end
    table.sort(out,function(a,b) return a.value==b.value and a.fullName<b.fullName or a.value>b.value end)
    return out
end
local function board(list,money)
    local text={}
    for i=1,math.min(3,#list) do text[#text+1]=i..'. '..list[i].name..'  '..(money and N.Money(list[i].value) or string.format('%.0f',list[i].value)) end
    return table.concat(text,'\n')
end
local tips={
    'Before heading out, leave some room in your bags. The next drop is rarely impressed by a full inventory.',
    'Check your supplies before a long trip. Food, drink and a little repair money are less exciting than a new axe, but easier to miss.',
    'Meeting friends for a dungeon? Agree where you are meeting before everyone starts running in a different direction.',
    'Keep a little gold for repairs and training. Your future self has expensive habits.'
}
local weather={
    'Durotar: dry, dusty, with a strong chance of dust.\n\nMulgore: a pleasant breeze. Hold on to your hat.\n\nTirisfal: fog. More fog after dark.',
    'The Barrens: sun all day. Complaints expected by noon.\n\nStranglethorn: warm rain, followed by warmer rain.\n\nOrgrimmar: little shade. Bring water.',
    'Durotar: clear skies. Red dust on all washing.\n\nMulgore: cool at sunrise, mild by noon.\n\nTirisfal: visibility measured in gravestones.'
}
local listings={
    '18:00  Cooking with Fire\nTonight: stew. Again.\n\n20:00  The Long Walk Back\nA familiar location.\n\n22:00  Fishing After Dark\nVery little dialogue.',
    '18:00  Auction House Antiques\nNobody agrees on a price.\n\n20:00  Who Pulled That?\nA guild mystery.\n\n22:00  Quiet by the Fire\nExcept for the shaman.'
}
local letters={
    'Dear editor,\n\nSomeone keeps leaving a wolf outside the inn. It has eaten the notice asking people not to leave wolves outside the inn.\n\nAn increasingly tired innkeeper',
    'Dear editor,\n\nI bought an axe advertised as barely used. The previous owner appears to have used it mainly as a doorstop.\n\nA disappointed customer',
    'Dear editor,\n\nPlease stop printing the fishing forecast. My friend now considers an entire evening by the pond a guild obligation.\n\nName withheld'
}
local function dateLine(edition) return 'PUBLISHED '..N.Date(edition.publishedAt)..'  |  ORIGINAL FORMALITIES  |  WEEKLY EDITION' end
function N.Back(edition,week,highlight)
    return {name='The back page',layout='back',texture='NewsletterBack.png',fields={
        masthead='The Back Page',edition=dateLine(edition),headline=highlight or 'Weather, wireless & small notices',
        weatherTitle='AZEROTH WEATHER',weatherBody=weather[week%#weather+1],
        listingsTitle='ON THE WIRELESS',listingsBody=listings[week%#listings+1],
        lettersTitle='LETTERS',lettersBody=letters[week%#letters+1],
        footer='FICTIONAL WEATHER, ENTERTAINMENT, LETTERS & ADVERTISEMENTS  |  NONE ARE LIVE GAME REPORTS'
    }}
end
function N.Welcome(edition,now)
    edition.publishedAt=MONDAY+LootBotGuildStatistics.Week(now)*WEEK
    edition.pages={{name='Welcome',layout='welcome',texture='NewsletterWelcome.png',fields={}},N.Back(edition,LootBotGuildStatistics.Week(now))}
    return edition
end
local fun={
    {60,'CORPSE RUNS','deaths'},{114,'THE LONG WAY DOWN','falling deaths'},
    {98,'WORK ORDERS','quests completed'},{341,'SPOILS OF WAR','epic items looted'},
    {1518,'AT THE WATER','fish caught'},{108,'SMALL TARGETS','critters killed'},
    {1042,'THE SOCIAL COLUMN','hugs given'},{1047,'THAT SORT OF WEEK','facepalms'}
}
local function article(metric,list)
    local top=list[1]
    return {title=metric[2],value=string.format('%.0f',top.value),summary=board(list)..'\n\n'..metric[3]..' this edition.\n\nA good week for the notebook.',body=top.name..' recorded '..string.format('%.0f',top.value)..' '..metric[3]..'.\n\n'..board(list)..'\n\nReported changes this edition. A late return can bring last week\'s adventures with it.'}
end
function N.Build(edition,records,db,week,now)
    edition.publishedAt=MONDAY+(week+1)*WEEK
    local gold,repairs,pvp,levels=rows(records,900001,true),rows(records,900003),rows(records,381),rows(records,900002,true)
    local wealth=gold[1] and gold[1].value>=10000
    local previous=db.weeks and db.weeks[week-1]
    if wealth and previous then
        local before=rows(previous,900001,true)
        local changed=not before[1] or before[1].fullName~=gold[1].fullName
        for _,r in pairs(records) do
            local a,b=r.start[900001],r.finish[900001]
            if numeric(a) and numeric(b) and math.abs(b-a)>=10000 then changed=true end
        end
        wealth=changed
    end
    local race=false
    for _,r in ipairs(levels) do if r.value<60 then race=true end end
    local levelChange=#rows(records,900002)>0
    race=race and #levels>=2 and (levelChange or not (db.weeks and db.weeks[week-1]))
    local active={}
    for _,metric in ipairs(fun) do local list=rows(records,metric[1]); if #list>0 then active[#active+1]=article(metric,list) end end
    local second=active[week%math.max(1,#active)+1]
    local third=active[(week+1)%math.max(1,#active)+1]
    if second==third then third=nil end
    local brief={}
    if pvp[1] then brief[#brief+1]='WORLD PVP\n'..pvp[1].name..' - '..pvp[1].value..' honorable kills' end
    if wealth then brief[#brief+1]='DEEPEST POCKETS\n'..gold[1].name..' - '..N.Money(gold[1].value) end
    if race then brief[#brief+1]='THE CLIMB\n'..levels[1].name..' - level '..levels[1].value end
    local participants=0; for _ in pairs(records) do participants=participants+1 end
    if #brief==0 then brief[1]=participants..' reporting characters\n\nHighlights are selected from real readings. Quiet counters stay out of the paper.' end
    local headline=edition.fields.headline
    if #active==0 and not wealth and not race and #pvp==0 and #rows(records,193)==0 and #rows(records,189)==0 then headline='A quiet week in the guild.' end
    if pvp[1] and week%2==0 then headline=pvp[1].name..' claimed '..pvp[1].value..' world honorable kills.' end
    local story={
        [60]='%s recorded %s deaths. The graveyard remains a familiar stop.',
        [114]='%s recorded %s deaths from falling. The editor advises a second look before taking the shortcut.',
        [98]='%s completed %s quests. Another stack of work orders cleared from the board.',
        [341]='%s looted %s epic items. A good week to have room in the bags.',
        [1518]='%s caught %s fish. The editor declines to ask how much of the evening this took.',
        [108]='%s killed %s critters. Local wildlife has declined to comment.',
        [193]='%s registered a new biggest-hit record of %s. That number is the record itself, not a weekly damage total.',
        [189]='%s registered a new biggest-heal record of %s. That number is the record itself, not a weekly healing total.'}
    local spot=edition.spotlight
    local main=spot and string.format(story[spot.id] or '%s recorded %s in this week\'s highlighted counter.',spot.name,string.format('%.0f',spot.value))
        or 'A quieter ledger this week. The editor is accepting tips, preferably before the presses start.'
    if pvp[1] and week%2==0 then main=pvp[1].name..' led the reported world PvP kills with '..pvp[1].value..'. Battleground results are not included.' end
    main=main..'\n\n'..participants..' characters reported for this edition. Figures come from saved readings; catch-up counts on return.\n\nMore from the guild inside.'
    local front={name='Front page',layout=week%2==0 and 'front' or 'frontLedger',texture=week%2==0 and 'NewsletterFront1.png' or 'NewsletterFront2.png',fields={
        masthead='Original Formalities',edition=dateLine(edition),headline=headline,byline='GUILD REPORT  /  THE WEEK IN REVIEW',lead=main,
        caption=week%2==0 and 'Our correspondent, catching up on the news.' or 'The accounts desk. Receipts preferred.',
        briefTitle='GUILD IN BRIEF',brief=table.concat(brief,'\n\n'),
        leftTitle=second and second.title or 'BEFORE YOU LEAVE',leftBody=second and second.summary or tips[week%#tips+1],
        middleTitle=third and third.title or 'FIELD NOTES',middleBody=third and third.summary or tips[(week+1)%#tips+1],
        footer='REAL GUILD FIGURES  |  SMALL NOTICES & ADVERTISEMENTS ARE FICTIONAL  |  '..N.Date(edition.publishedAt)
    }}
    edition.pages={front}
    local function feature(name,headline,sections,intro)
        if #sections==0 then return end
        local one,two=sections[1],sections[2]
        edition.pages[#edition.pages+1]={name=name,layout='inside',texture='NewsletterInside.png',fields={
            masthead=name,edition=dateLine(edition),headline=headline,intro=intro,
            leftTitle=one.title,leftValue=one.value or '',leftBody=one.body,
            rightTitle=two and two.title or 'FROM THE EDITOR',rightValue=two and two.value or '',rightBody=two and two.body or (tips[week%#tips+1]..'\n\nThe little advertisements below are fictional. The numbers above came from your guild.'),
            footer='REPORTED CHARACTER DATA  |  '..N.Date(edition.publishedAt)..'  |  CLASSIFIEDS ARE FICTIONAL'
        }}
    end
    local ledger={}
    if wealth then ledger[#ledger+1]={title='THE DEEPEST POCKETS',value=N.Money(gold[1].value),body=gold[1].name..' leads the reported purses.\n\n'..board(gold,true)..'\n\nOur goblin calls this a tax report. These are pocket balances, not gold earned. Banks, items and unreported characters are excluded.\n\nNo taxes collected. Yet.'} end
    if repairs[1] then ledger[#ledger+1]={title='THE REPAIR COUNTER',value=N.Money(repairs[1].value),body=repairs[1].name..' tops the recorded repair bills.\n\n'..board(repairs,true)..'\n\nPersonal Repair All payments confirmed by the addon. Single-item and guild-funded repairs are excluded.\n\nA bill does not prove a death count. The blacksmith has no complaints.'} end
    feature('The Goblin Ledger','The copper had to go somewhere.',ledger,'Our accounts desk reports on the guild\'s purses and the blacksmith\'s receipts.')
    local roads={}
    if pvp[1] then roads[#roads+1]={title='TROUBLE ON THE ROADS',value=pvp[1].value..' world kills',body=pvp[1].name..' recorded '..pvp[1].value..' world honorable kills.\n\n'..board(pvp)..'\n\nWorld PvP only. Battleground kills stay out of this column.\n\nPlanned encounters or an argument over a quest mob? The ledger does not say.'} end
    if race then roads[#roads+1]={title='THE ROAD TO SIXTY',value='Level '..levels[1].value,body=levels[1].name..' has the highest reported level: '..levels[1].value..'.\n\n'..board(levels)..'\n\nThe latest levels reported for this issue. Each character has a place, including alts.\n\nThis column retires once the reported field reaches 60, or stays out when the race goes quiet.'} end
    feature('Out on the Roads','A little progress. A little trouble.',roads,'World PvP and the climb to sixty, when the guild gives us something to report.')
    if #ledger==0 and #roads==0 and #active>0 then
        feature('Around the Guild','The smaller stories still count.',{second,third},'A closer look at this week\'s recorded adventures. Empty counters are not printed.')
    end
    edition.pages[#edition.pages+1]=N.Back(edition,week)
    return edition
end

function N.Demo(now)
    local week=LootBotGuildStatistics.Week(now)-1
    local first,last=MONDAY+week*WEEK+3600,MONDAY+(week+1)*WEEK-3600
    local records={
        ['Gruk-Demo']={first=first,last=last,start={[60]=100,[98]=400,[381]=20,[900001]=10000,[900002]=39,[900003]=0},finish={[60]=118,[98]=426,[381]=37,[900001]=2234567,[900002]=40,[900003]=23456}},
        ['Mara-Demo']={first=first,last=last,start={[60]=10,[1518]=90,[900001]=100000,[900002]=40,[900003]=0},finish={[60]=12,[1518]=188,[900001]=1234567,[900002]=41,[900003]=11000}},
        ['Tusk-Demo']={first=first,last=last,start={[60]=5,[341]=0,[900001]=10000,[900002]=35,[900003]=0},finish={[60]=8,[341]=2,[900001]=334500,[900002]=37,[900003]=2500}}
    }
    local edition=LootBotGuildStatistics.Edition({weeks={[week]=records}},now)
    edition.demo=true
    for _,page in ipairs(edition.pages) do page.fields.edition='DEMO - MADE-UP FIGURES  |  '..N.Date(edition.publishedAt)..'  |  ORIGINAL FORMALITIES' end
    return edition
end

-- Positions are expressed on the original 1086 x 1448 paper, before zoom.
local function s(key,x,y,w,h,size,center,strong,role) return {key=key,x=x,y=y,w=w,h=h,size=size,center=center,strong=strong,role=role} end
-- These three engravings have a 1055x1491 source grid, padded to the common page.
local function p(key,x,y,w,h,size,center,strong,role) return s(key,x*1086/1055,y*1448/1491,w*1086/1055,h*1448/1491,size,center,strong,role) end
N.Layouts={
    welcome={},
    front={p('masthead',220,118,620,90,55,true,true,'masthead'),p('edition',35,258,980,28,18,true),
        p('headline',35,315,980,110,42,false,true),p('byline',32,452,635,28,18),p('lead',33,510,265,400,22),
        p('caption',340,914,350,28,17,true),p('briefTitle',747,507,270,36,23,false,true),p('brief',747,557,270,360,22),
        p('leftTitle',35,1080,290,43,25,false,true),p('leftBody',35,1135,290,260,20),p('middleTitle',375,1080,290,43,25,false,true),p('middleBody',375,1135,290,260,20),p('footer',35,1455,980,24,14,true)},
    frontLedger={p('masthead',200,75,640,75,50,true,true,'masthead'),p('edition',45,195,960,28,18,true),
        p('headline',45,265,960,110,42,false,true),p('byline',47,418,630,27,18),p('lead',47,475,250,350,22),
        p('caption',345,852,345,28,17,true),p('briefTitle',747,450,270,36,23,false,true),p('brief',747,510,270,350,22),
        p('leftTitle',47,1080,285,43,25,false,true),p('leftBody',47,1135,285,260,20),p('middleTitle',380,1080,285,43,25,false,true),p('middleBody',380,1135,285,260,20),p('footer',35,1455,980,24,14,true)},
    inside={p('masthead',150,170,730,75,48,true,true,'masthead'),p('edition',150,267,732,27,16,true),p('headline',150,320,730,75,34,false,true),p('intro',150,435,730,60,21),
        p('leftTitle',154,565,340,40,25,false,true),p('leftValue',154,615,340,65,38,false,true),p('leftBody',154,700,340,335,19),p('rightTitle',540,565,340,40,25,false,true),p('rightValue',540,615,340,65,38,false,true),p('rightBody',540,700,340,335,19),p('footer',145,1450,770,24,13,true)},
    back={s('masthead',100,36,880,80,52,true,true,'masthead'),s('edition',45,148,996,28,18,true),s('headline',45,210,996,85,40,false,true),
        s('weatherBody',45,390,300,255,20),s('listingsBody',390,390,300,255,20),s('lettersBody',735,390,300,255,20),s('footer',40,1396,1000,24,13,true)}
}
