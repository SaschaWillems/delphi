program ExploTexGen;

{$MODE Delphi}

uses
  Forms, Interfaces,
  ExploTexGen_MainForm in 'ExploTexGen_MainForm.pas' {GLForm},
  dglOpenGL in 'D:\Projekt Weltherrscher\dglOpenGL.pas',
  Textures in 'Textures.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Explosion Texture Generator';
  Application.CreateForm(TGLForm, GLForm);
  Application.Run;
end.
