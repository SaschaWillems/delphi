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

unit TrugBild_RealityScene;

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
  TPerson = record
    FadePos: single;
    FadeDir: single;
    Text: string;
    Texture: string;
    CharPos: byte;
    CharTimer: single;
  end;

  TRealityScene = class
  private
    XMLNode: IXMLNode;
    CurrentNode: integer;
    CurrentLine: integer;
    BlinkTimer: single;
    FadePos: single;
    FadeDir: single;
    FadeSpeed: single;
    LineStepTimer: single;
    Person: array[0..1] of TPerson;
    LastTextPos: string;
    Name: string;
    BlurTimer: single;
    Caption: string;
    CaptionTimer: single;
    procedure StartFade(ASpeed: single);
    procedure UpdateFBO;
    procedure GetCurrentNodeText;
    procedure NextLine;
  public
    FBO: TFrameBufferObject;
    procedure LoadFromXML(AXMLNode: IXMLNode);
    procedure Render;
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
  end;

var
  RealityScene: TRealityScene;

implementation

const
  Left  = 0;
  Right = 1;

 // =====================================================================================================================
 // TRealityScene
 // =====================================================================================================================


 // =====================================================================================================================
 // TRealityScene.Create
 // =====================================================================================================================
constructor TRealityScene.Create;
begin
  FBO        := TFrameBufferObject.Create(2048, 2048);
  //  LoadFromXML('data\reality.xml');
  BlinkTimer := 25;
end;


 // =====================================================================================================================
 // TRealityScene.Destroy
 // =====================================================================================================================
destructor TRealityScene.Destroy;
begin
  FBO.Free;
  inherited;
end;


 // =====================================================================================================================
 // TRealityScene.GetCurrentNodeText
 // =====================================================================================================================
procedure TRealityScene.GetCurrentNodeText;
begin
  Name := XMLNode.Attributes['name'];
  Person[Left].Texture := XMLNode.Attributes['left'];
  Person[Right].Texture := XMLNode.Attributes['right'];

  if SameText(XMLNode.ChildNodes[CurrentLine].Attributes['position'], 'left') then
  begin
    Person[Left].Text := XMLNode.ChildNodes[CurrentLine].NodeValue;
    if XMLNode.ChildNodes[CurrentLine].Attributes['position'] <> LastTextPos then
    begin
      Person[Left].FadePos := 0;
      Person[Left].FadeDir := 1;
    end;
    Person[Left].CharPos := 1;
    Person[Left].CharTimer := 0;
    Person[Right].FadeDir  := -1;
  end;

  if SameText(XMLNode.ChildNodes[CurrentLine].Attributes['position'], 'right') then
  begin
    Person[Right].Text := XMLNode.ChildNodes[CurrentLine].NodeValue;
    if XMLNode.ChildNodes[CurrentLine].Attributes['position'] <> LastTextPos then
    begin
      Person[Right].FadePos := 0;
      Person[Right].FadeDir := 1;
    end;
    Person[Right].CharPos := 1;
    Person[Right].CharTimer := 0;
    Person[Left].FadeDir    := -1;
  end;

  LastTextPos := XMLNode.ChildNodes[CurrentLine].Attributes['position'];
end;


 // =====================================================================================================================
 // TRealityScene.LoadFromXML
 // =====================================================================================================================
procedure TRealityScene.LoadFromXML(AXMLNode: IXMLNode);
begin
  XMLNode := AXMLNode;

  CurrentNode := 0;
  CurrentLine := 0;

  GetCurrentNodeText;

  if AXMLNode.ParentNode.HasAttribute('name') then
  begin
    Caption      := 'Chapter ' + AXMLNode.ParentNode.Attributes['index'] + ' - ' + AXMLNode.ParentNode.Attributes['name'];
    CaptionTimer := 0;
  end;
end;


 // =====================================================================================================================
 // TRealityScene.NextLine
 // =====================================================================================================================
 //  Select next line of text in current dialog node, or switch back to game if last line
 // =====================================================================================================================
procedure TRealityScene.NextLine;
begin
  if CurrentLine = XMLNode.ChildNodes.Count - 1 then
  begin
    // If last line, switch state
    //  For final chapter, change state to game ending
    if SameText(Name, 'final') then
    begin
      Game.Ending := geGood;
      Game.ChangeState(gsEnding);
    end
    else
      Game.ChangeState(gsIngame);
    Person[Left].Text  := '';
    Person[Right].Text := '';
  end
  else
  begin
    Inc(CurrentLine);
    GetCurrentNodeText;
  end;
end;


 // =====================================================================================================================
 // TRealityScene.UpdateFBO
 // =====================================================================================================================
