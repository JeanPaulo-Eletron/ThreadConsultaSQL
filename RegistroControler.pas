unit RegistroControler;

interface
uses Registry, Windows, SysUtils, Vcl.Controls, Dialogs;

procedure GravaCfg(const Path, NomeArquivo: string; Valor: Integer);
function LerCfg(const Path, NomeArquivo : string) : Integer;

implementation

procedure GravaCfg(const Path, NomeArquivo: string; Valor: Integer);
var  arq: TextFile; { declarando a variável "arq" do tipo arquivo texto }
     CaminhoENomeArquivo: String;
Begin
  CaminhoENomeArquivo := ExtractFilePath(ParamStr(0))+NomeArquivo+'.cfg';
  FileSetAttr(CaminhoENomeArquivo, 0);
  AssignFile(arq, CaminhoENomeArquivo);
  Rewrite(arq);
  Writeln(arq,IntToStr(Valor));
  CloseFile(arq);
  FileSetAttr(CaminhoENomeArquivo, FileGetAttr(CaminhoENomeArquivo) or faHidden);
end;

function LerCfg(const Path, NomeArquivo : string) : Integer;
var  arq: TextFile; { declarando a variável "arq" do tipo arquivo texto }
     TxtRetorno: String;
     CaminhoENomeArquivo: String;
Begin
  CaminhoENomeArquivo := ExtractFilePath(ParamStr(0))+NomeArquivo+'.cfg';
  Result := 0;
  if not FileExists(CaminhoENomeArquivo) 
    then begin
      GravaCfg(Path,  NomeArquivo, 0);
      Exit;
    end;
  AssignFile(arq, CaminhoENomeArquivo);
  Reset(arq);
  Readln(arq, TxtRetorno);
  CloseFile(arq);
  Result := StrToInt(TxtRetorno);
end;

end.
