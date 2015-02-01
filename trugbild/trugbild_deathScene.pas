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

unit TrugBild_DeathScene;

interface

uses
  Windows,
  Messages,
  SysUtils,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  Math,
  glMisc,
  Types,
  ComObj,
  dglOpenGL,
  Vcl.ExtCtrls,
  glFrameBufferObject,
  glSlangShaderManager,
  glMath,
  glTextureManager,
  glFont,
  XMLDoc,
  XMLIntf,
  Trugbild_Global,
  TrugBild_GameClass;

type
  TDeathScene = class
  private
    XMLDoc: IXMLDocument;
    BlinkTimer: single;
    FadePos: single;
    FadeDir: single;
    FadeSpeed: single;
    BlurTimer: single;
    procedure StartFade(ASpeed: single);
  public
    FBO: TFrameBufferObject;
    LightFade: single;
    procedure UpdateFBO;
    procedure Render;
    constructor Create;
    destructor Destroy; override;
  end;

var
  DeathScene: TDeathScene;

implementation

 // =====================================================================================================================
 // TDeathScene
 // =====================================================================================================================


 // =====================================================================================================================
 // TDeathScene.Create
 // =====================================================================================================================
constructor TDeathScene.Create;
begin
  FBO        := TFrameBufferObject.Create(2048, 2048);
  BlinkTimer := 25;
end;


 // =====================================================================================================================
 // TDeathScene.Destroy
 // =====================================================================================================================
destructor TDeathScene.Destroy;
begin
  XMLDoc := nil;
  FBO.Free;
  inherited;
end;


 // =====================================================================================================================
 // TDeathScene.UpdateFBO
 // =====================================================================================================================
procedure TDeathScene.UpdateFBO;
var
  AR: single;
  OffsetX: single;
  i: integer;
begin
  AR      := Application.MainForm.ClientWidth / Application.MainForm.ClientHeight;
  OffsetX := Clamp((Application.MainForm.ClientWidth / 2 - MousePos.X) * 0.06, -50, 50);

  FBO.Enable;

  glViewport(0, 0, FBO.Width, FBO.Height);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, FBO.Width, FBO.Height, 0, -256, 256);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);
  glDisable(GL_LIGHTING);
  glDepthMask(False);

  // Stars
  TextureManager.SetBlending(bmBlend);
  TextureManager.DrawQuad(0, FBO.Height, 0, FBO.Width, -FBO.Height, 'stars');

  // Background higlight in screen center
  TextureManager.SetBlending(bmAdd);
  glColor3f(1, 1, 1);
  TextureManager.DrawQuad(FBO.Width / 2, FBO.Height / 2 + 200, 0, 1600, 2200 * AR, 'radialgradientblack', (flCenter));

  // People (TODO : Maybe depending on decisisions? Lonely death?)
  TextureManager.SetBlending(bmBlend);
  TextureManager.DrawQuad(FBO.Width / 2, FBO.Height / 2 + 300, 0, 1024, 1024 * AR, 'reality_peoplegroup', flCenter, True);
  TextureManager.SetWrapMode(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE);

  TextureManager.DrawQuad(280, FBO.Height / 2 + 400, 0, 1024, 1024 * AR, 'reality_femalegroup', flCenter, True);
  TextureManager.SetWrapMode(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE);

  TextureManager.DrawQuad(FBO.Width - 380, FBO.Height / 2 + 500, 0, 550, 1100 * AR, 'reality_coupleb', flCenter, True);
  TextureManager.SetWrapMode(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE);

  // Sickbed
  TextureManager.SetBlending(bmBlend);
  glColor3f(0.6, 0.6, 0.6);
  TextureManager.DrawQuad(FBO.Width / 2 - (1024 * 0.75) + OffsetX, FBO.Height - (1024 * AR * 0.75), 0, 2048 * 0.75, 1024 * AR * 0.75, 'reality_sickbed', 0, True);
  TextureManager.SetWrapMode(GL_CLAMP, GL_CLAMP);

  TextureManager.SetBlending(bmBlend);
  glColor3f(1, 1, 1);
  TextureManager.DrawQuad(FBO.Width - 750 + OffsetX * 2.75, -20, 0, 575, 575 * AR, 'reality_sickbedhandle', 0, True);
  TextureManager.SetWrapMode(GL_CLAMP, GL_CLAMP);

  // Death light
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR);
  glColor3f(LightFade, LightFade, LightFade);
  TextureManager.DrawQuad(FBO.Width / 2, FBO.Height / 2 + 200, 0, 2000 + (1200 * LightFade), (2000 + (800 * LightFade)) * AR, 'radialgradientblack', (flCenter));
  TextureManager.DrawQuad(FBO.Width / 2, FBO.Height / 2 + 200, 0, 2000 + (1200 * LightFade), (2000 + (800 * LightFade)) * AR, 'radialgradientblack', (flCenter));

  // Blinking
  BlinkTimer := BlinkTimer - TimeFactor * 0.75;
  if BlinkTimer < 0 then
  begin
    BlinkTimer := 25 + Random(25);
    StartFade(0.25 + Random * 0.1 - Random * 0.1);
  end;

  TextureManager.SetBlending(bmNone);
  glDepthMask(True);

  FBO.Disable;
