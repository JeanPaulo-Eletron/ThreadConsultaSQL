program ControladorThreadEventosConsulta;

uses
  Vcl.Forms,
  Main in 'Main.pas' {FormMain},
  Vcl.Themes,
  Vcl.Styles,
  ThreadControler in 'ThreadControler.pas',
  TimeoutControler in 'TimeoutControler.pas',
  UAssyncControler in 'UAssyncControler.pas',
  RegistroControler in 'RegistroControler.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Sapphire Kamri');
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
