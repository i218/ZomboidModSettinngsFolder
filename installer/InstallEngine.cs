using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

internal sealed class Payload {
    internal readonly Dictionary<string, byte[]> Files = new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase);
    internal static Payload Embedded() {
        var assembly = Assembly.GetExecutingAssembly();
        using (var zip = assembly.GetManifestResourceStream("payload.zip"))
        using (var manifest = assembly.GetManifestResourceStream("payload.manifest")) return Read(zip, manifest);
    }
    internal static string Hash(byte[] bytes) {
        using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant();
    }
    internal static Payload Read(Stream zip, Stream manifest) {
        if (zip == null || manifest == null) throw new IOException("Missing embedded payload.");
        var expected = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
        using (var reader = new StreamReader(manifest, new UTF8Encoding(false, true))) {
            string line;
            while ((line = reader.ReadLine()) != null) {
                var fields = line.Split('|');
                long length;
                if (fields.Length != 3 || !Regex.IsMatch(fields[0], "^[a-f0-9]{64}$") ||
                    !long.TryParse(fields[1], out length) || length < 0 || length > 8388608 || expected.ContainsKey(fields[2]))
                    throw new IOException("Invalid payload manifest.");
                CheckName(fields[2]); expected.Add(fields[2], fields);
                if (expected.Count > 2000) throw new IOException("Payload file limit exceeded.");
            }
        }
        var result = new Payload(); long total = 0;
        using (var archive = new ZipArchive(zip, ZipArchiveMode.Read)) {
            foreach (var entry in archive.Entries) {
                CheckName(entry.FullName);
                string[] fields;
                if (!expected.TryGetValue(entry.FullName, out fields) || entry.Length != long.Parse(fields[1]))
                    throw new IOException("Unexpected payload entry.");
                total += entry.Length;
                if (total > 33554432) throw new IOException("Payload size limit exceeded.");
                string relative = entry.FullName.Substring("ModSettingsFolders/".Length);
                if (result.Files.ContainsKey(relative)) throw new IOException("Duplicate payload entry.");
                byte[] bytes;
                using (var stream = entry.Open()) using (var output = new MemoryStream()) {
                    var buffer = new byte[8192]; int count;
                    while ((count = stream.Read(buffer, 0, buffer.Length)) > 0) {
                        if (output.Length + count > entry.Length) throw new IOException("Payload length mismatch.");
                        output.Write(buffer, 0, count);
                    }
                    bytes = output.ToArray();
                }
                if (bytes.LongLength != entry.Length || Hash(bytes) != fields[0]) throw new IOException("Payload checksum mismatch.");
                result.Files.Add(relative, bytes);
            }
        }
        if (result.Files.Count != expected.Count || !result.Files.ContainsKey("42/mod.info")) throw new IOException("Incomplete payload.");
        if (!InstallEngine.HasIdentity(Encoding.UTF8.GetString(result.Files["42/mod.info"]))) throw new IOException("Wrong mod identity.");
        return result;
    }
    private static void CheckName(string name) {
        if (!name.StartsWith("ModSettingsFolders/", StringComparison.Ordinal) || name.IndexOfAny(new[] {'\\', ':', '|', '\0'}) >= 0)
            throw new IOException("Unsafe payload path.");
        foreach (string part in name.Split('/')) {
            if (part.Length == 0 || part == "." || part == ".." || part.EndsWith(".") || part.EndsWith(" ") ||
                part.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 || Regex.IsMatch(part, @"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)", RegexOptions.IgnoreCase))
                throw new IOException("Unsafe payload path segment.");
        }
    }
}

internal sealed class InstallResult {
    internal string Target;
    internal string Backup;
    internal bool AlreadyCurrent;
}

