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

unit TrugBild_EndingScene;

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
  TrugBild_GameClass,
  TrugBild_DecisionClass,
  TrugBild_PlayerClass;

type
  TEndingMenuSelection = (selNone, selLeft, selRight, selBottom, selTop);

  TEndingScene = class
  private
    CharTimer: single;
    CharPos: integer;
    LinePos: integer;
    Lines: TStringList;
    BlurTimer: single;
    SwayTimer: single;
    CurrAnswer: integer;
    AnswerTimer: single;
    function GetMenuSelection: TEndingMenuSelection;
    procedure RenderMenuBackground;
    procedure RenderMenuHighlight;
    procedure RenderMenuText;
    procedure UpdateFBO;
    procedure UpdateEffectsFBO;
  public
    FBO: TFrameBufferObject;
    FBOEffects: TFrameBufferObject;
    procedure GenerateEndingLines;
    procedure Render;
    procedure Update;
    procedure Click;
    constructor Create(AFBO, AFBOEffects: TFrameBufferObject);
    destructor Destroy; override;
    procedure Reset;
  end;

var
  EndingScene: TEndingScene;

implementation

 // =====================================================================================================================
 // TEndingScene
 // =====================================================================================================================


 // =====================================================================================================================
 // TEndingScene.Create
 // =====================================================================================================================
constructor TEndingScene.Create(AFBO, AFBOEffects: TFrameBufferObject);
begin
  Lines      := TStringList.Create;
  FBO        := AFBO;
  FBOEffects := AFBOEffects;
  Reset;
end;


 // =====================================================================================================================
 // TEndingScene.Destroy
 // =====================================================================================================================
destructor TEndingScene.Destroy;
begin
  Lines.Free;
  inherited;
end;


 // =====================================================================================================================
 // TEndingScene.GenerateEndingLines
 // =====================================================================================================================
procedure TEndingScene.GenerateEndingLines;
var
  i: integer;
begin
  Reset;

  Lines.Clear;
  Lines.Add('and thus your journey ends...');
  Lines.Add('');

  // Ending
  case Game.Ending of
    geGood: Lines.Add('you died away in peace');
    geBad: Lines.Add('your life ended all of a sudden');
  end;

  Lines.Add('');

  // TODO : Maybe tweak the texts...

  // Mostly negative answers
  if Player.Bias < 0 then
    if Player.Bias < 100 then
      Lines.Add('...you painted a very grim an dark picture of life')
    else
      Lines.Add('...you painted a dark picture of life');

  // Neutral answers
  if Player.Bias = 0 then
    Lines.Add('...you had a differentiated view on life');

  // Mostly positive answers
  if Player.Bias > 0 then
    if Player.Bias > 100 then
      Lines.Add('...you had a love for life second to none')
    else
      Lines.Add('...you had a positive view on life itself');

  // Save answers
  Game.LogMessage('Playthrough ended at ' + DateTimeToStr(Now));
  Game.LogMessage('Decisions saved');

  with TStringList.Create do
  begin
    for i := 0 to Player.AnswerHistory.Count - 1 do
      Add(Player.DecisionHistory[i] + ' ' + Player.AnswerHistory[i]);
    SaveToFile(Game.AppDataDir + 'decisions_' + FormatDateTime('yyyy-mm-dd_hh-nn-ss', Now) + '.txt');
    Free;
  end;

  // Reset answer and timer
  CurrAnswer  := 0;
  AnswerTimer := 0;
end;


 // =====================================================================================================================
 // TEndingScene.GetMenuSelection
 // =====================================================================================================================
function TEndingScene.GetMenuSelection: TEndingMenuSelection;
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
 // TEndingScene.Render
 // =====================================================================================================================
