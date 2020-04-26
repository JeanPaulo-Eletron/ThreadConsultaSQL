//Feito por: Jean Paulo Athanazio De Mei
//Coloque Assync no nome do componente para torna-lo Utilizavél por várias threads
//ao mesmo tempo, não colocando ele só pode ser utilizado por uma thread por vez.
//com o assync por enquanto se deve colocar o DS da grid não o DS diretamente, irei
//corrigir esse problema em breve.
unit Main;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    System.Rtti, System.TypInfo, Generics.Collections, Vcl.ExtCtrls,
    Vcl.DBCtrls;

const
    WM_OPEN                       = WM_USER + 1;
    WM_PROCEDIMENTOGENERICO       = WM_USER + 2;
    WM_PROCEDIMENTOGENERICOASSYNC = WM_USER + 3;
    WM_TIMERP                     = WM_USER + 4;
    WM_TIMERASSYNC                = WM_USER + 5;
    WM_TERMINATE                  = WM_USER + 6;
type
    TProcedure        = Procedure of object;
    TRProcedure       = reference to procedure;
    TSQLList          = record
      Qry: TADOQuery;
      Button: TButton;
      DS:  TDataSource;
      Connection: TADOConnection;
    end;
    TRecordProcedure = record
      Procedimento : TProcedure;
      RProcedimento : TProc;
      Tipo : Integer;
      ID   : Integer;
      MetaDado : String;
      NomeProcedimento : String;
      DSList  : TList<TDataSource>;
    end;
type
    TThreadMain = class(TThread)
private
    QtdeProcAsync: Integer;
    MyListProc: TList<TRecordProcedure>;
    MyListProcAssync: TList<TRecordProcedure>;
    MyListProcWillProcAssync: TList<TRecordProcedure>;
    MyListProcTimer: TList<TRecordProcedure>;
    MyListProcTimerAssync: TList<TRecordProcedure>;
    QtdeTimers: Integer;
    MyListTimer: TList<TRecordProcedure>;
    ID : Integer;
    procedure Dispatcher;
    procedure WMProcGenerico(Msg: TMsg);
    procedure WMOpen(Msg: TMsg);
    procedure WMProcGenericoAssync(Msg: TMsg);
    procedure WMTIMER(Msg: TMsg);
    procedure WMTIMERAssync(Msg: TMsg);
    procedure PrepararRequisicaoConsulta(DS: TDataSource;Button: TButton);
    procedure DesvincularComponente(DS: TDataSource);
    procedure VincularComponente(DS: TDataSource);
    procedure NovaConexao(DS: TDataSource);overload;
protected
    Rest : Integer;
    SQLList: TSQLList;
    procedure Execute; override;
public
    EmConsulta: boolean;
    RecordProcedure:  TRecordProcedure;
    Connection: TADOConnection;
    Query: TADOQuery;
    DataSource: TDataSource;
    NaoPermitirFilaRequisicao: Boolean;
    MyList:     TList<TSQLList>;
    MyListConnection: TList<TSQLList>;
    procedure Open(DS: TDataSource; Button: TButton);
    procedure ExecSQL(DS: TDataSource; Button: TButton);
    procedure Timer(Rest: NativeUInt; Procedimento: TProcedure);overload;
    procedure Timer(Rest: NativeUInt; Procedimento: TProc);overload;
    procedure TimerAssync(Rest: NativeUInt; Procedimento: TProc);overload;
    procedure TimerAssync(Rest: NativeUInt; Procedimento: TProcedure);overload;
    procedure ProcedimentoGenerico(Procedimento: TProcedure);overload;
    procedure ProcedimentoGenerico(Procedimento: TProc);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc);overload;
    procedure ProcedimentoGenerico(Procedimento: TProcedure; NomeProcedimento: String);overload;
    procedure ProcedimentoGenerico(Procedimento: TProc; NomeProcedimento: String);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure; NomeProcedimento: String);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc; NomeProcedimento: String);overload;
    procedure CancelarConsulta;
    procedure NovaConexao(DS: TDataSource; ProcedimentoOrigem: String);overload;
    procedure Kill;
    procedure ClonarQry(Qry: TAdoQuery);
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
    Button6: TButton;
    Button7: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