internal static class InstallEngine {
    internal const string Id = "ModSettingsFolders";
    internal static bool HasIdentity(string text) {
        var ids = Regex.Matches(text, @"(?m)^id=([^\r\n]*)\r?$");
        return ids.Count == 1 && ids[0].Groups[1].Value == Id;
    }
    internal static string Root(string input) {
        if (string.IsNullOrWhiteSpace(input)) throw new IOException("Choose a Zomboid user directory.");
        string root = Path.GetFullPath(Environment.ExpandEnvironmentVariables(input.Trim())).TrimEnd('\\', '/');
        if (string.Equals(Path.GetFileName(root), "mods", StringComparison.OrdinalIgnoreCase)) root = Path.GetDirectoryName(root);
        if (!Regex.IsMatch(root, @"^[A-Za-z]:\\") || root.Length <= 3 ||
            string.Equals(root, Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), StringComparison.OrdinalIgnoreCase) ||
            string.Equals(root, Environment.GetFolderPath(Environment.SpecialFolder.Windows), StringComparison.OrdinalIgnoreCase))
            throw new IOException("Choose a local Zomboid user directory, not a drive, profile or Windows root.");
        NoLinks(root);
        if (File.Exists(Path.Combine(root, "projectzomboid.jar")) || File.Exists(Path.Combine(root, "ProjectZomboid64.exe")))
            throw new IOException("Choose the user directory, not the game installation directory.");
        return root;
    }
    private static void Child(string root, string path) {
        if (!Path.GetFullPath(path).StartsWith(Path.GetFullPath(root).TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase))
            throw new IOException("Path escapes the selected directory.");
    }
    private static void NoLinks(string path) {
        for (string current = Path.GetFullPath(path); !string.IsNullOrEmpty(current); current = Path.GetDirectoryName(current)) {
            if ((File.Exists(current) || Directory.Exists(current)) && (File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("Junctions and symbolic links are not supported for installation paths.");
        }
    }
    private static void Tree(string path) {
        NoLinks(path);
        if (!Directory.Exists(path)) return;
        var pending = new Stack<string>(); pending.Push(path); int count = 0;
        while (pending.Count > 0) foreach (string entry in Directory.GetFileSystemEntries(pending.Pop())) {
            if (++count > 20000) throw new IOException("Existing mod tree is unexpectedly large.");
            var attributes = File.GetAttributes(entry);
            if ((attributes & FileAttributes.ReparsePoint) != 0) throw new IOException("Linked files in the mod directory are not supported.");
            if ((attributes & FileAttributes.Directory) != 0) pending.Push(entry);
        }
    }
    internal static void Verify(Payload payload, string target) {
        Tree(target);
        if (!Directory.Exists(target) || Directory.GetFiles(target, "*", SearchOption.AllDirectories).Length != payload.Files.Count)
            throw new IOException("Installed file inventory mismatch.");
        foreach (var entry in payload.Files) {
            string path = Path.Combine(target, entry.Key.Replace('/', Path.DirectorySeparatorChar)); Child(target, path); NoLinks(path);
            if (!File.Exists(path) || Payload.Hash(File.ReadAllBytes(path)) != Payload.Hash(entry.Value))
                throw new IOException("Installed file checksum mismatch.");
        }
    }
    internal static InstallResult Install(Payload payload, string input, Action<string> checkpoint = null) {
        string root = Root(input); Directory.CreateDirectory(root);
        string mods = Path.Combine(root, "mods"), target = Path.Combine(mods, Id);
        string stage = Path.Combine(root, ".ModSettingsFolders-stage-" + Guid.NewGuid().ToString("N"));
        string stagedMod = Path.Combine(stage, Id), backupRoot = Path.Combine(root, "ModSettingsFoldersBackups"), backup = null;
        string lockPath = Path.Combine(root, ".ModSettingsFolders-install.lock");
        Child(root, mods); Child(root, target); Child(root, stage); Child(root, backupRoot); Child(root, lockPath);
        NoLinks(lockPath); NoLinks(mods); NoLinks(target); NoLinks(backupRoot);
        using (var installLock = new FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None)) {
            if (File.Exists(mods) || File.Exists(target) || File.Exists(backupRoot)) throw new IOException("A file occupies an installation directory.");
            Tree(target);
            if (Directory.Exists(target)) {
                string identity = Path.Combine(target, "42", "mod.info"); NoLinks(identity);
                if (!File.Exists(identity) || !HasIdentity(File.ReadAllText(identity))) throw new IOException("The target contains a different or unidentified mod.");
                try { Verify(payload, target); return new InstallResult {Target = target, AlreadyCurrent = true}; }
                catch (IOException) { /* A recognized previous version needs replacement. */ }
            }
            bool oldMoved = false, newMoved = false;
            try {
                Directory.CreateDirectory(stagedMod);
                foreach (var entry in payload.Files) {
                    string path = Path.Combine(stagedMod, entry.Key.Replace('/', Path.DirectorySeparatorChar)); Child(stagedMod, path); NoLinks(path);
                    Directory.CreateDirectory(Path.GetDirectoryName(path)); File.WriteAllBytes(path, entry.Value);
                }
                Verify(payload, stagedMod);
                if (checkpoint != null) checkpoint("staged");
                Directory.CreateDirectory(mods); NoLinks(mods); Tree(target);
                if (Directory.Exists(target)) {
                    Directory.CreateDirectory(backupRoot); NoLinks(backupRoot);
                    backup = Path.Combine(backupRoot, DateTime.UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N"));
                    Child(backupRoot, backup); Directory.Move(target, backup); oldMoved = true;
                }
                if (checkpoint != null) checkpoint("old-moved");
                NoLinks(target); Directory.Move(stagedMod, target); newMoved = true;
                if (checkpoint != null) checkpoint("new-moved");
                Verify(payload, target);
                return new InstallResult {Target = target, Backup = backup};
            } catch {
                try {
                    if (newMoved) { Child(root, target); Tree(target); Directory.Move(target, Path.Combine(stage, "failed-install")); }
                    if (oldMoved) { NoLinks(target); Tree(backup); Directory.Move(backup, target); }
                } catch (Exception rollback) {
                    throw new IOException("Installation failed and automatic rollback could not complete. Previous files remain in ModSettingsFoldersBackups. " + rollback.Message);
                }
                throw;
            } finally {
                // Recursive cleanup is limited to our unique staging child, never mods/backups.
                Child(root, stage);
                if (Directory.Exists(stage)) { Tree(stage); Directory.Delete(stage, true); }
            }
        }
    }
}
