//  Inherited;
unit ADOQueryControler;

interface

uses
    Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
    Dialogs, Db, Vcl.Grids, Vcl.DBGrids, Vcl.StdCtrls,
    System.TypInfo, Generics.Collections, Vcl.ExtCtrls, Vcl.DBCtrls,
    SyncObjs, Vcl.Themes, Vcl.Buttons, Data.Win.ADODB, Winapi.ADOInt,
    ThreadControler;

type
    TStatus = class(TObject)
    public
      FEmConsulta: Boolean;
      EmProcesso: Boolean;
    end;
TThread = class(ThreadControler.TThread)
  function  NovaConexao(DataSourceReferencia: TDataSource; ProcedimentoOrigem: String; ComponenteVinculado: TObject):TRecordProcedure;overload;
  procedure CancelarConsulta(ProcedimentoOrigem: String);
end;
TAdoQuery = class(Data.Win.ADODB.TADOQuery)
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
  property  ComponenteVinculado: TObject read GetComponenteVinculado write SetComponenteVinculado;
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
  procedure Open(NomeProcedimento: String; Thread: TThread);overload;
  procedure Open(NomeProcedimento: String; Thread: TThread; ComponenteVinculado: TObject);overload;
  procedure Open(NomeProcedimento: String; Thread: TThread; CallBack:TProc); overload;
  procedure Open(NomeProcedimento: String; Thread: TThread; ComponenteVinculado: TObject; CallBack:TProc); overload;
  procedure Open(NomeProcedimento: String; Thread: TThread; CallBack:TProcedure); overload;
  procedure Open(NomeProcedimento: String; Thread: TThread; ComponenteVinculado: TObject; CallBack:TProcedure); overload;
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
function  LocalizarDataSource(Qry: TAdoQuery): TDataSource;
type
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

function TThread.NovaConexao(DataSourceReferencia: TDataSource; ProcedimentoOrigem: String; ComponenteVinculado: TObject): TRecordProcedure;
begin
  TAdoQuery(DataSourceReferencia.DataSet).ComponenteVinculado := ComponenteVinculado;
  Result := Form.Thread.NovaConexao(DataSourceReferencia,ProcedimentoOrigem);
end;

function TForm.GetOnCreate: TNotifyEvent;
begin
  FOnCreate := FormCreate;
  Result    := FOnCreate;
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
            TAdoQuery(Procedimento.DSList.Items[J].Qry).Cancelar;
          finally
            Procedimento.DSList.Items[J].Status.FEmConsulta := False;
          end;
        end;
      end;
    end;
  end);
end;

procedure TForm.FormCreate(Sender: TObject);
begin
  Thread  := TThread.Create(false);
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

function TForm.IsForm: Boolean;//Esse controlador de thread só funciona em forms (para startar ele automáticamente, mas voce pode herdar a classe na unit que desejar e criar e startar a thread por lá) !!!
begin
  Result := true;
end;

////////////////////////QUERY FACILITADORES////////////////////////////

procedure TAdoQuery.ADOConnection1WillExecute(Connection: TADOConnection; // Decidi colocar isso aqui para podermos centralizar o padrão ADOQueryWillExecute quando ele estiver em modo assyncrono (se ele tentará refazer a conexão, se irá dar alerta e fechar o sistema, etc...
    var CommandText: WideString; var CursorType: TCursorType;
    var LockType: TADOLockType; var CommandType: TCommandType;
    var ExecuteOptions: TExecuteOptions; var EventStatus: TEventStatus;
    const Command: _Command; const Recordset: _Recordset);
begin
  Recordset.Properties['Preserve on commit'].Value := True;//  Após confirmar uma transação, o conjunto de registros permanece ativo. Portanto, é possível buscar novas linhas; atualizar, excluir e inserir linhas; e assim por diante.
  Recordset.Properties['Preserve on abort'].Value  := True;//	Após abortar uma transação, o conjunto de registros permanece ativo. Portanto, é possível buscar novas linhas, atualizar, excluir e inserir linhas e assim por diante.
end;