private
{ Private declarations }
    Thread1 : TThreadMain;
public
{ Public declarations }
    procedure Consulta;
    procedure Synchronize(AThreadProc: TProc);overload;
    procedure Synchronize(AThreadProc: TProc; Thread: TThread);overload;
end;
var
  Form1: TForm1;
  Timerid: UINT;
implementation

{$R *.DFM}

// ------------------- FUNÇOES GLOBAIS -------------------- //
procedure MyTimeout( hwnd: HWND; uMsg: UINT;idEvent: UINT ; dwTime : DWORD);
stdcall;
var
   I: integer;
   Proc : TProc;
begin
  for I := 0 to Length(Form1.Thread1.MyListTimer.List) do if Form1.Thread1.MyListTimer.List[I].ID = Integer(idEvent) then break;
  Proc := Form1.Thread1.MyListTimer.List[I].RProcedimento;
  Proc;
end;

// ------------------- THREAD CONSULTA -------------------- //

procedure TThreadMain.Execute;
begin
  Rest := 1;
  FreeOnTerminate := self.Finished;
  if MyListProcWillProcAssync = nil
    then MyListProcWillProcAssync := TList<TRecordProcedure>.Create;
  if MyListProc = nil
    then  MyListProc := TList<TRecordProcedure>.Create;
  while not Terminated do begin
    Dispatcher;
  end;
end;

procedure TThreadMain.Dispatcher;
var
  Msg : TMsg;
  Cores : TSystemInfo;
begin
  GetSystemInfo(Cores);
  if PeekMessage(Msg, 0, 0, 0, PM_NOREMOVE) then begin
    Sleep(Rest);
    {
      Bloqueada ---> verificar se threads estão bloqueada, para atender sobe demanda. ---> Monitor(Para aumentar a qtde sobe demanda """(Cores.dwNumberOfProcessors - 1) + IdlenessIndex(Uma expressão matemática logaritma baseada na memoria ram e no numero de cores[Uso intensivo de CPU, Uso intensivo de HD --> Por meta dados])""")
      Threshold ---> Limiar   NODE X APACHE(LENTIDÃO).
      Inferno da DLL e CALLBACKS e usar promices fica mais simples.
    }
    while QtdeProcAsync >= (Integer(Cores.dwNumberOfProcessors) - 1) do sleep(Rest);//melhorar para IO
    EmConsulta := true;
    ID := ID + 1;
    try
      try
        case Msg.Message of
          WM_OPEN:                       WMOpen(Msg);
          WM_PROCEDIMENTOGENERICO:       WMProcGenerico(Msg);
          WM_PROCEDIMENTOGENERICOASSYNC: WMProcGenericoAssync(Msg);
          WM_TIMERP:                     WMTIMER(Msg);
          WM_TIMERASSYNC:                WMTIMERAssync(Msg);
          WM_TIMER:                      MyTimeout(Msg.hwnd,Msg.message,Msg.wParam,Msg.lParam);
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

procedure TThreadMain.ProcedimentoGenerico(Procedimento: TProcedure; NomeProcedimento: String);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  RecordProcedure.Procedimento := Procedimento;
  RecordProcedure.NomeProcedimento := NomeProcedimento;
  RecordProcedure.DSList := TList<TDataSource>.Create;
  MyListProc.Add(RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICO, 0, 0);
end;

procedure TThreadMain.ProcedimentoGenerico(Procedimento: TProc; NomeProcedimento: String);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  Self.RecordProcedure.RProcedimento := Procedimento;
  RecordProcedure.NomeProcedimento := NomeProcedimento;
  RecordProcedure.DSList := TList<TDataSource>.Create;
  MyListProc.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICO, 1, 0);
end;

procedure TThreadMain.ProcedimentoGenerico(Procedimento: TProcedure);
begin
  ProcedimentoGenerico(Procedimento,'');
end;

procedure TThreadMain.ProcedimentoGenerico(Procedimento: TProc);
begin
  ProcedimentoGenerico(Procedimento,'');
end;

