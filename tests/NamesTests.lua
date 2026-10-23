local N=ModSettingsFolders.Names
local oldInfo,oldActive=getModInfoByID,getActivatedMods
function getModInfoByID(id)
    if id=='source.mod' or id=='Source-Mod' then return {getName=function() return unicodeName end} end
    if id=='broken' then error('metadata unavailable') end
end
assert(N.display('source.mod','source.mod')==unicodeName)
assert(N.display('source.mod','   ')==unicodeName)
assert(N.display('source.mod','UI_missing_title')==unicodeName)
assert(N.display('source.mod','Settings')==unicodeName)
assert(N.display('source.mod','Handwritten section name')=='Handwritten section name')
assert(N.display('unknown','unknown')=='unknown' and N.display('broken','')=='broken')
function getActivatedMods() return {size=function() return 1 end,get=function() return 'Source-Mod' end} end
assert(N.display('source_mod','source_mod')==unicodeName)
function getActivatedMods() return {size=function() return 2 end,get=function(_,n) return n==0 and 'Source-Mod' or 'source.mod' end} end
assert(N.display('source_mod','source_mod')=='source_mod','ambiguous owner guessed')
getModInfoByID=oldInfo;getActivatedMods=oldActive
print('PASS section names: source metadata for missing/ID/untranslated titles, Unicode, real names retained, unique normalized IDs and unavailable metadata')
