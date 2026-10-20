local F=ModSettingsFolders;local I,M,S=F.Import,F.Model,F.Store
local oldInfo,oldActive=getModInfoByID,getActivatedMods
assert(not I.available(),'button shown without ModFolders')
function getModInfoByID(id)
    if id=='ModFolders' then return {getName=function() return 'ModFolders' end} end
    if id=='aliasMod' then return {getName=function() return 'Readable Title' end} end
end
assert(I.available(),'installed ModFolders not detected')
local function hex(text)
    local codes={};for n=1,#text do codes[#codes+1]=string.format('%X',text:byte(n)) end
    return table.concat(codes,',')
end
local sourceText='version=2\nnext=4\nfolder=1|1|'..hex('Visual')..'\nfolder=2|0|'..hex(unicodeName)..'\nfolder=3|1|'..hex('New')..'\nmember='..hex('alpha')..'|1\nmember='..hex('aliasMod')..'|2\nmember='..hex('beta')..'|3\nmember='..hex('missing')..'|1\n'
local source=assert(I.decode(sourceText))
assert(source.folders[2].name==unicodeName and source.folders[2].collapsed)
local legacy=assert(I.decode('folder=1|1|Old%20Folder\nmember=mod.id|1\nnext=2\n'))
assert(legacy.folders[1].name=='Old Folder' and legacy.members['mod.id']==1)
if MSF_ModFoldersCodec then
    local encoded=MSF_ModFoldersCodec.encode(unicodeName)
    local decoded=assert(I.decode('version=2\nfolder=1|1|'..encoded..'\n'))
    assert(decoded.folders[1].name==MSF_ModFoldersCodec.v2(encoded) and decoded.folders[1].name==unicodeName)
    for _,value in ipairs({'Old%20Folder','%0418%043D','mod.id','%25','%7C'}) do
        local text='folder=1|1|'..value..'\n'
        assert(assert(I.decode(text)).folders[1].name==MSF_ModFoldersCodec.v1(value))
    end
    print('PASS installed ModFolders codec: v2 Unicode and legacy percent-escape compatibility')
end
for _,text in ipairs({'version=3\n','version=2\nfolder=1|1|GG\n','version=2\nfolder=1|1|10000\n','folder=1|1|A\nfolder=1|1|B\n','member=missing|1\n','folder=1|1|A\nmember=x|1\nmember=x|1\n',string.rep('x',524289),'return os.execute("bad")'}) do assert(not I.decode(text),'invalid import accepted') end
local groups={{id='alpha',name='Alpha'},{id='beta',name='Beta'},{id='unrelatedID',name='Readable Title'}}
assert(I.resolve('aliasMod',groups)=='unrelatedID')
assert(not I.resolve('aliasMod',{{id='a',name='Readable Title'},{id='b',name='Readable Title'}}),'ambiguous display-name match accepted')
local state=M.new();local first=assert(M.create(state,'visual'));local other=assert(M.create(state,'Local'))
M.move(state,'oldDisabled',first);M.move(state,'beta',other)
state.folders[1].collapsed=true
local unchanged=M.encode(state)
local candidate,report=I.merge(state,source,groups)
assert(candidate and M.encode(state)==unchanged,'merge mutated existing state')
assert(#candidate.folders==3 and candidate.members.alpha==first and candidate.members.oldDisabled==first)
assert(candidate.members.beta==other and M.find(candidate,other).name=='Local','existing folder identity lost')
assert(report.assigned==3 and report.skipped==1 and report.created==1)
local again=assert(I.merge(candidate,source,groups));assert(M.encode(again)==M.encode(candidate),'repeated import not idempotent')
-- Overlap joins whole components, preserving both folders contents and oldest local name.
local overlap=assert(I.decode('folder=1|1|Visual\nmember=alpha|1\nmember=beta|1\n'))
M.move(state,'alpha',first);M.move(state,'otherDisabled',other)
local joined=assert(I.merge(state,overlap,groups))
assert(#joined.folders==1 and joined.members.alpha==first and joined.members.beta==first and joined.members.otherDisabled==first)
local full=M.new();for n=1,99 do assert(M.create(full,'Folder'..n)) end
assert(not I.merge(full,assert(I.decode('folder=1|1|Extra\n')),{}),'folder capacity exceeded')
local fullSections=M.new();local only=M.create(fullSections,'Existing')
for n=1,2000 do M.move(fullSections,'old'..n,only) end
assert(not I.merge(fullSections,assert(I.decode('folder=1|1|Existing\nmember=new|1\n')),{{id='new',name='New'}}),'membership capacity exceeded')
local oldState,oldGood=S.state,S.good
local oldFile=files[I.file];local oldMessage=F.UI.message
local notice;F.UI.message=function(key) notice=key end
files[I.file]=sourceText;S.state=M.new()
local owner=newOptions(1280);owner:addModOptionsPanel();local controller=owner.msfController
assert(controller.importButton and controller.tree:getY()>controller.importButton:getY()+controller.importButton:getHeight())
local originalWriter=getFileWriter
getFileWriter=function(path,...) assert(path~=I.file,'source config write attempted');return originalWriter(path,...) end
controller:importMenu();local menu=controller.contextMenu
assert(menu.options[1].text=='ModFolders')
controller:importFolders();assert(notice=='UI_MSF_Imported' and files[I.file]==sourceText and S.state==controller.state)
local goodState=S.state;local encoded=M.encode(goodState)
failWrite=true;controller:importFolders();failWrite=false
assert(notice=='UI_MSF_SaveFailed' and S.state==goodState and M.encode(controller.state)==encoded,'failed save changed live state')
files[I.file]='version=999\n';controller:importFolders()
assert(notice=='UI_MSF_ImportFailed' and S.state==goodState)
files[I.file]=nil;local beforeWrites=writes
controller:importFolders();assert(notice=='UI_MSF_ImportFailed' and files[I.file]==nil and writes==beforeWrites,'missing source was created')
getFileWriter=originalWriter;F.UI.detach(owner)
getModInfoByID=nil;getActivatedMods=nil
local without=newOptions(1280);without:addModOptionsPanel();assert(not without.msfController.importButton);F.UI.detach(without)
getModInfoByID=oldInfo;getActivatedMods=oldActive
files[I.file]=oldFile;S.state=oldState;S.good=oldGood;F.UI.message=oldMessage
print('PASS ModFolders import: installed-only UI, Unicode v1/v2 parsing, unique mapping, nondestructive/transitive merge, idempotence, bounds, source isolation and failed-save rollback')