procedure TThreadMain.ProcedimentoGenericoAssync(Procedimento: TProcedure);
begin
  ProcedimentoGenericoAssync(Procedimento,'');
end;

procedure TThreadMain.ProcedimentoGenericoAssync(Procedimento: TProc);
begin
  ProcedimentoGenericoAssync(Procedimento,'');
end;

procedure TThreadMain.ProcedimentoGenericoAssync(Procedimento: TProcedure; NomeProcedimento: String);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcAssync = nil
    then  MyListProcAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.Procedimento := Procedimento;
  RecordProcedure.NomeProcedimento := NomeProcedimento;
  RecordProcedure.DSList := TList<TDataSource>.Create;
  MyListProcAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 0, 0);
end;

procedure TThreadMain.ProcedimentoGenericoAssync(Procedimento: TProc; NomeProcedimento: String);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcAssync = nil
    then  MyListProcAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.RProcedimento := Procedimento;
  RecordProcedure.NomeProcedimento := NomeProcedimento;
  RecordProcedure.DSList := TList<TDataSource>.Create;
  MyListProcAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 1, 0);
end;

procedure TThreadMain.Timer(Rest: NativeUInt; Procedimento: TProcedure);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcTimer = nil
    then  MyListProcTimer := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.Procedimento := Procedimento;
  MyListProcTimer.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_TIMERP, Rest, 0);
end;

procedure TThreadMain.Timer(Rest: NativeUInt; Procedimento: TProc);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcTimer = nil
    then  MyListProcTimer := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.RProcedimento := Procedimento;
  MyListProcTimer.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_TIMERP, Rest, 1);
end;

procedure TThreadMain.TimerAssync(Rest: NativeUInt; Procedimento: TProcedure);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcTimerAssync = nil
    then  MyListProcTimerAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.Procedimento := Procedimento;
  MyListProcTimerAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_TIMERASSYNC, Rest, 0);
end;

procedure TThreadMain.TimerAssync(Rest: NativeUInt; Procedimento: TProc);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcTimerAssync = nil
    then  MyListProcTimerAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.RProcedimento := Procedimento;
  MyListProcTimerAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_TIMERASSYNC, Rest, 1);
end;

procedure TThreadMain.WMOpen(Msg: TMsg);
var
Button : TButton;
List   : TSQLList;
Aux : Integer;
begin
try
  Synchronize(
  procedure
  begin
    List  := Self.MyList.First;//*** Ele tem que pegar a primeira colocada, pois é a primeira a ser executada ***
    NovaConexao(List.DS);
    SQLList := MyListConnection.Last;
    Aux   := Integer(Msg.wParam);
    Button := List.Button;
    SQLList.Qry.Close;
    SQLList.DS.Enabled := True;
    SQLList.Connection.BeginTrans;
    Button.Enabled := True;
  end
  );
  if Aux = 0
    then SQLList.Qry.Open
    else SQLList.Qry.ExecSQL;
  if EmConsulta
    then SQLList.Connection.CommitTrans
    else begin
      SQLList.Qry.Close;
      SQLList.DS.Enabled := True;
      Button.Enabled := True;
    end;//é porque eu cancelei no meio
  finally
    VincularComponente(List.DS);
    Button.Caption := 'Consultar direto';
    MyList.Remove(List);
    MyListConnection.Remove(SQLList);
 end;
end;

{Procedimento Generico}
procedure TThreadMain.WMProcGenerico(Msg: TMsg);
var
  Procedimento: TProc;
  I: Integer;
  RecordProcedure: TRecordProcedure;
begin
  RecordProcedure := MyListProc.First;
  if Integer(Msg.wParam) = 0
    then begin
      RecordProcedure.Procedimento;
    end
    else begin
      Procedimento := RecordProcedure.RProcedimento;
      Procedimento;
    end;
  RecordProcedure.Procedimento;
  for I := 0 to RecordProcedure.DSList.Count - 1 do DesvincularComponente(RecordProcedure.DSList.List[I]);
  MyListProc.Remove(MyListProc.First);
end;

