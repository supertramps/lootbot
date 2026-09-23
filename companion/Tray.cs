using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

public class LootBotWindow : Form {
    readonly string root = AppDomain.CurrentDomain.BaseDirectory;
    readonly NotifyIcon tray = new NotifyIcon();
    readonly TextBox log = new TextBox();
    readonly Label status = new Label();
    readonly CheckBox all = new CheckBox();
    readonly ComboBox mode = new ComboBox();
    readonly Button start = new Button();
    Process helper;
    bool exiting;

    public LootBotWindow() {
        Text="LootBot — Guild relay"; ClientSize=new Size(660,440); MinimumSize=new Size(676,478);
        StartPosition=FormStartPosition.CenterScreen; Font=new Font("Segoe UI",10);
        var info=new Label { Text="Friends need only the addon. On your relay character: /lootbot relay on\nStart this app before logging in, or use /lootbot sync to replay saved events.",
            Location=new Point(16,16),Size=new Size(625,50) };
        Controls.Add(info);
        mode.DropDownStyle=ComboBoxStyle.DropDownList; mode.Items.AddRange(new object[]{"Preview — no Discord posts","Live — post to Discord"});
        mode.SelectedIndex=0; mode.Location=new Point(16,78); mode.Width=295; Controls.Add(mode);
        all.Text="All loot for testing"; all.Checked=true; all.Location=new Point(330,78); all.Width=200; Controls.Add(all);
        start.Text="Start relay"; start.Location=new Point(16,118); start.Width=125; start.Height=34; start.Click+=(s,e)=>StartHelper(); Controls.Add(start);
        var stop=new Button { Text="Stop",Location=new Point(151,118),Size=new Size(85,34) }; stop.Click+=(s,e)=>StopHelper(); Controls.Add(stop);
        var configure=new Button { Text=File.Exists(Path.Combine(root,"cloud-config.json"))?"Relay registration":"Configure Discord",Location=new Point(246,118),Size=new Size(160,34) }; configure.Click+=(s,e)=>{if(File.Exists(Path.Combine(root,"cloud-config.json")))RegisterRelay();else Configure();}; Controls.Add(configure);
        var hide=new Button { Text="Hide to tray",Location=new Point(416,118),Size=new Size(125,34) }; hide.Click+=(s,e)=>Hide(); Controls.Add(hide);
        var options=new Button {Text="Tools",Location=new Point(550,118),Size=new Size(94,34)};options.Click+=(s,e)=>{if(!File.Exists(Path.Combine(root,"cloud-config.json"))){MessageBox.Show(this,"Connect this installation to the shared service first.");return;}using(var w=new ToolsWindow())w.ShowDialog(this);};Controls.Add(options);
        if(File.Exists(Path.Combine(root,"cloud-config.json"))){all.Checked=false;all.Enabled=false;all.Text="Filters: use Tools";}
        status.Text="Stopped. Choose Preview or Live, then Start relay."; status.Location=new Point(16,164); status.Size=new Size(625,40); Controls.Add(status);
        log.Multiline=true; log.ReadOnly=true; log.ScrollBars=ScrollBars.Vertical; log.Location=new Point(16,210); log.Size=new Size(628,210);
        log.Anchor=AnchorStyles.Top|AnchorStyles.Bottom|AnchorStyles.Left|AnchorStyles.Right; log.Font=new Font("Consolas",9); Controls.Add(log);
        var menu=new ContextMenuStrip(); menu.Items.Add("Open LootBot",null,(s,e)=>{Show();Activate();});
        menu.Items.Add("Stop relay",null,(s,e)=>StopHelper()); menu.Items.Add("Exit",null,(s,e)=>{exiting=true;Close();});
        tray.Icon=SystemIcons.Information; tray.Text="LootBot — stopped"; tray.Visible=true; tray.ContextMenuStrip=menu;
        tray.DoubleClick+=(s,e)=>{Show();Activate();};
        FormClosing+=(s,e)=>{ if(!exiting && e.CloseReason==CloseReason.UserClosing) {e.Cancel=true;Hide();} else {StopHelper();tray.Dispose();} };
    }
    void Append(string text) {
        if(text==null || IsDisposed) return;
        if(InvokeRequired) { try {BeginInvoke(new Action<string>(Append),text);} catch(InvalidOperationException){} return; }
        if(log.TextLength>80000) log.Text=log.Text.Substring(log.TextLength-40000);
        log.AppendText(text+Environment.NewLine);
        if(text.Length>0 && !text.StartsWith(" ") && !text.StartsWith("{") && !text.StartsWith("}")) status.Text=text;
        try {
            string dir=Path.Combine(root,"state"); Directory.CreateDirectory(dir);
            string file=Path.Combine(dir,"helper.log");
            if(File.Exists(file) && new FileInfo(file).Length>2000000) File.WriteAllText(file,"");
            File.AppendAllText(file,DateTime.Now.ToString("s")+" "+text+Environment.NewLine);
        } catch(IOException) {} catch(UnauthorizedAccessException) {}
    }
    void StartHelper() {
        if(helper!=null && !helper.HasExited) {Append("Already running. Stop before changing mode.");return;}
        bool live=mode.SelectedIndex==1;
        if(live && !File.Exists(Path.Combine(root,"cloud-config.json")) && !File.Exists(Path.Combine(root,"webhook.dpapi"))) {Configure(); if(!File.Exists(Path.Combine(root,"webhook.dpapi")))return;}
        string node=Path.Combine(root,"runtime","node.exe");
        if(!File.Exists(node)) node="node.exe";
        var psi=new ProcessStartInfo(node, "\""+Path.Combine(root,"companion","main.js")+"\""+(live?" --send":"")+(all.Checked?" --all":""));
        psi.WorkingDirectory=root; psi.UseShellExecute=false; psi.CreateNoWindow=true;
        psi.RedirectStandardOutput=true;psi.RedirectStandardError=true;psi.RedirectStandardInput=true;
        psi.StandardOutputEncoding=Encoding.UTF8;psi.StandardErrorEncoding=Encoding.UTF8;
        helper=new Process {StartInfo=psi,EnableRaisingEvents=true};
        helper.OutputDataReceived+=(s,e)=>Append(e.Data);helper.ErrorDataReceived+=(s,e)=>Append(e.Data);
        helper.Exited+=(s,e)=>{
            Append("Relay helper stopped. You can review the log above.");
            try {BeginInvoke(new Action(()=>{start.Enabled=true;mode.Enabled=true;all.Enabled=!File.Exists(Path.Combine(root,"cloud-config.json"));tray.Text="LootBot — stopped";}));}
            catch(InvalidOperationException){}
        };
        try {
            helper.Start();helper.BeginOutputReadLine();helper.BeginErrorReadLine();
            tray.Text=live?"LootBot — live relay":"LootBot — preview";start.Enabled=false;mode.Enabled=false;all.Enabled=false;
        } catch(Exception) {Append("Could not start Node.js. Install Node.js LTS and reopen LootBot."); helper=null;}
    }
    void StopHelper() {
        if(helper!=null) {
            try {
                if(!helper.HasExited) {helper.StandardInput.WriteLine("stop");helper.StandardInput.Flush(); if(!helper.WaitForExit(12000)) helper.Kill();}
            } catch(InvalidOperationException) {} catch(IOException) {}
            helper.Dispose();helper=null;
        }
        start.Enabled=true;mode.Enabled=true;all.Enabled=!File.Exists(Path.Combine(root,"cloud-config.json"));tray.Text="LootBot — stopped";status.Text="Stopped.";
    }
    public static void SaveWebhook(string path,string url) {
        if(!Regex.IsMatch(url,@"\Ahttps://discord\.com/api(?:/v\d+)?/webhooks/\d+/[A-Za-z0-9_-]+\z")) throw new ArgumentException("Invalid webhook URL");
        byte[] secret=Encoding.Unicode.GetBytes(url);
        try { File.WriteAllText(path,BitConverter.ToString(ProtectedData.Protect(secret,null,DataProtectionScope.CurrentUser)).Replace("-",""),Encoding.ASCII); }
        finally {Array.Clear(secret,0,secret.Length);}
    }
    void RegisterRelay() {
        try {
            var psi=new ProcessStartInfo(Path.Combine(root,"runtime","node.exe"),"\""+Path.Combine(root,"companion","cloud.js")+"\" --enroll");
            psi.WorkingDirectory=root;psi.UseShellExecute=false;psi.CreateNoWindow=true;psi.RedirectStandardOutput=true;psi.RedirectStandardError=true;
            using(var p=Process.Start(psi)){p.StandardOutput.ReadToEnd();p.StandardError.ReadToEnd();p.WaitForExit();if(p.ExitCode!=0)throw new Exception();}
            using(var dialog=new Form {Text="Register this relay",ClientSize=new Size(600,360),StartPosition=FormStartPosition.CenterParent}) {
                var info=new Label {Text="Send this public registration to your guild's LootBot administrator.\nThey must approve this relay before it can submit events. This is not a password.",Location=new Point(12,12),Size=new Size(575,48)};
                var field=new TextBox {Multiline=true,ReadOnly=true,ScrollBars=ScrollBars.Vertical,Location=new Point(12,70),Size=new Size(575,225),Text=File.ReadAllText(Path.Combine(root,"relay-registration.json"))};
                var copy=new Button {Text="Copy registration",Location=new Point(12,310),Size=new Size(170,32)};copy.Click+=(s,e)=>Clipboard.SetText(field.Text);
                dialog.Controls.Add(info);dialog.Controls.Add(field);dialog.Controls.Add(copy);dialog.ShowDialog(this);
            }
        }catch{MessageBox.Show(this,"Could not create the relay identity. Check the runtime and folder permissions.");}
    }
    void Configure() {
        using(var dialog=new Form { Text="Discord webhook",ClientSize=new Size(550,160),StartPosition=FormStartPosition.CenterParent,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,MinimizeBox=false }) {
            var label=new Label {Text="Paste your channel's webhook URL. It is encrypted for this Windows user.\nSaving does not send a Discord message.",Location=new Point(14,12),Size=new Size(525,40)};
            var field=new TextBox {UseSystemPasswordChar=true,Location=new Point(14,62),Width=520};
            var save=new Button {Text="Save",Location=new Point(434,106),Size=new Size(100,32)};
            save.Click+=(s,e)=>{try {SaveWebhook(Path.Combine(root,"webhook.dpapi"),field.Text.Trim());field.Clear();dialog.DialogResult=DialogResult.OK;dialog.Close();}catch(Exception){MessageBox.Show(dialog,"Could not save. Check the Discord webhook URL and folder permissions.");}};
            dialog.Controls.Add(label);dialog.Controls.Add(field);dialog.Controls.Add(save);dialog.AcceptButton=save;dialog.ShowDialog(this);
        }
    }
    [STAThread] public static int Main(string[] args) {
        if(args.Length==2 && args[0]=="--test-save") {SaveWebhook(args[1],"https://discord.com/api/webhooks/123/LootBotSyntheticTestOnly");return 0;}
        bool created;
        using(var mutex=new Mutex(true,"Local\\LootBotTray",out created)) {
            if(!created) {MessageBox.Show("LootBot is already running. Open it from the system tray.");return 1;}
            Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new LootBotWindow());
        }
        return 0;
    }
}
