unit RegistroControler;

interface
uses Registry, Windows, SysUtils, Vcl.Controls, Dialogs, SyncObjs, TLHelp32, StrUtils;
Type
TRegistro = Class(TObject)
  private
    function ObterCodigoProcesso(ExeFileName: string): Integer;
    procedure SetQtdeProcAsync(Valor: Integer);
    function  GetQtdeProcAsync : Integer;
  public
    Lock : TCriticalSection;
    property QtdeProcAsync: Integer read GetQtdeProcAsync write SetQtdeProcAsync;
End;

implementation

{ TRegistro }

function TRegistro.GetQtdeProcAsync: Integer;
var  arq: TextFile;
     TxtRetorno: String;
     TxtCodigoProcesso: String;
     CaminhoENomeArquivo: String;
Begin
  Lock.Acquire;
  Result := 0;
  CaminhoENomeArquivo := ExtractFilePath(ParamStr(0))+'Registro.el';
  if not FileExists(CaminhoENomeArquivo)
    then begin
      QtdeProcAsync := 0;
      Exit;
    end;
  AssignFile(arq, CaminhoENomeArquivo);
  Reset(arq);
  Readln(arq, TxtRetorno);
  Readln(arq, TxtCodigoProcesso);
  CloseFile(arq);
  if StrToInt(IfThen(TxtCodigoProcesso='','0',TxtCodigoProcesso)) <> ObterCodigoProcesso(ExtractFileName(ParamStr(0)))
    then QtdeProcAsync := 0
    else Result := StrToInt(TxtRetorno);
  Lock.Release;
end;

procedure TRegistro.SetQtdeProcAsync(Valor: Integer);
var  arq: TextFile;
     CaminhoENomeArquivo: String;
Begin
  Lock.Acquire;
  CaminhoENomeArquivo := ExtractFilePath(ParamStr(0))+'Registro.el';
  FileSetAttr(CaminhoENomeArquivo, 0);
  AssignFile(arq, CaminhoENomeArquivo);
  Rewrite(arq);
  Writeln(arq,IntToStr(Valor));
  Writeln(arq,ObterCodigoProcesso(ExtractFileName(ParamStr(0))));
  CloseFile(arq);
  FileSetAttr(CaminhoENomeArquivo, FileGetAttr(CaminhoENomeArquivo) or faHidden);
  Lock.Release;
end;

function TRegistro.ObterCodigoProcesso(ExeFileName: string): Integer;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  Result := 0;
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(ExeFileName))) then
      Result := FProcessEntry32.th32ProcessID;
     ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

end.