procedure TThreadMain.WMProcGenericoAssync(Msg: TMsg);
var
  Procedimento: TProc;
  Aux: TRecordProcedure;
begin
  Aux := MyListProcAssync.First;
  QtdeProcAsync := QtdeProcAsync + 1;
  ID := ID + 1;
  Aux.ID := ID;
  MyListProcWillProcAssync.Add(Aux);
  //Ele deve esperar os outros processos assyncronos acabarem para poder executar, caso o contr�rio perde a eficiencia.
  if Integer(Msg.wParam) = 0
    then begin
      CreateAnonymousThread(
        procedure
        var
          I, J : Integer;
        begin
          for I := 0 to Length(Form1.Thread1.MyListProcWillProcAssync.List) do if Form1.Thread1.MyListProcWillProcAssync.List[I].ID = ID  then break;
          MyListProcWillProcAssync.List[I].Procedimento;
          if Self.Finished
            then exit;
          QtdeProcAsync := QtdeProcAsync - 1;
          for J := 0 to MyListProcWillProcAssync.List[I].DSList.Count - 1 do VincularComponente(MyListProcWillProcAssync.List[I].DSList.List[J]);
          MyListProcWillProcAssync.Delete(I);
        end).Start;
    end
    else begin
      CreateAnonymousThread(
        procedure
        var
          I, J : Integer;
        begin
          for I := 0 to Length(Form1.Thread1.MyListProcWillProcAssync.List) do if Form1.Thread1.MyListProcWillProcAssync.List[I].ID = ID  then break;
          Procedimento := Form1.Thread1.MyListProcWillProcAssync.List[I].RProcedimento;
          Procedimento;
          if Self.Finished
            then exit;
          QtdeProcAsync := QtdeProcAsync - 1;
          for J := 0 to MyListProcWillProcAssync.List[I].DSList.Count - 1 do VincularComponente(MyListProcWillProcAssync.List[I].DSList.List[J]);
          MyListProcWillProcAssync.Delete(I);
        end
      ).Start;
    end;
    MyListProcAssync.Delete(0);
end;

procedure TThreadMain.WMTIMER(Msg: TMsg);
var
  Aux: TRecordProcedure;
  Procedimento:  TProcedure;
  RProcedimento: TProc;
  Rest: NativeUInt;
begin
  QtdeTimers := QtdeTimers + 1;
  Rest := Msg.wParam;

  if Msg.lParam = 0
    then Procedimento  := MyListProcTimer.First.Procedimento
    else RProcedimento := MyListProcTimer.First.RProcedimento;

  if Msg.lParam = 0
    then begin
      Aux.RProcedimento :=
        procedure begin
          if Terminated
            then Abort;
          QtdeProcAsync := QtdeProcAsync + 1;
          Procedimento;
          QtdeProcAsync := QtdeProcAsync - 1;
        end;
    end
    else begin
      Aux.RProcedimento :=
        procedure begin
          if Terminated
            then Abort;
          QtdeProcAsync := QtdeProcAsync + 1;
          RProcedimento;
          QtdeProcAsync := QtdeProcAsync - 1;
        end;
    end;
  Aux.Tipo := Rest;
  if MyListTimer = nil
    then MyListTimer := TList<TRecordProcedure>.Create;
  Synchronize(
    procedure begin
      TimerId   := SetTimer(0, QtdeTimers, Rest, @MyTimeout);
      Aux.ID    := TimerID;
      MyListTimer.Add(Aux);
    end);// não async vai no main
  MyListProcTimer.Delete(0);
end;

procedure TThreadMain.WMTIMERAssync(Msg: TMsg);
var
  Aux: TRecordProcedure;
  Procedimento:  TProcedure;
  RProcedimento: TProc;
  Rest: NativeUInt;
