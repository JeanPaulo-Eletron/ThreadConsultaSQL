//Feito por: Jean Paulo Athanazio De Mei
{     Anotações:
      Bloqueada ---> verificar se threads estão bloqueada, para atender sobe demanda. ---> Monitor(Para aumentar a qtde sobe demanda """(Cores.dwNumberOfProcessors - 1) + IdlenessIndex(Uma expressão matemática logaritma baseada na memoria ram e no numero de cores[Uso intensivo de CPU, Uso intensivo de HD --> Por meta dados])""")
      Threshold ---> Limiar   NODE X APACHE(LENTIDÃO).
      Inferno da DLL e CALLBACKS e usar promices fica mais simples.
}
// Timer foi criado para possibilitar ser thread save(Porém depois fazendo alguns testes com componente,
// percebi que com algumas adptações manuais(como dar enabled false quando iniciar e true quando terminar,
// e criar um váriavel global para saber se está executando quando mecher no enabled dele
//[porem se quiser inativar depois da execução terá que tratar manualmente]) dá pra usar ele,
// use qual preferir, mas o timer da thread é próprio para isso).
unit Main;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    {System.Rtti,} System.TypInfo, Generics.Collections, Vcl.ExtCtrls,
    Vcl.DBCtrls, SyncObjs;

const
    WM_OPEN                       = WM_USER + 1;
    WM_PROCEDIMENTOGENERICOASSYNC = WM_USER + 2;
    WM_TIMERTHREADASSYNC          = WM_USER + 3;
    WM_TERMINATE                  = WM_USER + 4;
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
      NomeProcedimento : String;
      DSList  : TList<TDataSource>;
      SQLList: TSQLList;
      EmConsulta: Boolean;
      Rest: Integer;
      EmProcesso: Boolean;
      Tag: NativeInt;
    end;
type
    TThreadMain = class(TThread)
private
    QtdeProcAsync: Integer;
    MyListProcAssync: TList<TRecordProcedure>;
    MyListProcWillProcAssync: TList<TRecordProcedure>;
    MyListProcTimerAssync: TList<TRecordProcedure>;
    MyListProcWillTimer: TList<TRecordProcedure>;
    QtdeTimers: Integer;
    ID : Integer;
    procedure Dispatcher;
    procedure WMProcGenericoAssync(Msg: TMsg);
    procedure WMTIMERAssync(Msg: TMsg);
    procedure DesvincularComponente(DS: TDataSource);
    procedure VincularComponente(DS: TDataSource);
protected
    procedure Execute; override;
public
    Rest : Integer;
    EmProcesso: boolean;
    RecordProcedure:  TRecordProcedure;
    Connection: TADOConnection;
    Query: TADOQuery;
    DataSource: TDataSource;
    NaoPermitirFilaDeProcessos: Boolean;
    MyList:     TList<TSQLList>;
    procedure TimerAssync(Rest: NativeUInt; Procedimento: TProc);overload;
    procedure TimerAssync(Rest: NativeUInt; Procedimento: TProcedure);overload;
    procedure TimerAssync(Rest: NativeUInt; Procedimento: TProc; NomeProcedimento: string);overload;
    procedure TimerAssync(Rest: NativeUInt; Procedimento: TProcedure; NomeProcedimento: string);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure; NomeProcedimento: String);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc; NomeProcedimento: String);overload;
    function  NovaConexao(DS: TDataSource; ProcedimentoOrigem: String):TRecordProcedure;overload;
    procedure Kill;
    procedure CancelarConsulta(ProcedimentoOrigem: String);
    procedure SetRest(Rest:Integer; ProcedimentoOrigem: String);
    function  GetRest(ProcedimentoOrigem: String):Integer;
    procedure  StopTimer(ProcedimentoOrigem: String);
    procedure  StartTimer(ProcedimentoOrigem: String);
end;

TFormMain = class(TForm)
    Query1: TADOQuery;
    Button3: TButton;
    ADOConnection1: TADOConnection;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    Button4: TButton;
    Button5: TButton;
    lbl1: TLabel;
    Button7: TButton;
    Button1: TButton;
    Button2: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
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
  FormMain: TFormMain;
  Timerid: UINT;
  FLock : TCriticalSection;
implementation

{$R *.DFM}

