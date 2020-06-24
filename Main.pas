unit Main;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    System.TypInfo, Generics.Collections, Vcl.ExtCtrls,
    Vcl.DBCtrls, SyncObjs, Vcl.Themes, Vcl.Buttons,
    TimeoutControler, Registry, RegistroControler;
type
TFormMain = class(TForm)
    ComboBox1: TComboBox;
    Button1: TButton;
    Memo1: TMemo;
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
    Mensagem: String;
begin
  Timer1 := SetTimeOut(
                Procedure
                begin
                  ThreadControler.Infobox('Olá mundo!');
                end, 1000,False, True,True);
//  Timer2 := SetTimeOut(
//                Procedure
//                begin
//                  while true do Sleep(1);
//                end, 1000,False, True,True);
//  Timer2 := SetTimeOut(
//                Procedure
//                begin
//                  ThreadControler.Infobox('ANCAPSTÂO!');
//                end, 1000);
end;

procedure TFormMain.ComboBox1Change(Sender: TObject);
begin
  TStyleManager.TrySetStyle(ComboBox1.Items[ComboBox1.ItemIndex]);
end;

end.
