unit ThreadControler;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    System.TypInfo, Generics.Collections, Vcl.ExtCtrls, Vcl.DBCtrls,
    SyncObjs, Vcl.Themes;

const
    WM_OPEN                       = WM_USER + 1;
    WM_PROCEDIMENTOGENERICOASSYNC = WM_USER + 2;
    WM_TIMERTHREADASSYNC          = WM_USER + 3;
    WM_TERMINATE                  = WM_USER + 4;
type
    TProcedure        = Procedure of object;
    TRProcedure       = reference to procedure;
    TStatus = class(TObject)
    public
      EmConsulta: Boolean;
      EmProcesso: Boolean;
    end;
    TDSList = record
      DS  : TDataSource;
      Qry : TAdoQuery;
      Status: TStatus;
    end;
    TSQLList          = record
      Qry: TADOQuery;
      Button: TButton;
      DS:  TDataSource;
      Connection: TADOConnection;
    end;
    TInformacoesAdicionais = class(TObject)
    public
      ID   : Integer;
      NomeProcedimento : String;
      Tag: NativeInt;
      CallBack: TProc;
    end;
    TRecordProcedure = record
      Procedimento : TProcedure;
      RProcedimento : TProc;
      Status : TStatus;
      SQLList: TSQLList;
      InformacoesAdicionais : TInformacoesAdicionais;
      DSList  : TList<TDSList>;
    end;
TThread = class(System.Classes.TThread)
private
    QtdeProcAsync: Integer;
    FilaProcAssyncPendentesDeExecucao: TList<TRecordProcedure>;
    FilaProcAssyncEmExecucao: TList<TRecordProcedure>;
    ID : Integer;
    Cores : TSystemInfo;
    Msg : TMsg;
    NomeProcedimento : TList<String>;
    Owner: TObject;
    procedure Dispatcher;
    procedure WMProcGenericoAssync(Msg: TMsg);
    procedure DesvincularComponente(DS: TDataSource);
    procedure VincularComponente(DS: TDataSource);
protected
    procedure Execute; override;
public
    RestInterval : Integer;
    EmProcesso: boolean;
    RecordProcedure:  TRecordProcedure;
    Connection: TADOConnection;
    Query: TADOQuery;
    DataSource: TDataSource;
    NaoPermitirFilaDeProcessos: Boolean;
    MyList:     TList<TSQLList>;
    FLock : TCriticalSection;
    procedure Synchronize(AMethod: TThreadMethod); overload; inline;
    procedure Synchronize(AThreadProc: TThreadProcedure); overload; inline;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure; NomeProcedimento: String);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc; NomeProcedimento: String);overload;
    procedure PrepararProcedimento(Procedimento: TRecordProcedure; NomeProcedimento: String);
    function  NovaConexao(DataSourceReferencia: TDataSource; ProcedimentoOrigem: String):TRecordProcedure;overload;
    procedure Kill;
    procedure CancelarConsulta(ProcedimentoOrigem: String);
end;
TForm = class(Vcl.Forms.TForm)
  procedure FormDestroy(Sender: TObject);
  procedure FormCreate(Sender: TObject);
  procedure ADOConnection1WillExecute(Connection: TADOConnection;
    var CommandText: WideString; var CursorType: TCursorType;
    var LockType: TADOLockType; var CommandType: TCommandType;
    var ExecuteOptions: TExecuteOptions; var EventStatus: TEventStatus;
    const Command: _Command; const Recordset: _Recordset);
private
  function IsForm: Boolean;
protected
  FOnDestroy: TNotifyEvent;
  FOnCreate:  TNotifyEvent;
  function GetOnDestroy: TNotifyEvent;
  function GetOnCreate: TNotifyEvent;
  property OnDestroy: TNotifyEvent read GetOnDestroy write FOnDestroy stored IsForm;
  property OnCreate: TNotifyEvent  read GetOnCreate  write FOnCreate stored IsForm;
public
  Thread : TThread;
end;
var
  Form: TForm;
implementation
{$R *.DFM}