// ------------------- FUNÇOES GLOBAIS -------------------- //
procedure MyTimeout( hwnd: HWND; uMsg: UINT;idEvent: UINT ; dwTime : DWORD);
stdcall;
var
   I: integer;
   Proc : TProc;
   RecordProcedure: TRecordProcedure;
begin
  for I := 0 to Length(FormMain.Thread1.MyListProcWillTimer.List)-1 do if FormMain.Thread1.MyListProcWillTimer.List[I].ID = Integer(idEvent) then begin
    Proc :=
    procedure
    var
     Proc : TProc;
    begin
      FLock.Acquire;
      RecordProcedure := FormMain.Thread1.MyListProcWillTimer.Items[I];
      if RecordProcedure.EmProcesso
        then exit;
      RecordProcedure.EmProcesso := True;
      Proc := RecordProcedure.RProcedimento;
      FLock.Release;
      Proc;
      FLock.Acquire;
      TimerId   := SetTimer(0, IDEvent, RecordProcedure.Rest, @MyTimeout);
      RecordProcedure.ID := Integer(Timerid);
      FLock.Release;
    end;
    Proc;
  end;
end;

// ------------------- THREAD CONSULTA -------------------- //

procedure TThreadMain.Execute;
begin
  Rest := 1;
  FreeOnTerminate := self.Finished;
  if MyListProcWillProcAssync = nil
    then MyListProcWillProcAssync := TList<TRecordProcedure>.Create;
  if MyListProcWillTimer = nil
    then MyListProcWillTimer := TList<TRecordProcedure>.Create;
  FLock := TCriticalSection.Create;
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
    if Integer(Cores.dwNumberOfProcessors) > 1
      then while QtdeProcAsync >= (Integer(Cores.dwNumberOfProcessors) - 1) do sleep(Rest);//Otimização para hardware não sobrecarregar de processos pessados.
    EmProcesso := true;
    ID := ID + 1;
    try
      try
        case Msg.Message of
          WM_PROCEDIMENTOGENERICOASSYNC: WMProcGenericoAssync(Msg);
          WM_TIMERTHREADASSYNC:          WMTIMERAssync(Msg);
          WM_TIMER:                      MyTimeout(Msg.hwnd,Msg.message,Msg.wParam,Msg.lParam);
          WM_DESTROY:                    Destroy;
          WM_TERMINATE:                  Terminate;
        end;
      finally
        EmProcesso := false;
        PeekMessage(Msg, 0, 0, 0, PM_REMOVE);
      end;
    except
      Self.Execute;
    end;
  end
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
  if NaoPermitirFilaDeProcessos and EmProcesso
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
  if NaoPermitirFilaDeProcessos and EmProcesso
    then exit;
  if MyListProcAssync = nil
    then  MyListProcAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.RProcedimento := Procedimento;
  RecordProcedure.NomeProcedimento := NomeProcedimento;
  RecordProcedure.DSList := TList<TDataSource>.Create;
  MyListProcAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 1, 0);
end;

procedure TThreadMain.TimerAssync(Rest: NativeUInt; Procedimento: TProcedure; NomeProcedimento: string);
begin
  if NaoPermitirFilaDeProcessos and EmProcesso
    then exit;
  if MyListProcTimerAssync = nil
    then  MyListProcTimerAssync := TList<TRecordProcedure>.Create;
  RecordProcedure.Procedimento     := Procedimento;
  RecordProcedure.NomeProcedimento := NomeProcedimento;
  MyListProcTimerAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_TIMERTHREADASSYNC, Rest, 1);
end;

procedure TThreadMain.TimerAssync(Rest: NativeUInt; Procedimento: TProcedure);
begin
  TimerAssync(Rest,Procedimento,'');
end;

procedure TThreadMain.TimerAssync(Rest: NativeUInt; Procedimento: TProc);
begin
  TimerAssync(Rest,Procedimento,'');
end;