begin
  QtdeTimers := QtdeTimers + 1;
  Rest := Msg.wParam;

  if Msg.lParam = 0
    then Procedimento  := MyListProcTimerAssync.First.Procedimento
    else RProcedimento := MyListProcTimerAssync.First.RProcedimento;

  if Msg.lParam = 0
    then begin
      Aux.RProcedimento  := procedure
                            begin
                              if Terminated
                                then Abort;
                              CreateAnonymousThread(procedure begin
                                                      QtdeProcAsync := QtdeProcAsync + 1;
                                                      Procedimento;
                                                      QtdeProcAsync := QtdeProcAsync - 1
                                                    end).Start;
                            end;
    end
    else begin
      Aux.RProcedimento := procedure
                           begin
                             if Terminated
                               then Abort;
                             CreateAnonymousThread( procedure
                                                    begin
                                                      QtdeProcAsync := QtdeProcAsync + 1;
                                                      RProcedimento;
                                                      QtdeProcAsync := QtdeProcAsync - 1
                                                    end).Start;
                           end;
    end;
  Aux.Tipo := Rest;
  if MyListTimer = nil
    then MyListTimer := TList<TRecordProcedure>.Create;
  Synchronize(
    procedure begin
      TimerId   := SetTimer(0, QtdeTimers, Rest, @MyTimeout);
      Aux.ID    := TimerID;
      MyListTimer.Add(Aux);
    end);// não async vai no main
  MyListProcTimerAssync.Delete(0);
end;

procedure TThreadMain.NovaConexao(DS: TDataSource);
begin
  NovaConexao(DS,'');
end;

procedure TThreadMain.NovaConexao(DS: TDataSource; ProcedimentoOrigem: String);
// é importante criar uma nova conexão ao acessar o banco pra não dar erro de ter duas consultas
// retornando resultado ao mesmo tempo, e também para permitir o rollback sem afetar as outras consultas...
var
  Qry: TAdoQuery;
  ConnectionAux: TADOConnection;
  I : Integer;
  RecordProcedure: TRecordProcedure;
 begin
  if MyListConnection = nil
    then MyListConnection := TList<TSQLList>.Create;

  for I := 0 to Length(Form1.Thread1.MyListProc.List)-1 do
  if Pos(ProcedimentoOrigem, Form1.Thread1.MyListProc.List[I].NomeProcedimento) <> 0
    then begin
      Synchronize(
        Procedure
        begin
          RecordProcedure                 := Form1.Thread1.MyListProc.List[I];
          RecordProcedure.MetaDado        := MyListProc.First.MetaDado + 'Houve Nova Conexão;';
          RecordProcedure.DSList.Add(DS);
        end);
    end;
  for I := 0 to Length(Form1.Thread1.MyListProcWillProcAssync.List)-1 do
  if Pos(ProcedimentoOrigem, Form1.Thread1.MyListProcWillProcAssync.List[I].NomeProcedimento) <> 0
    then begin
      Synchronize(
        Procedure
        begin
          RecordProcedure                 := Form1.Thread1.MyListProcWillProcAssync.List[I];
          RecordProcedure.MetaDado        := RecordProcedure.MetaDado + 'Houve Nova Conexão;';
          RecordProcedure.DSList.Add(DS);
        end);
    end;

  ID := ID + 1;
  DesvincularComponente(DS);
  Qry := TAdoQuery(DS.DataSet);
  ConnectionAux := Qry.Connection;
  if ConnectionAux <> nil then begin
    SQLList.Connection                      := TADOConnection.Create(Form1);
    SQLList.Connection.ConnectionString     := ConnectionAux.ConnectionString;
    SQLList.Connection.ConnectionTimeout    := ConnectionAux.ConnectionTimeout;
    SQLList.Connection.ConnectOptions       := ConnectionAux.ConnectOptions;
    SQLList.Connection.CursorLocation       := ConnectionAux.CursorLocation;
    SQLList.Connection.DefaultDatabase      := ConnectionAux.DefaultDatabase;
    SQLList.Connection.IsolationLevel       := ConnectionAux.IsolationLevel;
    SQLList.Connection.KeepConnection       := ConnectionAux.KeepConnection;
    SQLList.Connection.LoginPrompt          := ConnectionAux.LoginPrompt;
    SQLList.Connection.Mode                 := ConnectionAux.Mode;
    SQLList.Connection.Name                 := 'Thread'+IntToStr(ID)+IntToStr(Self.ThreadID)+ConnectionAux.Name;
    SQLList.Connection.Provider             := ConnectionAux.Provider;
    SQLList.Connection.Tag                  := ConnectionAux.Tag;
  end;
  if pos('Assync',Qry.Name) <> 0 then begin
    Try
      ClonarQry(Qry);
    except
      Self.Synchronize(
        Procedure begin
          SQLList.Connection.Connected := True;
          Qry.Connection        := SQLList.Connection;
          SQLList.Qry            := Qry;
        end);
    end;
  end
  else begin
    Self.Synchronize(
      Procedure begin
        SQLList.Connection.Connected := True;
        Qry.Connection        := SQLList.Connection;
        SQLList.Qry            := Qry;
      end);
  end;

  if pos('Assync',DS.Name) <> 0 then begin
    if (DS <> nil) then begin
      SQLList.DS                      := TDataSource.Create(Form1);
      SQLList.DS.AutoEdit             := DS.AutoEdit;
      SQLList.DS.Name                 := 'Thread'+IntToStr(ID)+IntToStr(Self.ThreadID)+DS.Name;
      SQLList.DS.Tag                  := DS.Tag;
      SQLList.DS.DataSet              := TDataSet(SQLList.Qry);
      DS.Enabled                      := False;
    end;
  end
  else SQLList.DS := DS;

  SQLList.Connection.Connected            := True;
  MyListConnection.Add(SQLList);
