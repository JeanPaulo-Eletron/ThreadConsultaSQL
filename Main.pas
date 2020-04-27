//Feito por: Jean Paulo Athanazio De Mei
//Timer ainda não está adaptado para usar consultas
{     Anotações:
      Bloqueada ---> verificar se threads estão bloqueada, para atender sobe demanda. ---> Monitor(Para aumentar a qtde sobe demanda """(Cores.dwNumberOfProcessors - 1) + IdlenessIndex(Uma expressão matemática logaritma baseada na memoria ram e no numero de cores[Uso intensivo de CPU, Uso intensivo de HD --> Por meta dados])""")
      Threshold ---> Limiar   NODE X APACHE(LENTIDÃO).
      Inferno da DLL e CALLBACKS e usar promices fica mais simples.
}
unit Main;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    System.Rtti, System.TypInfo, Generics.Collections, Vcl.ExtCtrls,
    Vcl.DBCtrls;

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
    end;
type
    TThreadMain = class(TThread)
private
    QtdeProcAsync: Integer;
    MyListProcAssync: TList<TRecordProcedure>;
    MyListProcWillProcAssync: TList<TRecordProcedure>;
    MyListProcTimerAssync: TList<TRecordProcedure>;
    QtdeTimers: Integer;
    MyListTimer: TList<TRecordProcedure>;
    ID : Integer;
    procedure Dispatcher;
    procedure WMProcGenericoAssync(Msg: TMsg);
    procedure WMTIMERAssync(Msg: TMsg);
    procedure DesvincularComponente(DS: TDataSource);
    procedure VincularComponente(DS: TDataSource);
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

TFormMain = class(TForm)
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
  FormMain: TFormMain;
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
  for I := 0 to Length(FormMain.Thread1.MyListTimer.List) do if FormMain.Thread1.MyListTimer.List[I].ID = Integer(idEvent) then break;
  Proc := FormMain.Thread1.MyListTimer.List[I].RProcedimento;
  Proc;
end;

// ------------------- THREAD CONSULTA -------------------- //

procedure TThreadMain.Execute;
begin
  Rest := 1;
  FreeOnTerminate := self.Finished;
  if MyListProcWillProcAssync = nil
    then MyListProcWillProcAssync := TList<TRecordProcedure>.Create;
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
    while QtdeProcAsync >= (Integer(Cores.dwNumberOfProcessors) - 1) do sleep(Rest);//melhorar para IO
    EmConsulta := true;
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
        EmConsulta := false;
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
  if MyListProcTimerAssync = nil
    then  MyListProcTimerAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.Procedimento := Procedimento;
  MyListProcTimerAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_TIMERTHREADASSYNC, Rest, 1);
end;

procedure TThreadMain.Timer(Rest: NativeUInt; Procedimento: TProc);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcTimerAssync = nil
    then  MyListProcTimerAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.RProcedimento := Procedimento;
  MyListProcTimerAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_TIMERTHREADASSYNC, Rest, 2);
end;

procedure TThreadMain.TimerAssync(Rest: NativeUInt; Procedimento: TProcedure);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcTimerAssync = nil
    then  MyListProcTimerAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.Procedimento := Procedimento;
  MyListProcTimerAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_TIMERTHREADASSYNC, Rest, 3);
end;

procedure TThreadMain.TimerAssync(Rest: NativeUInt; Procedimento: TProc);
begin
  if NaoPermitirFilaRequisicao and EmConsulta
    then exit;
  if MyListProcTimerAssync = nil
    then  MyListProcTimerAssync := TList<TRecordProcedure>.Create;
  Self.RecordProcedure.RProcedimento := Procedimento;
  MyListProcTimerAssync.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_TIMERTHREADASSYNC, Rest, 4);
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

  if Msg.lParam mod 2 = 1
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
  if Msg.lParam <= 2
    then Aux.RProcedimento := procedure begin
                                Synchronize(procedure
                                            var
                                              Procedimento : TProc;
                                            begin
                                              Procedimento := Aux.RProcedimento;
                                              Procedimento;
                                            end);
                              end;
  Synchronize( procedure begin
                 TimerId   := SetTimer(0, QtdeTimers, Rest, @MyTimeout);
                 Aux.ID    := TimerID;
                 MyListTimer.Add(Aux);
               end );// não async vai no main
  MyListProcTimerAssync.Delete(0);
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
    SQLList.Connection                      := TADOConnection.Create(FormMain);
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
  for I := 0 to Length(FormMain.Thread1.MyListProcWillProcAssync.List)-1 do
  if ProcedimentoOrigem = FormMain.Thread1.MyListProcWillProcAssync.List[I].NomeProcedimento
    then begin
      Synchronize(
        Procedure
        begin
          RecordProcedure                 := FormMain.Thread1.MyListProcWillProcAssync.ExtractAt(I);
          RecordProcedure.DSList.Add(DS);
          RecordProcedure.SQLList         := SQLList;
          RecordProcedure.EmConsulta      := True;
          FormMain.Thread1.MyListProcWillProcAssync.Insert(I, RecordProcedure);
        end);
    end;
  RecordProcedure.SQLList.Qry.Close;
  RecordProcedure.SQLList.Connection.Connected := True;
  RecordProcedure.SQLList.Connection.BeginTrans;
  Result := RecordProcedure;
end;

procedure TThreadMain.CancelarConsulta(ProcedimentoOrigem: String);
var
  I: Integer;
begin
  for I := 0 to FormMain.Thread1.MyListProcWillProcAssync.Count - 1 do
  if FormMain.Thread1.MyListProcWillProcAssync.Items[I].NomeProcedimento = ProcedimentoOrigem then begin
    if FormMain.Thread1.MyListProcWillProcAssync.Items[I].EmConsulta then begin
      Synchronize(
        Procedure
        var
          Procedimento : TRecordProcedure;
        begin
          try
            Procedimento := FormMain.Thread1.MyListProcWillProcAssync.ExtractAt(I);
            Procedimento.SQLList.DS.Enabled := False;
            Procedimento.SQLList.Connection.RollbackTrans;
          finally
            Procedimento.EmConsulta := False;
            FormMain.Thread1.MyListProcWillProcAssync.Insert(I, Procedimento);
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
        DSAux      := TDataSource.Create(FormMain);
        DSAux.Name := DS.Name+'INACTIVE'+IntToStr(ID);
        Synchronize(Procedure begin TDBGrid(Form.Components[i]).DataSource := DSAux end);
      end
      else
    if (Form.Components[i] is TDBMemo)  and (TDBMemo(Form.Components[i]).DataSource = DS)
      then begin
        ID := ID + 1;
        DSAux      := TDataSource.Create(FormMain);
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
end;
// ------------------- MAIN -------------------- //

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

procedure TFormMain.Button6Click(Sender: TObject);
begin
  Thread1.Timer(3000,
  procedure
  begin
    if StrToInt(FormMain.lbl1.Caption) > 2000
      then FormMain.lbl1.Caption := '0';
  end);
end;

procedure TFormMain.Button7Click(Sender: TObject);
begin
  Thread1.TimerAssync(100,
  procedure
  begin
    if StrToInt(FormMain.lbl1.Caption) > 2000
      then FormMain.lbl1.Caption := '0';
  end);
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

procedure TFormMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if not Button3.Visible
    then FormMain.Button4Click(Button4);
  Application.ProcessMessages;
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
