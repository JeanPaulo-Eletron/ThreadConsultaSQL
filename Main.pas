//Feito por: Jean Paulo Athanazio De Mei
{     Anotações:
      Bloqueada ---> verificar se threads estão bloqueada, para atender sobe demanda. ---> Monitor(Para aumentar a qtde sobe demanda """(Cores.dwNumberOfProcessors - 1) + IdlenessIndex(Uma expressão matemática logaritma baseada na memoria ram e no numero de cores[Uso intensivo de CPU, Uso intensivo de HD --> Por meta dados])""")
      Threshold ---> Limiar   NODE X APACHE(LENTIDÃO).
      Inferno da DLL e CALLBACKS e usar promices fica mais simples.
}

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
    TStatus = class(TObject)
    public
      EmConsulta: Boolean;
      EmProcesso: Boolean;
    end;
    TInformacoesAdicionais = class(TObject)
    public
      ID   : Integer;
      NomeProcedimento : String;
      Tag: NativeInt;
    end;
    TRecordProcedure = record
      Procedimento : TProcedure;
      RProcedimento : TProc;
      Status : TStatus;
      SQLList: TSQLList;
      InformacoesAdicionais : TInformacoesAdicionais;
      DSList  : TList<TDataSource>;
    end;
type
    TThreadMain = class(TThread)
private
    QtdeProcAsync: Integer;
    FilaProcAssyncPendentesDeExecucao: TList<TRecordProcedure>;
    FilaProcAssyncEmExecucao: TList<TRecordProcedure>;
    ID : Integer;
    Cores : TSystemInfo;
    Msg : TMsg;
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
  if FilaProcAssyncEmExecucao = nil
    then FilaProcAssyncEmExecucao := TList<TRecordProcedure>.Create;
  FormMain.FLock := TCriticalSection.Create;
  GetSystemInfo(Cores);
  while not Terminated do begin
    Dispatcher;
  end;
end;

procedure TThreadMain.Dispatcher;
var ThreadAntiga : TThreadMain;
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
      ThreadAntiga := FormMain.Thread1;
      FormMain.Thread1 := TThreadMain.Create(false);
      ThreadAntiga.Terminate;
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
  if FilaProcAssyncPendentesDeExecucao = nil
    then  FilaProcAssyncPendentesDeExecucao := TList<TRecordProcedure>.Create;
  RecordProcedure.Procedimento := Procedimento;
  RecordProcedure.InformacoesAdicionais := TInformacoesAdicionais.Create;
  RecordProcedure.InformacoesAdicionais.NomeProcedimento := NomeProcedimento;
  RecordProcedure.DSList := TList<TDataSource>.Create;
  RecordProcedure.Status := TStatus.Create;
  FilaProcAssyncPendentesDeExecucao.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 0, 0);
end;

procedure TThreadMain.ProcedimentoGenericoAssync(Procedimento: TProc; NomeProcedimento: String);
begin
  if NaoPermitirFilaDeProcessos and EmProcesso
    then exit;
  if FilaProcAssyncPendentesDeExecucao = nil
    then  FilaProcAssyncPendentesDeExecucao := TList<TRecordProcedure>.Create;
  RecordProcedure.RProcedimento := Procedimento;
  RecordProcedure.InformacoesAdicionais := TInformacoesAdicionais.Create;
  RecordProcedure.InformacoesAdicionais.NomeProcedimento := NomeProcedimento;
  RecordProcedure.DSList := TList<TDataSource>.Create;
  RecordProcedure.Status := TStatus.Create;
  FilaProcAssyncPendentesDeExecucao.Add(Self.RecordProcedure);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 1, 0);
end;

procedure TThreadMain.WMProcGenericoAssync(Msg: TMsg);
var
  Procedimento: TProc;
  RecordProcedure: TRecordProcedure;
  I: Integer;
  NomeProcedimento : String;
