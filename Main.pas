//Feito por: Jean Paulo Athanazio De Mei
unit Main;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    System.Rtti, System.TypInfo, Generics.Collections;

const
    WM_OPEN                 = WM_USER + 1;
    WM_PROCEDIMENTOGENERICO = WM_USER + 2;
    WM_TERMINATE            = WM_USER + 3;
type
    TProcedure        = Procedure of object;
    TSQLList          = record
      Qry: TADOQuery;
      Button: TButton;
      DS:  TDataSource;
    end;
    TRecordProcedure = record
      Procedimento : TProcedure;
    end;
    procedure DesativarDataSource(Qry: TADOQuery);
    procedure AtivarDataSource(Qry:TAdoQuery);
  // Coisas para lembrar que eu possa usar no futuro caso seja necessário
  //TProcedureObj = Procedure (Obj: TObject) of object;
  //TThreadState  = set of (csSemFilaRequisicao, csDestruir, csSemNotificacao);
  //Include(TThreadState, csFreeNotification);
  //if (csFreeNotification in Instance.FComponentState)
type
    TThreadMain = class(TThread)
private
    Connection: TADOConnection;
    Query: TADOQuery;
    DataSource: TDataSource;
    NaoPermitirFilaRequisicao: Boolean;
    MyList: TList<TSQLList>;
    procedure WMProcGenerico(Msg: TMsg);
    procedure WMOpen(Msg: TMsg);
    procedure PrepararRequisicaoConsulta(DS: TDataSource;Button: TButton);
    procedure RolocarGrid(DS: TDataSource);
protected
    procedure Execute; override;
public
    EmConsulta: boolean;
    RecordProcedure: TRecordProcedure;
    procedure Open(DS: TDataSource; Button: TButton);
    procedure ExecSQL(DS: TDataSource; Button: TButton);
    procedure ProcedimentoGenerico(Procedimento: TProcedure; Button: TButton);
    procedure CancelarConsulta;
    procedure NovaConexao(DS: TDataSource);
    procedure Kill;
end;

TForm1 = class(TForm)
    Query1: TADOQuery;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    ADOConnection1: TADOConnection;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    Button4: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
private
{ Private declarations }
    Thread1 : TThreadMain;
public
{ Public declarations }
    procedure Consulta;
end;
var
  Form1: TForm1;
implementation

{$R *.DFM}
// ------------------- FUNÇÕES GLOBAIS -------------------- //

procedure DesativarDataSource(Qry: TADOQuery);
var
  i: integer;
  Form: TForm;
begin
  Form := TForm(Qry.Owner);
  for i := 0 to (Form.ComponentCount - 1) do begin
   if (Form.Components[i] is TDataSource) and (TDataSource(Form.Components[i]).DataSet = Qry)
     then TDataSource(Form.Components[i]).Enabled := False;
  end;
end;

procedure AtivarDataSource(Qry: TADOQuery);
var
  i: integer;
  Form: TForm;
begin
  Form := TForm(Qry.Owner);
  for i := 0 to (Form.ComponentCount - 1) do begin
   if (Form.Components[i] is TDataSource) and (TDataSource(Form.Components[i]).DataSet = Qry)
     then TDataSource(Form.Components[i]).Enabled := True;
  end;
end;

// ------------------- THREAD CONSULTA -------------------- //
{eventos}

procedure TThreadMain.RolocarGrid(DS: TDataSource);
var
  i: integer;
  Form: TForm;
  Qry:   TAdoQuery;
begin
  Qry:= TAdoQuery(DS.DataSet);
  Form := TForm(Qry.Owner);
  for i := 0 to (Form.ComponentCount - 1) do begin
       if (Form.Components[i] is TDBGrid)  and (TDBGrid(Form.Components[i]).DataSource = DS)
         then TDBGrid(Form.Components[i]).DataSource := DataSource;
  end;
end;

procedure TThreadMain.PrepararRequisicaoConsulta(DS: TDataSource; Button: TButton);
var
  ExecSQLList :TSQLList;
