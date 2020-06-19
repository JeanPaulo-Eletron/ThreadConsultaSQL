unit RegistroControler;

interface
uses Registry, Windows, SysUtils, Vcl.Controls;

procedure GravaReg(const Path, Variavel, Valor : string);
function  LerReg(const Path, Variavel : string; ValorDefault: string = '') : String;
procedure GravaRegBoolean(const Path,VAriavel : String; const Valor : Boolean);
function  LerRegBoolean(const Path, Variavel: string; ValorDefault: string = 'S') : Boolean;
function  LerRegDouble(const Path, Variavel: String): Double;
procedure GravaRegComponentes(const Path: String; Comp : TControl);
procedure LerRegComponentes(Path : String;Comp : TControl);
procedure GravaRegDouble(const Path, variavel : String; const Valor : Double);

implementation
//Funções para agilizar o registro do Windows
//Fonte: http://help.market.com.br/delphi/funcao_-_funcoes_para_acessar_.htm


// Grava no Registro do Windows o Valor especificado

procedure GravaReg(const Path, Variavel, Valor : string);
var
  Reg: Tregistry;
Begin
  Reg         := TRegistry.Create;
  Reg.RootKey := HKEY_CURRENT_USER; //!! Atenção não use HKEY_LOCAL_MACHINE no Windows NT/2000
  Reg.CreateKey(Path);
  Reg.OpenKey(Path, True);
  Reg.WriteString(Variavel, Valor);
  FreeAndNil(Reg);
end;



// Ler do Registro do Windows no Path especifivado

function LerReg(const Path, Variavel : string; ValorDefault: string = '') : String;

var

  Reg: TRegistry;

Begin
  Reg         := TRegistry.Create;
  Reg.RootKey := HKEY_CURRENT_USER;
  Reg.CreateKey(Path);
  Reg.OpenKey(Path, True);
  if Reg.ValueExists(Variavel)
    then Result := Reg.ReadString(Variavel)
    else Result := ValorDefault;
  FreeAndNil(Reg);
end;

//////////////////////////////// FUNCOES DERIVADAS ////////////////////////////////////

// Grava um Booleano no Registro

procedure GravaRegBoolean(const Path,VAriavel : String; const Valor : Boolean);
begin
  if Valor Then
    GravaReg(Path,Variavel,'S')
  else
    GravaReg(Path,Variavel,'N');
end;



// Ler e retornar um booleano segundo o registro
function LerRegBoolean(const Path, Variavel: string; ValorDefault: string = 'S') : Boolean;
begin
  Result := LerReg(Path, Variavel, ValorDefault) = 'S';
end;



// Ler de um Registro um Valor e transformar para Double
function LerRegDouble(const Path, Variavel: String): Double;
begin
  Result := StrToFloat(LerReg(Path,Variavel));
end;



// Grava o Top e o Left do ComponentePadrao no Path especifivado + \Componentes
procedure GravaRegComponentes(const Path: String; Comp : TControl);
begin
  GravaReg(Path + '\Componentes', Comp.Name + 'Left', IntToStr(comp.Left));
  GravaReg(Path + '\Componentes', Comp.Name + 'Top' , IntToStr(comp.top));
end;



// Le No Path especificado o Top e o Left do Componente
procedure LerRegComponentes(Path : String;Comp : TControl);
var
  I: Integer;
Begin
  I := StrToInt(LerReg(Path + '\Componentes',Comp.Name + 'Top'));
  if I > 0 then Comp.Top := I;
  I := StrToInt(LerReg(Path + '\Componentes',Comp.Name + 'Left'));
  if I > 0 then Comp.Left := I;
end;



//Grava um String com um valor Double Passado como parametro no Path tb Parametro

procedure GravaRegDouble(const Path, variavel : String; const Valor : Double);
var
  NValor: string;
Begin
  NValor := FloatToStr(Valor);
  GravaReg(Path, Variavel, NValor);
end;

end.
