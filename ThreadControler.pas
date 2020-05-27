//  Inherited;
//  Thread.Start;
unit ThreadControler;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Vcl.StdCtrls,
    System.TypInfo, Generics.Collections, Vcl.ExtCtrls, Vcl.DBCtrls,
    SyncObjs, Vcl.Themes, Vcl.Buttons, Data.Win.ADODB, Winapi.ADOInt;

const
    WM_OPEN                       = WM_USER + 1;
    WM_PROCEDIMENTOGENERICOASSYNC = WM_USER + 2;
    WM_TIMERTHREADASSYNC          = WM_USER + 3;
    WM_TERMINATE                  = WM_USER + 4;
procedure InfoBox(Mensagem: String);
Function  CopiarObjetoConexao(Connection:TAdoConnection): TAdoConnection;
type
    TProcedure        = Procedure of object;
    TRProcedure       = reference to procedure;
    TStatus = class(TObject)
    public
      FEmConsulta: Boolean;
      EmProcesso: Boolean;
    end;
TComponent = class(System.Classes.TComponent)
public
  FComponents: TList<TComponent>;
end;
TADOQuery = class(Data.Win.ADODB.TADOQuery)
  private
    FSpeedButton: TSpeedButton;
    FButton:      TButton;
    FCheckBox:    TCheckBox;
    FEmConsulta : Boolean;
    FTPCallBack: TProc;
    procedure SetComponenteVinculado(ComponenteVinculado : TObject);overload;
    function  GetComponenteVinculado:TObject;
    procedure ADOConnection1WillExecute(Connection: TADOConnection;
      var CommandText: WideString; var CursorType: TCursorType;
      var LockType: TADOLockType; var CommandType: TCommandType;
      var ExecuteOptions: TExecuteOptions; var EventStatus: TEventStatus;
      const Command: _Command; const Recordset: _Recordset);
  public
  CaptionAnterior : TCaption;
  Cancelado: Boolean;
  property ComponenteVinculado: TObject read GetComponenteVinculado write SetComponenteVinculado;
  property  EmConsulta: Boolean read FEmConsulta;
  procedure OpenAssync;
  procedure Open;overload;
  procedure Open(CallBack:TProc);overload;
  procedure Open(CallBack:TProc; ComponenteVinculado: TObject);overload;
  procedure Open(CallBack:TProcedure);overload;
  procedure Open(CallBack:TProcedure; ComponenteVinculado: TObject);overload;
  procedure Cancelar;
  procedure EOnFetchProgress(DataSet: TCustomADODataSet; Progress, MaxProgress: Integer; var EventStatus: TEventStatus);
  procedure EOnFetchComplete(DataSet: TCustomADODataSet; const Error: Error; var EventStatus: TEventStatus);
  procedure ECBOnFetchComplete(DataSet: TCustomADODataSet; const Error: Error; var EventStatus: TEventStatus);
  procedure CompletarConsulta(DataSet:TCustomADODataSet);
  procedure PrepararOpen(EOnFetchComplete:TRecordsetEvent);
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
    function  NovaConexao(DataSourceReferencia: TDataSource; ProcedimentoOrigem: String; ComponenteVinculado: TObject):TRecordProcedure;overload;
    procedure Kill;
    procedure CancelarConsulta(ProcedimentoOrigem: String);
end;
TForm = class(Vcl.Forms.TForm)
  procedure FormDestroy(Sender: TObject);
  procedure FormCreate(Sender: TObject);
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

function TForm.GetOnCreate: TNotifyEvent;
begin
  FOnCreate := FormCreate;
  Result    := FOnCreate;
end;

procedure TForm.FormCreate(Sender: TObject);
begin
  Thread  := TThread.Create(True);
  TForm(Sender).Thread.Owner := Sender;
end;

procedure TForm.FormDestroy(Sender: TObject);
begin
  if Thread <> nil
    then Thread.Kill;
end;

function TForm.GetOnDestroy: TNotifyEvent;
begin
  FOnDestroy := FormDestroy;
  result := FOnDestroy;
end;

function TForm.IsForm: Boolean;//Esse controlador de thread s� funciona em forms (para startar) !!!
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
    if Integer(Cores.dwNumberOfProcessors) > 2 // 1 n�cleo e 2 threads ou inferior
      then while QtdeProcAsync >= (Integer(Cores.dwNumberOfProcessors) - 1) do sleep(RestInterval) //Otimiza��o para hardware n�o sobrecarregar de processos pessados.
      else while QtdeProcAsync > 2 do sleep(RestInterval); // ele s� aceita realizar dois processos assyncronos por vez
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
  RecordProcedure := FilaProcAssyncPendentesDeExecucao.ExtractAt(0);// Pegando primeira requisi��o da fila
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
            if (RecordProcedure.DSList.Items[L].Status.FEmConsulta) and (( stOpen in RecordProcedure.DSList.List[L].Qry.Connection.State))
              then begin
                if RecordProcedure.DSList.List[L].DS.DataSet = nil
                  then RecordProcedure.DSList.List[L].DS.DataSet := RecordProcedure.DSList.List[L].Qry;
                RecordProcedure.DSList.List[L].Status.FEmConsulta := False;
              end
              else begin
                RecordProcedure.DSList.List[L].Qry.Connection.Close;
              end;
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