begin
  if (NaoPermitirFilaRequisicao and EmConsulta)or( Button.Caption = 'Cancelar')
    then exit;
  Button.Enabled := False;
  Button.Caption := 'Cancelar';
  if MyList = nil
    then MyList := TList<TSQLList>.Create;
  ExecSQLList.DS     := DS;
  NovaConexao(DS);
  ExecSQLList.Qry    := Query;
  ExecSQLList.Button := Button;
  MyList.Add(ExecSQLList);
end;

procedure TThreadMain.Open(DS: TDataSource; Button: TButton);
begin
  PrepararRequisicaoConsulta(DS, Button);
  PostThreadMessage(ThreadID, WM_OPEN, 0, 0);
end;

procedure TThreadMain.ExecSQL(DS: TDataSource; Button: TButton);
begin
  PrepararRequisicaoConsulta(DS, Button);
  PostThreadMessage(ThreadID, WM_OPEN, 1, 0);
end;

procedure TThreadMain.ProcedimentoGenerico(Procedimento: TProcedure; Button: TButton);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  Button.Enabled := False;
  Self.RecordProcedure.Procedimento := Procedimento;
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICO, Integer(@Self.RecordProcedure), 0);
end;

{inicio}
procedure TThreadMain.Execute;
var
Msg : TMsg;
begin
  FreeOnTerminate := self.Finished;
  //Rever em caso de falha
  PeekMessage(Msg, 0, WM_USER, WM_USER, PM_NOREMOVE);//remove qualquer mensagem
  while not Terminated do begin
    if GetMessage(Msg, 0, 0, 0) then
    EmConsulta := true;
    try
      try
        case Msg.Message of
          WM_OPEN:                 WMOpen(Msg);
          WM_PROCEDIMENTOGENERICO: WMProcGenerico(Msg);
          WM_DESTROY:              Destroy;
          WM_NULL:                 exit;
          WM_TERMINATE:            Terminate;
          else Continue;
        end;
      finally
        EmConsulta := false;
      end;
    except
      Self.Execute;//Caso ocorra um erro tentar executar novamente.
    end;
  end;
end;
//Queue
{Consulta}
{Open}
procedure TThreadMain.WMOpen(Msg: TMsg);
var
Qry    : TADOQuery;
Button : TButton;
List   : TSQLList;
Form   : TForm;
i, Aux : Integer;
begin
try
  Query.Connection := nil;
  Synchronize(
  procedure
  begin
    Aux   := Integer(Msg.wParam);
    List  := Self.MyList.Last;
    Button := List.Button;
    Qry := List.Qry;
    Qry.Close;
    Qry.Connection     := Connection;
    DataSource.Enabled := True;
    Connection.BeginTrans;
    RolocarGrid(List.DS);
    Button.Enabled := True;
  end
  );
  if Aux = 0
    then Qry.Open
    else Qry.ExecSQL;
  if EmConsulta
    then Connection.CommitTrans
    else begin
      Qry.Close;
      AtivarDataSource(Qry);
      Button.Enabled := True;
    end;//é porque eu cancelei no meio
  finally
    Button.Caption := 'Consultar direto';
 end;
end;

{Procedimento Generico}
procedure TThreadMain.WMProcGenerico(Msg: TMsg);
var
  Aux: ^TRecordProcedure;
  Procedimento: TProcedure;
begin
  Aux := Pointer(Msg.wParam);
  Procedimento := Aux^.Procedimento;
  Procedimento;
end;

procedure TThreadMain.NovaConexao(DS: TDataSource);
var
  Qry: TAdoQuery;
  ConnectionAux: TADOConnection;
