//Feito por: Jean Paulo Athanazio De Mei
unit Main;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    System.Rtti, System.TypInfo, Generics.Collections, Vcl.ExtCtrls;

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
    MyListTimerAssync: TList<TRecordProcedure>;
    ID : Integer;
    procedure Dispatcher;
    procedure WMProcGenerico(Msg: TMsg);
    procedure WMOpen(Msg: TMsg);
    procedure WMProcGenericoAssync(Msg: TMsg);
    procedure WMTIMER(Msg: TMsg);
    procedure WMTIMERAssync(Msg: TMsg);
    procedure PrepararRequisicaoConsulta(DS: TDataSource;Button: TButton);
    procedure RelocarGrid(DS: TDataSource);
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
    procedure CancelarConsulta;
    procedure NovaConexao(DS: TDataSource);
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
  for I := 0 to Length(Form1.Thread1.MyListTimer.List) do if Form1.Thread1.MyListTimer.List[I].ID = idEvent  then break;
  Proc := Form1.Thread1.MyListTimer.List[I].RProcedimento;
  Proc;
end;

// ------------------- THREAD CONSULTA -------------------- //

procedure TThreadMain.Execute;
begin
  Rest := 1;
  FreeOnTerminate := self.Finished;
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
    while QtdeProcAsync >= (Cores.dwNumberOfProcessors - 1) do sleep(Rest);//melhorar para IO
    EmConsulta := true;
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

procedure TThreadMain.RelocarGrid(DS: TDataSource);
var
  i: integer;
  Form: TForm;
  Qry:   TAdoQuery;
begin
  Qry:= TAdoQuery(DS.DataSet);
  DS.DataSet := nil;
  Form := TForm(Qry.Owner);
  for i := 0 to (Form.ComponentCount - 1) do begin
       if (Form.Components[i] is TDBGrid)  and (TDBGrid(Form.Components[i]).DataSource = DS)
         then TDBGrid(Form.Components[i]).DataSource := SQLList.DS;
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

procedure TThreadMain.ProcedimentoGenerico(Procedimento: TProcedure);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProc = nil
    then  MyListProc := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.Procedimento := Procedimento;
  MyListProc.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICO, 0, 0);
end;

procedure TThreadMain.ProcedimentoGenerico(Procedimento: TProc);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProc = nil
    then  MyListProc := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.RProcedimento := Procedimento;
  MyListProc.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICO, 1, 0);
end;

procedure TThreadMain.ProcedimentoGenericoAssync(Procedimento: TProcedure);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcAssync = nil
    then  MyListProcAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.Procedimento := Procedimento;
  MyListProcAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 0, 0);
end;

procedure TThreadMain.ProcedimentoGenericoAssync(Procedimento: TProc);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcAssync = nil
    then  MyListProcAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.RProcedimento := Procedimento;
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
    RelocarGrid(List.DS);
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
    Button.Caption := 'Consultar direto';
    MyList.Remove(List);
    MyListConnection.Remove(SQLList);
 end;
end;

{Procedimento Generico}
procedure TThreadMain.WMProcGenerico(Msg: TMsg);
var
  Procedimento: TProc;
begin
  if Integer(Msg.wParam) = 0
    then begin
      MyListProc.first.Procedimento;
    end
    else begin
      Procedimento := MyListProc.first.RProcedimento;
      Procedimento;
    end;
  MyListProc.Remove(MyListProc.First);
end;

procedure TThreadMain.WMProcGenericoAssync(Msg: TMsg);
var
  Procedimento: TProc;
  Aux: TRecordProcedure;