uses Main;

procedure TForm.ADOConnection1WillExecute(Connection: TADOConnection;
    var CommandText: WideString; var CursorType: TCursorType;
    var LockType: TADOLockType; var CommandType: TCommandType;
    var ExecuteOptions: TExecuteOptions; var EventStatus: TEventStatus;
    const Command: _Command; const Recordset: _Recordset);
begin
  Recordset.Properties['Preserve on commit'].Value := True;
  Recordset.Properties['Preserve on abort'].Value := True;
end;

procedure TForm.FormCreate(Sender: TObject);
begin
  TForm(Sender).Thread       := TThread.Create(False);
  TForm(Sender).Thread.Owner := Sender;
end;

procedure TForm.FormDestroy(Sender: TObject);
begin
  if Thread <> nil
    then Thread.Kill;
end;

function TForm.GetOnCreate: TNotifyEvent;
begin
  FOnCreate := FormCreate;
  Result    := FOnCreate;
end;

function TForm.GetOnDestroy: TNotifyEvent;
begin
  FOnDestroy := FormDestroy;
  result := FOnDestroy;
end;

function TForm.IsForm: Boolean;
begin
  Result := true;
end;
// ------------------- THREAD CONSULTA -------------------- //

procedure TThread.Execute;
begin
  RestInterval := 1;
  FreeOnTerminate := self.Finished;
  if FilaProcAssyncEmExecucao = nil
    then FilaProcAssyncEmExecucao := TList<TRecordProcedure>.Create;
  FLock := TCriticalSection.Create;
  GetSystemInfo(Cores);
  NomeProcedimento := TList<String>.Create;
  while not Terminated do begin
    Dispatcher;
  end;
end;

procedure TThread.Dispatcher;
var ThreadAntiga : TThread;
begin
  Sleep(RestInterval);
  if PeekMessage(Msg, 0, 0, 0, PM_NOREMOVE) then begin
    if Integer(Cores.dwNumberOfProcessors) > 2 // 1 núcleo e 2 threads ou inferior
      then while QtdeProcAsync >= (Integer(Cores.dwNumberOfProcessors) - 1) do sleep(RestInterval) //Otimização para hardware não sobrecarregar de processos pessados.
      else while QtdeProcAsync > 2 do sleep(RestInterval); // ele só aceita realizar dois processos assyncronos por vez
    EmProcesso := true;
    ID := ID + 1;
    try
      try
        case Msg.Message of
          WM_PROCEDIMENTOGENERICOASSYNC: WMProcGenericoAssync(Msg);
          WM_DESTROY:                    Destroy;
          WM_TERMINATE:                  Terminate;
        end;
      finally
        EmProcesso := false;
        PeekMessage(Msg, 0, 0, 0, PM_REMOVE);
      end;
    except
      ThreadAntiga := Self;
      TForm(Owner).Thread := TThread.Create(false);
      ThreadAntiga.Terminate;
    end;
  end
end;

procedure TThread.ProcedimentoGenericoAssync(Procedimento: TProcedure);
begin
  ProcedimentoGenericoAssync(Procedimento,'');
end;

procedure TThread.ProcedimentoGenericoAssync(Procedimento: TProc);
begin
  ProcedimentoGenericoAssync(Procedimento,'');
end;

procedure TThread.ProcedimentoGenericoAssync(Procedimento: TProcedure; NomeProcedimento: String);
begin
  FLock.Acquire;
  RecordProcedure.Procedimento := Procedimento;
  PrepararProcedimento(RecordProcedure, NomeProcedimento);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 0, 0);
  FLock.Release;
end;

procedure TThread.ProcedimentoGenericoAssync(Procedimento: TProc; NomeProcedimento: String);
begin
  FLock.Acquire;
  RecordProcedure.RProcedimento := Procedimento;
  PrepararProcedimento(RecordProcedure, NomeProcedimento);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 1, 0);
  FLock.Release;
end;

