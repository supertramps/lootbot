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
 readonly string root=AppDomain.CurrentDomain.BaseDirectory;
 readonly JavaScriptSerializer json=new JavaScriptSerializer();
 readonly TextBox preview=new TextBox(),watch=new TextBox(),block=new TextBox(),botName=new TextBox();
 readonly PictureBox icon=new PictureBox();
 readonly Label status=new Label();
 readonly ComboBox quality=new ComboBox(),level=new ComboBox();
 readonly NumericUpDown item=new NumericUpDown();
 bool busy;
 string testId,testKind;int testValue;
 public ToolsWindow(){
  Text="LootBot — Tests and shared settings";ClientSize=new Size(820,650);StartPosition=FormStartPosition.CenterParent;Font=new Font("Segoe UI",10);FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;
  LabelAt("Tests work with WoW closed. Character shown: LootTester",16,14,790);
  LabelAt("Item ID",16,53,90);item.Minimum=1;item.Maximum=10000000;item.Value=19019;item.Location=new Point(110,50);item.Width=135;Controls.Add(item);
  ButtonAt("Preview item",260,48,()=>Action("preview-item",(int)item.Value));ButtonAt("Send item test",405,48,()=>Action("test-item",(int)item.Value));
  LabelAt("Level",16,99,90);level.DropDownStyle=ComboBoxStyle.DropDownList;for(int i=10;i<=60;i+=10)level.Items.Add(i);level.SelectedIndex=0;level.Location=new Point(110,96);level.Width=135;Controls.Add(level);
  ButtonAt("Preview level",260,94,()=>Action("preview-level",(int)level.SelectedItem));ButtonAt("Send level test",405,94,()=>Action("test-level",(int)level.SelectedItem));
  ButtonAt("Preview catch-up",540,94,()=>Action("preview-digest",0),125);ButtonAt("Send catch-up",680,94,()=>Action("test-digest",0),125);
  preview.Multiline=true;preview.ReadOnly=true;preview.ScrollBars=ScrollBars.Vertical;preview.Location=new Point(16,150);preview.Size=new Size(680,150);Controls.Add(preview);
  icon.Location=new Point(720,160);icon.Size=new Size(64,64);icon.SizeMode=PictureBoxSizeMode.Zoom;Controls.Add(icon);
  LabelAt("Personal rarity is set in WoW: /lootbot filter rare or /lootbot filter epic",16,317,790);
  LabelAt("Characters lock to Epic at level 40. Grey, white and green loot never reaches a relay.",16,350,790);
  quality.Visible=false;watch.Visible=false;
  LabelAt("Blocked IDs",16,394,135);block.Location=new Point(155,390);block.Width=640;Controls.Add(block);
  LabelAt("Discord name",16,433,135);botName.Location=new Point(155,429);botName.Width=300;botName.MaxLength=80;Controls.Add(botName);
  LabelAt("Separate IDs with commas. Blocked items take priority. Tests bypass filters.",16,472,790);
  ButtonAt("Load settings",16,510,LoadFilters);ButtonAt("Save",160,510,SaveFilters);
  status.Location=new Point(315,516);status.Size=new Size(480,35);Controls.Add(status);
  ButtonAt("Add relay",16,565,AddRelay);ButtonAt("Service status",160,565,ServiceStatus);
  Shown+=async(s,e)=>await LoadFilters();
 }
 void LabelAt(string text,int x,int y,int width){Controls.Add(new Label{Text=text,Location=new Point(x,y),Size=new Size(width,26)});}
 void ButtonAt(string text,int x,int y,Func<Task> action,int width=135){var b=new Button{Text=text,Location=new Point(x,y),Size=new Size(width,34)};b.Click+=async(s,e)=>await action();Controls.Add(b);}
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
 async Task LoadFilters(){try{var data=await Run(new{action="settings"});quality.SelectedIndex=Convert.ToInt32(data["minimumQuality"]);watch.Text=string.Join(", ",((System.Collections.IList)data["watchItemIds"]).Cast<object>());block.Text=string.Join(", ",((System.Collections.IList)data["blockedItemIds"]).Cast<object>());botName.Text=Convert.ToString(data["botName"]);}catch(Exception e){status.Text=e.Message;}}
 async Task SaveFilters(){try{await Run(new{action="settings",settings=new{minimumQuality=0,watchItemIds=new int[0],blockedItemIds=IDs(block.Text),botName=botName.Text.Trim()}});status.Text="Shared settings saved. Personal rarity is set in-game.";}catch(Exception e){MessageBox.Show(this,e.Message,"LootBot");}}
 async Task AddRelay(){
  using(var dialog=new Form{Text="Approve a guild relay",ClientSize=new Size(600,350),StartPosition=FormStartPosition.CenterParent}){
   var label=new Label{Text="Paste the public registration from your friend's Relay registration button.\nThis lets their app submit guild events. Your Discord webhook stays private.",Location=new Point(12,12),Size=new Size(576,45)};
   var field=new TextBox{Multiline=true,ScrollBars=ScrollBars.Vertical,Location=new Point(12,65),Size=new Size(576,215)};
   var approve=new Button{Text="Approve relay",Location=new Point(430,298),Size=new Size(158,34),DialogResult=DialogResult.OK};dialog.Controls.Add(label);dialog.Controls.Add(field);dialog.Controls.Add(approve);
   if(dialog.ShowDialog(this)!=DialogResult.OK)return;
   try{var registration=json.Deserialize<Dictionary<string,object>>(field.Text);var data=await Run(new{action="relays",registration=registration});preview.Text="Approved relay registrations:\r\n"+json.Serialize(data);status.Text="Relay registered.";}catch(Exception e){MessageBox.Show(this,e.Message,"LootBot");}
  }
 }
 async Task ServiceStatus(){try{var data=await Run(new{action="status"});preview.Text=json.Serialize(data);status.Text=Convert.ToBoolean(data["discordConfigured"])?"Service connected; Discord configured.":"Service connected; Discord still needs configuring.";}catch(Exception e){status.Text=e.Message;}}
}