procedure TAdoQuery.SetComponenteVinculado(ComponenteVinculado : TObject);
begin
  if ComponenteVinculado is TSpeedButton
    then begin
      FSpeedButton := TSpeedButton(ComponenteVinculado);
      if FSpeedButton.Caption <> 'Cancelar'
        then CaptionAnterior := FSpeedButton.Caption;
      FButton   := nil;
      FCheckBox := nil;
    end
    else
  if ComponenteVinculado is TButton
    then begin
      FButton := TButton(ComponenteVinculado);
      if FButton.Caption <> 'Cancelar'
        then CaptionAnterior := FButton.Caption;
      FSpeedButton := nil;
      FCheckBox    := nil;
    end
    else
  if ComponenteVinculado is TCheckBox
    then begin
      FCheckBox := TCheckBox(ComponenteVinculado);
      if FCheckBox.Caption <> 'Cancelar'
        then CaptionAnterior := FCheckBox.Caption;
      FSpeedButton := nil;
      FButton      := nil;
    end
    else Exception.Create('Tipo não programado!');
end;

function TAdoQuery.GetComponenteVinculado: TObject;
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

procedure TAdoQuery.Cancelar;
begin
  if (ComponenteVinculado <> nil) then begin
    if ( (ComponenteVinculado is TSpeedButton) and (TSpeedButton(ComponenteVinculado).Caption = 'Cancelar') ) or
       ( (ComponenteVinculado is TButton     ) and (TButton     (ComponenteVinculado).Caption = 'Cancelar') ) or
       ( (ComponenteVinculado is TCheckBox   ) and (TCheckBox   (ComponenteVinculado).Caption = 'Cancelar') )
      then Cancelado := True;
  end;
end;

procedure TAdoQuery.EOnFetchProgress(DataSet: TCustomADODataSet; Progress, MaxProgress: Integer; var EventStatus: TEventStatus);
begin
  if (Cancelado) then begin
    Syncronized(
    procedure
    begin
      Command.Cancel;// Cancelei o comando open no banco de dados
      TCheckBox   (ComponenteVinculado).Caption := CaptionAnterior;
    end);
  end;
  Cancelado := False;
end;

procedure TAdoQuery.EOnFetchComplete(DataSet: TCustomADODataSet; const Error: Error; var EventStatus: TEventStatus);
begin
  CompletarConsulta(DataSet);
end;

procedure TAdoQuery.OpenAssync;//Starta uma consulta de forma assyncrona independente de Thread, porém não espera a consulta terminar, para cancelar tem que chamar o diretamente o método cancelar da qry.
begin
  if ComponenteVinculado = nil
    then raise Exception.Create('Button não configurado');
  PrepararOpen(EOnFetchComplete);
end;

procedure TAdoQuery.Open;
begin
  if ComponenteVinculado <> nil
    then begin//O button da qry deve ser preenchido dentro da Thread(pois para cancelar esse componente deve conter o tratamento), então esperar não causa problemas
      if TCheckBox(ComponenteVinculado).Caption = 'Cancelar'
        then Cancelar;
      if (ComponenteVinculado is TCheckBox) and (not (TCheckBox(ComponenteVinculado)).Checked)
        then EXIT;
      OpenAssync;
      while FEmConsulta do Sleep(50);//Consultas com cancelar devem ser feitas em Thread, e para cancelar usar a procedure "CancelarConsulta".
    end
    else begin
      if Pos('Listagem',Name) > 0 then begin
        if not FEmConsulta
          then PrepararOpen(EOnFetchComplete);
        if Owner is TForm
          then TForm(Owner).Enabled := False;
        while FEmConsulta do Application.ProcessMessages;//Aqui está a "mágica", se não estiver em Thread ele continua a funcionar, porém, para querys que não são de listagem será necessário readequar o sistema para que ao pegar um valor ele espere a query terminar a consulta.
        if Owner is TForm
          then TForm(Owner).Enabled := True;
      end
      else begin
        ExecuteOptions := [];
        Active := True;//Ele dará um active normal, caso queira assyncrono use a com callback e readeque o código para ele só acessar a field quando a consulta estiver concluída.
      end;
    end;
end;

procedure TAdoQuery.CompletarConsulta(DataSet:TCustomADODataSet);
var DataSource : TDataSource;
begin
  Syncronized(
  procedure
  begin
    DataSet.Resync([]);
    DataSource := LocalizarDataSource(TAdoQuery(Self));
    if DataSource <> Nil
      then DataSource.Enabled := True;
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
    ExecuteOptions := [];
  end);
end;