procedure TThreadMain.TimerAssync(Rest: NativeUInt; Procedimento: TProc; NomeProcedimento: string);
begin
  if NaoPermitirFilaDeProcessos and EmProcesso
    then exit;
  if MyListProcTimerAssync = nil
    then  MyListProcTimerAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.RProcedimento := Procedimento;
  RecordProcedure.NomeProcedimento := NomeProcedimento;
  MyListProcTimerAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_TIMERTHREADASSYNC, Rest, 2);
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
  if Integer(Msg.wParam) = 0
    then begin
      CreateAnonymousThread(
        procedure
        var
          I, J : Integer;
        begin
          for I := 0 to Length(FormMain.Thread1.MyListProcWillProcAssync.List) do if FormMain.Thread1.MyListProcWillProcAssync.List[I].ID = ID  then break;
          MyListProcWillProcAssync.List[I].Procedimento;
          if Self.Finished
            then exit;
          QtdeProcAsync := QtdeProcAsync - 1;
          for J := 0 to MyListProcWillProcAssync.List[I].DSList.Count - 1 do begin
            if MyListProcWillProcAssync.List[I].EmConsulta
              then TAdoQuery(MyListProcWillProcAssync.List[I].DSList.List[J].DataSet).Connection.CommitTrans
              else TAdoQuery(MyListProcWillProcAssync.List[I].DSList.List[J].DataSet).Close;
            VincularComponente(MyListProcWillProcAssync.List[I].DSList.List[J]);
            MyListProcWillProcAssync.List[I].SQLList.DS.Destroy;
          end;
          MyListProcWillProcAssync.Delete(I);
        end).Start;
    end
    else begin
      CreateAnonymousThread(
        procedure
        var
          I, J : Integer;
        begin
          for I := 0 to Length(FormMain.Thread1.MyListProcWillProcAssync.List) do if FormMain.Thread1.MyListProcWillProcAssync.List[I].ID = ID  then break;
          Procedimento := FormMain.Thread1.MyListProcWillProcAssync.List[I].RProcedimento;
          Procedimento;
          if Self.Finished
            then exit;
          QtdeProcAsync := QtdeProcAsync - 1;
          for J := 0 to MyListProcWillProcAssync.List[I].DSList.Count - 1 do begin
            if MyListProcWillProcAssync.List[I].EmConsulta
              then TAdoQuery(MyListProcWillProcAssync.List[I].DSList.List[J].DataSet).Connection.CommitTrans
              else TAdoQuery(MyListProcWillProcAssync.List[I].DSList.List[J].DataSet).Close;
            VincularComponente(MyListProcWillProcAssync.List[I].DSList.List[J]);
            MyListProcWillProcAssync.List[I].SQLList.DS.Destroy;
          end;
          MyListProcWillProcAssync.Delete(I);
        end
      ).Start;
    end;
    MyListProcAssync.Delete(0);
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
  Aux  := MyListProcTimerAssync.ExtractAt(0);

  if Msg.lParam = 1
    then Procedimento  := Aux.Procedimento
    else RProcedimento := Aux.RProcedimento;

  Aux.DSList := TList<TDataSource>.Create;
  if Msg.lParam = 0
    then begin
      Aux.RProcedimento  := procedure
                            begin
                              if Terminated
                                then Abort;
                              CreateAnonymousThread(procedure
                                                    var
                                                      I: Integer;
                                                    begin
                                                      QtdeProcAsync := QtdeProcAsync + 1;
                                                      Procedimento;
                                                      QtdeProcAsync := QtdeProcAsync - 1;
                                                      for I := 0 to Aux.DSList.Count - 1 do begin
                                                        if Aux.EmConsulta
                                                          then TAdoQuery(Aux.DSList.List[I].DataSet).Connection.CommitTrans
                                                          else TAdoQuery(Aux.DSList.List[I].DataSet).Close;
                                                        VincularComponente(Aux.DSList.List[I]);
                                                        Aux.EmProcesso := False;
                                                      end;
                                                    end).Start;
                            end;
    end
    else begin
      Aux.RProcedimento := procedure
                           begin
                             if Terminated
                               then Abort;
                             CreateAnonymousThread(procedure
                                                   var
                                                     I: Integer;
                                                   begin
                                                     QtdeProcAsync := QtdeProcAsync + 1;
                                                     RProcedimento;
                                                     QtdeProcAsync := QtdeProcAsync - 1;
                                                     for I := 0 to Aux.DSList.Count - 1 do begin
                                                       if Aux.EmConsulta
                                                         then TAdoQuery(Aux.DSList.List[I].DataSet).Connection.CommitTrans
                                                         else TAdoQuery(Aux.DSList.List[I].DataSet).Close;
                                                       VincularComponente(Aux.DSList.List[I]);
                                                       Aux.EmProcesso := False;
                                                     end;
                                                   end).Start;
                           end;
    end;
  Aux.Rest := Rest;
  Synchronize( procedure begin
                 TimerId   := SetTimer(0, QtdeTimers, 0, @MyTimeout);
                 Aux.ID    := TimerID;
                 Aux.Tipo  := QtdeTimers;
                 MyListProcWillTimer.Add(Aux);
               end );// não async vai no main