procedure TThread.PrepararProcedimento(Procedimento: TRecordProcedure;  NomeProcedimento: String);
begin
  if NaoPermitirFilaDeProcessos and EmProcesso
    then exit;
  if FilaProcAssyncPendentesDeExecucao = nil
    then  FilaProcAssyncPendentesDeExecucao := TList<TRecordProcedure>.Create;
  Procedimento.InformacoesAdicionais := TInformacoesAdicionais.Create;
  Procedimento.InformacoesAdicionais.NomeProcedimento := NomeProcedimento;
  Procedimento.DSList :=  TList<TDSList>.Create;
  Procedimento.Status := TStatus.Create;
  FilaProcAssyncPendentesDeExecucao.Add(Procedimento);
end;

procedure TThread.WMProcGenericoAssync(Msg: TMsg);
var
  Procedimento: TProc;
  RecordProcedure: TRecordProcedure;
  I: Integer;
begin
  RecordProcedure := FilaProcAssyncPendentesDeExecucao.ExtractAt(0);// Pegando primeira requisição da fila
  ID := ID + 1;
  RecordProcedure.InformacoesAdicionais.ID := ID;

  for I := 0 to FilaProcAssyncEmExecucao.Count - 1 do
  if (RecordProcedure.InformacoesAdicionais.NomeProcedimento = FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento) then begin
    exit;
  end;
  QtdeProcAsync := QtdeProcAsync + 1;
  RecordProcedure.Status.EmProcesso  := True;
  NomeProcedimento.Add(RecordProcedure.InformacoesAdicionais.NomeProcedimento);
  FilaProcAssyncEmExecucao.Add(RecordProcedure);
  EmProcesso := True;
  CreateAnonymousThread(
    procedure
    var
      I, L: Integer;
      RecordProcedure: TRecordProcedure;
      NomeProcedimento: String;
    begin
      Try
        FLock.Acquire;
        NomeProcedimento := Self.NomeProcedimento.ExtractAt(0);
        for I := 0 to FilaProcAssyncEmExecucao.Count - 1 do
        if FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento = NomeProcedimento  then break;
        RecordProcedure := FilaProcAssyncEmExecucao.Items[I];
        Self.EmProcesso := False;
        FLock.Release;
        if Integer(Msg.wParam) = 0
          then RecordProcedure.Procedimento
          else begin
            Procedimento := RecordProcedure.RProcedimento;
            Procedimento;
          end;
        if Self.Finished
          then exit;
        for L := 0 to RecordProcedure.DSList.Count - 1 do begin
          Synchronize(
          Procedure Begin
            if (RecordProcedure.DSList.Items[L].Status.EmConsulta) and (( stOpen in RecordProcedure.DSList.List[L].Qry.Connection.State))
              then begin
                if RecordProcedure.DSList.List[L].DS.DataSet = nil
                  then RecordProcedure.DSList.List[L].DS.DataSet := RecordProcedure.DSList.List[L].Qry;
                RecordProcedure.DSList.List[L].Qry.Connection.CommitTrans;
                RecordProcedure.DSList.List[L].Status.EmConsulta := False;
              end
              else RecordProcedure.DSList.List[L].Qry.Connection.Close;
          end);
          VincularComponente(RecordProcedure.DSList.List[L].DS);
        end;
        FilaProcAssyncEmExecucao.Remove(RecordProcedure);
      Finally
        QtdeProcAsync := QtdeProcAsync - 1;
      End;
    end).Start;
  while EmProcesso do Sleep(RestInterval);
end;