begin
  if MyListProcWillProcAssync = nil
    then MyListProcWillProcAssync := TList<TRecordProcedure>.Create;
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
          I : Integer;
        begin
          for I := 0 to Length(Form1.Thread1.MyListProcWillProcAssync.List) do if Form1.Thread1.MyListProcWillProcAssync.List[I].ID = ID  then break;
          MyListProcWillProcAssync.List[I].Procedimento;
          if Self.Finished
            then exit;
          QtdeProcAsync := QtdeProcAsync - 1;
          MyListProcWillProcAssync.Delete(0);
        end).Start;
    end
    else begin
      CreateAnonymousThread(
        procedure
        var
          I : Integer;
        begin
          for I := 0 to Length(Form1.Thread1.MyListProcWillProcAssync.List) do if Form1.Thread1.MyListProcWillProcAssync.List[I].ID = ID  then break;
          Procedimento := Form1.Thread1.MyListProcWillProcAssync.List[I].RProcedimento;
          Procedimento;
          if Self.Finished
            then exit;
          QtdeProcAsync := QtdeProcAsync - 1;
          MyListProcWillProcAssync.Delete(0);
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

  if Msg.lParam = 0
    then Procedimento  := MyListProcTimer.First.Procedimento
    else RProcedimento := MyListProcTimer.First.RProcedimento;

  Rest := Msg.wParam;
  if Msg.lParam = 0
    then begin
      Aux.RProcedimento :=
        procedure begin
          if Terminated
            then exit;
          QtdeProcAsync := QtdeProcAsync + 1;
          Procedimento;
          QtdeProcAsync := QtdeProcAsync - 1;
        end;
    end
    else begin
      Aux.RProcedimento :=
        procedure begin
          if Terminated
            then exit;
          QtdeProcAsync := QtdeProcAsync - 1;
          RProcedimento;
          QtdeProcAsync := QtdeProcAsync + 1;
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
begin
  if Msg.lParam = 0
    then Aux.Procedimento  := MyListProcTimerAssync.First.Procedimento
    else Aux.RProcedimento := MyListProcTimerAssync.First.RProcedimento;
  if MyListTimer = nil
    then MyListTimerAssync := TList<TRecordProcedure>.Create;
  ID := ID + 1;
  Aux.ID := ID;
  MyListTimerAssync.Add(Aux);
  CreateAnonymousThread(
    procedure
    var
      Rest: NativeUInt;
      I:    Integer;
      RProc: TProc;
    begin
      Rest := Msg.wParam;
      for I := 0 to Length(Form1.Thread1.MyListTimerAssync.List) do if Form1.Thread1.MyListTimerAssync.List[I].ID = ID  then break;
      RProc := Form1.Thread1.MyListTimerAssync.List[I].RProcedimento;
      while true do begin
        Sleep(Rest);
        if Finished
          then exit;
        if Terminated
          then break;
        QtdeProcAsync := QtdeProcAsync + 1;
        if Msg.lParam = 0
          then Form1.Thread1.MyListTimerAssync.List[I].Procedimento
          else RProc;
        QtdeProcAsync := QtdeProcAsync - 1;
      end;
      MyListTimerAssync.Delete(I);
    end
  ).Start;
  MyListProcTimerAssync.Delete(0);
end;

procedure TThreadMain.NovaConexao(DS: TDataSource);
// é importante criar uma nova conexão ao acessar o banco pra não dar erro de ter duas consultas
// retornando resultado ao mesmo tempo, e também para permitir o rollback sem afetar as outras consultas...
var
  Qry: TAdoQuery;
  ConnectionAux: TADOConnection;
  I : Integer;
  Field : TField;
  MyList: TSQLList;
 begin
  if MyListConnection = nil
    then MyListConnection := TList<TSQLList>.Create;
  ID := ID + 1;
  Qry := TAdoQuery(DS.DataSet);
  ConnectionAux := Qry.Connection;
  if ConnectionAux <> nil then begin
    MyList.Connection                      := TADOConnection.Create(Form1);
    MyList.Connection.ConnectionString     := ConnectionAux.ConnectionString;
    MyList.Connection.ConnectionTimeout    := ConnectionAux.ConnectionTimeout;
    MyList.Connection.ConnectOptions       := ConnectionAux.ConnectOptions;
    MyList.Connection.CursorLocation       := ConnectionAux.CursorLocation;
    MyList.Connection.DefaultDatabase      := ConnectionAux.DefaultDatabase;
    MyList.Connection.IsolationLevel       := ConnectionAux.IsolationLevel;
    MyList.Connection.KeepConnection       := ConnectionAux.KeepConnection;
    MyList.Connection.LoginPrompt          := ConnectionAux.LoginPrompt;
    MyList.Connection.Mode                 := ConnectionAux.Mode;
    MyList.Connection.Name                 := 'Thread'+IntToStr(ID)+IntToStr(Self.ThreadID)+ConnectionAux.Name;
    MyList.Connection.Provider             := ConnectionAux.Provider;
    MyList.Connection.Tag                  := ConnectionAux.Tag;
  end;
  if pos('Assync',Qry.Name) <> 0 then begin
    Try
      ClonarQry(Qry);
    except
      Self.Synchronize(
        Procedure begin
          MyList.Connection.Connected := True;
          Qry.Connection        := MyList.Connection;
          MyList.Qry            := Qry;
        end);
    end;
  end
  else begin
    Self.Synchronize(
      Procedure begin
        MyList.Connection.Connected := True;
        Qry.Connection        := MyList.Connection;
        MyList.Qry            := Qry;
      end);
  end;

  if (DS <> nil) then begin
    MyList.DS                      := TDataSource.Create(Form1);
    MyList.DS.AutoEdit             := DS.AutoEdit;
    MyList.DS.Name                 := 'Thread'+IntToStr(ID)+IntToStr(Self.ThreadID)+DS.Name;
    MyList.DS.Tag                  := DS.Tag;
    MyList.DS.DataSet              := TDataSet(MyList.Qry);
    DS.Enabled                     := False;
  end;
  MyList.Connection.Connected            := True;
  MyListConnection.Add(MyList);
end;
procedure TThreadMain.ClonarQry(Qry: TAdoQuery);
begin

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
  Thread1.ProcedimentoGenerico(Consulta);
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
