unit TimeoutControler;

interface
uses
    Windows, SysUtils, Graphics, Generics.Collections, Messages, Forms;
Type
  TProcedure        = Procedure of object;
  TTimeOut  = Class(TObject)
    Callback : TProc;
    RestInterval : Integer;
    LoopTimer: Boolean;
    IDEvent : Integer;
    Tag     : Integer;
  End;
  Function SetTimeOut(CallBack: TProcedure; RestInterval: Integer; LoopTimer: Boolean = False):Integer;overload;
  Function SetTimeOut(CallBack: TProc; RestInterval: Integer; LoopTimer: Boolean = False):Integer;overload;
  Function Localizar(idEvent:UINT):Integer;
var
  TimeOut  : TList<TTimeOut>;
  QtdeTimers : Integer;
  Timerid: UINT;

implementation

procedure MyTimeout( hwnd: HWND; uMsg: UINT;idEvent: UINT ; dwTime : DWORD);
stdcall;
VAR
  _CallBack : TProc;
  idxTimer  : Integer;
begin
  idxTimer := Localizar(idEvent);
  if not (TimeOut.List[idxTimer].LoopTimer)
    then KillTimer(0,IDEvent);
  _CallBack := TimeOut.List[idxTimer].Callback;
  _CallBack;
  if (TimeOut.List[idxTimer].LoopTimer)
    then TimeOut.List[idxTimer].IDEvent := SetTimer(0, IDEvent, TimeOut.List[idxTimer].RestInterval, @MyTimeOut);
end;

Function SetTimeOut(CallBack: TProc; RestInterval: Integer; LoopTimer: Boolean = False):Integer;overload;
var Timer : TTimeOut;
begin
  if TimeOut = nil
    then TimeOut := TList<TTimeOut>.Create;
  QtdeTimers := QtdeTimers + 1;
  Timer  := TTimeOut.Create;
  Timer.Callback     := CallBack;
  Timer.RestInterval := RestInterval;
  Timer.LoopTimer    := LoopTimer;
  Timer.Tag          := 0;
  Timer.IDEvent := SetTimer(0, QtdeTimers, RestInterval, @MyTimeOut);
  TimeOut.Add(Timer);
  Result := Timer.IDEvent;
end;

function SetTimeOut(CallBack: TProcedure; RestInterval: Integer; LoopTimer: Boolean = False):Integer;
begin
  SetTimeOut(procedure begin Callback end, RestInterval, LoopTimer);
end;

Function Localizar(idEvent:UINT):Integer;
var I : Integer;
begin
  for I := 0 to TimeOut.Count - 1 do
    if TimeOut.List[I].IDEvent = idEvent then break;
  Result := I;
end;

end.

