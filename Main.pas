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
var Timer1, Timer2: TTimeOut;
begin
  Timer1 := SetTimeOut(
                Procedure
                begin
                  ThreadControler.Infobox('Olá mundo!');
                  Timer1.LoopTimer    := True;
                  Timer1.RestInterval := Timer1.RestInterval + 1000;
                end, 1000);
  Timer2 := SetTimeOut(
                Procedure
                begin
                  ThreadControler.Infobox('ANCAPSTÂO!');
                  Timer2.LoopTimer    := True;
                end, 1000);
end;

procedure TFormMain.ComboBox1Change(Sender: TObject);
begin
  TStyleManager.TrySetStyle(ComboBox1.Items[ComboBox1.ItemIndex]);
end;

end.
