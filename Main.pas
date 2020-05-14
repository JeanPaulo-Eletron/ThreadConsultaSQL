//Feito por: Jean Paulo Athanazio De Mei
{     Anotações:
      Bloqueada ---> verificar se threads estão bloqueada, para atender sobe demanda. ---> Monitor(Para aumentar a qtde sobe demanda """(Cores.dwNumberOfProcessors - 1) + IdlenessIndex(Uma expressão matemática logaritma baseada na memoria ram e no numero de cores[Uso intensivo de CPU, Uso intensivo de HD --> Por meta dados])""")
      Threshold ---> Limiar   NODE X APACHE(LENTIDÃO).
      Inferno da DLL e CALLBACKS e usar promices fica mais simples.
}

// é intessante ver as opções do próprios componentes ADO para conexões assyncronas;
// Fazer Call Back
unit Main;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    System.TypInfo, Generics.Collections, Vcl.ExtCtrls,
    Vcl.DBCtrls, SyncObjs, Vcl.Themes, ThreadControler;

const
    WM_OPEN                       = WM_USER + 1;
    WM_PROCEDIMENTOGENERICOASSYNC = WM_USER + 2;
    WM_TIMERTHREADASSYNC          = WM_USER + 3;
    WM_TERMINATE                  = WM_USER + 4;
type

TFormMain = class(TForm)
    Query1: TADOQuery;
    Button3: TButton;
    ADOConnection1: TADOConnection;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    Button4: TButton;
    Button5: TButton;
    lbl1: TLabel;
    ComboBox1: TComboBox;
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject); override;
private
{ Private declarations }
public
{ Public declarations }
    procedure Consulta;
end;
var
  FormMain: TFormMain;
implementation

{$R *.DFM}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  inherited;
//
end;

// ------------------- MAIN -------------------- //

procedure TFormMain.Button3Click(Sender: TObject);
begin
  Thread.ProcedimentoGenericoAssync(Consulta,'Consulta');
  Thread.ProcedimentoGenericoAssync(Consulta,'Consulta');
end;

procedure TFormMain.Button4Click(Sender: TObject);
begin
  Thread.CancelarConsulta('Consulta');
end;

procedure TFormMain.Button5Click(Sender: TObject);
begin
  Thread.ProcedimentoGenericoAssync(
              Procedure
              begin
                while true do begin
                  sleep(1);
                  if Thread.Finished
                    then exit;
                  Thread.Synchronize(
                  procedure
                  begin
                    FormMain.lbl1.Caption := IntToStr( StrToInt(FormMain.lbl1.Caption) + 10);
                  end);
                end;
              end);
end;

procedure TFormMain.ComboBox1Change(Sender: TObject);
begin
  TStyleManager.TrySetStyle(ComboBox1.Items[ComboBox1.ItemIndex]);
end;

procedure TFormMain.Consulta;
var
  RecordProcedure: TRecordProcedure;
begin
  try
    RecordProcedure := Thread.NovaConexao(DataSource1,'Consulta');
    Button3.Visible := False;
    RecordProcedure.SQLList.Qry.Close;
    RecordProcedure.SQLList.Qry.Open;
  finally
    Button3.Enabled := True;
    Button3.Visible := True;
  end;
end;

procedure TFormMain.FormShow(Sender: TObject);
var
  s: String;
begin
  ComboBox1.Items.BeginUpdate;
  try
    ComboBox1.Items.Clear;
    for s in TStyleManager.StyleNames do
       ComboBox1.Items.Add(s);
    ComboBox1.Sorted := True;
    ComboBox1.ItemIndex := ComboBox1.Items.IndexOf(TStyleManager.ActiveStyle.Name);
  finally
    ComboBox1.Items.EndUpdate;
  end;
end;

end.
