using System;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Collections.Generic;

internal static class InstallerTests {
    private static string workspace;
    private static int checks;
    private static void Check(bool value, string name) { if (!value) throw new Exception(name); checks++; }
    private static void Reject(Action action, string name) {
        bool rejected = false; try { action(); } catch (IOException) {rejected = true;}
        Check(rejected, name);
    }
    private static string Area(string name) { return Path.Combine(workspace, name); }
    private static string Seed(string name, string id) {
        string root = Area(name), mod = Path.Combine(root, "mods", InstallEngine.Id);
        Directory.CreateDirectory(Path.Combine(mod, "42"));
        File.WriteAllText(Path.Combine(mod, "42", "mod.info"), "id=" + id + "\nmodversion=0.0.1\n");
        File.WriteAllText(Path.Combine(mod, "legacy.txt"), "previous files"); return root;
    }
    private static void BadPayload(string name, string text, string manifestOverride, bool duplicate) {
        byte[] bytes = Encoding.UTF8.GetBytes(text);
        var manifest = Encoding.UTF8.GetBytes(manifestOverride ?? (Payload.Hash(bytes) + "|" + bytes.Length + "|" + name + "\n"));
        using (var zip = new MemoryStream()) {
            using (var archive = new ZipArchive(zip, ZipArchiveMode.Create, true)) {
                using (var stream = archive.CreateEntry(name).Open()) stream.Write(bytes, 0, bytes.Length);
                if (duplicate) using (var stream = archive.CreateEntry(name).Open()) stream.Write(bytes, 0, bytes.Length);
            }
            zip.Position = 0;
            Reject(delegate { Payload.Read(zip, new MemoryStream(manifest)); }, "reject malformed payload: " + name);
        }
    }
    private static int Main(string[] args) {
        try {
            workspace = Path.GetFullPath(args[0]);
            if (Directory.Exists(workspace)) throw new IOException("Test workspace must be new.");
            Directory.CreateDirectory(workspace);
            var payload = Payload.Embedded(); Check(payload.Files.Count > 5, "embedded payload");
            string fresh = Area("fresh"); var first = InstallEngine.Install(payload, fresh);
            InstallEngine.Verify(payload, first.Target); Check(!first.AlreadyCurrent && first.Backup == null, "fresh install");
            Check(Directory.GetDirectories(fresh, ".ModSettingsFolders-stage-*").Length == 0, "staging removed");
            File.WriteAllText(Path.Combine(fresh, "ModSettingsFolders.cfg"), "custom layout");
            File.WriteAllText(Path.Combine(fresh, "ModOptions.ini"), "custom settings");
            File.WriteAllText(Path.Combine(fresh, "mods", "default.txt"), "enabled list");
            Directory.CreateDirectory(Path.Combine(fresh, "mods", "AnotherMod"));
            File.WriteAllText(Path.Combine(fresh, "mods", "AnotherMod", "keep.txt"), "unrelated");
            var second = InstallEngine.Install(payload, Path.Combine(fresh, "mods"));
            Check(second.AlreadyCurrent && second.Target == first.Target, "idempotent; mods path normalized");
            Check(!Directory.Exists(Path.Combine(fresh, "ModSettingsFoldersBackups")), "no redundant backup");
            Check(File.ReadAllText(Path.Combine(fresh, "ModSettingsFolders.cfg")) == "custom layout" && File.ReadAllText(Path.Combine(fresh, "ModOptions.ini")) == "custom settings", "settings retained");
            Check(File.ReadAllText(Path.Combine(fresh, "mods", "default.txt")) == "enabled list" && File.ReadAllText(Path.Combine(fresh, "mods", "AnotherMod", "keep.txt")) == "unrelated", "other mods and profile retained");
            string old = Seed("upgrade", InstallEngine.Id); var upgrade = InstallEngine.Install(payload, old);
            Check(upgrade.Backup != null && upgrade.Backup.StartsWith(Path.Combine(old, "ModSettingsFoldersBackups")), "backup outside mods");
            Check(File.ReadAllText(Path.Combine(upgrade.Backup, "legacy.txt")) == "previous files" && !File.Exists(Path.Combine(upgrade.Target, "legacy.txt")), "old files retained only in backup");
            InstallEngine.Verify(payload, upgrade.Target);
            foreach (string point in new[] {"staged", "old-moved", "new-moved"}) {
                string root = Seed("rollback-" + point, InstallEngine.Id);
                Reject(delegate { InstallEngine.Install(payload, root, delegate(string where) {if (where == point) throw new IOException("Injected failure");}); }, "rollback failure " + point);
                Check(File.ReadAllText(Path.Combine(root, "mods", InstallEngine.Id, "legacy.txt")) == "previous files", "previous version restored " + point);
                Check(Directory.GetDirectories(root, ".ModSettingsFolders-stage-*").Length == 0, "staging cleanup " + point);
            }
            string unknown = Seed("unknown", "AnotherMod");
            Reject(delegate { InstallEngine.Install(payload, unknown); }, "foreign mod protected");
            Check(File.ReadAllText(Path.Combine(unknown, "mods", InstallEngine.Id, "legacy.txt")) == "previous files", "foreign files unchanged");
            string locked = Area("locked"); Directory.CreateDirectory(locked);
            using (var installLock = new FileStream(Path.Combine(locked, ".ModSettingsFolders-install.lock"), FileMode.Create, FileAccess.ReadWrite, FileShare.None))
                Reject(delegate {InstallEngine.Install(payload, locked);}, "concurrent install rejected");
            Check(!Directory.Exists(Path.Combine(locked, "mods")), "locked install has no payload writes");
            string blocked = Area("file-collision"); Directory.CreateDirectory(blocked); File.WriteAllText(Path.Combine(blocked, "mods"), "preserve");
            Reject(delegate {InstallEngine.Install(payload, blocked);}, "file directory collision rejected");
            Check(File.ReadAllText(Path.Combine(blocked, "mods")) == "preserve", "collision file preserved");
            string unicode = Area("Каталог с пробелами"); InstallEngine.Verify(payload, InstallEngine.Install(payload, unicode).Target); checks++;
            Reject(delegate {InstallEngine.Root(Path.GetPathRoot(workspace));}, "drive root rejected");
            Reject(delegate {InstallEngine.Root(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile));}, "profile root rejected");
            Reject(delegate {InstallEngine.Root("\\\\" + "server\\share\\Zomboid");}, "network root rejected");
            string gameDir = Area("game-directory"); Directory.CreateDirectory(gameDir); File.WriteAllText(Path.Combine(gameDir, "projectzomboid.jar"), "placeholder");
            Reject(delegate {InstallEngine.Root(gameDir);}, "game install directory rejected");
            Check(!Directory.Exists(Path.Combine(gameDir, "mods")), "game directory unchanged");
            BadPayload("ModSettingsFolders/../escape.txt", "x", null, false);
            BadPayload("ModSettingsFolders/42/mod.info", "id=AnotherMod\n", null, false);
            BadPayload("ModSettingsFolders/42/mod.info", "id=ModSettingsFolders\n", null, true);
            BadPayload("ModSettingsFolders/42/mod.info", "id=ModSettingsFolders\n", new string('0',64) + "|" + Encoding.UTF8.GetByteCount("id=ModSettingsFolders\n") + "|ModSettingsFolders/42/mod.info\n", false);
            BadPayload("ModSettingsFolders/42/CON.txt", "x", null, false);
            Console.WriteLine("PASS " + checks + " installer checks; isolated filesystem only; GUI and live game untested"); return 0;
        } catch (Exception error) {Console.Error.WriteLine(error.ToString()); return 1;}
    }
}