function TThread.NovaConexao(DataSourceReferencia: TDataSource; ProcedimentoOrigem: String):TRecordProcedure;
// é importante criar uma nova conexão ao acessar o banco pra não dar erro de ter duas consultas
// retornando resultado ao mesmo tempo, e também para permitir o rollback sem afetar as outras consultas...
begin
  Self.Synchronize(
  Procedure
  var
    I: Integer;
    SQLList: TSQLList;
    Status: TStatus;
    RecordProcedureRetorno: TRecordProcedure;
    DSList: TDSList;
    WillExecuteEvent : TMethod;
  begin
    ID := ID + 1;
    DataSourceReferencia.Enabled := False;
    DesvincularComponente(DataSourceReferencia);
    DataSourceReferencia.Enabled := True;
    RecordProcedureRetorno.SQLList.Connection                      := TADOConnection.Create(Form);
    RecordProcedureRetorno.SQLList.Connection.ConnectionString     := TAdoQuery(DataSourceReferencia.DataSet).Connection.ConnectionString;
    RecordProcedureRetorno.SQLList.Connection.ConnectionTimeout    := TAdoQuery(DataSourceReferencia.DataSet).Connection.ConnectionTimeout;
    RecordProcedureRetorno.SQLList.Connection.ConnectOptions       := TAdoQuery(DataSourceReferencia.DataSet).Connection.ConnectOptions;
    RecordProcedureRetorno.SQLList.Connection.CursorLocation       := TAdoQuery(DataSourceReferencia.DataSet).Connection.CursorLocation;
    RecordProcedureRetorno.SQLList.Connection.DefaultDatabase      := TAdoQuery(DataSourceReferencia.DataSet).Connection.DefaultDatabase;
    RecordProcedureRetorno.SQLList.Connection.IsolationLevel       := TAdoQuery(DataSourceReferencia.DataSet).Connection.IsolationLevel;
    RecordProcedureRetorno.SQLList.Connection.KeepConnection       := TAdoQuery(DataSourceReferencia.DataSet).Connection.KeepConnection;
    RecordProcedureRetorno.SQLList.Connection.LoginPrompt          := TAdoQuery(DataSourceReferencia.DataSet).Connection.LoginPrompt;
    RecordProcedureRetorno.SQLList.Connection.Mode                 := TAdoQuery(DataSourceReferencia.DataSet).Connection.Mode;
    RecordProcedureRetorno.SQLList.Connection.Name                 := 'Thread'+IntToStr(ID)+IntToStr(Self.ThreadID)+TAdoQuery(DataSourceReferencia.DataSet).Connection.Name;
    RecordProcedureRetorno.SQLList.Connection.Provider             := TAdoQuery(DataSourceReferencia.DataSet).Connection.Provider;
    RecordProcedureRetorno.SQLList.Connection.Tag                  := TAdoQuery(DataSourceReferencia.DataSet).Connection.Tag;
    RecordProcedureRetorno.SQLList.Qry                             := TAdoQuery(DataSourceReferencia.DataSet);
    RecordProcedureRetorno.SQLList.Connection.Connected := True;
    RecordProcedureRetorno.SQLList.Qry.Connection                  := RecordProcedureRetorno.SQLList.Connection;
    RecordProcedureRetorno.SQLList.DS                              := DataSourceReferencia;
    RecordProcedureRetorno.SQLList.Connection.Connected            := True;
    WillExecuteEvent.Data := Pointer(TForm);
    WillExecuteEvent.Code := TForm.MethodAddress('ADOConnection1WillExecute');
    RecordProcedureRetorno.SQLList.Connection.OnWillExecute        := TWillExecuteEvent(WillExecuteEvent);
    RecordProcedureRetorno.SQLList.Connection.BeginTrans;
    for I := 0 to FilaProcAssyncEmExecucao.Count - 1 do
    if ProcedimentoOrigem = FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento
      then begin
        RecordProcedure := FilaProcAssyncEmExecucao.Items[I];
        Status := RecordProcedure.Status;
        Status.EmConsulta        := True;
        DSList.DS                := DataSourceReferencia;
        DSList.Status            := TStatus.Create;
        DSList.Status.EmConsulta := True;
        DSList.Qry               := TAdoQuery(DataSourceReferencia.DataSet);
        RecordProcedure.DSList.Add(DSList);
        RecordProcedure.SQLList         := RecordProcedureRetorno.SQLList;
      end;
    FLock.Acquire;
    RecordProcedure := RecordProcedureRetorno;
  end);
  Result := RecordProcedure;
  FLock.Release;
end;

