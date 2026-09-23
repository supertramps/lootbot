using System;
using System.Drawing;
using System.Windows.Forms;

internal static class UiTheme {
    public static readonly Color Canvas=Color.FromArgb(246,248,245);
    public static readonly Color Surface=Color.White;
    public static readonly Color Ink=Color.FromArgb(28,43,37);
    public static readonly Color Muted=Color.FromArgb(94,111,101);
    public static readonly Color Line=Color.FromArgb(218,227,220);
    public static readonly Color Green=Color.FromArgb(36,103,75);
    public static readonly Color GreenDark=Color.FromArgb(27,80,59);
    public static readonly Color GreenTint=Color.FromArgb(231,242,234);
    public static readonly Color Gold=Color.FromArgb(180,130,65);

    public static void Form(Form form) {
        form.BackColor=Canvas;
        form.ForeColor=Ink;
        form.Font=new Font("Segoe UI",10);
        form.AutoScaleMode=AutoScaleMode.Font;
    }
    public static Panel Card(Control parent, int x,int y,int width,int height) {
        var card=new Panel {Location=new Point(x,y),Size=new Size(width,height),BackColor=Surface};
        card.Paint+=(s,e)=>ControlPaint.DrawBorder(e.Graphics,card.ClientRectangle,Line,ButtonBorderStyle.Solid);
        parent.Controls.Add(card);
        return card;
    }
    public static Label Label(Control parent,string text,int x,int y,int width,int height=24,bool strong=false,Color? color=null,float size=10) {
        var label=new Label {Text=text,Location=new Point(x,y),Size=new Size(width,height),AutoEllipsis=true,
            Font=new Font("Segoe UI",size,strong?FontStyle.Bold:FontStyle.Regular),ForeColor=color??(strong?Ink:Muted),BackColor=Color.Transparent};
        parent.Controls.Add(label);
        return label;
    }
    public static void Button(Button button,string text,int x,int y,int width,int height,bool primary=false) {
        button.Text=text;button.Location=new Point(x,y);button.Size=new Size(width,height);
        button.FlatStyle=FlatStyle.Flat;button.FlatAppearance.BorderSize=1;
        button.FlatAppearance.BorderColor=primary?Green:Line;
        button.FlatAppearance.MouseOverBackColor=primary?GreenDark:GreenTint;
        button.BackColor=primary?Green:Surface;button.ForeColor=primary?Surface:Ink;
        button.Font=new Font("Segoe UI",9.5f,FontStyle.Bold);
        button.UseVisualStyleBackColor=false;
    }
    public static Button Button(Control parent,string text,int x,int y,int width,int height,Action click,bool primary=false) {
        var button=new Button();Button(button,text,x,y,width,height,primary);
        button.Click+=(s,e)=>click();parent.Controls.Add(button);return button;
    }
    public static Button AsyncButton(Control parent,string text,int x,int y,int width,int height,Func<System.Threading.Tasks.Task> click,bool primary=false) {
        var button=new Button();Button(button,text,x,y,width,height,primary);
        button.Click+=async(s,e)=>await click();parent.Controls.Add(button);return button;
    }
    public static void Field(TextBox box,int x,int y,int width,int height=30) {
        box.Location=new Point(x,y);box.Size=new Size(width,height);box.BorderStyle=BorderStyle.FixedSingle;
        box.BackColor=Surface;box.ForeColor=Ink;box.Font=new Font("Segoe UI",10);
    }
    public static void Field(ComboBox box,int x,int y,int width) {
        box.Location=new Point(x,y);box.Width=width;box.DropDownStyle=ComboBoxStyle.DropDownList;
        box.FlatStyle=FlatStyle.Flat;box.BackColor=Surface;box.ForeColor=Ink;
    }
}