begin
  Qry := TAdoQuery(DS.DataSet);
  Connection := Qry.Connection;
  if Connection = nil then begin
    Connection                      := TADOConnection.Create(Form1);
    Connection.ConnectionString     := ConnectionAux.ConnectionString;
    Connection.ConnectionTimeout    := ConnectionAux.ConnectionTimeout;
    Connection.ConnectOptions       := ConnectionAux.ConnectOptions;
    Connection.CursorLocation       := ConnectionAux.CursorLocation;
    Connection.DefaultDatabase      := ConnectionAux.DefaultDatabase;
    Connection.IsolationLevel       := ConnectionAux.IsolationLevel;
    Connection.KeepConnection       := ConnectionAux.KeepConnection;
    Connection.LoginPrompt          := ConnectionAux.LoginPrompt;
    Connection.Mode                 := ConnectionAux.Mode;
    Connection.Name                 := 'Thread'+IntToStr(Self.ThreadID)+ ConnectionAux.Name;
    Connection.Provider             := ConnectionAux.Provider;
    Connection.Tag                  := ConnectionAux.Tag;
  end;
  if Query = nil then begin
    Query                           := TADOQuery.Create(Form1);
    Query.AutoCalcFields            := Qry.AutoCalcFields;
    Query.CacheSize                 := Qry.CacheSize;
    Query.CommandTimeout            := Qry.CommandTimeout;
    Query.ConnectionString          := Qry.ConnectionString;
    Query.CursorLocation            := Qry.CursorLocation;
    Query.CursorType                := Qry.CursorType;
    Query.DataSource                := Qry.DataSource;
    Query.EnableBCD                 := Qry.EnableBCD;
    Query.ExecuteOptions            := Qry.ExecuteOptions;
    Query.Filter                    := Qry.Filter;
    Query.Filtered                  := Qry.Filtered;
    Query.LockType                  := Qry.LockType;
    Query.MarshalOptions            := Qry.MarshalOptions;
    Query.MaxRecords                := Qry.MaxRecords;
    Query.Name                      := 'Thread'+IntToStr(Self.ThreadID)+Qry.Name;
    Query.ParamCheck                := Qry.ParamCheck;
    Query.Parameters                := Qry.Parameters;
    Query.Prepared                  := Qry.Prepared;
    Query.SQL                       := Qry.SQL;
    Query.Tag                       := Qry.Tag;
    Query.Connection                := Connection;
  end;
  if DataSource = nil then begin
    DataSource                      := TDataSource.Create(Form1);
    DataSource.AutoEdit             := DS.AutoEdit;
    DataSource.DataSet              := TDataSet(Query);
    DataSource.Name                 := 'Thread'+IntToStr(Self.ThreadID)+DS.Name;
    DataSource.Tag                  := DS.Tag;
  end;
  Connection.Connected            := True;
end;

procedure TThreadMain.CancelarConsulta;
begin
    if EmConsulta then begin
      Synchronize(
        Procedure
        var
          Qry  : TAdoQuery;
          Form : TForm;
          i    : integer;
        begin
          try
            Qry  := TAdoQuery(Self.Connection.DataSets[0]);
            DataSource.Enabled := False;
            Self.Connection.RollbackTrans;
          finally
            EmConsulta := False;
          end;
        end
      );
    end;
end;

procedure TThreadMain.Kill;
begin
  if EmConsulta
    then Destroy
    else Terminate;
end;

// ------------------- MAIN -------------------- //

procedure TForm1.Button1Click(Sender: TObject);
begin
  if not (Thread1.EmConsulta)
    then begin
      Thread1.Open(DataSource1,Button1);
      Button1.Caption := 'Cancelar';
    end
    else begin
      Thread1.CancelarConsulta;
      Button1.Caption := 'Consultar direto';
    end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  Thread1.ExecSQL(DataSource1, Button2);
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  Thread1.ProcedimentoGenerico(Consulta, Button3);
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  Thread1.CancelarConsulta;
end;

procedure TForm1.Consulta;
begin
  try
    Thread1.NovaConexao(DataSource1);
    Thread1.Query.Connection := Thread1.Connection;
    Thread1.Query.Close;
    Thread1.Connection.Connected := True;
    Self.DBGrid1.DataSource := Thread1.DataSource;
    Thread1.Connection.BeginTrans;
    Button3.Visible := False;
    Thread1.Query.Open;
    Thread1.Synchronize(
    procedure
    begin
      if Thread1.EmConsulta
        then Thread1.Connection.CommitTrans
        else begin
          Thread1.Query.Close;
          Thread1.DataSource.Enabled := True;
          Thread1.EmConsulta := False;
        end;//é porque eu cancelei no meio
    end
    );
  finally
    Button3.Enabled := True;
    Button3.Visible := True;
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if not Button3.Visible
    then Form1.Button4Click(Button4);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Thread1 := TThreadMain.Create(False);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  Thread1.Kill;
end;

end.
