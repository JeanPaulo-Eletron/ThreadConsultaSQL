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
      SQLList: TSQLList;
      EmConsulta: Boolean;
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
    procedure WMProcGenericoAssync(Msg: TMsg);
    procedure WMTIMER(Msg: TMsg);
    procedure WMTIMERAssync(Msg: TMsg);
    procedure PrepararRequisicaoConsulta(DS: TDataSource;Button: TButton);
    procedure DesvincularComponente(DS: TDataSource);
    procedure VincularComponente(DS: TDataSource);
    function  NovaConexao(DS: TDataSource):TRecordProcedure;overload;
protected
    Rest : Integer;
    procedure Execute; override;
public
    EmConsulta: boolean;
    RecordProcedure:  TRecordProcedure;
    Connection: TADOConnection;
    Query: TADOQuery;
    DataSource: TDataSource;
    NaoPermitirFilaRequisicao: Boolean;
    MyList:     TList<TSQLList>;
    procedure Timer(Rest: NativeUInt; Procedimento: TProcedure);overload;
    procedure Timer(Rest: NativeUInt; Procedimento: TProc);overload;
    procedure TimerAssync(Rest: NativeUInt; Procedimento: TProc);overload;
    procedure TimerAssync(Rest: NativeUInt; Procedimento: TProcedure);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure; NomeProcedimento: String);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc; NomeProcedimento: String);overload;
    function  NovaConexao(DS: TDataSource; ProcedimentoOrigem: String):TRecordProcedure;overload;
    procedure Kill;
    procedure CancelarConsulta(ProcedimentoOrigem: String);
end;

TForm1 = class(TForm)
    Query1: TADOQuery;
    Button3: TButton;
    ADOConnection1: TADOConnection;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    Button4: TButton;
    Button5: TButton;
    lbl1: TLabel;
    Button6: TButton;
    Button7: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
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

function TThreadMain.NovaConexao(DS: TDataSource):TRecordProcedure;
begin
  Result := NovaConexao(DS,'');
end;

function TThreadMain.NovaConexao(DS: TDataSource; ProcedimentoOrigem: String):TRecordProcedure;
// é importante criar uma nova conexão ao acessar o banco pra não dar erro de ter duas consultas
// retornando resultado ao mesmo tempo, e também para permitir o rollback sem afetar as outras consultas...
var
  Qry: TAdoQuery;
  ConnectionAux: TADOConnection;
  I : Integer;
  RecordProcedure: TRecordProcedure;
  SQLList: TSQLList;
 begin
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

  Self.Synchronize(
    Procedure begin
      SQLList.Connection.Connected := True;
      Qry.Connection               := SQLList.Connection;
      SQLList.Qry                  := Qry;
      DS.Enabled := False;
      SQLList.DS := DS;
      SQLList.DS.Enabled := True;
    end);
  for I := 0 to Length(Form1.Thread1.MyListProc.List)-1 do
  if ProcedimentoOrigem = Form1.Thread1.MyListProc.List[I].NomeProcedimento
    then begin
      Synchronize(
        Procedure
        begin
          RecordProcedure                  := Form1.Thread1.MyListProc.ExtractAt(I);
          RecordProcedure.MetaDado         := MyListProc.First.MetaDado + 'Houve Nova Conexão;';
          RecordProcedure.DSList.Add(DS);
          RecordProcedure.SQLList          := SQLList;
          RecordProcedure.EmConsulta := True;
          Form1.Thread1.MyListProc.Insert(I, RecordProcedure);
        end);
    end;
  for I := 0 to Length(Form1.Thread1.MyListProcWillProcAssync.List)-1 do
  if ProcedimentoOrigem = Form1.Thread1.MyListProcWillProcAssync.List[I].NomeProcedimento
    then begin
      Synchronize(
        Procedure
        begin
          RecordProcedure                 := Form1.Thread1.MyListProcWillProcAssync.ExtractAt(I);
          RecordProcedure.MetaDado        := RecordProcedure.MetaDado + 'Houve Nova Conexão;';
          RecordProcedure.DSList.Add(DS);
          RecordProcedure.SQLList         := SQLList;
          RecordProcedure.EmConsulta := True;
          Form1.Thread1.MyListProcWillProcAssync.Insert(I, RecordProcedure);
        end);
    end;
  Result := RecordProcedure;
end;

procedure TThreadMain.CancelarConsulta(ProcedimentoOrigem: String);
var
  I: Integer;
begin
  for I := 0 to Form1.Thread1.MyListProcWillProcAssync.Count - 1 do
  if Form1.Thread1.MyListProcWillProcAssync.Items[I].NomeProcedimento = ProcedimentoOrigem then begin
    if Form1.Thread1.MyListProcWillProcAssync.Items[I].EmConsulta then begin
      Synchronize(
        Procedure
        var
          Procedimento : TRecordProcedure;
        begin
          try
            Procedimento := Form1.Thread1.MyListProcWillProcAssync.ExtractAt(I);
            Procedimento.SQLList.DS.Enabled := False;
            Procedimento.SQLList.Connection.RollbackTrans;
          finally
            Procedimento.EmConsulta := False;
            Form1.Thread1.MyListProcWillProcAssync.Insert(I, Procedimento);
          end;
        end
      );
    end;
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
        Synchronize(Procedure begin TDBGrid(Form.Components[i]).DataSource := DSAux end);
      end
      else
    if (Form.Components[i] is TDBMemo)  and (TDBMemo(Form.Components[i]).DataSource = DS)
      then begin
        ID := ID + 1;
        DSAux      := TDataSource.Create(Form1);
        DSAux.Name := DS.Name+'INACTIVE'+IntToStr(ID);
        Synchronize(Procedure begin TDBMemo(Form.Components[i]).DataSource := DSAux end);
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
      then begin
        Synchronize(Procedure begin TDBGrid(Form.Components[i]).DataSource := DS end);
      end
      else
    if (Form.Components[i] is TDBMemo)  and (Copy(String(TDBMemo(Form.Components[i]).DataSource.Name),0,Pos('INACTIVE', String(TDBMemo(Form.Components[i]).DataSource.Name))-1) = DS.Name)
      then begin
        Synchronize(procedure begin TDBMemo(Form.Components[i]).DataSource := DS end);
      end
  end;
  //Criar em breve --> Vincular Todos Daquele Mesmo Ramo De Processos
end;
// ------------------- MAIN -------------------- //

procedure TForm1.Button3Click(Sender: TObject);
begin
  Thread1.ProcedimentoGenericoAssync(Consulta,'Consulta');
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  Thread1.CancelarConsulta('Consulta');
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
  RecordProcedure: TRecordProcedure;
begin
  try
    RecordProcedure := Thread1.NovaConexao(DataSource1,'Consulta');
    RecordProcedure.SQLList.Qry.Close;
    RecordProcedure.SQLList.Connection.Connected := True;
    RecordProcedure.SQLList.Connection.BeginTrans;
    Button3.Visible := False;
    RecordProcedure.SQLList.Qry.Open;
    Thread1.Synchronize(
    procedure
    var
      I : Integer;
    begin
      for I := 0 to Thread1.MyListProcWillProcAssync.Count do if RecordProcedure.NomeProcedimento = Thread1.MyListProcWillProcAssync.List[I].NomeProcedimento then break;
      if Thread1.MyListProcWillProcAssync.List[I].EmConsulta
        then RecordProcedure.SQLList.Connection.CommitTrans
        else RecordProcedure.SQLList.Qry.Close;//é porque eu cancelei no meio
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
