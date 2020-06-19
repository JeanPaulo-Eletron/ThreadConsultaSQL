unit TimeoutControler;

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
    procedure Dispatcher;
  protected
    procedure Execute; override;
  public
    procedure JogarProcedureNaFilaAssyncrona(CallBack: TProc);
    procedure Synchronize(AMethod: TThreadMethod); overload; inline;
    procedure Synchronize(AThreadProc: TThreadProcedure); overload; inline;
  end;
  TProcedure        = Procedure of object;
  TTimeOut  = Class(TObject)
    Callback : TProc;
    RestInterval : Integer;
    LoopTimer: Boolean;
    IDEvent : Integer;
    Tag     : Integer;
    FreeOnTerminate: Boolean;
    Assync: Boolean;
  End;
  Function SetTimeOut (CallBack: TProcedure; RestInterval: Integer; LoopTimer: Boolean = False; FreeOnTerminate: Boolean = True; Assync: Boolean = False):TTimeOut;overload;
  Function SetTimeOut (CallBack: TProc; RestInterval: Integer; LoopTimer: Boolean = False; FreeOnTerminate: Boolean = True; Assync: Boolean = False):TTimeOut;overload;
  Function SetInterval(CallBack: TProcedure; RestInterval: Integer; FreeOnTerminate: Boolean = True; Assync: Boolean = False):TTimeOut;overload;
  Function SetInterval(CallBack: TProc; RestInterval: Integer; FreeOnTerminate: Boolean = True; Assync: Boolean = False):TTimeOut;overload;
  Function Localizar(idEvent:UINT):Integer;
var
  TimeOut  : TList<TTimeOut>;
  QtdeTimers : Integer;
  AssyncControler: TAssyncControler;

implementation

procedure MyTimeout( hwnd: HWND; uMsg: UINT;idEvent: UINT ; dwTime : DWORD);
stdcall;
VAR
  _CallBack : TProc;
  _TimeOut: TTimeOut;
begin
  _TimeOut := TimeOut.List[Localizar(idEvent)];
  if not (_TimeOut.LoopTimer)
    then KillTimer(0,IDEvent);
  _CallBack := _TimeOut.Callback;
  if not _TimeOut.Assync
    then _CallBack
    else AssyncControler.JogarProcedureNaFilaAssyncrona(_CallBack);
  if (_TimeOut.LoopTimer)
    then _TimeOut.IDEvent := SetTimer(0, IDEvent, _TimeOut.RestInterval, @MyTimeOut)
    else begin
      if (_TimeOut.FreeOnTerminate) and not (_TimeOut.Assync) then begin
        TimeOut.Remove(_TimeOut);
        _TimeOut.Free;
        _TimeOut := Nil;
      end;
    end;
end;

Function SetTimeOut(CallBack: TProc; RestInterval: Integer; LoopTimer: Boolean = False; FreeOnTerminate: Boolean = True; Assync: Boolean = False):TTimeOut;overload;
var Timer : TTimeOut;
begin
  if TimeOut = nil
    then TimeOut := TList<TTimeOut>.Create;

  QtdeTimers := QtdeTimers + 1;
  Timer  := TTimeOut.Create;
  if (Assync) and (AssyncControler = nil)
    then AssyncControler := TAssyncControler.Create;

  Timer.Callback        := CallBack;
  Timer.RestInterval    := RestInterval;
  Timer.LoopTimer       := LoopTimer;
  Timer.Tag             := 0;
  Timer.FreeOnTerminate := FreeOnTerminate;
  Timer.Assync          := Assync;
  Timer.IDEvent := SetTimer(0, QtdeTimers, RestInterval, @MyTimeOut);
  TimeOut.Add(Timer);
  Result := Timer;
end;

function SetTimeOut(CallBack: TProcedure; RestInterval: Integer; LoopTimer: Boolean = False; FreeOnTerminate: Boolean = True; Assync: Boolean = False):TTimeOut;
begin
  Result := SetTimeOut(procedure begin Callback end, RestInterval, LoopTimer, FreeOnTerminate, Assync);
end;

Function SetInterval(CallBack: TProcedure; RestInterval: Integer; FreeOnTerminate: Boolean = True; Assync: Boolean = False):TTimeOut;overload;
begin
  Result := SetInterval(procedure begin CallBack end,RestInterval, FreeOnTerminate, Assync);
end;

Function SetInterval(CallBack: TProc; RestInterval: Integer; FreeOnTerminate: Boolean = True; Assync: Boolean = False):TTimeOut;overload;
begin
  Result := SetTimeOut(CallBack, RestInterval, True, FreeOnTerminate, Assync);
end;

Function Localizar(idEvent:UINT):Integer;
var I : Integer;
begin
  for I := 0 to TimeOut.Count - 1 do
    if TimeOut.List[I].IDEvent = idEvent then break;
  Result := I;
end;

// Thread para execução assyncrona
procedure TAssyncControler.Execute;
begin
  FreeOnTerminate := not self.Finished;
  GetSystemInfo(Cores);
  GravaReg('DelphiRegControlers','QtdeProcAsync','0');
  while not Terminated do begin
    Dispatcher;
  end;
end;

procedure TAssyncControler.Dispatcher;
var ThreadAntiga : TThread;
    CallBack: TProc;
begin
  Sleep(1);
  if PeekMessage(Msg, 0, 0, 0, PM_NOREMOVE) then begin
    if Integer(Cores.dwNumberOfProcessors) > 2 // 1 núcleo e 2 threads ou inferior
      then while StrToInt(LerReg('DelphiRegControlers','QtdeProcAsync','0')) >= (Integer(Cores.dwNumberOfProcessors) - 1) do sleep(1) //Otimização para hardware não sobrecarregar de processos pessados.
      else while StrToInt(LerReg('DelphiRegControlers','QtdeProcAsync','0')) > 2 do sleep(1); // ele só aceita realizar dois processos assyncronos por vez
    try
      try
        case Msg.Message of
          WM_PROCEDIMENTOGENERICOASSYNC: begin
                                           GravaReg('DelphiRegControlers','QtdeProcAsync',IntToStr(StrToInt(LerReg('DelphiRegControlers','QtdeProcAsync','0')) + 1));
                                           CallBack := FilaDeProcedures.ExtractAt(0);
                                           CallBack;
                                           GravaReg('DelphiRegControlers','QtdeProcAsync',IntToStr(StrToInt(LerReg('DelphiRegControlers','QtdeProcAsync','0')) - 1));
                                           if FilaDeProcedures.Count = 0 then begin
                                             AssyncControler  := nil;
                                             FilaDeProcedures.Free;
                                             FilaDeProcedures := nil;
                                             Terminate;
                                           end;
                                         end;
          WM_TERMINATE:                  Terminate;
        end;
      finally
        PeekMessage(Msg, 0, 0, 0, PM_REMOVE);
      end;
    except
      Self.Terminate;
    end;
  end
end;
procedure TAssyncControler.JogarProcedureNaFilaAssyncrona(CallBack: TProc);
begin
  if FilaDeProcedures = nil
    then FilaDeProcedures := TList<TProc>.Create;
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