function TThread.NovaConexao(DataSourceReferencia: TDataSource; ProcedimentoOrigem: String; ComponenteVinculado: TObject): TRecordProcedure;
begin
  TAdoQuery(DataSourceReferencia.DataSet).ComponenteVinculado := ComponenteVinculado;
  Result := NovaConexao(DataSourceReferencia,ProcedimentoOrigem);
end;

function TThread.NovaConexao(DataSourceReferencia: TDataSource; ProcedimentoOrigem: String):TRecordProcedure;
// � importante criar uma nova conex�o ao acessar o banco pra n�o dar erro de ter duas consultas
// retornando resultado ao mesmo tempo, e tamb�m para permitir o rollback sem afetar as outras consultas...
begin
  Self.Synchronize(
  Procedure
  var
    I: Integer;
    SQLList: TSQLList;
    Status: TStatus;
    RecordProcedureRetorno: TRecordProcedure;
    DSList: TDSList;
  begin
    ID := ID + 1;
    DataSourceReferencia.Enabled := False;
    DesvincularComponente(DataSourceReferencia);
    DataSourceReferencia.Enabled := True;
    RecordProcedureRetorno.SQLList.Connection           := CopiarObjetoConexao(TAdoQuery(DataSourceReferencia.DataSet).Connection);
    RecordProcedureRetorno.SQLList.Connection.Name      := 'Thread'+IntToStr(ID)+IntToStr(Self.ThreadID)+TAdoQuery(DataSourceReferencia.DataSet).Connection.DataSets[0].Name;
    RecordProcedureRetorno.SQLList.Qry                  := TAdoQuery(DataSourceReferencia.DataSet);
    RecordProcedureRetorno.SQLList.Connection.Connected := True;
    RecordProcedureRetorno.SQLList.Qry.Connection       := RecordProcedureRetorno.SQLList.Connection;
    RecordProcedureRetorno.SQLList.DS                   := DataSourceReferencia;
    RecordProcedureRetorno.SQLList.Connection.Connected := True;

    for I := 0 to FilaProcAssyncEmExecucao.Count - 1 do
    if ProcedimentoOrigem = FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento
      then begin
        RecordProcedure := FilaProcAssyncEmExecucao.Items[I];
        Status := RecordProcedure.Status;
        Status.FEmConsulta        := True;
        DSList.DS                := DataSourceReferencia;
        DSList.DS.Enabled        := True;
        DSList.Status            := TStatus.Create;
        DSList.Status.FEmConsulta := True;
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

function CopiarObjetoConexao(Connection:TAdoConnection): TAdoConnection;
var
  ConnectionResult: TAdoConnection;
begin
    ConnectionResult                      := TADOConnection.Create(Form);
    ConnectionResult.ConnectionString     := Connection.ConnectionString;
    ConnectionResult.ConnectionTimeout    := Connection.ConnectionTimeout;
    ConnectionResult.ConnectOptions       := Connection.ConnectOptions;
    ConnectionResult.CursorLocation       := Connection.CursorLocation;
    ConnectionResult.DefaultDatabase      := Connection.DefaultDatabase;
    ConnectionResult.IsolationLevel       := Connection.IsolationLevel;
    ConnectionResult.KeepConnection       := Connection.KeepConnection;
    ConnectionResult.LoginPrompt          := Connection.LoginPrompt;
    ConnectionResult.Mode                 := Connection.Mode;
    ConnectionResult.Provider             := 'SQLNCLI11.1';
    ConnectionResult.Tag                  := Connection.Tag;
    ConnectionResult.CommandTimeout       := Connection.CommandTimeout;
    Result := ConnectionResult;
end;

procedure TThread.CancelarConsulta(ProcedimentoOrigem: String);
begin
  Queue(
  Procedure
  var
  I, J: Integer;
  Procedimento : TRecordProcedure;
  begin
    for I := 0 to FilaProcAssyncEmExecucao.Count - 1 do
    if FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento = ProcedimentoOrigem then begin
      if (FilaProcAssyncEmExecucao.Items[I].Status.EmProcesso) and (FilaProcAssyncEmExecucao.Items[I].Status.FEmConsulta) then begin
        Procedimento := FilaProcAssyncEmExecucao.Items[I];
        for J := 0 to  Procedimento.DSList.Count - 1 do begin
          try
            Procedimento.DSList.Items[J].Qry.Cancelar;
          finally
            Procedimento.DSList.Items[J].Status.FEmConsulta := False;
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
    while QtdeProcAsync > 0 do sleep(RestInterval);
    Terminate;
    WaitFor;
    Free;
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

////////////////////////QUERY FACILITADORES////////////////////////////

procedure TADOQuery.ADOConnection1WillExecute(Connection: TADOConnection;
    var CommandText: WideString; var CursorType: TCursorType;
    var LockType: TADOLockType; var CommandType: TCommandType;
    var ExecuteOptions: TExecuteOptions; var EventStatus: TEventStatus;
    const Command: _Command; const Recordset: _Recordset);
begin
  Recordset.Properties['Preserve on commit'].Value := True;//  Ap�s confirmar uma transa��o, o conjunto de registros permanece ativo. Portanto, � poss�vel buscar novas linhas; atualizar, excluir e inserir linhas; e assim por diante.
  Recordset.Properties['Preserve on abort'].Value := True;//	Ap�s abortar uma transa��o, o conjunto de registros permanece ativo. Portanto, � poss�vel buscar novas linhas, atualizar, excluir e inserir linhas e assim por diante.
end;

procedure TADOQuery.SetComponenteVinculado(ComponenteVinculado : TObject);
begin
  if ComponenteVinculado is TSpeedButton
    then begin
      FSpeedButton := TSpeedButton(ComponenteVinculado);
      CaptionAnterior := FSpeedButton.Caption;
      FButton   := nil;
      FCheckBox := nil;
    end
    else
  if ComponenteVinculado is TButton
    then begin
      FButton := TButton(ComponenteVinculado);
      CaptionAnterior := FButton.Caption;
      FSpeedButton := nil;
      FCheckBox    := nil;
    end
    else
  if ComponenteVinculado is TCheckBox
    then begin
      FCheckBox := TCheckBox(ComponenteVinculado);
      CaptionAnterior := FCheckBox.Caption;
      FSpeedButton := nil;
      FButton      := nil;
    end
    else Exception.Create('Tipo n�o programado!');
end;

function TADOQuery.GetComponenteVinculado: TObject;
begin
  if FSpeedButton<>nil
    then Result := FSpeedButton
    else
  if FButton <> nil
    then Result := FButton
    else
  if FCheckBox <> nil
    then Result := FCheckBox
    else Result := nil;
end;

procedure TADOQuery.Cancelar;
begin
  if (ComponenteVinculado <> nil) then begin
    if ( (ComponenteVinculado is TSpeedButton) and (TSpeedButton(ComponenteVinculado).Caption = 'Cancelar') ) or
       ( (ComponenteVinculado is TButton     ) and (TButton     (ComponenteVinculado).Caption = 'Cancelar') ) or
       ( (ComponenteVinculado is TCheckBox   ) and (TCheckBox   (ComponenteVinculado).Caption = 'Cancelar') )
      then begin
        Cancelado := True;
      end;
  end;
end;

procedure TADOQuery.EOnFetchProgress(DataSet: TCustomADODataSet; Progress, MaxProgress: Integer; var EventStatus: TEventStatus);
var ThreadAux : TThread;
begin
  if Cancelado and (Connection.InTransaction)
    then Connection.RollbackTrans;
  Cancelado := False;
end;

procedure TADOQuery.EOnFetchComplete(DataSet: TCustomADODataSet; const Error: Error; var EventStatus: TEventStatus);
var ThreadAux : TThread;
begin
  CompletarConsulta(DataSet);
end;

procedure TAdoQuery.OpenAssync;//Starta uma consulta de forma assyncrona independente de Thread, por�m n�o espera a consulta terminar, para cancelar tem que chamar o diretamente o m�todo cancelar da qry.
var WillExecuteEvent : TMethod;
    Form : TForm;
    I: Integer;
    DataSource: TDataSource;
begin
  if ComponenteVinculado = nil
    then raise Exception.Create('Button n�o configurado');
  PrepararOpen(EOnFetchComplete);
end;

procedure TAdoQuery.Open;
begin
  if ComponenteVinculado <> nil
    then begin//O button da qry deve ser preenchido dentro da Thread(pois para cancelar esse componente deve conter o tratamento), ent�o esperar n�o causa problemas
      if Connection.InTransaction
        then EXIT
        else
      if (ComponenteVinculado is TCheckBox) and (not (TCheckBox(ComponenteVinculado)).Checked)
        then EXIT;
      OpenAssync;
      while FEmConsulta do Sleep(50);
    end
    else begin
      if not FEmConsulta
        then PrepararOpen(EOnFetchComplete);
      TForm(Owner).Enabled := False;
      while FEmConsulta do Application.ProcessMessages;//Aqui est� a "m�gica"
      TForm(Owner).Enabled := True;
    end;
end;

procedure TADOQuery.CompletarConsulta(DataSet:TCustomADODataSet);
begin
  TForm(Owner).Thread.Synchronize(
  Procedure begin
    DataSet.Resync([]);
    if Connection.InTransaction
      then Connection.CommitTrans;
    if (ComponenteVinculado is TSpeedButton)
      then TSpeedButton(ComponenteVinculado).Caption := CaptionAnterior
      else
    if (ComponenteVinculado is TButton)
      then TButton(ComponenteVinculado)     .Caption := CaptionAnterior
      else
    if (ComponenteVinculado is TCheckBox)
      then TCheckBox(ComponenteVinculado)   .Caption := CaptionAnterior;
    FEmConsulta := False;
    Cancelado := False;
  end);
end;

procedure TADOQuery.PrepararOpen(EOnFetchComplete:TRecordsetEvent);
var WillExecuteEvent : TMethod;
    ThreadAux : TThread;
begin
  if Connection.InTransaction
    then EXIT
    else
  if (ComponenteVinculado is TCheckBox) and (not (TCheckBox(ComponenteVinculado)).Checked)
    then EXIT;
  Close;
  ThreadAux :=
  ThreadControler.TThread(
  TThread.CreateAnonymousThread(
    Procedure begin
      ThreadAux.Synchronize(
        procedure begin
          Connection := CopiarObjetoConexao(Connection);
          WillExecuteEvent.Data := Pointer(TADOQuery);
          WillExecuteEvent.Code := TADOQuery.MethodAddress('ADOConnection1WillExecute');
          Connection.OnWillExecute := TWillExecuteEvent(WillExecuteEvent);
          OnFetchProgress := EOnFetchProgress;
          OnFetchComplete := EOnFetchComplete;
          ExecuteOptions := [eoAsyncExecute, eoAsyncFetchNonBlocking];
          Connection.Connected := True;
        end);
      ThreadAux.Terminate;
    end));
  ThreadAux.Start;
  while not ThreadAux.Terminated do Application.ProcessMessages;
  Connection.BeginTrans;
  if ComponenteVinculado <> nil then begin
    if (ComponenteVinculado is TSpeedButton)
      then TSpeedButton(ComponenteVinculado).Caption := 'Cancelar'
      else
    if (ComponenteVinculado is TButton)
      then TButton(ComponenteVinculado)     .Caption := 'Cancelar'
      else
    if (ComponenteVinculado is TCheckBox)
      then TCheckBox(ComponenteVinculado)   .Caption := 'Cancelar';
  end;
  FEmConsulta := True;
  Try
    Active := True;
  Except
    on E:Exception do begin
      Infobox('Houve um problema ao tentar realizar a consulta no banco de dados:' + E.Message);
      abort;
    end;
  end;
end;

procedure TADOQuery.ECBOnFetchComplete(DataSet: TCustomADODataSet;
  const Error: Error; var EventStatus: TEventStatus);
begin
  CompletarConsulta(DataSet);
  FTPCallBack;
end;

procedure TADOQuery.Open(CallBack: TProc);
var ThreadAux  : TThread;
    I          : Integer;
    DataSource : TDataSource;
begin
  for I := 0 to TForm(Owner).ComponentCount - 1 do  // Localizando DataSource
  if TForm(Owner).Components[I] IS TDataSource
    then if TDataSource(TForm(Owner).Components[I]).DataSet.Name = Self.Name
      then  DataSource := TDataSource(TForm(Owner).Components[I]);
  if DataSource = Nil
    then raise Exception.Create('DataSource n�o configurado');

  if FEmConsulta
    then begin
      Cancelar;
      DataSource.Enabled := False;
    end
    else begin
      FTPCallBack := CallBack;
      PrepararOpen(ECBOnFetchComplete);
      DataSource.Enabled := True;
    end
end;

procedure TADOQuery.Open(CallBack: TProcedure);
var Proc: TProc;
begin
  Proc := Procedure Begin CallBack end;
  Open(Proc);
end;

procedure TADOQuery.Open(CallBack: TProc; ComponenteVinculado: TObject);
begin
  if Self.ComponenteVinculado <> ComponenteVinculado
    then Self.ComponenteVinculado := ComponenteVinculado;
  Open(CallBack);
end;

procedure TADOQuery.Open(CallBack: TProcedure; ComponenteVinculado: TObject);
begin
  if Self.ComponenteVinculado <> ComponenteVinculado
    then Self.ComponenteVinculado := ComponenteVinculado;
  Open(CallBack);
end;

procedure InfoBox(Mensagem: String);
begin
  Application.BringToFront;
  Application.MessageBox( PChar(Mensagem), 'Aten��o',MB_OK + MB_ICONINFORMATION);
end;
end.

