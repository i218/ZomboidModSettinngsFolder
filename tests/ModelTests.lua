local M=ModSettingsFolders.Model
local s=M.new();local a=assert(M.create(s," "..unicodeName.." "));local b=assert(M.create(s,"Gameplay"))
assert(not M.create(s,"Gameplay") and not M.create(s,"\n") and not M.create(s,string.rep("x",161)))
assert(M.move(s,"section.one",a) and M.move(s,"disabled-section",b));assert(not M.move(s,"x","missing"))
s.folders[1].collapsed=true;s.unfiledCollapsed=true
local decoded=assert(M.decode(M.encode(s)));assert(decoded.members["disabled-section"]==b and decoded.folders[1].name==unicodeName and decoded.unfiledCollapsed)
assert(M.reorder(decoded,b,-1) and decoded.folders[1].id==b);assert(M.rename(decoded,a,"UI"))
assert(M.delete(decoded,b) and not decoded.members["disabled-section"] and decoded.members["section.one"]==a)
assert(not M.decode("MSF2\n") and not M.decode("MSF1\nF|f1|0|%zz\n"))
assert(not M.decode("MSF1\nM|f9|61\n") and not M.decode("MSF1\nU|0\nU|1\n"))
assert(not M.decode("MSF1\nF|f1|0|61\nF|f1|0|62\n"))
local malicious="return os.execute('bad')";assert(M.create(decoded,malicious));assert(M.decode(M.encode(decoded)))
local S=ModSettingsFolders.Store;assert(#S.load().folders==0)
S.state=s;assert(S.save());local first=files[S.file]
s.folders[1].name="Changed";assert(S.save());assert(files[S.backup]==first)
S.state=nil;S.good=nil;files[S.file]="broken\n";assert(S.load().folders[1].name==unicodeName and S.recovered)
S.state=nil;S.good=nil;S.recovered=nil;files[S.file]="MSF2\nfuture data\n";assert(#S.load().folders==0 and S.blocked)
local before=files[S.file];assert(not S.save() and files[S.file]==before)
S.state=nil;S.good=nil;S.blocked=nil;files[S.file]=nil;files[S.backup]=nil;S.load();assert(S.save())
local good=files[S.file];failWrite=true;assert(not S.save() and files[S.file]==good);failWrite=false
print('PASS layout model: UTF-8, stable IDs, absent mods, rename/delete/reorder, bounded strict parsing, no code evaluation, backup recovery, future-format protection and disk failure')

local escaped=assert(M.create(s,"100% | UI"));assert(M.decode(M.encode(s)).folders[3].name=="100% | UI")
