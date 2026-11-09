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
    return formatter and formatter('!%Y-%m-%d',timestamp):gsub('^!','') or ('Utgåva '..tostring(timestamp))
end
function N.PublicationDate(edition,timestamp)
    local previous=N.Date(edition.publishedAt)
    edition.publishedAt=timestamp
    for _,page in ipairs(edition.pages) do
        page.fields.edition='UTGIVEN '..N.Date(timestamp)..'  |  ORIGINAL FORMALITIES  |  VECKANS NUMMER'
        if page.fields.footer then page.fields.footer=page.fields.footer:gsub(previous,N.Date(timestamp)) end
    end
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
    'Lämna lite plats i väskorna. Nästa fynd tänker inte vänta medan du städar.',
    'Mat, dryck och reparationspengar före långresan. Inte lika kul som en ny yxa, men gôtt att ha.',
    'Bestäm mötesplats innan alla börjar springa åt varsitt håll. Det sparar en del tjöt.',
    'Spara lite till reparationer och träning. Det blir dyrt att bli duktig.'
}
local weather={
    'Durotar: torrt och dammigt. Tvätten får samma färg som marken.\n\nMulgore: frisk vind. Håll i hatten.\n\nTirisfal: dimma. Ingen större överraskning.',
    'Barrens: sol hela dagen. Skugga sökes.\n\nStranglethorn: regn på förmiddagen. Blötare på eftermiddagen.\n\nOrgrimmar: varmt vid Götaplatsen. Ta med vatten.'
}
local listings={
    '18:00  Vad blir det för käk?\nGryta. Igen.\n\n20:00  Vem drog igång det där?\nEtt mysterium i flera delar.\n\n22:00  Fiske i mörker\nInte mycket tjöt.',
    '18:00  Fynd eller lurendrejeri?\nGoblinen värderar ditt arvegods.\n\n20:00  Sista vagnen hem\nGår den, så går den.\n\n22:00  Lugnt vid brasan\nTills schamanen kommer.'
}
local letters={
    'Bäste redaktör!\n\nNågon ställer sin varg utanför värdshuset. Nu har den ätit upp skylten om att vargar inte får stå där.\n\nEn trött värdshusvärd',
    'Bäste redaktör!\n\nJag köpte en yxa som skulle vara knappt använd. Som vapen, kanske. Som dörrstopp verkar den ha tjänstgjort länge.\n\nEn missnöjd kund'
}
local function dateLine(edition) return 'UTGIVEN '..N.Date(edition.publishedAt)..'  |  ORIGINAL FORMALITIES  |  VECKANS NUMMER' end
function N.Back(edition,week,highlight)
    return {name='Sista sidan',layout='back',texture='NewsletterBack.png',fields={
        masthead='Sista sidan',edition=dateLine(edition),headline=highlight or 'Väder, kvällsnöjen och lite tjöt',
        weatherTitle='VÄDRET',weatherBody=weather[week%#weather+1],
        listingsTitle='I KVÄLL',listingsBody=listings[week%#listings+1],
        lettersTitle='INSÄNDARE',lettersBody=letters[week%#letters+1],
        footer='OF-Posten'
    }}
end
function N.Welcome(edition,now)
    edition.publishedAt=MONDAY+LootBotGuildStatistics.Week(now)*WEEK
    edition.pages={{name='Välkommen',layout='welcome',texture='NewsletterWelcome.png',fields={}},N.ProfessionPage(edition,{})}
    return edition
end
local fun={
    {60,'TILLBAKA TILL KYRKOGÅRDEN','dödsfall'},{114,'DET VAR EN BIT NER','dödsfall efter fall'},
    {98,'JOBBET SKA GÖRAS','avklarade quest'},{341,'FINT I PÅSARNA','episka fynd'},
    {1518,'VID VATTNET','fångade fiskar'},{108,'SMÅVILT','dödade smådjur'},
    {1042,'LITE VÄRME','utdelade kramar'},{1047,'EN SÅN VECKA','uppgivna suckar'}
}
local function article(metric,list)
    local top=list[1]
    return {title=metric[2],value=string.format('%.0f',top.value),summary=board(list)..'\n\n'..metric[3]..' i detta nummer.',body=top.name..' noterade '..string.format('%.0f',top.value)..' '..metric[3]..'.\n\n'..board(list)}
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
    if pvp[1] then brief[#brief+1]='STRID UTE I VÄRLDEN\n'..pvp[1].name..' - '..pvp[1].value..' ärofyllda segrar' end
    if wealth then brief[#brief+1]='GÔTT OM GULD\n'..gold[1].name..' - '..N.Money(gold[1].value) end
    if race then brief[#brief+1]='GUILDENS SVETTIGASTE\n'..levels[1].name..' - nivå '..levels[1].value end
    local participants=0; for _ in pairs(records) do participants=participants+1 end
    if #brief==0 then brief[1]=participants..' rapporterande karaktärer.\n\nVi trycker det som hänt. Stilla räknare får vila.' end
    local headlines={
 [60]='%s dog %s gånger. På det igen.',[114]='%s föll mot sin död %s gånger.',
 [115]='%s brann upp %s gånger.',[112]='%s drunknade %s gånger.',[594]='Hogger fällde %s %s gånger.',
 [98]='%s klarade %s quest. Redigt jobbat.',[341]='%s kom hem med %s episka fynd.',
 [107]='%s fällde %s varelser.',[345]='%s drack %s hälsodrycker.',[1044]='%s drog till med %s need-rolls.',
 [1518]='%s drog upp %s fiskar. Det nappade visst.',[108]='%s fällde %s smådjur. Varför då?',
 [1042]='%s delade ut %s kramar.',[1065]='%s vinkade %s gånger.',[1047]='%s suckade uppgivet %s gånger.',
 [1066]='%s skrattade %s gånger.',[193]='%s slog till med %s i en enda träff.',[189]='%s läkte %s i ett enda svep.'
 }
 local star=edition.spotlight
 local headline=star and string.format(headlines[star.id] or '%s noterade %s. Det får vi la skriva om.',star.name,string.format('%.0f',star.value)) or 'Lite nytt från våra äventyr.'
    if #active==0 and not wealth and not race and #pvp==0 and #rows(records,193)==0 and #rows(records,189)==0 then headline='En lugn vecka. Det händer la ibland.' end
    if pvp[1] and week%2==0 then headline=pvp[1].name..' tog '..pvp[1].value..' ärofyllda segrar ute i världen.' end
    local story={
        [60]='%s dog %s gånger. Kyrkogårdsvakten börjar känna igen ansiktet.',
        [114]='%s föll mot sin död %s gånger. Genvägen blev visst en omväg.',
        [98]='%s klarade %s quest. Nån får la göra jobbet.',
        [341]='%s fick med sig %s episka fynd hem. Gôtt om plats i påsarna behövdes.',
        [1518]='%s drog upp %s fiskar. Vi frågar inte hur länge det tog.',
        [108]='%s dödade %s smådjur. Djurlivet avböjer att kommentera.',
        [193]='%s satte nytt rekord med en träff på %s. En enda smäll, inte veckans totalskada.',
        [189]='%s satte nytt läkningsrekord på %s. En enda läkning, inte veckans totalsumma.'}
    local spot=edition.spotlight
    local main=spot and string.format(story[spot.id] or '%s noterade %s i veckans utvalda gren.',spot.name,string.format('%.0f',spot.value))
        or 'Lite lugnare i spalterna. Redaktionen tar gärna emot tips innan pressen går.'
    if pvp[1] and week%2==0 then main=pvp[1].name..' ledde striderna ute i världen med '..pvp[1].value..'.' end

    local front={name='Förstasidan',layout=week%2==0 and 'front' or 'frontLedger',texture=week%2==0 and 'NewsletterFront1.png' or 'NewsletterFront2.png',fields={
        masthead='OF-Posten',edition=dateLine(edition),headline=headline,byline='FRÅN GUILDEN  /  VECKAN SOM GICK',lead=main,
        caption=week%2==0 and 'En stilla förmiddag på Götaplatsen i Orgrimmar.' or 'Ordning på guldet. Kvitto medtages.',
        briefTitle='KORT FRÅN GUILDEN',brief=table.concat(brief,'\n\n'),
        leftTitle=second and second.title or 'INNAN DU GÅR',leftBody=second and second.summary or tips[week%#tips+1],
        middleTitle=third and third.title or 'ATT TÄNKA PÅ',middleBody=third and third.summary or tips[(week+1)%#tips+1],
        footer='OF-Posten  |  '..N.Date(edition.publishedAt)
    }}
    edition.pages={front}
    local function feature(name,headline,sections,intro)
        if #sections==0 then return end
        local one,two=sections[1],sections[2]
        edition.pages[#edition.pages+1]={name=name,layout=name=='Goblinens kassabok' and 'dataLedger' or 'dataStories',texture='NewsletterInside.png',fields={
            masthead=name,edition=dateLine(edition),headline=headline,intro=intro,
            leftTitle=one.title,leftValue=one.value or '',leftBody=one.body,
            rightTitle=two and two.title or '',rightValue=two and two.value or '',rightBody=two and two.body or '',
            footer='OF-Posten  |  '..N.Date(edition.publishedAt)..''
        }}
    end
    local ledger={}
    if wealth then ledger[#ledger+1]={title='GÔTT OM GULD',value=N.Money(gold[1].value),body=gold[1].name..' har mest guld i fickorna.\n\n'..board(gold,true)..'\n\nIngen skatt uttagen. Än.'} end
    if repairs[1] then ledger[#ledger+1]={title='SMEDEN TACKAR',value=N.Money(repairs[1].value),body=repairs[1].name..' toppar de registrerade reparationsnotorna.\n\n'..board(repairs,true)..'\n\nSmeden klagar inte.'} end
    feature('Goblinens kassabok','Nånstans tog pengarna vägen.',ledger,'Vi har tittat i börsarna och räknat smedens kvitton.')
    local roads={}
    if pvp[1] then roads[#roads+1]={title='STÖK PÅ VÄGARNA',value=pvp[1].value..' segrar ute i världen',body='Höj stopet för '..pvp[1].name..' och '..pvp[1].value..' ärofyllda segrar ute i världen. Alliansen får la ta en annan väg hem.\n\n'..board(pvp)} end
    if race then roads[#roads+1]={title='GUILDENS SVETTIGASTE',value='Nivå '..levels[1].value,body=levels[1].name..' har högst rapporterad nivå: '..levels[1].value..'.\n\n'..board(levels)} end
    feature('Ute på vägarna','Lite framåt. Lite slagsmål.',roads,'Strider ute i världen och vägen till sextio, när det finns nåt att skriva om.')
    if #ledger==0 and #roads==0 and #active>0 then
        feature('Runt om i guilden','Det lilla är också värt lite tjöt.',{second,third},'Veckans rapporterade bravader i lite närmare blick. Tomma räknare får vila.')
    end
    -- Requested recurring spotlight. These are reported lifetime totals, not invented weekly deltas.
    local needs,kills=rows(records,1044,true),rows(records,1487,true)
    local spotlight={}
    if needs[1] then spotlight[#spotlight+1]={title='DEN BEHÖVDE JAG LA',value=string.format('%.0f need-rolls',needs[1].value),
        body=board(needs)..'\n\n'..needs[1].name..' har rollat need flest gånger. Den behövdes la.'} end
    if kills[1] then spotlight[#spotlight+1]={title='SISTA SMÄLLEN',value=string.format('%.0f killing blows',kills[1].value),
        body=board(kills)..'\n\n'..kills[1].name..' delade ut flest sista smällar. Nån måste la avsluta jobbet.'} end
    feature('Need & sista smällen','Den behövde jag. Den med.',spotlight,'Totalt per karaktär.')
    local duels={}
    for name,r in pairs(records) do
        local won,lost=r.finish[319],r.finish[320]
        if numeric(won) and numeric(lost) and won+lost>0 then duels[#duels+1]={name=short(name),fullName=name,won=won,lost=lost} end
    end
    table.sort(duels,function(a,b) return a.won==b.won and (a.lost==b.lost and a.fullName<b.fullName or a.lost<b.lost) or a.won>b.won end)
    local contests={}
    if duels[1] then
        local lines={}
        for i=1,math.min(3,#duels) do
            local d=duels[i]
            lines[#lines+1]=d.name..': '..d.won..' V / '..d.lost..' F\n'..(d.lost==0 and 'Obesegrad' or string.format('V/F %.2f',d.won/d.lost))..string.format(' | %.0f%% vunna',100*d.won/(d.won+d.lost))
        end
        local losses=rows(records,320,true)
        if losses[1] then lines[#lines+1]='Flest förluster: '..losses[1].name..' ('..string.format('%.0f',losses[1].value)..'). Vi tar la en till?' end
        contests[#contests+1]={title='SKA VI TA DET UTANFÖR?',value=duels[1].won..' vinster',
            body=table.concat(lines,'\n\n')}
    end
    local deposits=db.bankDonations
    if deposits and deposits[1] then contests[#contests+1]={title='GÖTT, NÅN BETALAR',value=N.Money(deposits[1].value),
        body=board(deposits,true)..'\n\n'..deposits[1].name..' toppar guldinsättningarna som syns i bankloggen. Goblinen tackar.'} end
    feature('Dueller & guildkassan','Lite slagsmål. Lite samhällsnytta.',contests,'Vem tar flest dueller, och vem håller kassan vid liv? Bara tillgängliga uppgifter trycks.')
    -- Compact, data-first activity pages: only measured changes qualify.
    local activities={{347,'GÔTT I MAGEN','portioner mat'},{346,'EN TILL, ELLER?','drycker'},{349,'STAMKUND I LUFTEN','flygresor'},
        {98,'QUEST AVKLARADE','avklarade quest'},{94,'DET FÅR VA','övergivna quest'},{112,'TOG SIG VATTEN ÖVER HUVUDET','drunkningar'},
        {1518,'DET NAPPADE','fångade fiskar'},{353,'HEM LJUVA HEM','hemresor med hearthstone'},{114,'GENVÄGEN NER','dödsfall efter fall'},
        {1044,'DEN BEHÖVDE JAG','need-rolls'},{1042,'EN KRAM PÅ DET','kramar'},{1066,'NÅN HADE ROLIGT','skratt'}}
    local cards={}
    for _,metric in ipairs(activities) do
        local list=rows(records,metric[1])
        if list[1] then cards[#cards+1]={title=metric[2],body=board(list)..'\n\n'..metric[3]} end
    end
    for offset=1,#cards,6 do
        if #edition.pages>=7 then break end -- reserve final page for professions; protocol max 8
        local fields={masthead='Veckan i siffror',edition=dateLine(edition),headline='Det här hade ni för er.',intro=''}
        for i=1,6 do local card=cards[offset+i-1];if card then fields['card'..string.char(64+i)..'Title']=card.title;fields['card'..string.char(64+i)..'Body']=card.body end end
        edition.pages[#edition.pages+1]={name='Veckan i siffror',layout='dataSix',texture='NewsletterInside.png',fields=fields}
    end
    edition.pages[#edition.pages+1]=N.ProfessionPage(edition,records)
    return edition
end

function N.ProfessionPage(edition,records)
    local professions={{1519,'Fishing',false},{1524,'Cooking',false},{281,'First Aid',false},
        {1527,'Alchemy',true},{1532,'Blacksmithing',true},{1535,'Enchanting',true},{1536,'Leatherworking',true},
        {1537,'Mining',true},{1538,'Herbalism',true},{1541,'Skinning',true},{1542,'Tailoring',true},{1544,'Engineering',true}}
    local fields={masthead='Yrkesfolket',edition=dateLine(edition),headline='Vem kan sitt hantverk?',intro='Rapporterad färdighet. Rekordfält visar högsta uppnådda nivå och kan avse ett tidigare yrke.'}
    for i,metric in ipairs(professions) do
        local list=rows(records,metric[1],true)
        fields['card'..string.char(64+i)..'Title']=metric[2]
        fields['card'..string.char(64+i)..'Body']=(list[1] and board(list) or 'Ingen rapporterad nivå än.')..'\n\n'..(metric[3] and 'Högsta uppnådda nivå' or 'Rapporterad nivå')
    end
    return {name='Yrkesfolket',layout='professions',texture='NewsletterInside.png',fields=fields}
end

function N.Demo(now)
    local week=LootBotGuildStatistics.Week(now)-1
    local first,last=MONDAY+week*WEEK+3600,MONDAY+(week+1)*WEEK-3600
    local records={
        ['Gruk-Demo']={first=first,last=last,start={[60]=100,[98]=400,[381]=20,[900001]=10000,[900002]=39,[900003]=0},finish={[60]=118,[98]=426,[381]=37,[900001]=2234567,[900002]=40,[900003]=23456}},
        ['Mara-Demo']={first=first,last=last,start={[60]=10,[1518]=90,[900001]=100000,[900002]=40,[900003]=0},finish={[60]=12,[1518]=188,[900001]=1234567,[900002]=41,[900003]=11000}},
        ['Tusk-Demo']={first=first,last=last,start={[60]=5,[341]=0,[900001]=10000,[900002]=35,[900003]=0},finish={[60]=8,[341]=2,[900001]=334500,[900002]=37,[900003]=2500}}
    }
    for index,name in ipairs({'Gruk-Demo','Mara-Demo','Tusk-Demo'}) do
        local r=records[name]
        for _,id in ipairs({347,346,349,98,94,112,1518,353,114,1044,1042,1066}) do r.start[id]=100;r.finish[id]=100+index*7+(id%11) end
        for _,id in ipairs({1519,1524,281,1527,1532,1535,1536,1537,1538,1541,1542,1544}) do r.start[id]=25*index;r.finish[id]=50*index end
    end
    local edition=LootBotGuildStatistics.Edition({weeks={[week]=records}},now)
    edition.demo=true
    N.PublicationDate(edition,now)
    for _,page in ipairs(edition.pages) do page.fields.edition='PROVNUMMER - PÅHITTADE SIFFROR  |  '..N.Date(edition.publishedAt)..'  |  ORIGINAL FORMALITIES' end
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

-- OF-Posten front artwork has a baked masthead and approved caption.
-- Data fields keep their original values; only typesetting coordinates change.
N.Layouts.front={
 p('edition',40,187,975,29,17,true),p('headline',40,240,975,115,38,false,true),
 p('byline',40,375,635,25,16),p('lead',40,428,225,425,19),
 p('briefTitle',722,425,295,38,23,false,true),p('brief',722,475,295,350,21),
 p('leftTitle',40,1000,305,40,23,false,true),p('leftBody',40,1050,305,175,18),
 p('middleTitle',385,1000,295,40,23,false,true),p('middleBody',385,1050,295,175,18),
 p('footer',35,1462,980,20,12,true)
}
N.Layouts.frontLedger=N.Layouts.front

-- The interior bottom strip now carries advertisements; the date remains in its header.
table.remove(N.Layouts.inside,#N.Layouts.inside)

-- OF-Posten is already printed into the back-page texture.
table.remove(N.Layouts.back,1)

-- Data-first layouts use an unprinted paper area of the existing texture.
local function grid(columns,rows)
 local layout={s('masthead',50,40,986,95,52,true,true,'masthead'),s('edition',50,150,986,32,20,true),s('headline',50,210,986,80,38,false,true),s('intro',50,305,986,80,23)}
 local width=986/columns;local height=990/rows
 for i=1,columns*rows do
  local x=50+((i-1)%columns)*width;local y=410+math.floor((i-1)/columns)*height
  local key='card'..string.char(64+i)
  layout[#layout+1]=s(key..'Title',x,y,width-28,68,columns==3 and 24 or 28,false,true)
  layout[#layout+1]=s(key..'Body',x,y+75,width-28,height-90,columns==3 and 22 or 26)
 end
 return layout
end
N.Layouts.dataSix=grid(2,3)
N.Layouts.professions=grid(3,4)

N.Layouts.dataLedger={s('masthead',50,40,986,95,52,true,true),s('edition',50,150,986,32,20,true),s('headline',50,220,986,80,38,false,true),s('intro',50,320,986,90,24),
 s('leftTitle',50,470,460,70,30,false,true),s('leftValue',50,560,460,90,48,false,true),s('leftBody',50,690,460,650,27),
 s('rightTitle',570,470,460,70,30,false,true),s('rightValue',570,560,460,90,48,false,true),s('rightBody',570,690,460,650,27)}
N.Layouts.dataStories={s('masthead',50,40,986,95,52,true,true),s('edition',50,150,986,32,20,true),s('headline',50,220,986,80,38,false,true),s('intro',50,320,986,90,24),
 s('leftTitle',50,450,986,60,32,false,true),s('leftValue',50,530,280,80,42,false,true),s('leftBody',360,530,670,350,26),
 s('rightTitle',50,950,986,60,32,false,true),s('rightValue',50,1030,280,80,42,false,true),s('rightBody',360,1030,670,350,26)}

-- Typesetting follows the generated middle-page rules; headlines are baked into art.
N.Layouts.dataLedger={s('edition',80,190,926,32,20,true),s('headline',80,275,926,80,38,false,true),s('intro',80,370,926,90,24),
 s('leftTitle',65,530,440,70,30,false,true),s('leftValue',65,620,440,90,48,false,true),s('leftBody',65,730,440,580,25),
 s('rightTitle',580,530,440,70,30,false,true),s('rightValue',580,620,440,90,48,false,true),s('rightBody',580,730,440,580,25)}
N.Layouts.dataStories={s('edition',95,190,896,32,20,true),s('headline',95,275,896,80,38,false,true),s('intro',95,370,896,90,24),
 s('leftTitle',95,530,896,60,32,false,true),s('leftValue',95,620,240,80,38,false,true),s('leftBody',370,620,620,265,24),
 s('rightTitle',95,960,896,60,32,false,true),s('rightValue',95,1040,240,80,38,false,true),s('rightBody',370,1040,620,290,24)}

N.Layouts.dataSix={s('edition',85,205,916,32,20,true),s('headline',80,285,926,80,38,false,true),s('intro',80,385,926,95,24)}
for i=1,6 do
 local x=(i%2==1) and 80 or 565;local y=530+math.floor((i-1)/2)*294;local key='card'..string.char(64+i)
 N.Layouts.dataSix[#N.Layouts.dataSix+1]=s(key..'Title',x,y,435,65,26,false,true)
 N.Layouts.dataSix[#N.Layouts.dataSix+1]=s(key..'Body',x,y+75,435,180,24)
end

-- Profession back-page artwork: three columns, four rows, tool engravings outside data.
N.Layouts.professions={s('edition',105,205,876,30,18,true),s('headline',105,260,876,60,32,false,true),s('intro',105,335,876,50,19)}
local professionRows={415,623,825,1027}
for i=1,12 do
 local x=103+((i-1)%3)*305;local y=professionRows[math.floor((i-1)/3)+1];local key='card'..string.char(64+i)
 N.Layouts.professions[#N.Layouts.professions+1]=s(key..'Title',x,y,272,35,23,false,true)
 N.Layouts.professions[#N.Layouts.professions+1]=s(key..'Body',x,y+41,272,140,20)
end