end;
procedure TThreadMain.ClonarQry(Qry: TAdoQuery);
var
  I : Integer;
  Field : TField;
begin
  if (Qry <> nil) then begin
    SQLList.Qry                           := TADOQuery.Create(Form1);
    SQLList.Qry.AutoCalcFields            := Qry.AutoCalcFields;
    SQLList.Qry.CacheSize                 := Qry.CacheSize;
    SQLList.Qry.CommandTimeout            := Qry.CommandTimeout;
    SQLList.Qry.ConnectionString          := Qry.ConnectionString;
    SQLList.Qry.CursorLocation            := Qry.CursorLocation;
    SQLList.Qry.CursorType                := Qry.CursorType;
    SQLList.Qry.DataSource                := Qry.DataSource;
    SQLList.Qry.EnableBCD                 := Qry.EnableBCD;
    SQLList.Qry.ExecuteOptions            := Qry.ExecuteOptions;
    SQLList.Qry.Filter                    := Qry.Filter;
    SQLList.Qry.Filtered                  := Qry.Filtered;
    SQLList.Qry.LockType                  := Qry.LockType;
    SQLList.Qry.MarshalOptions            := Qry.MarshalOptions;
    SQLList.Qry.MaxRecords                := Qry.MaxRecords;
    SQLList.Qry.Name                      := 'Thread'+IntToStr(Self.ThreadID)+Qry.Name;
    SQLList.Qry.ParamCheck                := Qry.ParamCheck;
    SQLList.Qry.Parameters                := Qry.Parameters;
    SQLList.Qry.Prepared                  := Qry.Prepared;
    SQLList.Qry.SQL                       := Qry.SQL;
    SQLList.Qry.Tag                       := Qry.Tag;
    SQLList.Qry.Connection                := Connection;
    SQLList.Qry.DataSetField              := Qry.DataSetField;
    SQLList.Qry.Open;
    while SQLList.Qry.Fields.Count<>0 do begin
      SQLList.Qry.Fields.Remove(SQLList.Qry.Fields.Fields[SQLList.Qry.Fields.Count-1]);
    end;
    for I:=0 to Qry.Parameters.Count - 1 do begin
      SQLList.Qry.Parameters.Items[i]       := Qry.Parameters.Items[i];
    end;
    SQLList.Qry.Close;
    for I:=0 to Qry.Fields.Count-1 do begin
      // Criando campos, cópias da qry base
      if Qry.Fields.Fields[I].ClassName = 'TSmallintField'
       then Field := TSmallintField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TIntegerField'
       then Field := TIntegerField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TStringField'
       then Field := TStringField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TBooleanField'
       then Field := TBooleanField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TFloatField'
       then Field := TFloatField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TCurrencyField'
       then Field := TCurrencyField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TWordField'
       then Field := TWordField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TBCDField'
       then Field := TBCDField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TDateField'
       then Field := TDateField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TTimeField'
       then Field := TTimeField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TDateTimeField'
       then Field := TDateTimeField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TBytesField'
       then Field := TBytesField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TVarBytesField'
       then Field := TVarBytesField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TAutoIncField'
       then Field := TAutoIncField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TBlobField'
       then Field := TBlobField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TMemoField'
       then Field := TMemoField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TGraphicField'
       then Field := TGraphicField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TWideStringField'
       then Field := TWideStringField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TLargeIntField'
       then Field := TLargeIntField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TADTField'
       then Field := TADTField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TArrayField'
       then Field := TArrayField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TReferenceField'
       then Field := TReferenceField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TDataSetField'
       then Field := TDataSetField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TVariantField'
       then Field := TVariantField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TInterfaceField'
       then Field := TInterfaceField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TIDispatchField'
       then Field := TIDispatchField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TGuidField'
       then Field := TGuidField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TSQLTimeStampField'
       then Field := TSQLTimeStampField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TFMTBcdField'
       then Field := TFMTBcdField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TWideStringField'
       then Field := TWideStringField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TWideMemoField'
       then Field := TWideMemoField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TSQLTimeStampField'
       then Field := TSQLTimeStampField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TLongWordField'
       then Field := TLongWordField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TShortintField'
       then Field := TShortintField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TExtendedField'
       then Field := TExtendedField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TSQLTimeStampOffsetField'
       then Field := TSQLTimeStampOffsetField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TAggregateField'
       then Field := TAggregateField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TUnsignedAutoIncField'
       then Field := TUnsignedAutoIncField.Create(Form1)
       else
      if Qry.Fields.Fields[I].ClassName = 'TSingleField'
       then Field := TSingleField.Create(Form1);
      Field.EditMask     := Qry.Fields.Fields[I].EditMask;
      Field.DisplayWidth := Qry.Fields.Fields[I].DisplayWidth;
      Field.FieldKind    := Qry.Fields.Fields[I].FieldKind;
      Field.ReadOnly     := Qry.Fields.Fields[I].ReadOnly;
      Field.Visible      := Qry.Fields.Fields[I].Visible;
      Field.FieldName    := Qry.Fields.Fields[I].FieldName;
      Field.OnValidate   := Qry.Fields.Fields[I].OnValidate;
      Field.OnGetText    := Qry.Fields.Fields[I].OnGetText;
      Field.OnSetText    := Qry.Fields.Fields[I].OnSetText;
      Field.OnChange     := Qry.Fields.Fields[I].OnChange;
      Field.DataSet      := TDataSet(SQLList.Qry);
      if (Qry.Fields.Fields[I].ClassName = 'TFloatField')    or (Qry.Fields.Fields[I].ClassName = 'TBCDField') or
         (Qry.Fields.Fields[I].ClassName = 'TExtendedField') or (Qry.Fields.Fields[I].ClassName = 'TSingleField')or
         (Qry.Fields.Fields[I].ClassName = 'TFMTBCDField')   or (Qry.Fields.Fields[I].ClassName = 'TUnsignedAutoIncField') or
         (Qry.Fields.Fields[I].ClassName = 'TAggregateField') // Todas os tipos de campos que possuem esse tipo de operação(currency)
        then TFloatField(Field).currency   := TFloatField(Qry.Fields.Fields[I]).currency;
    end;
  end;
