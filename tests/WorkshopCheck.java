import java.nio.file.*;
import java.util.*;
import zombie.core.znet.SteamWorkshopItem;

/** Calls only the installed game's metadata/content validators. Never initializes Steam. */
public final class WorkshopCheck {
    public static void main(String[] args) throws Exception {
        var folder=Path.of(args[0]).toAbsolutePath();
        // Initialize only path roots, with cache restricted to this build package's parent.
        // Do not initialize the game filesystem, Steam, Lua, a window or user profile.
        zombie.ZomboidFileSystem.instance.base.set(Path.of(".").toAbsolutePath().toFile());
        zombie.ZomboidFileSystem.instance.setCacheDir(folder.getParent().toString());
        var item=new SteamWorkshopItem(folder.toString());
        if(!item.readWorkshopTxt()) throw new AssertionError("Native metadata reader rejected workshop.txt");
        if(!"private".equals(item.getVisibility())) throw new AssertionError("Expected private initial visibility");
        var allowed=Files.readAllLines(Path.of("media/WorkshopTags.txt"));
        if(!allowed.containsAll(item.getTags())) throw new AssertionError("Unknown Workshop tags");
        String result=item.validateContents();
        if(result!=null) throw new AssertionError("Native content validator: "+result+" "+item.getExtendedErrorInfo(result));
        if(!item.getSubmitDescription().contains("ModSettingsFolders")) throw new AssertionError("Native mod ID registration missing");
        System.out.println("PASS installed SteamWorkshopItem metadata/content/PNG validator; tags="+item.getTags()+"; no upload attempted");
    }
}