procedure TAdoQuery.PrepararOpen(EOnFetchComplete:TRecordsetEvent);
var DataSource: TDataSource;
begin
  if (ComponenteVinculado is TCheckBox) and (not (TCheckBox(ComponenteVinculado)).Checked)
    then EXIT;
  Close;
  Syncronized(
  procedure
  begin
    Connection := CopiarObjetoConexao(Connection);
    Connection.OnWillExecute := TWillExecuteEvent(LocalizarProcedurePeloNome('ADOConnection1WillExecute',TAdoQuery));
    OnFetchProgress := EOnFetchProgress;
    OnFetchComplete := EOnFetchComplete;
    ExecuteOptions := [eoAsyncExecute, eoAsyncFetchNonBlocking];
    Connection.Connected := True;
  end
  );
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
    Cancelado := False;
    Try
      Active := True;
    Except
      on E:Exception do begin
        Infobox('Houve um problema ao tentar realizar a consulta no banco de dados:' + E.Message);
        abort;
      end;
    end;
    DataSource := LocalizarDataSource(TAdoQuery(Self));
    if DataSource <> nil
      then DataSource.Enabled := False;
end;

procedure TAdoQuery.ECBOnFetchComplete(DataSet: TCustomADODataSet;
  const Error: Error; var EventStatus: TEventStatus);
begin
  CompletarConsulta(DataSet);
  FTPCallBack;
end;

procedure TAdoQuery.Open(CallBack: TProc);
begin
  if FEmConsulta
    then Cancelar
    else begin
      FTPCallBack := CallBack;
      PrepararOpen(ECBOnFetchComplete);
    end
end;

procedure TAdoQuery.Open(CallBack: TProcedure);
var Proc: TProc;
begin
  Proc := Procedure Begin CallBack end;
  Open(Proc);
end;

procedure TAdoQuery.Open(CallBack: TProc; ComponenteVinculado: TObject);
begin
  if Self.ComponenteVinculado <> ComponenteVinculado
    then Self.ComponenteVinculado := ComponenteVinculado;
  Open(CallBack);
end;

procedure TAdoQuery.Open(CallBack: TProcedure; ComponenteVinculado: TObject);
begin
  if Self.ComponenteVinculado <> ComponenteVinculado
    then Self.ComponenteVinculado := ComponenteVinculado;
  Open(CallBack);
end;

procedure TAdoQuery.Open(NomeProcedimento: String; Thread: TThread);
begin
  Thread.NovaConexao(LocalizarDataSource(Self),NomeProcedimento);
  Open;
end;

procedure TAdoQuery.Open(NomeProcedimento: String; Thread: TThread;
  ComponenteVinculado: TObject);
begin
  Thread.NovaConexao(LocalizarDataSource(Self),NomeProcedimento, ComponenteVinculado);
  Open;
end;

procedure TAdoQuery.Open(NomeProcedimento: String; Thread: TThread;
  CallBack: TProc);
begin
  Thread.NovaConexao(LocalizarDataSource(Self),NomeProcedimento);
  open(CallBack);
end;

procedure TAdoQuery.Open(NomeProcedimento: String; Thread: TThread;
  ComponenteVinculado: TObject; CallBack: TProc);
begin
  Thread.NovaConexao(LocalizarDataSource(Self),NomeProcedimento, ComponenteVinculado);
  open(CallBack);
end;

procedure TAdoQuery.Open(NomeProcedimento: String; Thread: TThread;
  ComponenteVinculado: TObject; CallBack: TProcedure);
var Proc: TProc;
begin
  Proc := Procedure Begin CallBack end;
  open(NomeProcedimento, Thread, ComponenteVinculado, Proc);
end;

procedure TAdoQuery.Open(NomeProcedimento: String; Thread: TThread;
  CallBack: TProcedure);
var Proc: TProc;
begin
  Proc := Procedure Begin CallBack end;
  open(NomeProcedimento, Thread, Proc);
end;

function LocalizarDataSource(Qry: TAdoQuery): TDataSource;
var I : Integer;
begin
  Result := Nil;
  if Qry.Owner IS TForm then
  for I := 0 to TForm(Qry.Owner).ComponentCount - 1 do  // Localizando DataSource
  if TForm(Qry.Owner).Components[I] IS TDataSource
    then if TDataSource(TForm(Qry.Owner).Components[I]).DataSet.Name = Qry.Name
      then begin
        Result := TDataSource(TForm(Qry.Owner).Components[I]);
        exit;
      end;
end;

end.