end;

procedure TThreadMain.CancelarConsulta;
begin
    if EmConsulta then begin
      Synchronize(
        Procedure
        begin
          try
            SQLList.DS.Enabled := False;
            SQLList.Connection.RollbackTrans;
          finally
            EmConsulta := False;
          end;
        end
      );
    end;
end;

procedure TThreadMain.Kill;
begin
  KillTimer(0, TimerId);
  if (EmConsulta) or (QtdeProcAsync <> 0)
    then Destroy
    else Terminate;
end;

procedure TThreadMain.DesvincularComponente(DS: TDataSource);
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
        DSAux      := TDataSource.Create(Form1);
        DSAux.Name := DS.Name+'INACTIVE'+IntToStr(ID);
        TDBGrid(Form.Components[i]).DataSource := DSAux
      end
      else
    if (Form.Components[i] is TDBMemo)  and (TDBMemo(Form.Components[i]).DataSource = DS)
      then begin
        ID := ID + 1;
        DSAux      := TDataSource.Create(Form1);
        DSAux.Name := DS.Name+'INACTIVE'+IntToStr(ID);
        TDBMemo(Form.Components[i]).DataSource := DSAux;
      end;
  end;
end;

procedure TThreadMain.VincularComponente(DS: TDataSource);
var
  i: integer;
  Form: TForm;
  Qry:   TAdoQuery;