procedure TRealityScene.UpdateFBO;
var
  AR: single;
  OffsetX: single;
  i: integer;
  Alpha: single;
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

  glClearColor(0.05, 0.05, 0.05, 1);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);
  glDisable(GL_LIGHTING);
  glDepthMask(False);

  // Stars
  TextureManager.SetBlending(bmBlend);
  TextureManager.DrawQuad(0, FBO.Height, 0, FBO.Width, -FBO.Height, 'stars');

  // Person and highlight on the left
  TextureManager.SetBlending(bmAdd);
  glColor3f(0.25 + Person[Left].FadePos * 0.75, 0.25 + Person[Left].FadePos * 0.75, 0.25 + Person[Left].FadePos * 0.75);
  TextureManager.DrawQuad(-200 + OffsetX * 0.45, FBO.Height - 1024 - 1100, -50, 1024, 1024 * AR, 'radialgradientblack');
  TextureManager.SetBlending(bmBlend);
  TextureManager.DrawQuad(-180 + Person[Left].FadePos * 25 + OffsetX * 0.75, FBO.Height - 1024 - 700, 0, 1150, 1150 * AR, Person[Left].Texture, 0, True);
  TextureManager.SetWrapMode(GL_CLAMP, GL_CLAMP);

  // Person and highlight on the right
  TextureManager.SetBlending(bmAdd);
  glColor3f(0.25 + Person[Right].FadePos * 0.75, 0.25 + Person[Right].FadePos * 0.75, 0.25 + Person[Right].FadePos * 0.75);
  TextureManager.DrawQuad(FBO.Width - 650 + OffsetX * 0.45, 200, 0, 1024, 1024 * AR, 'radialgradientblack');
  TextureManager.SetBlending(bmBlend);
  TextureManager.DrawQuad(FBO.Width - 800 - Person[Right].FadePos * 50 + OffsetX * 0.75, FBO.Height - 1024 - 500, 0, 1000, 1000 * AR, Person[Right].Texture, 0, True);
  TextureManager.SetWrapMode(GL_CLAMP, GL_CLAMP);

  // Sickbed
  TextureManager.SetBlending(bmBlend);
  glColor3f(0.6, 0.6, 0.6);
  TextureManager.DrawQuad(FBO.Width / 2 - (1024 * 0.75) + OffsetX, FBO.Height - (1024 * AR * 0.75), 0, 2048 * 0.75, 1024 * AR * 0.75, 'reality_sickbed', 0, True);
  TextureManager.SetWrapMode(GL_CLAMP, GL_CLAMP);

  TextureManager.SetBlending(bmBlend);
  glColor3f(1, 1, 1);
  TextureManager.DrawQuad(FBO.Width - 750 + OffsetX * 2.75, -20, 0, 575, 575 * AR, 'reality_sickbedhandle', 0, True);
  TextureManager.SetWrapMode(GL_CLAMP, GL_CLAMP);

  // Text
  for i := Left to Right do
    with Person[i] do
      if (Text <> '') and (Game.FadePos = 0) then
      begin
        TextShadowOffset := 2;
        glPushMatrix;
        if i = Left then
        begin
          glTranslatef(300, FBO.Height - 950, 0);
          glScalef(1 / AR, 1, 1);
          Font.Print2D(Copy(Text, 1, CharPos), [0, 0, 0], FontAlignLeft, 8, FadePos * 0.75, True);
        end;
        if i = Right then
        begin
          glTranslatef(FBO.Width - 250, FBO.Height - 500 * AR, 0);
          glScalef(1 / AR, 1, 1);
          Font.Print2D(Copy(Text, 1, CharPos), [0, 0, 0], FontAlignRight, 8, FadePos * 0.75, True);
        end;
        glPopMatrix;
        TextShadowOffset := 0;
        FadePos          := Clamp(FadePos + FadeDir * TimeFactor * 0.15, 0, 1);
        CharTimer        := CharTimer - TimeFactor;
        if CharTimer < 0 then
        begin
          CharTimer := 1;
          if CharPos = Length(Text) - 1 then
            LineStepTimer := 1;
          Inc(CharPos);
          if CharPos > Length(Text) then
            CharPos := Length(Text);
        end;
      end;

  // Chapter caption
  Alpha := 1;
  if CaptionTimer <= 1 then
    Alpha := CaptionTimer;
  if CaptionTimer > 1 then
    Alpha := 2 - CaptionTimer;
  glPushMatrix;
  TextShadowOffset := 2;
  glTranslatef(FBO.Width / 2, 125, 0);
  glScalef(1 / AR, 1, 1);
  Font.Print2D(Caption, [0, 0, 0], FontAlignCenter, 6, Alpha, True);
  TextShadowOffset := 0;
  glPopMatrix;

  // Timer for moving to next line
  if LineStepTimer > 0 then
  begin
    LineStepTimer := LineStepTimer - TimeFactor * 0.1;
    if LineStepTimer < 0 then
    begin
      LineStepTimer := 0;
      NextLine;
    end;
  end;

  // Blinking
  BlinkTimer := BlinkTimer - TimeFactor * 0.75;
  if BlinkTimer < 0 then
  begin
    BlinkTimer := 25 + Random(25);
    StartFade(0.25 + Random * 0.1 - Random * 0.1);
  end;

  glDepthMask(True);

  FBO.Disable;
end;


 // =====================================================================================================================
 // TRealityScene.RenderScene
 // =====================================================================================================================
procedure TRealityScene.Render;
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
    SetUniformf('m_Strength', [4]);
    SetUniformi('m_Texture', [0]);
    SetUniformf('alpha', [1]);
    SetUniformi('blur', [1]);
    SetUniformf('blurShift', [0.002{*Sin(DegToRad(BlurTimer))}, 0]);
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

  BlurTimer := Wrap(BlurTimer + TimeFactor * 10, 360);

  CaptionTimer := Clamp(CaptionTimer + TimeFactor * 0.05, 0, 3);
end;


 // =====================================================================================================================
 // TRealityScene.Reset
 // =====================================================================================================================
procedure TRealityScene.Reset;
var
  i: integer;
begin
  CurrentNode  := 0;
  CurrentLine  := 0;
  LastTextPos  := '';
  BlurTimer    := 0;
  CaptionTImer := 0;
  for i := Left to Right do
    with Person[i] do
    begin
      FadePos   := 0;
      FadeDir   := 0;
      CharPos   := 0;
      CharTimer := 1;
    end;
  GetCurrentNodeText;
end;


 // =====================================================================================================================
 // TRealityScene.StartFade
 // =====================================================================================================================
procedure TRealityScene.StartFade(ASpeed: single);
begin
  // No additional fade if already fading
  if FadePos > 0 then
    Exit;
  FadePos   := 0;
  FadeDir   := 1;
  FadeSpeed := ASpeed;
end;

end.

