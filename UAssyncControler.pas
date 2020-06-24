unit UAssyncControler;

interface
uses
    Windows, SysUtils, Generics.Collections, RegistroControler, SyncObjs,  Winapi.Messages, Classes;
const
    WM_PROCEDIMENTOGENERICOASSYNC = WM_USER + 1;
    WM_TERMINATE                  = WM_USER + 2;
Type
  TAssyncControler = class(TThread)
  private
    Cores : TSystemInfo;
    FilaDeProcedures: TList<TProc>;
    Msg : TMsg;
    Registro: TRegistro;
    procedure Dispatcher;
    procedure TriggerOciosidade;
  protected
    procedure Execute; override;
  public
    Constructor Create(CreateSuspended: Boolean = false);overload;
    Destructor  Destroy; Override;
    procedure JogarProcedureNaFilaAssyncrona(CallBack: TProc);
    procedure Synchronize(AMethod: TThreadMethod); overload; inline;
    procedure Synchronize(AThreadProc: TThreadProcedure); overload; inline;
  end;
var  AssyncControler: TAssyncControler;
implementation
// Thread para execução assyncrona
procedure TAssyncControler.Execute;
begin
  FreeOnTerminate := not self.Finished;
  TriggerOciosidade;
  GetSystemInfo(Cores);
  while not Terminated do begin
    Dispatcher;
  end;
end;


procedure TAssyncControler.TriggerOciosidade;
begin
  CreateAnonymousThread(
  Procedure Begin
    while true do begin
      Sleep(1);//Confira de 1 em 1 segundo se há trabalho para ser feito, se não há então termine
      if (Registro.QtdeProcAsync + FilaDeProcedures.Count) = 0 then begin
        Terminate;
        break;
      end;
    end;
  end).Start;
end;

Constructor TAssyncControler.Create(CreateSuspended: Boolean = false);
begin
  inherited create(CreateSuspended);
  FilaDeProcedures := TList<TProc>.Create;
  Registro         := TRegistro.Create;
  Registro.Lock    := TCriticalSection.Create;
end;

Destructor TAssyncControler.Destroy;
begin
  inherited;
  FilaDeProcedures.Free;
  FilaDeProcedures := nil;
  Registro.Lock.Free;
  Registro.Lock    := nil;
  Registro.Free;
  Registro         := nil;
  AssyncControler  := nil;
end;

procedure TAssyncControler.Dispatcher;
var ThreadAntiga : TThread;
    CallBack: TProc;
begin
  Sleep(1);
  if PeekMessage(Msg, 0, 0, 0, PM_NOREMOVE) then begin
    if Integer(Cores.dwNumberOfProcessors) > 2 // 1 núcleo e 2 threads ou inferior
      then while Registro.QtdeProcAsync >= (Integer(Cores.dwNumberOfProcessors) - 1) do sleep(1) //Otimização para hardware não sobrecarregar de processos pessados.
      else while Registro.QtdeProcAsync > 2 do sleep(1); // ele só aceita realizar dois processos assyncronos por vez
    try
      try
        case Msg.Message of
          WM_PROCEDIMENTOGENERICOASSYNC: begin
                                           AssyncControler.CreateAnonymousThread(
                                             procedure
                                             begin
                                               Registro.QtdeProcAsync := Registro.QtdeProcAsync + 1;
                                               CallBack := FilaDeProcedures.ExtractAt(0);
                                               CallBack;
                                               Registro.QtdeProcAsync := Registro.QtdeProcAsync - 1;
                                             end).Start;
                                         end;
          WM_TERMINATE:                  Terminate;
        end;
      finally
        PeekMessage(Msg, 0, 0, 0, PM_REMOVE);
      end;
    except
      Self.Terminate;
    end;
  end;
end;
procedure TAssyncControler.JogarProcedureNaFilaAssyncrona(CallBack: TProc);
begin
  FilaDeProcedures.Add(CallBack);
  PostThreadMessage(ThreadID, WM_PROCEDIMENTOGENERICOASSYNC, 0, 0);
end;

procedure TAssyncControler.Synchronize(AMethod: TThreadMethod);
begin
  Synchronize(Self, AMethod);
end;

procedure TAssyncControler.Synchronize(AThreadProc: TThreadProcedure);
begin
  Synchronize(Self, AThreadProc);
end;
end.