end;

function TThreadMain.NovaConexao(DS: TDataSource; ProcedimentoOrigem: String):TRecordProcedure;
// é importante criar uma nova conexão ao acessar o banco pra não dar erro de ter duas consultas
// retornando resultado ao mesmo tempo, e também para permitir o rollback sem afetar as outras consultas...
var
  Qry: TAdoQuery;
  ConnectionAux: TADOConnection;
  I, J : Integer;
  RecordProcedure, Aux: TRecordProcedure;
  SQLList: TSQLList;
 begin
  //Está parte serve para controlar requisições de nova conexão concorrentes ao mesmo DS
  for I := 0 to Length(FormMain.Thread1.MyListProcWillTimer.List) - 1 do if FormMain.Thread1.MyListProcWillTimer.List[I].NomeProcedimento = ProcedimentoOrigem then begin
    J := 0;
    while J < FormMain.Thread1.MyListProcWillTimer.List[I].DSList.Count do begin
      while (FormMain.Thread1.MyListProcWillTimer.List[I].DSList.List[J] = DS) do begin
        sleep(100);
        J := -1; // -1 + 1 = 0 ::>Verifique todas novamente<::
      end;
      J := J + 1;
    end;
  end;
  ID := ID + 1;
  DesvincularComponente(DS);
  FLock.Acquire;
  Qry := TAdoQuery(DS.DataSet);
  ConnectionAux := Qry.Connection;
  RecordProcedure.SQLList.Connection                      := TADOConnection.Create(FormMain);
  RecordProcedure.SQLList.Connection.ConnectionString     := ConnectionAux.ConnectionString;
  RecordProcedure.SQLList.Connection.ConnectionTimeout    := ConnectionAux.ConnectionTimeout;
  RecordProcedure.SQLList.Connection.ConnectOptions       := ConnectionAux.ConnectOptions;
  RecordProcedure.SQLList.Connection.CursorLocation       := ConnectionAux.CursorLocation;
  RecordProcedure.SQLList.Connection.DefaultDatabase      := ConnectionAux.DefaultDatabase;
  RecordProcedure.SQLList.Connection.IsolationLevel       := ConnectionAux.IsolationLevel;
  RecordProcedure.SQLList.Connection.KeepConnection       := ConnectionAux.KeepConnection;
  RecordProcedure.SQLList.Connection.LoginPrompt          := ConnectionAux.LoginPrompt;
  RecordProcedure.SQLList.Connection.Mode                 := ConnectionAux.Mode;
  RecordProcedure.SQLList.Connection.Name                 := 'Thread'+IntToStr(ID)+IntToStr(Self.ThreadID)+ConnectionAux.Name;
  RecordProcedure.SQLList.Connection.Provider             := ConnectionAux.Provider;
  RecordProcedure.SQLList.Connection.Tag                  := ConnectionAux.Tag;
  if (DS <> nil) then begin
    RecordProcedure.SQLList.DS                      := TDataSource.Create(FormMain);
    RecordProcedure.SQLList.DS.AutoEdit             := DS.AutoEdit;
    RecordProcedure.SQLList.DS.Name                 := 'Thread'+IntToStr(ID)+IntToStr(Self.ThreadID)+DS.Name;
    RecordProcedure.SQLList.DS.Tag                  := DS.Tag;
    RecordProcedure.SQLList.DS.DataSet              := TDataSet(SQLList.Qry);
    DS.Enabled                                      := False;
  end;
  RecordProcedure.SQLList.Connection.Connected := True;
  RecordProcedure.SQLList.Qry                  := Qry;
  RecordProcedure.SQLList.Qry.Connection       :=  RecordProcedure.SQLList.Connection;
  RecordProcedure.SQLList.DS.Enabled           := True;
  RecordProcedure.SQLList.Qry.Close;
  RecordProcedure.SQLList.Connection.Connected := True;
  RecordProcedure.SQLList.Connection.BeginTrans;
  for I := 0 to Length(FormMain.Thread1.MyListProcWillProcAssync.List)-1 do
  if ProcedimentoOrigem = FormMain.Thread1.MyListProcWillProcAssync.List[I].NomeProcedimento
    then begin
      Aux                 := FormMain.Thread1.MyListProcWillProcAssync.ExtractAt(I);
      Aux.DSList.Add(DS);
      Aux.SQLList         := RecordProcedure.SQLList;
      Aux.EmConsulta      := True;
      FormMain.Thread1.MyListProcWillProcAssync.Insert(I, Aux);
      RecordProcedure     := Aux;
    end;
  for I := 0 to Length(FormMain.Thread1.MyListProcWillTimer.List)-1 do
  if ProcedimentoOrigem = FormMain.Thread1.MyListProcWillTimer.List[I].NomeProcedimento
    then begin
      RecordProcedure                 := FormMain.Thread1.MyListProcWillTimer.ExtractAt(I);
      RecordProcedure.DSList.Add(DS);
      RecordProcedure.SQLList         := SQLList;
      RecordProcedure.EmConsulta      := True;
      FormMain.Thread1.MyListProcWillTimer.Insert(I, RecordProcedure);
      RecordProcedure := Aux;
    end;
  FLock.Release;
  Result := RecordProcedure;
