//Feito por: Jean Paulo Athanazio De Mei
unit Main;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    System.Rtti, System.TypInfo, Generics.Collections;

const
    WM_OPEN                       = WM_USER + 1;
    WM_PROCEDIMENTOGENERICO       = WM_USER + 2;
    WM_PROCEDIMENTOGENERICOASSYNC = WM_USER + 3;
    WM_TERMINATE                  = WM_USER + 4;
type
    TProcedure        = Procedure of object;
    TRProcedure       = reference to procedure;
    TSQLList          = record
      Qry: TADOQuery;
      Button: TButton;
      DS:  TDataSource;
    end;
    TRecordProcedure = record
      Procedimento : TProcedure;
      RProcedimento : TProc;
    end;
    procedure DesativarDataSource(Qry: TADOQuery);
    procedure AtivarDataSource(Qry:TAdoQuery);
type
    TThreadMain = class(TThread)
private
    Connection: TADOConnection;
    Query: TADOQuery;
    DataSource: TDataSource;
    NaoPermitirFilaRequisicao: Boolean;
    MyList:     TList<TSQLList>;
    QtdeProcAsssync: Integer;
    MyListProc: TList<TRecordProcedure>;
    procedure WMProcGenerico(Msg: TMsg);
    procedure WMOpen(Msg: TMsg);
    procedure WMProcGenericoAssync(Msg: TMsg);
    procedure PrepararRequisicaoConsulta(DS: TDataSource;Button: TButton);
    procedure RelocarGrid(DS: TDataSource);
protected
    Rest : Integer;
    procedure Execute; override;
public
    EmConsulta: boolean;
    RecordProcedure:  TRecordProcedure;
    procedure Open(DS: TDataSource; Button: TButton);
    procedure ExecSQL(DS: TDataSource; Button: TButton);
    procedure ProcedimentoGenerico(Procedimento: TProcedure; Button: TButton);overload;
    procedure ProcedimentoGenerico(Procedimento: TProc; Button: TButton);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure; Button: TButton);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc; Button: TButton);overload;
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
    Query2: TADOQuery;
    ADOConnection2: TADOConnection;
    DataSource2: TDataSource;
    Button5: TButton;
    lbl1: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Button5Click(Sender: TObject);
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

procedure TThreadMain.RelocarGrid(DS: TDataSource);
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
  ExecSQLList.Qry    := TAdoQuery(DS.DataSet);
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
  if MyListProc = nil
    then  MyListProc := TList<TRecordProcedure>.Create;
  Button.Enabled := False;
  Self.RecordProcedure.Procedimento := Procedimento;
  MyListProc.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICO, 0, 0);
end;

procedure TThreadMain.ProcedimentoGenerico(Procedimento: TProc; Button: TButton);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProc = nil
    then  MyListProc := TList<TRecordProcedure>.Create;
  Button.Enabled := False;
  Self.RecordProcedure.RProcedimento := Procedimento;
  MyListProc.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICO, 1, 0);
end;

procedure TThreadMain.ProcedimentoGenericoAssync(Procedimento: TProc; Button: TButton);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProc = nil
    then  MyListProc := TList<TRecordProcedure>.Create;
  Button.Enabled := False;
  Self.RecordProcedure.RProcedimento := Procedimento;
  MyListProc.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 1, 0);
end;

procedure TThreadMain.ProcedimentoGenericoAssync(Procedimento: TProcedure;
  Button: TButton);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProc = nil
    then  MyListProc := TList<TRecordProcedure>.Create;
  Button.Enabled := False;
  Self.RecordProcedure.Procedimento := Procedimento;
  MyListProc.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 0, 0);
end;

{inicio}
procedure TThreadMain.Execute;
var
Msg : TMsg;
begin
  Rest := 10;
  FreeOnTerminate := self.Finished;
  while not Terminated do begin
    if PeekMessage(Msg, 0, 0, 0, PM_NOREMOVE) then begin
      Sleep(Rest);
      EmConsulta := true;
      try
        try
          case Msg.Message of
            WM_OPEN:                       WMOpen(Msg);
            WM_PROCEDIMENTOGENERICO:       WMProcGenerico(Msg);
            WM_PROCEDIMENTOGENERICOASSYNC: WMProcGenericoAssync(Msg);
            WM_DESTROY:                    Destroy;
            WM_TERMINATE:                  Terminate;
          end;
        finally
          EmConsulta := false;
          PeekMessage(Msg, 0, 0, 0, PM_REMOVE);//remove última mensagem
        end;
      except
        Self.Execute;//Caso ocorra um erro tentar executar novamente.
      end;
    end
  end;
