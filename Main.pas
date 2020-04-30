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
unit Main;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Data.Win.ADODB, Vcl.StdCtrls,
    System.TypInfo, Generics.Collections, Vcl.ExtCtrls,
    Vcl.DBCtrls, SyncObjs, Vcl.Themes;

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
      RestInterval: Integer;
      EmProcesso: Boolean;
      Tag: NativeInt;
      Enabled: Boolean;
    end;
type
    TThreadMain = class(TThread)
private
    QtdeProcAsync: Integer;
    MyListProcAssync: TList<TRecordProcedure>;
    MyListProcWillProcAssync: TList<TRecordProcedure>;
    ID : Integer;
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
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProcedure; NomeProcedimento: String);overload;
    procedure ProcedimentoGenericoAssync(Procedimento: TProc; NomeProcedimento: String);overload;
    function  NovaConexao(DataSourceReferencia: TDataSource; ProcedimentoOrigem: String):TRecordProcedure;overload;
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
    ComboBox1: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure FormShow(Sender: TObject);
private
{ Private declarations }
    Thread1 : TThreadMain;
public
{ Public declarations }
    FLock : TCriticalSection;
    procedure Consulta;
    procedure Synchronize(AThreadProc: TProc);overload;
    procedure Synchronize(AThreadProc: TProc; Thread: TThread);overload;
end;
var
  FormMain: TFormMain;
  Timerid: UINT;
implementation

{$R *.DFM}

// ------------------- THREAD CONSULTA -------------------- //

procedure TThreadMain.Execute;
begin
  RestInterval := 1;
  FreeOnTerminate := self.Finished;
  if MyListProcWillProcAssync = nil
    then MyListProcWillProcAssync := TList<TRecordProcedure>.Create;
  FormMain.FLock := TCriticalSection.Create;
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
    Sleep(RestInterval);
    if Integer(Cores.dwNumberOfProcessors) > 1
      then while QtdeProcAsync >= (Integer(Cores.dwNumberOfProcessors) - 1) do sleep(RestInterval);//Otimização para hardware não sobrecarregar de processos pessados.
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
  CreateAnonymousThread(
    procedure
    var
      I, J : Integer;
    begin
      for I := 0 to Length(FormMain.Thread1.MyListProcWillProcAssync.List) do if FormMain.Thread1.MyListProcWillProcAssync.List[I].ID = ID  then break;
      if Integer(Msg.wParam) = 0
        then MyListProcWillProcAssync.List[I].Procedimento
        else begin
          Procedimento := FormMain.Thread1.MyListProcWillProcAssync.List[I].RProcedimento;
          Procedimento;
        end;
      if Self.Finished
        then exit;
      QtdeProcAsync := QtdeProcAsync - 1;
      for J := 0 to MyListProcWillProcAssync.List[I].DSList.Count - 1 do begin
        FormMain.FLock.Acquire;
        if MyListProcWillProcAssync.List[I].EmConsulta
          then TAdoQuery(MyListProcWillProcAssync.List[I].DSList.List[J].DataSet).Connection.CommitTrans
          else TAdoQuery(MyListProcWillProcAssync.List[I].DSList.List[J].DataSet).Close;
        VincularComponente(MyListProcWillProcAssync.List[I].DSList.List[J]);
        FormMain.FLock.Release;
      end;
      MyListProcWillProcAssync.Delete(I);
    end).Start;
    MyListProcAssync.Delete(0);
end;

function TThreadMain.NovaConexao(DataSourceReferencia: TDataSource; ProcedimentoOrigem: String):TRecordProcedure;
// é importante criar uma nova conexão ao acessar o banco pra não dar erro de ter duas consultas
// retornando resultado ao mesmo tempo, e também para permitir o rollback sem afetar as outras consultas...
var
  RecordProcedureRetorno: TRecordProcedure;
