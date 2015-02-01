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

unit TrugBild_About;

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
  VirtualFileSystem,
  Trugbild_Global,
  TrugBild_GameClass,
  TrugBild_DecisionClass,
  TrugBild_PlayerClass;

type
  TAboutMenuSelection = (selNone, selLeft, selRight, selBottom, selTop);

  TAbout = class
  private
    CharTimer: single;
    CharPos: integer;
    LinePos: integer;
    Lines: TStringList;
    BlurTimer: single;
    SwayTimer: single;
    function GetMenuSelection: TAboutMenuSelection;
    procedure RenderMenuBackground;
    procedure RenderMenuHighlight;
    procedure RenderMenuText;
    procedure UpdateFBO;
    procedure UpdateEffectsFBO;
  public
    FBO: TFrameBufferObject;
    FBOEffects: TFrameBufferObject;
    procedure Render;
    procedure Update;
    procedure Click;
    constructor Create(AFBO, AFBOEffects: TFrameBufferObject);
    destructor Destroy; override;
  end;

var
  About: TAbout;

implementation

 // =====================================================================================================================
 // TAbout
 // =====================================================================================================================


 // =====================================================================================================================
 // TAbout.Create
 // =====================================================================================================================
constructor TAbout.Create(AFBO, AFBOEffects: TFrameBufferObject);
begin
  Lines      := TStringList.Create;
  CharTimer  := 1;
  CharPos    := 0;
  LinePos    := 0;
  FBO        := AFBO;
  FBOEffects := AFBOEffects;
  VFS.LoadToStringList('data\about.txt', Lines);
end;


 // =====================================================================================================================
 // TAbout.Destroy
 // =====================================================================================================================
destructor TAbout.Destroy;
begin
  Lines.Free;
  inherited;
end;


 // =====================================================================================================================
 // TAbout.GetMenuSelection
 // =====================================================================================================================
function TAbout.GetMenuSelection: TAboutMenuSelection;
begin
  Result := selNone;

  with Application.MainForm do
    if (MousePos.x > ClientWidth / 2 - 200) and (MousePos.x < ClientWidth / 2 + 200) then
    begin
      if MousePos.y < 50 then
        Exit(selTop);
      if MousePos.y > ClientHeight - 50 then
        Exit(selBottom);
    end//      if (MousePos.y > ClientHeight / 2 - 200) and (MousePos.y < ClientHeight / 2 + 200) then
       //        begin
       //          if MousePos.x < 50 then
       //            exit(selLeft);
       //          if MousePos.x > ClientWidth - 50 then
       //            exit(selTop);
       //        end;
  ;

end;


 // =====================================================================================================================
 // TAbout.Render
 // =====================================================================================================================
procedure TAbout.Render;
var
  i: integer;
begin
  UpdateFBO;
  UpdateEffectsFBO;

  glViewport(0, 0, Application.MainForm.ClientWidth, Application.MainForm.ClientHeight);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, OrthoSize.x, 0, OrthoSize.y, -256, 256);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);
  glDisable(GL_LIGHTING);
  glColor3f(1, 1, 1);
  glDepthMask(False);
  glDepthFunc(GL_ALWAYS);

  with ShaderManager.Shader['filmgrain'] do
  begin
    Bind;
    SetUniformf('m_Time', [Trunc(DegTimer / 10) + 1]);
    SetUniformf('color', [1, 1, 1, 1]);
    SetUniformf('m_Strength', [4]);
    SetUniformi('m_Texture', [0]);
    SetUniformf('alpha', [1]);
    SetUniformi('blur', [0]);
    SetUniformf('blurShift', [0.002{*Sin(DegToRad(BlurTimer))}, 0]);
    SetUniformi('alphamodulatesgrain', [0]);
  end;

  FBO.Bind;
  TextureManager.DrawBlankQuad(0, 0, 0, OrthoSize.x, OrthoSize.y);

  ShaderManager.DisableShader;

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, OrthoSize.x, 0, OrthoSize.y, -256, 256);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glClear(GL_DEPTH_BUFFER_BIT);
  glDisable(GL_CULL_FACE);

  glDepthMask(False);

  // Radial gradient
  TextureManager.SetBlending(bmModulate);
  glColor3f(0.85, 0.85, 0.85);
  TextureManager.DrawQuad(0, 0, 0, OrthoSize.x, OrthoSize.y, 'radialgradient');

  // Effects
  FBOEffects.Bind;
  TextureManager.SetBlending(bmAdd);
  with ShaderManager.Shader['filmgrain'] do
  begin
    Bind;
    SetUniformf('m_Time', [Trunc(DegTimer / 10) + 1]);
    SetUniformf('color', [1, 1, 1, 1]);
    SetUniformf('m_Strength', [8]);
    SetUniformi('m_Texture', [0]);
    SetUniformi('blur', [0]);
    SetUniformf('alpha', [1]);
    SetUniformi('alphamodulatesgrain', [0]);
  end;
  glColor3f(0.8, 0.8, 0.8);
  TextureManager.DrawBlankQuad(0, 0, 1, OrthoSize.x, OrthoSize.y);
  ShaderManager.DisableShader;

  RenderMenuText;

  glDepthMask(True);

  TextureManager.SetBlending(bmBlend);