end;

procedure TThreadMain.WMOpen(Msg: TMsg);
var
Button : TButton;
List   : TSQLList;
Form   : TForm;
i, Aux : Integer;
begin
try
  Synchronize(
  procedure
  begin
    List  := Self.MyList.First;//*** Ele tem que pegar a primeira colocada, pois é a primeira a ser executada ***
    NovaConexao(List.DS);
    Aux   := Integer(Msg.wParam);
    Button := List.Button;
    Query.Close;
    Query.Connection     := Connection;
    DataSource.Enabled := True;
    Connection.BeginTrans;
    RelocarGrid(List.DS);
    Button.Enabled := True;
  end
  );
  if Aux = 0
    then Query.Open
    else Query.ExecSQL;
  if EmConsulta
    then Connection.CommitTrans
    else begin
      Query.Close;
      DataSource.Enabled := True;
      Button.Enabled := True;
    end;//é porque eu cancelei no meio
  finally
    Button.Caption := 'Consultar direto';
    MyList.Remove(List);
 end;
end;

{Procedimento Generico}
procedure TThreadMain.WMProcGenerico(Msg: TMsg);
var
  Aux: TRecordProcedure;
  Procedimento: TProc;
begin
  Aux := MyListProc.First;
  if Integer(Msg.wParam) = 0
    then begin
      MyListProc.First.Procedimento;
    end
    else begin
      Procedimento := MyListProc.First.RProcedimento;
      Procedimento;
    end;
  MyListProc.Remove(MyListProc.First);
end;

procedure TThreadMain.WMProcGenericoAssync(Msg: TMsg);
var
  Aux: TRecordProcedure;
  Procedimento: TProc;
begin
  Aux := MyListProc.First;
  if Integer(Msg.wParam) = 0
    then begin
      CreateAnonymousThread(MyListProc.First.Procedimento).Start;
    end
    else begin
      Procedimento := MyListProc.First.RProcedimento;
      CreateAnonymousThread(Procedimento).Start;
    end;
  MyListProc.Remove(MyListProc.First);
end;

procedure TThreadMain.NovaConexao(DS: TDataSource);
var
  Qry: TAdoQuery;
  ConnectionAux: TADOConnection;
begin
  Qry := TAdoQuery(DS.DataSet);
  ConnectionAux := Qry.Connection;
  if ConnectionAux <> nil then begin
    if Connection = nil
      then Connection               := TADOConnection.Create(Form1);
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
  if (Qry <> nil) then begin
    if Query = nil
      then Query                    := TADOQuery.Create(Form1);
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
  if (DS <> nil) then begin
    if DataSource = nil
      then DataSource                      := TDataSource.Create(Form1);
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
          Form : TForm;
          i    : integer;
        begin
          try
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
  if (EmConsulta) or (QtdeProcAsssync <> 0)
    then Destroy
    else Terminate;
end;

// ------------------- MAIN -------------------- //

procedure TForm1.Button1Click(Sender: TObject);
begin
  if not (Thread1.EmConsulta)
    then Thread1.Open(DataSource1,Button1)
    else begin
      Thread1.CancelarConsulta;
      Button1.Caption := 'Consultar direto';
    end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  if not (Thread1.EmConsulta)
    then Thread1.ExecSQL(DataSource2, Button2)
    else begin
      Thread1.CancelarConsulta;
      Button2.Caption := 'Consultar direto';
    end;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  Thread1.ProcedimentoGenerico(Consulta, Button3);
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  Thread1.CancelarConsulta;
end;

procedure TForm1.Button5Click(Sender: TObject);
var
  Proc : TProc;
begin
  Proc :=   Procedure
              begin
                while true do begin
                  sleep(1);
                  if Thread1.Finished
                    then exit;
                  Thread1.Queue(
                    procedure
                    begin
                      lbl1.Caption := IntToStr( StrToInt(lbl1.Caption) + 1);
                    end
                  );
                end;
              end;
  Thread1.ProcedimentoGenericoAssync(Proc, TButton(Sender));
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
    Thread1.QtdeProcAsssync := Thread1.QtdeProcAsssync - 1;
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if not Button3.Visible
    then Form1.Button4Click(Button4);
  Application.ProcessMessages;
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
