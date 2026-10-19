using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Mod Settings Folders Setup")]
[assembly: AssemblyCompany("i218")]
internal static class Setup {
    internal static string Version { get { return Assembly.GetExecutingAssembly().GetName().Version.ToString(3); } }
    internal static void CheckGameClosed() {
        foreach (string name in new[] {"ProjectZomboid64", "ProjectZomboid32", "ProjectZomboid"})
            foreach (var process in Process.GetProcessesByName(name)) { process.Dispose(); throw new IOException("Close Project Zomboid before installation."); }
    }
    [STAThread] private static int Main(string[] args) {
        try {
            if (args.Length == 1 && args[0] == "--verify-payload") { var payload = Payload.Embedded(); Console.WriteLine("PASS embedded payload: " + payload.Files.Count + " files"); return 0; }
            if (args.Length == 2 && args[0] == "--install") {
                var payload = Payload.Embedded(); CheckGameClosed(); var result = InstallEngine.Install(payload, args[1]);
                Console.WriteLine(result.AlreadyCurrent ? "Already current; checksums verified." : "Installation verified."); return 0;
            }
            if (args.Length != 0) throw new IOException("Usage: --verify-payload or --install <Zomboid user directory>");
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false); Application.Run(new InstallForm()); return 0;
        } catch (Exception error) {
            if (args.Length == 0) MessageBox.Show(error.Message, "Mod Settings Folders", MessageBoxButtons.OK, MessageBoxIcon.Error);
            else Console.Error.WriteLine(error.Message);
            return 1;
        }
    }
}

internal sealed class InstallForm : Form {
    private readonly TextBox directory = new TextBox();
    private readonly Label status = new Label();
    private readonly Button install = new Button();
    private readonly Button browse = new Button();
    internal InstallForm() {
        Text = "Mod Settings Folders — " + Setup.Version;
        Font = new Font("Segoe UI", 10); AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(630, 320); FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false; StartPosition = FormStartPosition.CenterScreen;
        var title = new Label {Text = "Установка Mod Settings Folders", Left = 20, Top = 18, Width = 590, Height = 28, Font = new Font(Font, FontStyle.Bold)};
        var hint = new Label {Text = "Закройте игру. Выберите пользовательский каталог Zomboid.\nДля -cachedir укажите ваш каталог, а не папку установки игры.", Left = 20, Top = 57, Width = 590, Height = 50};
        directory.SetBounds(20, 118, 470, 28);
        directory.Text = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Zomboid");
        browse.Text = "Обзор…"; browse.SetBounds(502, 117, 108, 30);
        browse.Click += delegate {
            using (var dialog = new FolderBrowserDialog {Description = "Пользовательский каталог Zomboid (или папка mods)", SelectedPath = directory.Text})
                if (dialog.ShowDialog(this) == DialogResult.OK) directory.Text = dialog.SelectedPath;
        };
        var note = new Label {Text = "Прежняя версия сохраняется в ModSettingsFoldersBackups.\nНастройки, сохранения и список включённых модов не изменяются.", Left = 20, Top = 164, Width = 590, Height = 45};
        status.SetBounds(20, 216, 590, 40); status.Text = "Без скачивания файлов. Права администратора не нужны.";
        install.Text = "Установить"; install.SetBounds(350, 270, 125, 32);
        var close = new Button {Text = "Закрыть", Left = 485, Top = 270, Width = 125, Height = 32}; close.Click += delegate {Close();};
        install.Click += delegate {
            install.Enabled = browse.Enabled = directory.Enabled = close.Enabled = false; UseWaitCursor = true;
            try {
                var payload = Payload.Embedded(); Setup.CheckGameClosed(); var result = InstallEngine.Install(payload, directory.Text);
                status.Text = result.AlreadyCurrent ? "Эта версия уже установлена. Файлы проверены." : "Установлено. Файлы проверены.";
                MessageBox.Show(this, "Готово: " + result.Target + (result.Backup == null ? "" : "\nРезервная копия: " + result.Backup) +
                    "\n\nВключите Mod Settings Folders в игре и перезапустите её.", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
            } catch (Exception error) { status.Text = "Установка не завершена."; MessageBox.Show(this, error.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error); }
            finally {install.Enabled = browse.Enabled = directory.Enabled = close.Enabled = true; UseWaitCursor = false;}
        };
        Controls.AddRange(new Control[] {title, hint, directory, browse, note, status, install, close}); AcceptButton = install; CancelButton = close;
    }
}
