using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

// WoW reads this ordinary addon file at startup/reload. No game input,
// process memory, SavedVariables or shared guild settings are modified.
public static class LocalLootTesting {
 public static string SelectAddonPath(string saved,string[] executables){
  var paths=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
  foreach(string executable in executables){
   string name=Path.GetFileNameWithoutExtension(executable);
   if(!System.Text.RegularExpressions.Regex.IsMatch(name??"",@"\AWow(?:Classic)?[TB]?\z",System.Text.RegularExpressions.RegexOptions.IgnoreCase))continue;
   string path=Path.Combine(Path.GetDirectoryName(executable),"Interface","AddOns","LootBot");
   if(File.Exists(Path.Combine(path,"LootBot.toc")))paths.Add(path);
  }
  if(paths.Count==1){foreach(string path in paths)return path;}
  if(paths.Count>1)return saved!=null&&paths.Contains(saved)?saved:null;
  return saved;
 }
 static string[] RunningExecutables(){
  var executables=new List<string>();
  foreach(var process in Process.GetProcessesByName("Wow"))using(process){
   try{executables.Add(process.MainModule.FileName);}catch(InvalidOperationException){}catch(System.ComponentModel.Win32Exception){}
  }
  foreach(string name in new[]{"WowT","WowB","WowClassic","WowClassicT","WowClassicB"})
   foreach(var process in Process.GetProcessesByName(name))using(process){
    try{executables.Add(process.MainModule.FileName);}catch(InvalidOperationException){}catch(System.ComponentModel.Win32Exception){}
   }
  return executables.ToArray();
 }
 static string CurrentAddonPath(string root,string[] executables){
  var state=Read(root);string saved=state.ContainsKey("addonPath")?Convert.ToString(state["addonPath"]):null;
  return SelectAddonPath(saved,executables);
 }
 static string StatePath(string root){return Path.Combine(root,"state","test-loot.json");}
 static Dictionary<string,object> Read(string root){
  try{return new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(StatePath(root)));}
  catch(IOException){return new Dictionary<string,object>();}
  catch(ArgumentException){return new Dictionary<string,object>();}
 }
 public static bool Enabled(string root){return Enabled(root,RunningExecutables());}
 public static bool Enabled(string root,string[] executables){
  try {
   string addonPath=CurrentAddonPath(root,executables);
   return addonPath!=null && File.ReadAllText(Path.Combine(addonPath,"LocalTestSettings.lua")).Contains("allLoot = true");
  }catch(IOException){return false;}catch(UnauthorizedAccessException){return false;}
 }
 public static void Apply(string root,string addonPath,bool enabled){
  addonPath=Path.GetFullPath(addonPath).TrimEnd(Path.DirectorySeparatorChar);
  if(!string.Equals(Path.GetFileName(addonPath),"LootBot",StringComparison.OrdinalIgnoreCase)
    || !File.Exists(Path.Combine(addonPath,"LootBot.toc"))
    || !File.ReadAllText(Path.Combine(addonPath,"LootBot.toc")).Contains("LocalTestSettings.lua"))
   throw new ArgumentException("Choose the installed LootBot addon folder under WoW's Interface/AddOns. Update the addon to this build first.");
  Directory.CreateDirectory(Path.Combine(root,"state"));
  File.WriteAllText(StatePath(root),new JavaScriptSerializer().Serialize(new{addonPath=addonPath}),new UTF8Encoding(false));
  File.WriteAllText(Path.Combine(addonPath,"LocalTestSettings.lua"),
    "-- Local desktop testing switch. Reload WoW to apply.\r\nLootBotLocalTestSettings = { allLoot = "+(enabled?"true":"false")+" }\r\n",new UTF8Encoding(false));
 }
 public static bool Configure(IWin32Window owner,string root,bool enabled){
  string addonPath=CurrentAddonPath(root,RunningExecutables());
  if(string.IsNullOrEmpty(addonPath)||!Directory.Exists(addonPath)){
   using(var picker=new FolderBrowserDialog()){
    picker.Description="Choose your installed LootBot addon folder inside WoW's game version / Interface / AddOns / LootBot";
    picker.ShowNewFolderButton=false;
    if(picker.ShowDialog(owner)!=DialogResult.OK)return false;
    addonPath=picker.SelectedPath;
   }
  }
  Apply(root,addonPath,enabled);return true;
 }
}
