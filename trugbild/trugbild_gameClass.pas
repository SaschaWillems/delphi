// =============================================================================
//
//  TrugBild
//
// =============================================================================
//
//  Copyright (C) 2013 by Sascha Willems (www.saschawillems.de)
//
//  This code is free software, you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License version 3 as published by the Free Software Foundation.
//
//  Please review the following information to ensure the GNU Lesser
//  General Public License version 3 requirements will be met:
//  http://opensource.org/licenses/lgpl-3.0.html
//
//  The code is distributed WITHOUT ANY WARRANTY; without even the
//  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
//  PURPOSE.  See the GNU LGPL 3.0 for more details.//
//
// =============================================================================


unit TrugBild_GameClass;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, Math,glMisc, Types, ComObj,
  dglOpenGL, Vcl.ExtCtrls, glFrameBufferObject, glSlangShaderManager, glMath, glTextureManager, glFont,
  XMLDoc, XMLIntf, ShlObj, ShellAPI, ActiveX,

  TrugBild_Global;

type
	TOnGameStateChange = procedure of object;
  TGameState = (gsMainMenu, gsIngame, gsReality, gsEnding, gsAbout);
  TGameEndingType = (geBad, geGood);
  TGame = class
  	private
      NewState          : TGameState;
      LogFile           : TextFile;
      procedure GetAppDataDir;
  	public
      AppDataDir        : String;
    	FadePos           : Single;
      FadeDir           : Single;
      FadeSpeed         : Single;
      State 	          : TGameState;
      Ending						: TGameEndingType;
      OnGameStateChange : TOnGameStateChange;
      procedure LogMessage(const AMessage : String);
      procedure ChangeState(ANewState : TGameState);
      procedure RenderFade;
      procedure Fade(AFadeSpeed : Single);
      constructor Create;
      destructor Destroy; override;
  end;


var
  Game : TGame;


implementation

// =====================================================================================================================
//  TGame
// =====================================================================================================================


// =====================================================================================================================
//  TGame.Create
// =====================================================================================================================
constructor TGame.Create;
begin
	State := gsMainMenu;
  GetAppDataDir;
  ForceDirectories(AppDataDir);
  AssignFile(LogFile, AppDataDir + '\log.txt');
  ReWrite(LogFile);
  CloseFile(LogFile);
end;


// =====================================================================================================================
//  TGame.ChangeState
// =====================================================================================================================
procedure TGame.ChangeState(ANewState: TGameState);
begin
	NewState := ANewState;
  Fade(FadeSpeed);
end;


// =====================================================================================================================
//  TGame.Destroy
// =====================================================================================================================
destructor TGame.Destroy;
begin
	LogMessage('All game objects released');
  inherited;
end;


// =====================================================================================================================
//  TGame.Fade
// =====================================================================================================================
procedure TGame.Fade(AFadeSpeed: Single);
begin
	if FadePos > 0 then
  	exit;
	FadePos    := 0;
  FadeDir    := 1;
  FadeSpeed  := AFadeSpeed;
end;


// =====================================================================================================================
//  TGame.GetAppDataDir
// =====================================================================================================================
procedure TGame.GetAppDataDir;
var
  pMalloc : IMalloc;
  pidl    : PItemIDList;
  Path    : PChar;
begin
	AppDataDir := ExtractFilePath(Application.ExeName);
  if (SHGetMalloc(pMalloc) <> S_OK) then
    begin
      exit;
    end;
  SHGetSpecialFolderLocation(Application.MainForm.Handle, CSIDL_APPDATA, pidl);
  GetMem(Path, MAX_PATH);
  SHGetPathFromIDList(pidl, Path);
  AppDataDir := Path + '\TrugBild\';
  FreeMem(Path);
  pMalloc.Free(pidl);
end;


// =====================================================================================================================
//  TGame.LogMessage
// =====================================================================================================================
procedure TGame.LogMessage(const AMessage: String);
begin
  Append(LogFile);
  WriteLn(LogFile, DateTimeToStr(Now) + ' : ' + AMessage);
  CloseFile(LogFile);
end;


// =====================================================================================================================
//  TGame.RenderFade
// =====================================================================================================================
procedure TGame.RenderFade;
begin
  if FadeDir <> 0 then
    begin
      FadePos := FadePos + FadeDir * FadeSpeed * TimeFactor;
      if FadePos < 0 then
        begin
          FadePos := 0;
          FadeDir := 0;
        end;
      if (FadeDir > 0) and (FadePos >=1) then
        begin
          // If a new game state has been set, switch over now
          if (FadeDir > 0) and (Game.State <> Game.NewState) then
          	begin
            	Game.State := Game.NewState;
              if Assigned(OnGameStateChange) then
              	OnGameStateChange;
            end;
          FadeDir := FadeDir * -1;
        end;
    end;

  if FadePos > 0 then
  	begin
    	TextureManager.DisableTextureStage(GL_TEXTURE0);
      TextureManager.SetBlending(bmBlend);
      glColor4f(0, 0, 0, FadePos);
      TextureManager.DrawBlankQuad(0, 0, 0, OrthoSize.x, OrthoSize.y);
      glColor3f(1, 1, 1);
    end;
end;

end.
