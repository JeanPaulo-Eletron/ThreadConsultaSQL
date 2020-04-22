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
    Connection: TADOConnection;
    Query: TADOQuery;
    DataSource: TDataSource;
    NaoPermitirFilaRequisicao: Boolean;
    MyList:     TList<TSQLList>;
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
    procedure Execute; override;
public
    EmConsulta: boolean;
    RecordProcedure:  TRecordProcedure;
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
    Query1COLUMN1: TIntegerField;
    Query1COLUMN2: TStringField;
    Query1COLUMN3: TBCDField;
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
  Procedimento: TProc;
begin
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
          MyListProcWillProcAssync.First.Procedimento;
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
    Query.DataSetField              := Qry.DataSetField;
    Query.Open;
    while Query.Fields.Count<>0 do begin
      Query.Fields.Remove(Query.Fields.Fields[Query.Fields.Count-1]);
    end;
    for I:=0 to Qry.Parameters.Count - 1 do begin
      Query.Parameters.Items[i]       := Qry.Parameters.Items[i];
    end;
    Query.Close;
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
      Field.DataSet      := TDataSet(Query);
      if (Qry.Fields.Fields[I].ClassName = 'TFloatField')    or (Qry.Fields.Fields[I].ClassName = 'TBCDField') or
         (Qry.Fields.Fields[I].ClassName = 'TExtendedField') or (Qry.Fields.Fields[I].ClassName = 'TSingleField')or
         (Qry.Fields.Fields[I].ClassName = 'TFMTBCDField')   or (Qry.Fields.Fields[I].ClassName = 'TUnsignedAutoIncField') or
         (Qry.Fields.Fields[I].ClassName = 'TAggregateField') // Todas os tipos de campos que possuem esse tipo de operação(currency)
        then TFloatField(Field).currency   := TFloatField(Qry.Fields.Fields[I]).currency;
    end
  end;
  if (DS <> nil) then begin
    if DataSource = nil
      then DataSource               := TDataSource.Create(Form1);
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
  KillTimer(0, TimerId);
  if (EmConsulta) or (QtdeProcAsync <> 0)
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