begin
  Qry:= TAdoQuery(DS.DataSet);
  if pos('Assync',DS.Name) <> 0
    then DS.DataSet := nil;
  Form := TForm(Qry.Owner);
  for i := 0 to (Form.ComponentCount - 1) do begin
    if (Form.Components[i] is TDBGrid)  and (Copy(String(TDBGrid(Form.Components[i]).DataSource.Name),0,Pos('INACTIVE', String(TDBGrid(Form.Components[i]).DataSource.Name))-1) = DS.Name)
      then TDBGrid(Form.Components[i]).DataSource := SQLList.DS
      else
    if (Form.Components[i] is TDBMemo)  and (Copy(String(TDBMemo(Form.Components[i]).DataSource.Name),0,Pos('INACTIVE', String(TDBMemo(Form.Components[i]).DataSource.Name))-1) = DS.Name)
      then TDBMemo(Form.Components[i]).DataSource := SQLList.DS;
  end;
  //Criar em breve --> Vincular Todos Daquele Mesmo Ramo De Processos
end;
// ------------------- MAIN -------------------- //

procedure TForm1.Button1Click(Sender: TObject);
begin
  if not (Thread1.EmConsulta)
    then Thread1.Open(DBGrid1.DataSource,Button1)
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
  Thread1.ProcedimentoGenericoAssync(Consulta,'Consulta');
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  Thread1.CancelarConsulta;
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  Thread1.ProcedimentoGenericoAssync(
              Procedure
              begin
                while true do begin
                  sleep(1);
                  if Thread1.Finished
                    then exit;
                  Thread1.Queue(
                  procedure
                  begin
                    form1.lbl1.Caption := IntToStr( StrToInt(form1.lbl1.Caption) + 10);
                  end);
                end;
              end);
end;

procedure TForm1.Button6Click(Sender: TObject);
begin
  Thread1.Timer(3000,
  procedure
  begin
    if StrToInt(Form1.lbl1.Caption) > 2000
      then Form1.lbl1.Caption := '0';
  end);
end;

procedure TForm1.Button7Click(Sender: TObject);
begin
  Thread1.TimerAssync(100,
  procedure
  begin
    if StrToInt(Form1.lbl1.Caption) > 2000
      then Form1.lbl1.Caption := '0';
  end);
end;

procedure TForm1.Consulta;
var
  SQLList: TSQLList;
begin
  try
    Thread1.NovaConexao(DataSource1,'Consulta');
    SQLList := Thread1.MyListConnection.Last;
    SQLList.Qry.Close;
    SQLList.Connection.Connected := True;
//    SQLList.Connection.BeginTrans;
    Button3.Visible := False;
    SQLList.Qry.Open;
    {
    Thread1.Synchronize(
    procedure
    begin
      if Thread1.EmConsulta
        then Thread1.Connection.CommitTrans
        else begin
          SQLList.Qry.Close;
          Thread1.EmConsulta := False;
        end;//é porque eu cancelei no meio
    end
    );}
  finally
    Button3.Enabled := True;
    Button3.Visible := True;
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

procedure TForm1.Synchronize(AThreadProc: TProc);
begin
  Thread1.Synchronize(Thread1,TThreadProcedure(AThreadProc));
end;

procedure TForm1.Synchronize(AThreadProc: TProc; Thread: TThread);
begin
  Thread1.Synchronize(Thread,TThreadProcedure(AThreadProc));
end;
end.