end;


procedure TThreadMain.CancelarConsulta(ProcedimentoOrigem: String);
var
  I: Integer;
  Procedimento : TRecordProcedure;
begin
  for I := 0 to FormMain.Thread1.MyListProcWillProcAssync.Count - 1 do
  if FormMain.Thread1.MyListProcWillProcAssync.Items[I].NomeProcedimento = ProcedimentoOrigem then begin
    if FormMain.Thread1.MyListProcWillProcAssync.Items[I].EmConsulta then begin
      try
        FLock.Acquire;
        Procedimento := FormMain.Thread1.MyListProcWillProcAssync.ExtractAt(I);
        Procedimento.SQLList.DS.Enabled := False;
        Procedimento.SQLList.Connection.RollbackTrans;
      finally
        Procedimento.EmConsulta := False;
        FormMain.Thread1.MyListProcWillProcAssync.Insert(I, Procedimento);
        FLock.Release;
      end;
    end;
  end;
end;

procedure TThreadMain.Kill;
var
  I: integer;
begin
  FreeAndNil(FLock);
  for I := 0 to MyListProcWillTimer.Count - 1 do KillTimer(0, MyListProcWillTimer.List[I].ID);
  for I := 0 to MyListProcWillProcAssync.Count - 1 do CancelarConsulta(MyListProcWillProcAssync.List[I].NomeProcedimento);//Cancelando todas as consultas
  if (EmProcesso) or (QtdeProcAsync <> 0)
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
        DSAux      := TDataSource.Create(FormMain);
        DSAux.Name := DS.Name+'INACTIVE'+IntToStr(ID);
        FLock.Acquire;
        TDBGrid(Form.Components[i]).DataSource := DSAux;
        FLock.Release;
      end
      else
    if (Form.Components[i] is TDBMemo)  and (TDBMemo(Form.Components[i]).DataSource = DS)
      then begin
        ID := ID + 1;
        DSAux      := TDataSource.Create(FormMain);
        DSAux.Name := DS.Name+'INACTIVE'+IntToStr(ID);
        FLock.Acquire;
        TDBMemo(Form.Components[i]).DataSource := DSAux;
        FLock.Release;
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
  Form := TForm(Qry.Owner);
  for i := 0 to (Form.ComponentCount - 1) do begin
    if (Form.Components[i] is TDBGrid)  and (Copy(String(TDBGrid(Form.Components[i]).DataSource.Name),0,Pos('INACTIVE', String(TDBGrid(Form.Components[i]).DataSource.Name))-1) = DS.Name)
      then begin
        FLock.Acquire;
        TDBGrid(Form.Components[i]).DataSource.Enabled := False;
        TDBGrid(Form.Components[i]).DataSource := DS;
        TDBGrid(Form.Components[i]).DataSource.Enabled := True;
        FLock.Release;
      end
      else
    if (Form.Components[i] is TDBMemo)  and (Copy(String(TDBMemo(Form.Components[i]).DataSource.Name),0,Pos('INACTIVE', String(TDBMemo(Form.Components[i]).DataSource.Name))-1) = DS.Name)
      then begin
        FLock.Acquire;
        TDBMemo(Form.Components[i]).DataSource.Enabled := False;
        TDBMemo(Form.Components[i]).DataSource := DS;
        TDBMemo(Form.Components[i]).DataSource.Enabled := True;
        FLock.Release;
      end
  end;
