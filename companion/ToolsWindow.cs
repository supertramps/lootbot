using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

public class ToolsWindow : Form {
 readonly string root=Path.GetDirectoryName(typeof(ToolsWindow).Assembly.Location);
 readonly JavaScriptSerializer json=new JavaScriptSerializer();
 readonly TextBox preview=new TextBox(),block=new TextBox(),botName=new TextBox(),serviceOutput=new TextBox();
 readonly PictureBox icon=new PictureBox();
 readonly Label status=new Label();
 readonly ComboBox level=new ComboBox();
 readonly NumericUpDown item=new NumericUpDown();
 bool busy;
 string testId,testKind;int testValue;
 public ToolsWindow():this(false){}
 public ToolsWindow(bool previewOnly){
  Text="LootBot — Tools";ClientSize=new Size(900,670);StartPosition=FormStartPosition.CenterParent;
  FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;UiTheme.Form(this);
  UiTheme.Label(this,"LOOTBOT  /  TOOLS",21,14,470,20,true,UiTheme.Green,9);
  UiTheme.Label(this,"Tests and guild settings",21,38,700,39,true,UiTheme.Ink,21);
  UiTheme.Label(this,"Preview announcements, manage blocked items and approve relays.",22,78,820,23);
  var tabs=new TabControl{Location=new Point(18,111),Size=new Size(864,493),
   DrawMode=TabDrawMode.OwnerDrawFixed,SizeMode=TabSizeMode.Fixed,ItemSize=new Size(155,34)};
  tabs.DrawItem+=(s,e)=>{
   var selected=(e.State&DrawItemState.Selected)==DrawItemState.Selected;
   using(var background=new SolidBrush(selected?UiTheme.Surface:UiTheme.Canvas))e.Graphics.FillRectangle(background,e.Bounds);
   using(var brush=new SolidBrush(selected?UiTheme.Green:UiTheme.Muted))
   using(var font=new Font("Segoe UI",9.5f,selected?FontStyle.Bold:FontStyle.Regular))
    e.Graphics.DrawString(tabs.TabPages[e.Index].Text,font,brush,e.Bounds.X+12,e.Bounds.Y+8);
   if(selected)using(var accent=new SolidBrush(UiTheme.Green))e.Graphics.FillRectangle(accent,e.Bounds.X,e.Bounds.Bottom-3,e.Bounds.Width,3);
  };
  Controls.Add(tabs);
  var tests=new TabPage("Message tests"){BackColor=UiTheme.Canvas};
  var guild=new TabPage("Guild settings"){BackColor=UiTheme.Canvas};
  var relays=new TabPage("Relays & status"){BackColor=UiTheme.Canvas};
  tabs.TabPages.Add(tests);tabs.TabPages.Add(guild);tabs.TabPages.Add(relays);

  var testCard=UiTheme.Card(tests,14,15,821,213);
  UiTheme.Label(testCard,"TRY A MESSAGE",19,14,340,20,true,UiTheme.Green,9);
  UiTheme.Label(testCard,"Works while WoW is closed. Tests use the name LootTester.",19,38,750,23);
  UiTheme.Label(testCard,"ITEM ID",19,75,145,20,true,UiTheme.Muted,8.5f);
  item.Minimum=1;item.Maximum=10000000;item.Value=19019;item.Location=new Point(19,99);item.Width=145;testCard.Controls.Add(item);
  TestButton(testCard,"Preview item",184,95,135,()=>Action("preview-item",(int)item.Value));
  TestButton(testCard,"Send item test",331,95,150,()=>Action("test-item",(int)item.Value),true);
  UiTheme.Label(testCard,"LEVEL",19,145,145,20,true,UiTheme.Muted,8.5f);
  UiTheme.Field(level,19,167,145);for(int i=10;i<=60;i+=10)level.Items.Add(i);level.SelectedIndex=0;testCard.Controls.Add(level);
  TestButton(testCard,"Preview level",184,163,135,()=>Action("preview-level",(int)level.SelectedItem));
  TestButton(testCard,"Send level test",331,163,150,()=>Action("test-level",(int)level.SelectedItem),true);
  TestButton(testCard,"Preview catch-up",511,95,145,()=>Action("preview-digest",0));
  TestButton(testCard,"Send catch-up",668,95,135,()=>Action("test-digest",0),true);
  var previewCard=UiTheme.Card(tests,14,239,821,199);
  UiTheme.Label(previewCard,"MESSAGE PREVIEW",19,13,260,20,true,UiTheme.Green,9);
  preview.Multiline=true;preview.ReadOnly=true;preview.ScrollBars=ScrollBars.Vertical;
  UiTheme.Field(preview,19,42,679,140);preview.BackColor=UiTheme.Canvas;
  preview.Font=new Font("Segoe UI",10);previewCard.Controls.Add(preview);
  icon.Location=new Point(722,53);icon.Size=new Size(76,76);icon.SizeMode=PictureBoxSizeMode.Zoom;previewCard.Controls.Add(icon);

  var settingsCard=UiTheme.Card(guild,14,15,821,423);
  UiTheme.Label(settingsCard,"GUILD SETTINGS",20,16,280,20,true,UiTheme.Green,9);
  UiTheme.Label(settingsCard,"Each character sets rarity in WoW",20,44,740,30,true,UiTheme.Ink,15);
  UiTheme.Label(settingsCard,"/lootbot filter rare   or   /lootbot filter epic",20,79,730,24);
  UiTheme.Label(settingsCard,"At level 40, that character stays on Epic. Grey, white and green never reach a relay.",20,107,770,42);
  UiTheme.Label(settingsCard,"BLOCKED ITEM IDS",20,165,700,20,true,UiTheme.Muted,8.5f);
  UiTheme.Field(block,20,190,772);settingsCard.Controls.Add(block);
  UiTheme.Label(settingsCard,"Separate IDs with commas. Blocked items will not be announced.",20,226,750,23);
  UiTheme.Label(settingsCard,"DISCORD NAME",20,269,480,20,true,UiTheme.Muted,8.5f);
  UiTheme.Field(botName,20,294,355);botName.MaxLength=80;settingsCard.Controls.Add(botName);
  UiTheme.AsyncButton(settingsCard,"Reload settings",20,362,152,36,LoadFilters);
  UiTheme.AsyncButton(settingsCard,"Save",185,362,116,36,SaveFilters,true);

  var relayCard=UiTheme.Card(relays,14,15,821,423);
  UiTheme.Label(relayCard,"RELAY MANAGEMENT",20,16,330,20,true,UiTheme.Green,9);
  UiTheme.Label(relayCard,"Approve a friend's relay or check the shared service.",20,45,750,30,true,UiTheme.Ink,14);
  UiTheme.Label(relayCard,"A relay only uploads events after an administrator approves its public registration.",20,81,770,43);
  UiTheme.AsyncButton(relayCard,"Add relay",20,137,130,36,AddRelay,true);
  UiTheme.AsyncButton(relayCard,"Service status",163,137,145,36,ServiceStatus);
  UiTheme.Label(relayCard,"SERVICE DETAILS",20,202,300,20,true,UiTheme.Muted,8.5f);
  serviceOutput.Multiline=true;serviceOutput.ReadOnly=true;serviceOutput.ScrollBars=ScrollBars.Vertical;
  UiTheme.Field(serviceOutput,20,228,772,173);serviceOutput.BackColor=UiTheme.Canvas;
  serviceOutput.Font=new Font("Consolas",9);relayCard.Controls.Add(serviceOutput);

  status.Text="Ready.";status.Location=new Point(21,617);status.Size=new Size(850,27);
  status.ForeColor=UiTheme.Muted;status.Font=new Font("Segoe UI",9);Controls.Add(status);
  if(!previewOnly)Shown+=async(s,e)=>await LoadFilters();
 }
 void TestButton(Control parent,string text,int x,int y,int width,Func<Task> action,bool primary=false){
  UiTheme.AsyncButton(parent,text,x,y,width,36,action,primary);
 }
 async Task<Dictionary<string,object>> Run(object request){
  if(busy)throw new Exception("Please wait for the current request.");busy=true;status.Text="Working…";
  try{
   string input=json.Serialize(request);
   string output=await Task.Run(()=>{
    var psi=new ProcessStartInfo(Path.Combine(root,"runtime","node.exe"),"\""+Path.Combine(root,"companion","tools.js")+"\"");psi.WorkingDirectory=root;psi.UseShellExecute=false;psi.CreateNoWindow=true;psi.RedirectStandardInput=true;psi.RedirectStandardOutput=true;psi.RedirectStandardError=true;psi.StandardOutputEncoding=System.Text.Encoding.UTF8;
    using(var p=Process.Start(psi)){p.StandardInput.Write(input);p.StandardInput.Close();string result=p.StandardOutput.ReadToEnd();p.StandardError.ReadToEnd();p.WaitForExit();return result;}
   });
   var data=json.Deserialize<Dictionary<string,object>>(output);if(data.ContainsKey("error"))throw new Exception(Convert.ToString(data["error"]));status.Text="Ready.";return data;
  }finally{busy=false;}
 }
 async Task Action(string action,int value){
  try{
   string kind=action.EndsWith("item")?"item":action.EndsWith("level")?"level":"digest";
   if(action.StartsWith("preview")||testId==null||testKind!=kind||testValue!=value){testId=Guid.NewGuid().ToString();testKind=kind;testValue=value;}
   var data=await Run(new{action=action,value=value,id=testId});var payload=(Dictionary<string,object>)data["payload"];var embeds=(System.Collections.IList)payload["embeds"];var embed=(Dictionary<string,object>)embeds[0];
   preview.Text=(payload.ContainsKey("content")?Convert.ToString(payload["content"])+Environment.NewLine+Environment.NewLine:"")+Convert.ToString(embed["title"])+Environment.NewLine+Environment.NewLine+Convert.ToString(embed["description"]);icon.Image=null;
   if(embed.ContainsKey("thumbnail")){string url=Convert.ToString(((Dictionary<string,object>)embed["thumbnail"])["url"]);if(url.StartsWith("https://wow.zamimg.com/images/wow/icons/large/"))icon.LoadAsync(url);}
   status.Text=action.StartsWith("preview")?"Preview only — nothing posted.":"Test queued for Discord. Usually arrives shortly.";
   if(!action.StartsWith("preview"))testId=null;
  }catch(Exception e){status.Text="Request failed.";MessageBox.Show(this,e.Message,"LootBot");}
 }
 static int[] IDs(string text){if(string.IsNullOrWhiteSpace(text))return new int[0];var values=text.Split(',').Select(s=>int.Parse(s.Trim())).Distinct().ToArray();if(values.Length>500||values.Any(n=>n<1||n>10000000))throw new Exception("Use up to 500 valid item IDs, separated by commas.");return values;}
 async Task LoadFilters(){try{var data=await Run(new{action="settings"});block.Text=string.Join(", ",((System.Collections.IList)data["blockedItemIds"]).Cast<object>());botName.Text=Convert.ToString(data["botName"]);}catch(Exception e){status.Text=e.Message;}}
 async Task SaveFilters(){try{await Run(new{action="settings",settings=new{minimumQuality=0,watchItemIds=new int[0],blockedItemIds=IDs(block.Text),botName=botName.Text.Trim()}});status.Text="Shared settings saved. Personal rarity is set in-game.";}catch(Exception e){MessageBox.Show(this,e.Message,"LootBot");}}
 async Task AddRelay(){
  using(var dialog=new Form{Text="LootBot — Approve relay",ClientSize=new Size(620,400),StartPosition=FormStartPosition.CenterParent,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false}){
   UiTheme.Form(dialog);
   UiTheme.Label(dialog,"APPROVE RELAY",20,18,340,20,true,UiTheme.Green,9);
   UiTheme.Label(dialog,"Add a friend's relay",20,43,520,35,true,UiTheme.Ink,16);
   UiTheme.Label(dialog,"Paste their public registration. Your Discord webhook stays private.",20,84,570,25);
   var field=new TextBox{Multiline=true,ScrollBars=ScrollBars.Vertical};UiTheme.Field(field,20,122,580,204);field.Font=new Font("Consolas",9);dialog.Controls.Add(field);
   var approve=new Button{DialogResult=DialogResult.OK};UiTheme.Button(approve,"Approve relay",430,341,170,36,true);dialog.Controls.Add(approve);dialog.AcceptButton=approve;
   if(dialog.ShowDialog(this)!=DialogResult.OK)return;
   try{var registration=json.Deserialize<Dictionary<string,object>>(field.Text);await Run(new{action="relays",registration=registration});serviceOutput.Text="Relay approved. Your friend can now start their relay.";status.Text="Relay registered.";}catch(Exception e){MessageBox.Show(this,e.Message,"LootBot");}
  }
 }
 async Task ServiceStatus(){try{
  var data=await Run(new{action="status"});bool discord=Convert.ToBoolean(data["discordConfigured"]);
  var lines=new List<string>{"Service: connected","Discord: "+(discord?"connected":"needs setup"),""};
  foreach(Dictionary<string,object> row in (System.Collections.IList)data["counts"])
   lines.Add(char.ToUpperInvariant(Convert.ToString(row["state"])[0])+Convert.ToString(row["state"]).Substring(1)+": "+Convert.ToString(row["count"]));
  serviceOutput.Text=string.Join(Environment.NewLine,lines);status.Text=discord?"Service connected; Discord configured.":"Service connected; Discord still needs configuring.";
 }catch(Exception e){status.Text=e.Message;}}
}