begin
  RecordProcedure := FilaProcAssyncPendentesDeExecucao.First;// Pegando primeira requisição da fila
  QtdeProcAsync := QtdeProcAsync + 1;
  ID := ID + 1;
  RecordProcedure.InformacoesAdicionais.ID := ID;

  for I := 0 to FormMain.Thread1.FilaProcAssyncEmExecucao.Count - 1 do
  if (RecordProcedure.InformacoesAdicionais.NomeProcedimento = FormMain.Thread1.FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento) then begin
    exit;
  end;

  RecordProcedure.Status.EmProcesso  := True;
  NomeProcedimento            := RecordProcedure.InformacoesAdicionais.NomeProcedimento;
  FilaProcAssyncEmExecucao.Add(RecordProcedure);
  CreateAnonymousThread(
    procedure
    var
      I, K, L: Integer;
      RecordProcedure: TRecordProcedure;
    begin
      FormMain.FLock.Acquire;
      for I := 0 to FormMain.Thread1.FilaProcAssyncEmExecucao.Count - 1 do if FormMain.Thread1.FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento = NomeProcedimento  then break;
      RecordProcedure := FormMain.Thread1.FilaProcAssyncEmExecucao.Items[I];
      FormMain.FLock.Release;
      if Integer(Msg.wParam) = 0
        then RecordProcedure.Procedimento
        else begin
          Procedimento := RecordProcedure.RProcedimento;
          Procedimento;
        end;
      if Self.Finished
        then exit;
      QtdeProcAsync := QtdeProcAsync - 1;
      for L := 0 to RecordProcedure.DSList.Count - 1 do begin
        if RecordProcedure.Status.EmConsulta
          then TAdoQuery(RecordProcedure.DSList.List[L].DataSet).Connection.CommitTrans
          else TAdoQuery(RecordProcedure.DSList.List[L].DataSet).Close;
        VincularComponente(RecordProcedure.DSList.List[L]);
      end;
      FilaProcAssyncEmExecucao.Remove(RecordProcedure);
    end).Start;
  FilaProcAssyncPendentesDeExecucao.Remove(RecordProcedure);
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
    I: Integer;
    SQLList: TSQLList;
    Status: TStatus;
  begin
    ID := ID + 1;
    DataSourceReferencia.Enabled := False;
    DesvincularComponente(DataSourceReferencia);
    DataSourceReferencia.Enabled := True;
    RecordProcedureRetorno.SQLList.Connection                      := TADOConnection.Create(FormMain);
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
    RecordProcedureRetorno.SQLList.Connection.BeginTrans;
    for I := 0 to FormMain.Thread1.FilaProcAssyncEmExecucao.Count - 1 do
    if ProcedimentoOrigem = FormMain.Thread1.FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento
      then begin
        RecordProcedure := FormMain.Thread1.FilaProcAssyncEmExecucao.Items[I];
        Status := RecordProcedure.Status;
        Status.EmConsulta      := True;
        RecordProcedure.DSList.Add(DataSourceReferencia);
        RecordProcedure.SQLList         := RecordProcedureRetorno.SQLList;
      end;
  end);
  Result := RecordProcedureRetorno;
end;

procedure TThreadMain.CancelarConsulta(ProcedimentoOrigem: String);
var
  I, J: Integer;
  Procedimento : TRecordProcedure;
begin
  for I := 0 to FormMain.Thread1.FilaProcAssyncEmExecucao.Count - 1 do
  if FormMain.Thread1.FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento = ProcedimentoOrigem then begin
    if FormMain.Thread1.FilaProcAssyncEmExecucao.Items[I].Status.EmConsulta then begin
      try
        Procedimento := FormMain.Thread1.FilaProcAssyncEmExecucao.Items[I];
        for J := 0 to  Procedimento.DSList.Count - 1 do begin
          Procedimento.DSList.Items[J].Enabled := False;
          TADOQuery(Procedimento.DSList.Items[J].DataSet).Connection.RollbackTrans;
        end;
      finally
        Procedimento.Status.EmConsulta := False;
      end;
    end;
  end;
end;

procedure TThreadMain.Kill;
var
  I: integer;
begin
  for I := 0 to FilaProcAssyncEmExecucao.Count - 1 do CancelarConsulta(FilaProcAssyncEmExecucao.Items[I].InformacoesAdicionais.NomeProcedimento);//Cancelando todas as consultas
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
        Synchronize(Procedure begin TDBGrid(Form.Components[i]).DataSource := DS end);
        DS.Enabled := True;
      end
      else
    if (Form.Components[i] is TDBMemo)  and (Copy(String(TDBMemo(Form.Components[i]).DataSource.Name),0,Pos('INACTIVE', String(TDBMemo(Form.Components[i]).DataSource.Name))-1) = DS.Name)
      then begin
        Synchronize(Procedure begin TDBMemo(Form.Components[i]).DataSource := DS end);
        DS.Enabled := True;
      end
  end;
end;

// ------------------- MAIN -------------------- //

procedure TFormMain.Button3Click(Sender: TObject);
begin
  Thread1.ProcedimentoGenericoAssync(Consulta,'Consulta');
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
    RecordProcedure.SQLList.Qry.Close;
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