end;


 // =====================================================================================================================
 // TDeathScene.RenderScene
 // =====================================================================================================================
procedure TDeathScene.Render;
begin
  UpdateFBO;

  glViewport(0, 0, Application.MainForm.ClientWidth, Application.MainForm.ClientHeight);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, OrthoSize.x, OrthoSize.y, 0, -256, 256);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);
  glDisable(GL_LIGHTING);
  glColor3f(0.6, 0.6, 0.6);
  glDepthMask(False);

  with ShaderManager.Shader['filmgrain'] do
  begin
    Bind;
    SetUniformf('m_Time', [Trunc(DegTimer / 10) + 1]);
    SetUniformf('color', [0.4, 0.4, 0.4, 1]);
    SetUniformf('m_Strength', [12]);
    SetUniformi('m_Texture', [0]);
    SetUniformf('alpha', [1]);
    SetUniformi('blur', [1]);
    SetUniformf('blurShift', [0.004{*Sin(DegToRad(BlurTimer))}, 0]);
    SetUniformi('alphamodulatesgrain', [0]);
  end;

  FBO.Bind;
  TextureManager.DrawBlankQuad(0, 0, 0, OrthoSize.x, OrthoSize.y);

  // Fade
  if FadeDir <> 0 then
  begin
    FadePos := FadePos + FadeDir * FadeSpeed * TimeFactor;
    if FadePos < 0 then
    begin
      FadePos := 0;
      FadeDir := 0;
    end;
    if (FadeDir > 0) and (FadePos >= 1) then
      FadeDir := FadeDir * -1;
  end;

  ShaderManager.DisableShader;

  TextureManager.SetBlending(bmBlend);
  TextureManager.DrawQuad(0, 0, 0, OrthoSize.x, OrthoSize.y, 'darkborders');

  if FadePos > 0 then
  begin
    TextureManager.DisableTextureStage(GL_TEXTURE0);
    TextureManager.SetBlending(bmBlend);
    glColor4f(0, 0, 0, FadePos * 0.5);
    TextureManager.DrawBlankQuad(0, 0, 0, OrthoSize.x, OrthoSize.y);
    glColor3f(1, 1, 1);
  end;

  glDepthMask(True);
  TextureManager.SetBlending(bmNone);
  TextureManager.DisableTextureStage(GL_TEXTURE0);

  BlurTimer := Wrap(BlurTimer + TimeFactor * 10, 360);
end;


 // =====================================================================================================================
 // TDeathScene.StartFade
 // =====================================================================================================================
procedure TDeathScene.StartFade(ASpeed: single);
begin
  // No additional fade if already fading
  if FadePos > 0 then
    Exit;
  FadePos   := 0;
  FadeDir   := 1;
  FadeSpeed := ASpeed;
end;

end.

end.

