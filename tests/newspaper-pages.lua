local G,N=LootBotGuildStatistics,LootBotNewspaperEdition
local week=G.Week(GetServerTime())-1
local published=345600+(week+1)*604800
local records={
    ['Gruk-Realm']={first=published-10000,last=published-1,start={[60]=20,[381]=10,[900001]=100000,[900002]=39,[900003]=0},finish={[60]=28,[381]=17,[900001]=1234567,[900002]=40,[900003]=23456}},
    ['Mara-Realm']={first=published-10000,last=published-1,start={[1518]=4,[900001]=200000,[900002]=38,[900003]=0},finish={[1518]=102,[900001]=400000,[900002]=41,[900003]=10000}}
}
local db={weeks={[week]=records}}
local edition=G.Edition(db,published+7200)
assert(edition.publishedAt==published and #edition.pages==5)
assert(edition.pages[1].name=='Förstasidan' and edition.pages[5].layout=='professions')
local text=''
for _,page in ipairs(edition.pages) do for _,v in pairs(page.fields) do text=text..v..'\n' end end
assert(text:find('123g 45s 67c',1,true),'richest must show actual balance, not gold earned')
assert(text:find('2g 34s 56c',1,true),'repair spend must be formatted from copper')
assert(text:find('7 ärofyllda segrar ute i världen',1,true))
assert(text:find('högst rapporterad nivå: 41',1,true))
assert(not text:find('FICTIONAL',1,true))
assert(N.Money(0)=='0g 0s 0c' and N.Money(10000)=='1g 0s 0c')
assert(G.Edition(db,published+86400*5).pages[1].fields.edition==edition.pages[1].fields.edition,'opening date must not change publication date')
local capped={}
for name,r in pairs(records) do capped[name]={first=r.first,last=r.last,start={[900002]=60},finish={[900002]=60}} end
local quiet=G.Edition({weeks={[week]=capped}},published+10)
assert(#quiet.pages==2 and quiet.pages[1].fields.headline=='En lugn vecka. Det händer la ibland.')
local unchanged={weeks={[week]=records,[week-1]=records}}
for _,r in pairs(records) do r.start[900001]=r.finish[900001] end
local same=G.Edition(unchanged,published+10)
assert(not same.pages[1].fields.brief:find('GÔTT OM GULD',1,true),'unchanged wealth should stay out')

-- Open real pages, traverse boundaries, reset pan/zoom and retain close behavior.
LootBotGuildStatistics.CurrentEdition=function() return edition end
LootBotNewsletterPreview.Show()
assert(LootBotNewsletterPreview.pageCount>=5)
assert(not LootBotNewsletterPreviousPage.enabled and LootBotNewsletterNextPage.enabled)
local pageLabel=LootBotNewsletterNavigation.labels[1]
assert(pageLabel.text:find('1 / 5',1,true))
local view=LootBotNewsletterViewport
local fitted=view.scrollChild.width
view.scripts.OnMouseWheel(view,1)
assert(view.scrollChild.width>fitted)
LootBotNewsletterNextPage.scripts.OnClick()
assert(LootBotNewsletterPreview.pageIndex==2 and view.scrollChild.width==fitted and view:GetVerticalScroll()==0)
assert(view.scrollChild.textures[1].path:find('NewsletterLedger.png',1,true))
LootBotNewsletterNextPage.scripts.OnClick()
assert(view.scrollChild.textures[1].path:find('NewsletterStories.png',1,true))
LootBotNewsletterNextPage.scripts.OnClick()
assert(view.scrollChild.textures[1].path:find('NewsletterStatistics.png',1,true))
LootBotNewsletterPreview.ChangePage(100)
assert(LootBotNewsletterPreview.pageIndex==5 and not LootBotNewsletterNextPage.enabled)
assert(view.scrollChild.textures[1].path:find('NewsletterProfessions.png',1,true))
LootBotNewsletterPreview.ChangePage(-100)
assert(LootBotNewsletterPreview.pageIndex==1)
LootBotNewsletterCloseButton.scripts.OnClick()
assert(not LootBotNewsletterFrame:IsShown())
local welcome=G.Launch(GetServerTime())
LootBotGuildStatistics.CurrentEdition=function() return welcome end
LootBotNewsletterPreview.Show()
assert(LootBotNewsletterPreview.pageCount==2 and view.scrollChild.textures[1].path:find('NewsletterWelcome.png',1,true))
LootBotNewsletterPreview.ChangePage(1)
assert(view.scrollChild.textures[1].path:find('NewsletterProfessions.png',1,true))
assert(not LootBotMarker:IsShown() and #LootBotMarker.textures==0)
local oldRead=LootBotDB.newspaperRead[UnitGUID('player')]
local dbBefore=LootBotDB.guildStatistics
SlashCmdList.LOOTBOT('newspaper demo')
assert(LootBotNewsletterPreview.pageCount>=5 and LootBotNewsletterPreview.previewEdition.demo)
assert(LootBotDB.newspaperRead[UnitGUID('player')]==oldRead and LootBotDB.guildStatistics==dbBefore)
LootBotNewsletterPreview.Show()
assert(not LootBotNewsletterPreview.previewEdition and LootBotNewsletterPreview.pageCount==2)
local quietMonday=G.Edition({startedWeek=week-3,weeks={[week-2]=records}},published+10)
assert(quietMonday.id==week and quietMonday.publishedAt==published and #quietMonday.pages==2)
assert(quietMonday.pages[1].fields.headline=='En lugn vecka. Det händer la ibland.')
assert(not quietMonday.pages[1].fields.brief:find('GÔTT OM GULD',1,true))
assert(G.Edition({startedWeek=week+1,weeks={}},published+10).launch,'first collection week keeps welcome cover')

-- Font auditions use the real demo renderer without touching guild readings.
local beforeRead=LootBotDB.newspaperRead and LootBotDB.newspaperRead[UnitGUID('player')]
local originalWeek=db.weeks[week]
for _,style in ipairs({'Crimson','Trycksvärta','WoW'}) do
 LootBotNewsletterPreview.ShowDemo(style)
 assert(LootBotNewsletterPreview.previewEdition.demo and LootBotNewsletterPreview.demoFont==style)
 assert(db.weeks[week]==originalWeek)
 assert((LootBotDB.newspaperRead and LootBotDB.newspaperRead[UnitGUID('player')])==beforeRead)
end
-- Opening after a display resize fits the current screen and reserves navigation space.
UIParent.GetHeight=function() return 1000 end
LootBotNewsletterPreview.ShowDemo('WoW')
assert(math.abs(LootBotNewsletterFrame.height-(1000*.97-33))<.01)
assert(LootBotNewsletterNavigation.width==LootBotNewsletterFrame.width)

local demo=N.Demo(GetServerTime())
assert(demo.publishedAt==GetServerTime(),'preview date is today')
assert(#demo.pages<=8 and demo.pages[#demo.pages].layout=='professions')
assert(demo.pages[2].layout~=demo.pages[3].layout)
local all='';for _,page in ipairs(demo.pages) do for _,v in pairs(page.fields) do all=all..v..'\n' end end
for _,word in ipairs({'portioner mat','drycker','flygresor','övergivna quest','drunkningar','Fishing','Cooking','First Aid'}) do assert(all:find(word,1,true),word) end
assert(demo.pages[#demo.pages].fields.cardABody:find('150',1,true))
assert(quiet.pages[#quiet.pages].fields.cardABody=='Ingen rapporterad nivå än.')
assert(quiet.pages[#quiet.pages].fields.cardDBody=='Ingen rapporterad nivå än.')

-- New layouts and expanded readings survive guild publication serialization.
demo.demo=nil
local encoded=LootBotNewspaperPublication.Encode(demo,'Alex-TestRealm',GetServerTime())
assert(encoded,'data edition must fit the publication budget')
local decoded=LootBotNewspaperPublication.Decode(encoded,GetServerTime())
assert(decoded and #decoded.pages==#demo.pages)
assert(decoded.pages[#decoded.pages].fields.cardABody==demo.pages[#demo.pages].fields.cardABody)