procedure TEndingScene.Render;
var
  i: integer;
  Alpha: single;
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

  // Text
  TextShadowOffset := 0.25;
  glPushMatrix;

  // Ending text
  glTranslatef(OrthoSize.x / 2, OrthoSize.y / 2 + Lines.Count * 25 / 2, 0);
  glScalef(1, -1, 1);
  for i := 0 to LinePos do
    if i < LinePos then
      FontBlack.Print2D(Lines[i], [0, i * 25, 0], FontAlignCenter, 2.5, 1, False)
    else
      FontBlack.Print2D(Copy(Lines[i], 1, CharPos), [0, i * 25, 0], FontAlignCenter, 2.5, 1, False);
  glPopMatrix;

  // Current answer
  if AnswerTimer < 1 then
    Alpha := AnswerTimer;
  if AnswerTimer > 1 then
    Alpha := 2 - AnswerTimer;
  glPushMatrix;
  glTranslatef(OrthoSize.x / 2, 100, 0);
  glScalef(1, -1, 1);
  FontBlack.Print2D(Player.DecisionHistory[CurrAnswer] + ' ' + Player.AnswerHistory[CurrAnswer], [0, {40-30*AnswerTimer}0, 0], FontAlignCenter, 2.5, Alpha, False);
  glPopMatrix;

  RenderMenuText;

  TextShadowOffset := 0;

  glDepthMask(True);

  TextureManager.SetBlending(bmBlend);
end;


 // =====================================================================================================================
 // TEndingScene.RenderMenuBackground
 // =====================================================================================================================
procedure TEndingScene.RenderMenuBackground;
begin
  glColor3f(0.45, 0.45, 0.45);
  // Right
  //  TextureManager.DrawQuad(FBO.Width, FBO.Height/2, 2, 400, 800, 'radialgradientblack', (flCenter));
  // Left
  //  TextureManager.DrawQuad(0, FBO.Height/2, 2, 400, 800, 'radialgradientblack', (flCenter));
  // Bottom
  TextureManager.DrawQuad(FBO.Width / 2, -50, 2, 400, 200, 'radialgradientblack', (flCenter));
  // Top
  TextureManager.DrawQuad(FBO.Width / 2, FBO.Height + 50, 2, 400, 200, 'radialgradientblack', (flCenter));
end;


 // =====================================================================================================================
 // TEndingScene.RenderMenuHighlight
 // =====================================================================================================================
procedure TEndingScene.RenderMenuHighlight;
begin
  case GetMenuSelection of
    //    selLeft   : TextureManager.DrawQuad(0, FBOEffects.Height/2, 2, 200, 400, 'radialgradientblack', (flCenter));
    //    selRight  : TextureManager.DrawQuad(FBOEffects.Width, FBOEffects.Height/2, 2, 200, 400, 'radialgradientblack', (flCenter));
    selBottom: TextureManager.DrawQuad(FBOEffects.Width / 2, 0, 2, 200, 100, 'radialgradientblack', (flCenter));
    selTop: TextureManager.DrawQuad(FBOEffects.Width / 2, FBOEffects.Height, 2, 200, 100, 'radialgradientblack', (flCenter));
  end;
end;


 // =====================================================================================================================
 // TEndingScene.RenderMenuText
 // =====================================================================================================================
procedure TEndingScene.RenderMenuText;
begin
  // Back to main menu
  glPushMatrix;
  glTranslatef(OrthoSize.x / 2, 0, 0);
  glScalef(1, -1, 1);
  if GetMenuSelection = selTop then
    Font.Print2D('Leave', [0, -OrthoSize.y, 0], FontAlignCenter, 2, 1, False)
  else
    Font.Print2D('Leave', [0, -OrthoSize.y, 0], FontAlignCenter, 2, 0.25, False);
  if GetMenuSelection = selBottom then
    Font.Print2D('Move on', [0, -25, 0], FontAlignCenter, 2, 1, False)
  else
    Font.Print2D('Move on', [0, -25, 0], FontAlignCenter, 2, 0.25, False);
  glPopMatrix;
end;


 // =====================================================================================================================
 // TEndingScene.Reset
 // =====================================================================================================================
procedure TEndingScene.Reset;
begin
  CharTimer := 1;
  CharPos   := 0;
  LinePos   := 0;
end;


 // =====================================================================================================================
 // TEndingScene.Update
 // =====================================================================================================================
