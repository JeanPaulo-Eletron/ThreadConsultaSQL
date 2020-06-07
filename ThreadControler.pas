unit ThreadControler;
//Feito por: Jean Paulo Athanazio De Mei
{     Anotações:
      Bloqueada ---> verificar se threads estão bloqueada, para atender sobe demanda. ---> Monitor(Para aumentar a qtde sobe demanda """(Cores.dwNumberOfProcessors - 1) + IdlenessIndex(Uma expressão matemática logaritma baseada na memoria ram e no numero de cores[Uso intensivo de CPU, Uso intensivo de HD --> Por meta dados])""")
      Threshold ---> Limiar   NODE X APACHE(LENTIDÃO).
      Inferno da DLL e CALLBACKS e usar promices fica mais simples.
}
// Timer foi criado para possibilitar ser thread save(Porém depois fazendo alguns testes com componente,
// percebi que com algumas adptações manuais(como dar enabled false quando iniciar e true quando terminar,
// e criar um váriavel global para saber se está executando quando mecher no enabled dele
// porem se quiser inativar depois da execução terá que tratar manualmente]) dá pra usar ele,
// use qual preferir, mas o timer da thread é próprio para isso).

// é intessante ver as opções do próprios componentes ADO para conexões assyncronas;
interface

uses Data.Win.ADODB, System.SysUtils, System.Classes, Generics.Collections, Winapi.Windows,
     Data.DB, SyncObjs, Forms, Winapi.Messages, Vcl.StdCtrls;
const
    WM_OPEN                       = WM_USER + 1;
    WM_PROCEDIMENTOGENERICOASSYNC = WM_USER + 2;
    WM_TIMERTHREADASSYNC          = WM_USER + 3;
    WM_TERMINATE                  = WM_USER + 4;

Type
    TProcedure        = Procedure of object;
    TRProcedure       = reference to procedure;
    TStatus = class(TObject)
    public
      FEmConsulta: Boolean;
      EmProcesso: Boolean;
    end;
    TDSList = record
      DS  : TDataSource;
      Qry : TAdoQuery;
      Status: TStatus;
    end;
    TSQLList          = record
      Qry: TAdoQuery;
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
procedure InfoBox(Mensagem: String);
Function  CopiarObjetoConexao(Connection:TAdoConnection): TAdoConnection;
Function  LocalizarProcedurePeloNome(NomeProcedure: String; ClasseReferencia: TClass):TMethod;
Procedure Syncronized(Procedimento:TProc);
Type
TThread = class(System.Classes.TThread)
private
    procedure Dispatcher;
    procedure WMProcGenericoAssync(Msg: TMsg);
protected
    QtdeProcAsync: Integer;
    FilaProcAssyncPendentesDeExecucao: TList<TRecordProcedure>;
    FilaProcAssyncEmExecucao: TList<TRecordProcedure>;
    ID : Integer;
    Cores : TSystemInfo;
    Msg : TMsg;
    NomeProcedimento : TList<String>;
    procedure Execute; override;
public
    RestInterval : Integer;
    EmProcesso: boolean;
    RecordProcedure:  TRecordProcedure;
    Query: TAdoQuery;
    DataSource: TDataSource;
    NaoPermitirFilaDeProcessos: Boolean;
    MyList:     TList<TSQLList>;
    FLock : TCriticalSection;
    Owner: TObject;
    procedure Synchronize(AMethod: TThreadMethod); overload; inline;
    procedure Synchronize(AThreadProc: TThreadProcedure); overload; inline;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure; NomeProcedimento: String);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc; NomeProcedimento: String);overload;
    procedure PrepararProcedimento(Procedimento: TRecordProcedure; NomeProcedimento: String);
    function  NovaConexao(DataSourceReferencia: TDataSource; ProcedimentoOrigem: String):TRecordProcedure;overload;
    procedure Kill;
end;


implementation

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
      Self.Terminate;
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
    Status: TStatus;
    RecordProcedureRetorno: TRecordProcedure;
    DSList: TDSList;
  begin
    ID := ID + 1;
    DataSourceReferencia.Enabled := False;
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

procedure TThread.Kill;
var
  I: integer;
begin
  FreeAndNil(FLock);
  while QtdeProcAsync > 0 do sleep(RestInterval);
  Terminate;
  WaitFor;
  Free;
end;

procedure TThread.Synchronize(AMethod: TThreadMethod);
begin
  Synchronize(Self, AMethod);
end;

procedure TThread.Synchronize(AThreadProc: TThreadProcedure);
begin
  Synchronize(Self, AThreadProc);
end;

procedure InfoBox(Mensagem: String);
begin
  Application.BringToFront;
  Application.MessageBox(PChar(Mensagem), 'Atenção',MB_OK + MB_ICONINFORMATION);
end;

function LocalizarProcedurePeloNome(NomeProcedure: String; ClasseReferencia: TClass):TMethod;
var Method: TMethod;
begin
  Method.Data := Pointer(ClasseReferencia);
  Method.Code := TAdoQuery.MethodAddress('ADOConnection1WillExecute');
  Result := Method;
end;

function CopiarObjetoConexao(Connection:TAdoConnection): TAdoConnection;
var
  ConnectionResult: TAdoConnection;
begin
    ConnectionResult                      := TADOConnection.Create(Application);
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

procedure Syncronized(Procedimento:TProc);
var ThreadAux : TThread;
begin
  ThreadAux :=
  TThread(
  TThread.CreateAnonymousThread(
    Procedure begin
      ThreadAux.Synchronize(
        procedure begin
          Procedimento;
        end);
      ThreadAux.Terminate;
    end));
  ThreadAux.Start;
  while not ThreadAux.Terminated do Application.ProcessMessages;
end;

end.