end;

procedure TThreadMain.SetRest(Rest: Integer; ProcedimentoOrigem: String);
var
  I : Integer;
  Procedimento: TRecordProcedure;
begin
  for I := 0 to Length(FormMain.Thread1.MyListProcWillTimer.List) - 1 do if FormMain.Thread1.MyListProcWillTimer.List[I].NomeProcedimento = ProcedimentoOrigem then begin
     FLock.Acquire;
     Procedimento      := FormMain.Thread1.MyListProcWillTimer.ExtractAt(I);
     Procedimento.Rest := Rest;
     FormMain.Thread1.MyListProcWillTimer.Insert(I, Procedimento);
     FLock.Release;
  end;
end;

function TThreadMain.GetRest(ProcedimentoOrigem: String): Integer;
var
  I : Integer;
begin
  Result := -1;
  for I := 0 to Length(FormMain.Thread1.MyListProcWillTimer.List) - 1 do if FormMain.Thread1.MyListProcWillTimer.List[I].NomeProcedimento = ProcedimentoOrigem
    then Result := FormMain.Thread1.MyListProcWillTimer.List[I].Rest;
end;


procedure TThreadMain.StartTimer(ProcedimentoOrigem: String);
var
  I : Integer;
begin
  for I := 0 to Length(FormMain.Thread1.MyListProcWillTimer.List) - 1 do if FormMain.Thread1.MyListProcWillTimer.List[I].NomeProcedimento = ProcedimentoOrigem then begin
    FLock.Acquire;
    TimerId   := SetTimer(0, FormMain.Thread1.MyListProcWillTimer.List[I].Tipo, FormMain.Thread1.MyListProcWillTimer.List[I].Rest, @MyTimeout);
    FormMain.Thread1.MyListProcWillTimer.List[I].ID := TimerId;
    FLock.Release;
  end;
end;

procedure TThreadMain.StopTimer(ProcedimentoOrigem: String);
var
  I : Integer;
begin
  for I := 0 to Length(FormMain.Thread1.MyListProcWillTimer.List) - 1 do if FormMain.Thread1.MyListProcWillTimer.List[I].NomeProcedimento = ProcedimentoOrigem
    then KillTimer(0,FormMain.Thread1.MyListProcWillTimer.List[I].ID);
end;


// ------------------- MAIN -------------------- //

procedure TFormMain.Button1Click(Sender: TObject);
begin
  Thread1.StopTimer('Contar');
end;

procedure TFormMain.Button2Click(Sender: TObject);
begin
  Thread1.StartTimer('Contar');
end;

procedure TFormMain.Button3Click(Sender: TObject);
begin
  Thread1.ProcedimentoGenericoAssync(Consulta,'Consulta');
end;

procedure TFormMain.Button4Click(Sender: TObject);
begin
  Thread1.CancelarConsulta('Consulta');
end;

procedure TFormMain.Button5Click(Sender: TObject);
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
                    FormMain.lbl1.Caption := IntToStr( StrToInt(FormMain.lbl1.Caption) + 10);
                  end);
                end;
              end);
end;

procedure TFormMain.Button7Click(Sender: TObject);
begin
  Thread1.TimerAssync(100,
  procedure
  begin
    if StrToInt(FormMain.lbl1.Caption) > 2000
      then Thread1.Synchronize(procedure begin FormMain.lbl1.Caption := '0' end);
    Thread1.SetRest(Thread1.GetRest('Contar')+10,'Contar');
  end,'Contar');
end;

procedure TFormMain.Consulta;
var
  RecordProcedure: TRecordProcedure;
begin
  try
    RecordProcedure := Thread1.NovaConexao(DataSource1,'Consulta');
    Button3.Visible := False;
    RecordProcedure.SQLList.Qry.Open;
  finally
    Button3.Enabled := True;
    Button3.Visible := True;
  end;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  Thread1 := TThreadMain.Create(False);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  Thread1.Kill;
end;

procedure TFormMain.Synchronize(AThreadProc: TProc);
begin
  Thread1.Synchronize(Thread1,TThreadProcedure(AThreadProc));
end;

procedure TFormMain.Synchronize(AThreadProc: TProc; Thread: TThread);
begin
  Thread1.Synchronize(Thread,TThreadProcedure(AThreadProc));
end;
end.
