unit TimeoutControler;

interface
uses
    Windows, SysUtils, Graphics, Generics.Collections, Messages, Forms;
Type
  TProcedure        = Procedure of object;
  TConfig  = Class(TObject)
    Callback : TProc;
    RestInterval : Integer;
    LoopTimer: Boolean;
  End;
  TTimeOut = Record
    Config  : TConfig;
    IDEvent : Integer;
    Tag     : Integer;
  End;
  Function SetTimeOut(CallBack: TProcedure; RestInterval: Integer):Integer;overload;
  Function SetTimeOut(CallBack: TProc; RestInterval: Integer):Integer;overload;
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
  if (not (TimeOut.List[idxTimer].Config.LoopTimer)) or (dwTime <> TimeOut.List[idxTimer].Config.RestInterval)
    then KillTimer(0,IDEvent);
  _CallBack := TimeOut.List[idxTimer].Config.Callback;
  _CallBack;
  if (TimeOut.List[idxTimer].Config.LoopTimer) and (dwTime <> TimeOut.List[idxTimer].Config.RestInterval)
    then TimeOut.List[idxTimer].IDEvent := SetTimer(0, IDEvent, TimeOut.List[idxTimer].Config.RestInterval, @MyTimeOut);
end;

Function SetTimeOut(CallBack: TProc; RestInterval: Integer):Integer;overload;
var Timer : TTimeOut;
begin
  if TimeOut = nil
    then TimeOut := TList<TTimeOut>.Create;
  QtdeTimers := QtdeTimers + 1;
  Timer.Config  := TConfig.Create;
  Timer.Config.Callback     := CallBack;
  Timer.Config.RestInterval := RestInterval;
  Timer.Config.LoopTimer    := False;
  Timer.Tag          := 0;
  Timer.IDEvent := SetTimer(0, QtdeTimers, RestInterval, @MyTimeOut);
  TimeOut.Add(Timer);
  Result := Timer.IDEvent;
end;

function SetTimeOut(CallBack: TProcedure; RestInterval: Integer):Integer;
begin
  SetTimeOut(procedure begin Callback end, RestInterval);
end;

Function Localizar(idEvent:UINT):Integer;
var I : Integer;
begin
  for I := 0 to TimeOut.Count - 1 do
    if TimeOut.List[I].IDEvent = idEvent then break;
  Result := I;
end;

end.