end;


 // =====================================================================================================================
 // TAbout.RenderMenuBackground
 // =====================================================================================================================
procedure TAbout.RenderMenuBackground;
begin
  glColor3f(0.45, 0.45, 0.45);
  // Bottom only (back to menu)
  TextureManager.DrawQuad(FBO.Width / 2, -50, 2, 400, 200, 'radialgradientblack', (flCenter));
end;


 // =====================================================================================================================
 // TAbout.RenderMenuHighlight
 // =====================================================================================================================
procedure TAbout.RenderMenuHighlight;
begin
  case GetMenuSelection of
    selBottom: TextureManager.DrawQuad(FBOEffects.Width / 2, 0, 2, 200, 100, 'radialgradientblack', (flCenter));
  end;
end;


 // =====================================================================================================================
 // TAbout.RenderMenuText
 // =====================================================================================================================
procedure TAbout.RenderMenuText;
var
  i: integer;
begin
  glPushMatrix;
  glTranslatef(OrthoSize.x / 2, 0, 0);
  glScalef(1, -1, 1);
  if GetMenuSelection = selBottom then
    Font.Print2D('Back to menu', [0, -25, 0], FontAlignCenter, 2, 1, False)
  else
    Font.Print2D('Back to menu', [0, -25, 0], FontAlignCenter, 2, 0.25, False);

  for i := 0 to Lines.Count - 1 do
    Font.Print2D(Lines[i], [0, -OrthoSize.y / 2 - Lines.Count * 10 + i * 22 + 50, 3], FontAlignCenter, 1.75, 0.75);
  glColor3f(1, 1, 1);

  glPopMatrix;
end;


 // =====================================================================================================================
 // TAbout.Update
 // =====================================================================================================================
procedure TAbout.Update;
begin
  SwayTimer := Wrap(SwayTimer + TimeFactor * 2, 360);

  CharTimer := CharTimer - TimeFactor;
  if CharTimer < 0 then
  begin
    CharTimer := 1;
    if (CharPos = Length(Lines[LinePos]) - 1) or (Length(Lines[LinePos]) = 0) then
      if LinePos < Lines.Count - 1 then
      begin
        Inc(LinePos);
        CharPos := 0;
      end;
    Inc(CharPos);
    if CharPos > Length(Lines[LinePos]) then
      CharPos := Length(Lines[LinePos]);
  end;
end;


 // =====================================================================================================================
 // TAbout.Update
 // =====================================================================================================================
procedure TAbout.UpdateFBO;
const
  HoleSize = 18;
var
  Alpha: single;
  i: integer;