begin
  Self.Synchronize(
  Procedure
  var
    I : Integer;
    Qry: TAdoQuery;
    ConnectionReferencia: TADOConnection;
    SQLList: TSQLList;
  begin
    FormMain.FLock.Acquire;
    ID := ID + 1;
    DataSourceReferencia.Enabled := False;
    DesvincularComponente(DataSourceReferencia);
    DataSourceReferencia.Enabled := True;
    Qry := TAdoQuery(DataSourceReferencia.DataSet);
    ConnectionReferencia := Qry.Connection;
    RecordProcedureRetorno.SQLList.Connection                      := TADOConnection.Create(FormMain);
    RecordProcedureRetorno.SQLList.Connection.ConnectionString     := ConnectionReferencia.ConnectionString;
    RecordProcedureRetorno.SQLList.Connection.ConnectionTimeout    := ConnectionReferencia.ConnectionTimeout;
    RecordProcedureRetorno.SQLList.Connection.ConnectOptions       := ConnectionReferencia.ConnectOptions;
    RecordProcedureRetorno.SQLList.Connection.CursorLocation       := ConnectionReferencia.CursorLocation;
    RecordProcedureRetorno.SQLList.Connection.DefaultDatabase      := ConnectionReferencia.DefaultDatabase;
    RecordProcedureRetorno.SQLList.Connection.IsolationLevel       := ConnectionReferencia.IsolationLevel;
    RecordProcedureRetorno.SQLList.Connection.KeepConnection       := ConnectionReferencia.KeepConnection;
    RecordProcedureRetorno.SQLList.Connection.LoginPrompt          := ConnectionReferencia.LoginPrompt;
    RecordProcedureRetorno.SQLList.Connection.Mode                 := ConnectionReferencia.Mode;
    RecordProcedureRetorno.SQLList.Connection.Name                 := 'Thread'+IntToStr(ID)+IntToStr(Self.ThreadID)+ConnectionReferencia.Name;
    RecordProcedureRetorno.SQLList.Connection.Provider             := ConnectionReferencia.Provider;
    RecordProcedureRetorno.SQLList.Connection.Tag                  := ConnectionReferencia.Tag;
    RecordProcedureRetorno.SQLList.Connection.Connected            := True;
    RecordProcedureRetorno.SQLList.Qry                             := Qry;
    RecordProcedureRetorno.SQLList.Qry.Connection                  := RecordProcedureRetorno.SQLList.Connection;
    RecordProcedureRetorno.SQLList.DS                              := DataSourceReferencia;
    RecordProcedureRetorno.SQLList.DS.DataSet                      := TDataSet(RecordProcedureRetorno.SQLList.Qry);
    RecordProcedureRetorno.SQLList.DS.Enabled                      := True;
    RecordProcedureRetorno.SQLList.Qry.Close;
    RecordProcedureRetorno.SQLList.Connection.Connected            := True;
    RecordProcedureRetorno.SQLList.Connection.BeginTrans;
    for I := 0 to Length(FormMain.Thread1.MyListProcWillProcAssync.List)-1 do
    if ProcedimentoOrigem = FormMain.Thread1.MyListProcWillProcAssync.List[I].NomeProcedimento
      then begin
            RecordProcedure                 := FormMain.Thread1.MyListProcWillProcAssync.ExtractAt(I);
            RecordProcedure.DSList.Add(DataSourceReferencia);
            RecordProcedure.SQLList         := RecordProcedureRetorno.SQLList;
            RecordProcedure.EmConsulta      := True;
            FormMain.Thread1.MyListProcWillProcAssync.Insert(I, RecordProcedure);
      end;
    FormMain.FLock.Release;
  end);
  Result := RecordProcedureRetorno;
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
        FormMain.FLock.Acquire;
        Procedimento := FormMain.Thread1.MyListProcWillProcAssync.ExtractAt(I);
        Procedimento.SQLList.DS.Enabled := False;
        Procedimento.SQLList.Connection.RollbackTrans;
      finally
        Procedimento.EmConsulta := False;
        FormMain.Thread1.MyListProcWillProcAssync.Insert(I, Procedimento);
        FormMain.FLock.Release;
      end;
    end;
  end;
end;

procedure TThreadMain.Kill;
var
  I: integer;
begin
  for I := 0 to MyListProcWillProcAssync.Count - 1 do CancelarConsulta(MyListProcWillProcAssync.List[I].NomeProcedimento);//Cancelando todas as consultas
  FreeAndNil(FormMain.FLock);
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
        FormMain.FLock.Acquire;
        TDBGrid(Form.Components[i]).DataSource := DSAux;
        FormMain.FLock.Release;
      end
      else
    if (Form.Components[i] is TDBMemo)  and (TDBMemo(Form.Components[i]).DataSource = DS)
      then begin
        ID := ID + 1;
        DSAux      := TDataSource.Create(FormMain);
        DSAux.Name := DS.Name+'INACTIVE'+IntToStr(ID);
        FormMain.FLock.Acquire;
        TDBMemo(Form.Components[i]).DataSource := DSAux;
        FormMain.FLock.Release;
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
        TDBGrid(Form.Components[i]).DataSource.Enabled := False;
        Synchronize(Procedure begin TDBGrid(Form.Components[i]).DataSource := DS end);
        TDBGrid(Form.Components[i]).DataSource.Enabled := True;
      end
      else
    if (Form.Components[i] is TDBMemo)  and (Copy(String(TDBMemo(Form.Components[i]).DataSource.Name),0,Pos('INACTIVE', String(TDBMemo(Form.Components[i]).DataSource.Name))-1) = DS.Name)
      then begin
        TDBMemo(Form.Components[i]).DataSource.Enabled := False;
        Synchronize(Procedure begin TDBMemo(Form.Components[i]).DataSource := DS end);
        TDBMemo(Form.Components[i]).DataSource.Enabled := True;
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

procedure TFormMain.ComboBox1Change(Sender: TObject);
begin
  TStyleManager.TrySetStyle(ComboBox1.Items[ComboBox1.ItemIndex]);
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

procedure TFormMain.FormShow(Sender: TObject);
var
  s: String;
begin
  ComboBox1.Items.BeginUpdate;
  try
    ComboBox1.Items.Clear;
    for s in TStyleManager.StyleNames do
       ComboBox1.Items.Add(s);
    ComboBox1.Sorted := True;
    ComboBox1.ItemIndex := ComboBox1.Items.IndexOf(TStyleManager.ActiveStyle.Name);
  finally
    ComboBox1.Items.EndUpdate;
  end;
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
