program ControladorThreadEventosConsulta;

uses
  Vcl.Forms,
  Main in 'Main.pas' {FormMain},
  Vcl.Themes,
  Vcl.Styles,
  AdoQueryControler in 'AdoQueryControler.pas' {Form},
  ThreadControler in 'ThreadControler.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Sapphire Kamri');
  Application.CreateForm(TFormMain, FormMain);
  Application.CreateForm(TForm, Form);
  Application.Run;
end.
