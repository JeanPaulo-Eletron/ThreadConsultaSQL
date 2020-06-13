unit Main;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    System.TypInfo, Generics.Collections, Vcl.ExtCtrls,
    Vcl.DBCtrls, SyncObjs, Vcl.Themes, Vcl.Buttons,
    TimeoutControler;
type

TFormMain = class(TForm)
    ComboBox1: TComboBox;
    DBGrid1: TDBGrid;
    Button1: TButton;
    procedure ComboBox1Change(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Timer1;
private
{ Private declarations }
public
{ Public declarations }
end;
var
  FormMain: TFormMain;
implementation

{$R *.DFM}

uses ThreadControler;

// ------------------- MAIN -------------------- //

procedure TFormMain.Button1Click(Sender: TObject);
begin
  SetTimeOut(Timer1,1000)
end;

procedure TFormMain.ComboBox1Change(Sender: TObject);
begin
  TStyleManager.TrySetStyle(ComboBox1.Items[ComboBox1.ItemIndex]);
end;

procedure TFormMain.Timer1;
begin
  ThreadControler.Infobox('Olá mundo!');
end;

end.