begin
  FBO.Enable;

  glViewport(0, 0, FBO.Width, FBO.Height);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, FBO.Width, FBO.Height, 0, -256, 256);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  glClearColor(0.15, 0.15, 0.15, 1);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);
  glDisable(GL_LIGHTING);

  // Background higlight in screen center
  TextureManager.SetBlending(bmBlend);
  glColor3f(1, 1, 1);

  with ShaderManager.Shader['stars'] do
  begin
    Bind;
    SetUniformf('time', [Timer]);
    SetUniformf('resolution', [FBO.Width, FBO.Width]);
  end;

  TextureManager.DrawBlankQuad(0, 0, 0, FBO.Width, FBO.Height);

  ShaderManager.DisableShader;

  // Dark gray background
  TextureManager.DisableTextureStage(GL_TEXTURe0);
  TextureManager.SetBlending(bmBlend);
  glBegin(GL_QUADS);
  glColor4f(0.15, 0.15, 0.15, 1);
  glVertex3f(0, 0, 1);
  glColor4f(0.15, 0.15, 0.15, 1);
  glVertex3f(FBO.Width, 0, 1);
  glColor4f(0.15, 0.15, 0.15, 0);
  glVertex3f(FBO.Width, FBO.Height * 0.65, 1);
  glColor4f(0.15, 0.15, 0.15, 0);
  glVertex3f(0, FBO.Height * 0.65, 1);
  glEnd;
  glColor3f(1, 1, 1);

  //  glColor3f(1+Sin(DegToRad(SwayTimer)), 1+Sin(DegToRad(SwayTimer)), 1+Sin(DegToRad(SwayTimer)));
  //  TextureManager.SetBlending(bmAdd);
  //  TextureManager.DrawQuad(FBO.Width / 2 - Sin(DegToRad(SwayTimer))*0, FBO.Height / 2 - Cos(DegToRad(SwayTimer))*0, 2, 600, 600, 'radialgradientblack', (flCenter));

  // Game logos
  with ShaderManager.Shader['filmgrain'] do
  begin
    Bind;
    SetUniformf('m_Time', [Trunc(DegTimer / 10) + 1]);
    SetUniformf('m_Strength', [40]);
    SetUniformi('m_Texture', [0]);
    SetUniformf('alpha', [1]);
    SetUniformi('alphamodulatesgrain', [1]);
    SetUniformi('blur', [0]);
  end;
  TextureManager.SetBlending(bmAdd);
  TextureManager.DrawQuad(FBO.Width / 2, FBO.Height - 200, 2, 650, -300, 'mainmenu_logo', (flCenter), True);
  TextureManager.DrawQuad(FBO.Width / 2, FBO.Height - 200, 2, 650, -300, 'mainmenu_logo', (flCenter), True);
  ShaderManager.DisableShader;

  RenderMenuBackground;

  glColor3f(1, 1, 1);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, FBO.Width, FBO.Height);
  gluPerspective(60, FBO.Width / FBO.Height, 1, 256);

  glClearColor(0, 0, 0, 1);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glClear(GL_DEPTH_BUFFER_BIT);
  glDisable(GL_CULL_FACE);

  TextureManager.DisableTextureStage(GL_TEXTURE0);
  TextureManager.SetBlending(bmNone);

  FBO.Disable;
end;


 // =====================================================================================================================
 // TAbout.UpdateEffectsFBO
 // =====================================================================================================================
procedure TAbout.UpdateEffectsFBO;
begin
  FBOEffects.Enable;

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, FBOEffects.Width, FBOEffects.Height);
  glOrtho(0, FBOEffects.Width, FBOEffects.Height, 0, -256, 256);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);
  glDisable(GL_LIGHTING);
  glDepthMask(False);

  TextureManager.DisableTextureStage(GL_TEXTURE0);

  glTranslatef(0, 1, -50);

  glColor3f(1, 1, 1);

  //  TextureManager.SetBlending(bmAdd);
  //  TextureManager.DrawQuad(FBOEffects.Width / 2 + Sin(DegToRad(SwayTimer))*0, FBOEffects.Height / 2 + Cos(DegToRad(SwayTimer))*0, 1, 250, 250, 'radialgradientblack', (flCenter));

  RenderMenuHighlight;

  FBOEffects.Disable;
end;


 // =====================================================================================================================
 // TAbout.Click
 // =====================================================================================================================
procedure TAbout.Click;
begin
  if GetMenuSelection = selBottom then
    Game.ChangeState(gsMainMenu);
end;


end.

