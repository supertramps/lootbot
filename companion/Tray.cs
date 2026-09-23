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
    readonly string root = Path.GetDirectoryName(typeof(LootBotWindow).Assembly.Location);
    readonly NotifyIcon tray = new NotifyIcon();
    readonly TextBox log = new TextBox();
    readonly Label status = new Label();
    readonly Label state = new Label();
    readonly CheckBox all = new CheckBox();
    readonly ComboBox mode = new ComboBox();
    readonly Button start = new Button();
    Process helper;
    bool exiting;

    public LootBotWindow() {
        Text="LootBot — Guild relay";ClientSize=new Size(820,630);MinimumSize=new Size(836,668);
        StartPosition=FormStartPosition.CenterScreen;FormBorderStyle=FormBorderStyle.FixedSingle;MaximizeBox=false;
        UiTheme.Form(this);
        UiTheme.Label(this,"LOOTBOT  /  GUILD RELAY",22,17,480,22,true,UiTheme.Green,9);
        UiTheme.Label(this,"Keep the guild in the loop",22,42,570,40,true,UiTheme.Ink,22);
        UiTheme.Label(this,"Friends only need the addon. This window is for relay volunteers.",23,87,710,23);
        state.Text="STOPPED";state.Location=new Point(681,29);state.Size=new Size(113,30);
        state.TextAlign=ContentAlignment.MiddleCenter;state.BackColor=UiTheme.Canvas;
        state.ForeColor=UiTheme.Muted;state.Font=new Font("Segoe UI",9,FontStyle.Bold);
        Controls.Add(state);

        var session=UiTheme.Card(this,20,122,780,170);
        UiTheme.Label(session,"SESSION",20,15,200,20,true,UiTheme.Green,9);
        UiTheme.Label(session,"Choose how this relay runs",20,37,480,27,true,UiTheme.Ink,13);
        UiTheme.Label(session,"MODE",20,77,100,20,true,UiTheme.Muted,8.5f);
        UiTheme.Field(mode,20,99,282);mode.Items.AddRange(new object[]{"Preview — no Discord posts","Live — post to Discord"});
        mode.SelectedIndex=0;session.Controls.Add(mode);
        UiTheme.Button(start,"Start relay",320,96,142,38,true);start.Click+=(s,e)=>StartHelper();session.Controls.Add(start);
        var stop=UiTheme.Button(session,"Stop",472,96,88,38,()=>StopHelper());
        all.Text="All loot (local test)";all.Checked=true;all.Location=new Point(584,102);all.Size=new Size(176,27);
        all.ForeColor=UiTheme.Muted;session.Controls.Add(all);
        if(File.Exists(Path.Combine(root,"cloud-config.json"))){
            all.Checked=false;all.Enabled=false;all.Visible=false;
            UiTheme.Label(session,"Shared service mode",584,103,176,24,false,UiTheme.Muted,9);
        }
        UiTheme.Label(session,"In WoW: /lootbot relay on   ·   Started after login? Use /lootbot sync.",20,140,730,21,false,UiTheme.Muted,9);

        var setup=UiTheme.Card(this,20,306,780,103);
        UiTheme.Label(setup,"SETUP & TOOLS",20,14,230,20,true,UiTheme.Green,9);
        UiTheme.Label(setup,"Registration, test messages and shared settings",20,36,710,22);
        UiTheme.Button(setup,File.Exists(Path.Combine(root,"cloud-config.json"))?"Relay registration":"Configure Discord",20,64,176,31,
            ()=>{if(File.Exists(Path.Combine(root,"cloud-config.json")))RegisterRelay();else Configure();});
        UiTheme.Button(setup,"Open tools",208,64,132,31,()=>{
            if(!File.Exists(Path.Combine(root,"cloud-config.json"))){MessageBox.Show(this,"Connect this installation to the shared service first.");return;}
            using(var w=new ToolsWindow())w.ShowDialog(this);
        });
        UiTheme.Button(setup,"Hide to tray",352,64,128,31,()=>Hide());

        var activity=UiTheme.Card(this,20,423,780,163);
        UiTheme.Label(activity,"ACTIVITY",20,13,170,22,true,UiTheme.Green,9);
        UiTheme.Label(activity,"What the relay is doing",20,34,530,22);
        log.Multiline=true;log.ReadOnly=true;log.ScrollBars=ScrollBars.Vertical;
        log.Location=new Point(20,65);log.Size=new Size(740,80);log.BackColor=UiTheme.Canvas;
        log.ForeColor=UiTheme.Ink;log.BorderStyle=BorderStyle.None;log.Font=new Font("Consolas",9);
        activity.Controls.Add(log);
        status.Text="Stopped. Choose Preview or Live, then start the relay.";
        status.Location=new Point(23,596);status.Size=new Size(760,23);status.ForeColor=UiTheme.Muted;
        status.Font=new Font("Segoe UI",9);Controls.Add(status);
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
            try {BeginInvoke(new Action(()=>{start.Enabled=true;mode.Enabled=true;all.Enabled=!File.Exists(Path.Combine(root,"cloud-config.json"));state.Text="STOPPED";state.ForeColor=UiTheme.Muted;tray.Text="LootBot — stopped";}));}
            catch(InvalidOperationException){}
        };
        try {
            helper.Start();helper.BeginOutputReadLine();helper.BeginErrorReadLine();
            tray.Text=live?"LootBot — live relay":"LootBot — preview";start.Enabled=false;mode.Enabled=false;all.Enabled=false;
            state.Text=live?"LIVE":"PREVIEW";state.ForeColor=UiTheme.Green;
        } catch(Exception) {Append("Could not start Node.js. Install Node.js LTS and reopen LootBot."); helper=null;}
    }
    void StopHelper() {
        if(helper!=null) {
            try {
                if(!helper.HasExited) {helper.StandardInput.WriteLine("stop");helper.StandardInput.Flush(); if(!helper.WaitForExit(12000)) helper.Kill();}
            } catch(InvalidOperationException) {} catch(IOException) {}
            helper.Dispose();helper=null;
        }
        start.Enabled=true;mode.Enabled=true;all.Enabled=!File.Exists(Path.Combine(root,"cloud-config.json"));tray.Text="LootBot — stopped";status.Text="Stopped.";state.Text="STOPPED";state.ForeColor=UiTheme.Muted;
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
            using(var dialog=new Form {Text="LootBot — Relay registration",ClientSize=new Size(620,390),StartPosition=FormStartPosition.CenterParent,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false}) {
                UiTheme.Form(dialog);
                UiTheme.Label(dialog,"RELAY REGISTRATION",20,18,380,20,true,UiTheme.Green,9);
                UiTheme.Label(dialog,"Share this code with the guild administrator",20,44,580,31,true,UiTheme.Ink,15);
                UiTheme.Label(dialog,"They must approve this relay before it can send events. This code is public.",20,82,580,27);
                var field=new TextBox {Multiline=true,ReadOnly=true,ScrollBars=ScrollBars.Vertical,Text=File.ReadAllText(Path.Combine(root,"relay-registration.json"))};
                UiTheme.Field(field,20,124,580,195);field.BackColor=UiTheme.Surface;field.Font=new Font("Consolas",9);dialog.Controls.Add(field);
                UiTheme.Button(dialog,"Copy registration",20,335,190,36,()=>Clipboard.SetText(field.Text),true);
                dialog.ShowDialog(this);
            }
        }catch{MessageBox.Show(this,"Could not create the relay identity. Check the runtime and folder permissions.");}
    }
    void Configure() {
        using(var dialog=new Form { Text="LootBot — Discord webhook",ClientSize=new Size(560,235),StartPosition=FormStartPosition.CenterParent,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,MinimizeBox=false }) {
            UiTheme.Form(dialog);
            UiTheme.Label(dialog,"DISCORD CONNECTION",20,17,340,20,true,UiTheme.Green,9);
            UiTheme.Label(dialog,"Connect a Discord channel",20,43,520,34,true,UiTheme.Ink,16);
            UiTheme.Label(dialog,"Paste the channel webhook URL. It stays encrypted on this Windows account.",20,83,520,28);
            var field=new TextBox {UseSystemPasswordChar=true};UiTheme.Field(field,20,122,520);dialog.Controls.Add(field);
            UiTheme.Label(dialog,"Saving does not send a message.",20,166,340,22);
            var save=new Button();UiTheme.Button(save,"Save",440,169,100,36,true);
            save.Click+=(s,e)=>{try {SaveWebhook(Path.Combine(root,"webhook.dpapi"),field.Text.Trim());field.Clear();dialog.DialogResult=DialogResult.OK;dialog.Close();}catch(Exception){MessageBox.Show(dialog,"Could not save. Check the Discord webhook URL and folder permissions.");}};
            dialog.Controls.Add(save);dialog.AcceptButton=save;dialog.ShowDialog(this);
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