procedure TThread.CancelarConsulta(ProcedimentoOrigem: String);
begin
  Queue(
  Procedure
  var
  I, J: Integer;
  Procedimento : TRecordProcedure;
  Recordset : _Recordset;
  begin
    for I := 0 to FilaProcAssyncEmExecucao.Count - 1 do
    if FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento = ProcedimentoOrigem then begin
      if (FilaProcAssyncEmExecucao.Items[I].Status.EmProcesso) and (FilaProcAssyncEmExecucao.Items[I].Status.EmConsulta) then begin
        Procedimento := FilaProcAssyncEmExecucao.Items[I];
        for J := 0 to  Procedimento.DSList.Count - 1 do begin
          try
            if ( Procedimento.DSList.Items[J].Status.EmConsulta ) and
               ( stOpen in Procedimento.DSList.Items[J].Qry.Connection.State)
              then begin
                Procedimento.DSList.Items[J].Qry.Connection.RollbackTrans;
              end;
          finally
            Procedimento.DSList.Items[J].Status.EmConsulta := False;
            Procedimento.DSList.Items[J].DS.Enabled := False;
          end;
        end;
      end;
    end;
  end);
end;

procedure TThread.Kill;
var
  I: integer;
begin
  try
    for I := 0 to FilaProcAssyncEmExecucao.Count - 1 do CancelarConsulta(FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento);//Cancelando todas as consultas
  finally
    FreeAndNil(FLock);
    if (EmProcesso) or (QtdeProcAsync <> 0)
      then Destroy
      else Terminate;
  end;
end;

procedure TThread.DesvincularComponente(DS: TDataSource);
var
  i: integer;
  Form: TForm;
  DSAux : TDataSource;
begin
  Form := TForm(DS.Owner);
  for i := 0 to (Form.ComponentCount - 1) do begin
    if (Form.Components[i] is TDBGrid)  and (TDBGrid(Form.Components[i]).DataSource = DS)
      then begin
        ID := ID + 1;
        DSAux      := TDataSource.Create(Form);
        DSAux.Name := DS.Name+'INACTIVE'+IntToStr(ID);
        Synchronize(Procedure begin TDBGrid(Form.Components[i]).DataSource := DSAux; end);
      end
      else
    if (Form.Components[i] is TDBMemo)  and (TDBMemo(Form.Components[i]).DataSource = DS)
      then begin
        ID := ID + 1;
        DSAux      := TDataSource.Create(Form);
        DSAux.Name := DS.Name+'INACTIVE'+IntToStr(ID);
        Synchronize(Procedure begin TDBMemo(Form.Components[i]).DataSource := DSAux; end);
      end;
  end;
end;

procedure TThread.VincularComponente(DS: TDataSource);
var
  i: integer;
  Form: TForm;
begin
  Form := TForm(DS.Owner);
  for i := 0 to (Form.ComponentCount - 1) do begin
    if (Form.Components[i] is TDBGrid)  and (Copy(String(TDBGrid(Form.Components[i]).DataSource.Name),0,Pos('INACTIVE', String(TDBGrid(Form.Components[i]).DataSource.Name))-1) = DS.Name)
      then begin
        Synchronize(Procedure begin
          TDBGrid(Form.Components[i]).DataSource := DS;
          DS.Enabled := True;
        end);
      end
      else
    if (Form.Components[i] is TDBMemo)  and (Copy(String(TDBMemo(Form.Components[i]).DataSource.Name),0,Pos('INACTIVE', String(TDBMemo(Form.Components[i]).DataSource.Name))-1) = DS.Name)
      then begin
        Synchronize(
        Procedure begin
          TDBMemo(Form.Components[i]).DataSource := DS;
          DS.Enabled := True;
        end);
      end
  end;
end;

procedure TThread.Synchronize(AMethod: TThreadMethod);
begin
  Synchronize(Self, AMethod);
end;

procedure TThread.Synchronize(AThreadProc: TThreadProcedure);
begin
  Synchronize(Self, AThreadProc);
end;

end.

