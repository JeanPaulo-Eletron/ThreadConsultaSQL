unit TimeoutControler;

interface
uses
    Windows, SysUtils, Graphics, Generics.Collections, Messages, Forms;
Type
  TProcedure        = Procedure of object;
  TTimeOut = Record
    Callback : TProcedure;
    RestInterval : Integer;
    IDEvent : Integer;
    LoopTimer: Boolean;
    Tag : Integer;
  End;
  Function SetTimeOut(CallBack: TProcedure; RestInterval: Integer):Integer;
  Function Localizar(idEvent:UINT):Integer;
var
  TimeOut  : TList<TTimeOut>;
  QtdeTimers : Integer;
  Timerid: UINT;

implementation

procedure MyTimeout( hwnd: HWND; uMsg: UINT;idEvent: UINT ; dwTime : DWORD);
stdcall;
begin
  if TimeOut.List[Localizar(idEvent)].LoopTimer
    then SetTimer(0, IDEvent, TimeOut.List[Localizar(idEvent)].RestInterval, @MyTimeout)
    else KillTimer(0,IDEvent);
  TimeOut.List[Localizar(idEvent)].Callback;
end;

function SetTimeOut(CallBack: TProcedure; RestInterval: Integer):Integer;
var Timer : TTimeOut;
begin
  if TimeOut = nil
    then TimeOut := TList<TTimeOut>.Create;
  QtdeTimers := QtdeTimers + 1;
  Timer.Callback     := CallBack;
  Timer.RestInterval := RestInterval;
  Timer.LoopTimer    := False;
  Timer.Tag          := 0;
  Timer.IDEvent := SetTimer(0, QtdeTimers, RestInterval, @MyTimeOut);
  TimeOut.Add(Timer);
  Result := Timer.IDEvent;
end;

Function Localizar(idEvent:UINT):Integer;
var I : Integer;
begin
  for I := 0 to TimeOut.Count - 1 do
    if TimeOut.List[I].IDEvent = idEvent then break;
  Result := I;
end;

end.

