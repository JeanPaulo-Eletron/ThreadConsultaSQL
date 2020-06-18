unit TimeoutControler;

interface
uses
    Windows, SysUtils, Generics.Collections;
Type
  TProcedure        = Procedure of object;
  TTimeOut  = Class(TObject)
    Callback : TProc;
    RestInterval : Integer;
    LoopTimer: Boolean;
    IDEvent : Integer;
    Tag     : Integer;
    FreeOnTerminate: Boolean;
  End;
  Function SetTimeOut (CallBack: TProcedure; RestInterval: Integer; LoopTimer: Boolean = False; FreeOnTerminate: Boolean = True):TTimeOut;overload;
  Function SetTimeOut (CallBack: TProc; RestInterval: Integer; LoopTimer: Boolean = False; FreeOnTerminate: Boolean = True):TTimeOut;overload;
  Function SetInterval(CallBack: TProcedure; RestInterval: Integer; FreeOnTerminate: Boolean = True):TTimeOut;overload;
  Function SetInterval(CallBack: TProc; RestInterval: Integer; FreeOnTerminate: Boolean = True):TTimeOut;overload;
  Function Localizar(idEvent:UINT):Integer;
var
  TimeOut  : TList<TTimeOut>;
  QtdeTimers : Integer;

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
  _CallBack;
  if (_TimeOut.LoopTimer)
    then _TimeOut.IDEvent := SetTimer(0, IDEvent, _TimeOut.RestInterval, @MyTimeOut)
    else begin
      if _TimeOut.FreeOnTerminate then begin
        TimeOut.Remove(_TimeOut);
        _TimeOut.Free;
        _TimeOut := Nil;
      end;
    end;
end;

Function SetTimeOut(CallBack: TProc; RestInterval: Integer; LoopTimer: Boolean = False; FreeOnTerminate: Boolean = True):TTimeOut;overload;
var Timer : TTimeOut;
begin
  if TimeOut = nil
    then TimeOut := TList<TTimeOut>.Create;
  QtdeTimers := QtdeTimers + 1;
  Timer  := TTimeOut.Create;
  Timer.Callback        := CallBack;
  Timer.RestInterval    := RestInterval;
  Timer.LoopTimer       := LoopTimer;
  Timer.Tag             := 0;
  Timer.FreeOnTerminate := FreeOnTerminate;
  Timer.IDEvent := SetTimer(0, QtdeTimers, RestInterval, @MyTimeOut);
  TimeOut.Add(Timer);
  Result := Timer;
end;

function SetTimeOut(CallBack: TProcedure; RestInterval: Integer; LoopTimer: Boolean = False; FreeOnTerminate: Boolean = True):TTimeOut;
begin
  Result := SetTimeOut(procedure begin Callback end, RestInterval, LoopTimer);
end;

Function SetInterval(CallBack: TProcedure; RestInterval: Integer; FreeOnTerminate: Boolean = True):TTimeOut;overload;
begin
  Result := SetInterval(procedure begin CallBack end,RestInterval, FreeOnTerminate);
end;

Function SetInterval(CallBack: TProc; RestInterval: Integer; FreeOnTerminate: Boolean = True):TTimeOut;overload;
begin
  Result := SetTimeOut(CallBack, RestInterval, True, FreeOnTerminate);
end;

Function Localizar(idEvent:UINT):Integer;
var I : Integer;
begin
  for I := 0 to TimeOut.Count - 1 do
    if TimeOut.List[I].IDEvent = idEvent then break;
  Result := I;
end;

end.