procedure TEndingScene.Update;
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

  AnswerTimer := AnswerTimer + TimeFactor * 0.05;
  if AnswerTimer > 2 then
  begin
    AnswerTimer := 0;
    Inc(CurrAnswer);
    if CurrAnswer > Player.AnswerHistory.Count - 1 then
      CurrAnswer := 0;
  end;
end;


 // =====================================================================================================================
 // TEndingScene.Update
 // =====================================================================================================================
procedure TEndingScene.UpdateFBO;
const
  HoleSize = 18;
var
  Alpha: single;
  PlaneColS, PlaneColE: TglVertex4f;
begin
  FBO.Enable;

  glViewport(0, 0, FBO.Width, FBO.Height);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, FBO.Width, FBO.Height, 0, -256, 256);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  glClearColor(0.15, 0.15, 0.15, 1);
  if Player.Bias < 0 then
    glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);
  glDisable(GL_LIGHTING);
  //  glDepthMask(False);

  // Background higlight in screen center
  if Player.Bias >= 0 then
  begin
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
  end;

  // Dark gray background
  if Player.Bias >= 0 then
  begin
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
  end
  else
  begin
    glPushMatrix;
    PlaneColS := glVertex(0.25, 0.25, 0.25, 1);
    PlaneColE := glVertex(0.25, 0.25, 0.25, 0);
    TextureManager.DisableTextureStage(GL_TEXTURe0);
    TextureManager.SetBlending(bmBlend);
    glBegin(GL_QUADS);
    glColor4fv(@PlaneColS);
    glVertex3f(0, FBO.Height, 1);
    glColor4fv(@PlaneColS);
    glVertex3f(FBO.Width, FBO.Height, 1);
    glColor4fv(@PlaneColE);
    glVertex3f(FBO.Width, FBO.Height * 0.65, 1);
    glColor4fv(@PlaneColE);
    glVertex3f(0, FBO.Height * 0.65, 1);
    glEnd;
    glBegin(GL_QUADS);
    glColor4fv(@PlaneColS);
    glVertex3f(0, 0, 1);
    glColor4fv(@PlaneColS);
    glVertex3f(FBO.Width, 0, 1);
    glColor4fv(@PlaneColE);
    glVertex3f(FBO.Width, FBO.Height * 0.35, 1);
    glColor4fv(@PlaneColE);
    glVertex3f(0, FBO.Height * 0.35, 1);
    glEnd;
    glColor3f(1, 1, 1);
    glPopMatrix;
  end;

  if Player.Bias >= 0 then
  begin
    // White "spirit" light for positive ending
    glColor3f(1 + Sin(DegToRad(SwayTimer)), 1 + Sin(DegToRad(SwayTimer)), 1 + Sin(DegToRad(SwayTimer)));
    TextureManager.SetBlending(bmAdd);
    TextureManager.DrawQuad(FBO.Width / 2 - Sin(DegToRad(SwayTimer)) * 0, FBO.Height / 2 - Cos(DegToRad(SwayTimer)) * 0, 2, 600, 600, 'radialgradientblack', (flCenter));
  end
  else
  ;

  TextureManager.SetBlending(bmAdd);

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
 // TEndingScene.UpdateEffectsFBO
 // =====================================================================================================================
procedure TEndingScene.UpdateEffectsFBO;
begin
  FBOEffects.Enable;

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, FBOEffects.Width, FBOEffects.Height);
  //  gluPerspective(60, FBOEffects.Width/FBOEffects.Height, 1, 256);
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

  if Player.Bias >= 0 then
  begin
    TextureManager.SetBlending(bmAdd);
    TextureManager.DrawQuad(FBOEffects.Width / 2 + Sin(DegToRad(SwayTimer)) * 0, FBOEffects.Height / 2 + Cos(DegToRad(SwayTimer)) * 0, 1, 250, 250, 'radialgradientblack', (flCenter));
  end;

  RenderMenuHighlight;

  FBOEffects.Disable;
end;


 // =====================================================================================================================
 // TEndingScene.Click
 // =====================================================================================================================
procedure TEndingScene.Click;
begin
  if GetMenuSelection = selBottom then
    Game.ChangeState(gsMainMenu);
  if GetMenuSelection = selTop then
    Quit := True;
end;


end.

