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

unit TrugBild_MainForm;

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
  bassSoundSystem,
  ShellAPI,
  ShlObj,
  ActiveX,
  VirtualFileSystem,
  TrugBild_Global,
  TrugBild_RealityScene,
  TrugBild_GameClass,
  TrugBild_DecisionClass,
  TrugBild_PlayerClass,
  TrugBild_DeathScene,
  TrugBild_MainMenu,
  TrugBild_EndingScene,
  TrugBild_ChapterClass,
  TrugBild_About;

type
  TStage = class
  private
    XMLDoc: IXMLDocument;
    Chapters: array of TChapter;
    BlurTimer: single;
    CurrChapter: integer;
    SpeedFactor: single;
    procedure RenderLadders(AFBO: TFrameBufferObject; AForColorPicking: Boolean);
    procedure RenderHoles(AFBO: TFrameBufferObject; AForColorPicking: Boolean);
    procedure RenderCorridors(AFBO: TFrameBufferObject; AForColorPicking: Boolean);
    procedure RenderDoors(AFBO: TFrameBufferObject; AForColorPicking: Boolean);
  public
    Name: string;
    Title: string;
    TagLine: string;
    procedure Update;
    procedure Render(AFBO: TFrameBufferObject; AForColorPicking: Boolean);
    procedure LoadFromFile(const AFileName: string);
    procedure SelectAnswer;
    function CurrentChapter: TChapter;
    function NextChapter: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    procedure StateChange;
  end;

  TRenderer = class
  private
    FBO: TFrameBufferObject;
    FBOEffects: TFrameBufferObject;
    FBOColSel: TFrameBufferObject;
    FBOText: TFrameBufferObject;
    RC: HGLRC;
    DC: HDC;
    SwayTimer: single;
    Sway: Boolean;  // Debugging
    Noise: Boolean; // Debugging
    Blur: Boolean;  // Debugging
    CursorTex: glUInt;
    procedure RenderToTexture(AFBO: TFrameBufferObject; AForColorPicking: Boolean = False);
    procedure RenderOverlays;
    procedure ColorPicking;
  public
    Debug: Boolean;
    procedure Render;
    procedure UpdateTimers;
    constructor Create;
    destructor Destroy; override;
  end;

  TGLForm = class(TForm)
    TimerStartGame: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TimerStartGameTimer(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
    procedure FormClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    QPCf: int64;
    Windowed: Boolean;
    DebugKeys: Boolean;
    DebugOverlay: Boolean;
    procedure GameLoop;
    procedure CreateVFS;
  public
    procedure GoToFullScreen(pWidth, pHeight, pBPP, pFrequency: word);
  end;

var
  GLForm: TGLForm;
  Renderer: TRenderer;
  Stage: TStage;

implementation

{$R *.dfm}

 // =====================================================================================================================
 // GetCurrentDecision
 // =====================================================================================================================
 // TODO : Maybe move to somewhere else?
function GetCurrentDecision: TDecision;
begin
  Result := nil;

  if Game.State = gsIngame then
    Exit(Stage.CurrentChapter.GetDecision);

  if Game.State = gsMainMenu then
    Exit(MainMenu.Decision);

  if not Assigned(Result) then

    raise Exception.Create('GetCurrentDecision : Decision is NIL!');
end;


 // =====================================================================================================================
 // TRenderer
 // =====================================================================================================================

 // =====================================================================================================================
 // TRenderer.Create
 // =====================================================================================================================
constructor TRenderer.Create;
begin
  try
    Game.LogMessage('Initializing Renderer');
    InitOpenGL;
    DC := GetDC(GLForm.Handle);
    RC := CreateRenderingContext(DC, [opDoubleBuffered], 32, 24, 0, 0, 0, 0);
    ActivateRenderingContext(DC, RC);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glClearColor(0, 0, 0, 0);
    Game.LogMessage('Rendercontext created');

    if not GL_VERSION_2_1 then
    begin
      MessageDlg('This game requires at least OpenGL 2.1 to run!', mtError, [mbOK], 0);
      halt(0);
    end;

    if (not glIsExtSupported('GL_ARB_framebuffer_object')) and (not glIsExtSupported('GL_EXT_framebuffer_object')) then
    begin
      MessageDlg('Your graphics card (or driver) doesn''t support GL_ARB_framebuffer_object or GL_EXT_framebuffer_object!', mtError, [mbOK], 0);
      halt(0);
    end;

    TextureManager := TTextureManager.Create;
    VFS.LoadTexturesInDirectory('data\preload\', '.dds', TextureManager, True);
    RenderLoadingScreen(DC);

    Game.LogMessage('Creating frame buffer objects');
    FBO        := TFrameBufferObject.Create(2048, 1024);
    FBOColSel  := TFrameBufferObject.Create(2048, 1024);
    FBOEffects := TFrameBufferObject.Create(2048, 1024);
    FBOText    := TFrameBufferObject.Create(2048, 1024);

    Game.LogMessage('Loading shaders');
    ShaderManager := TGLSLShaderManager.Create;
    VFS.LoadShader('filmgrain', 'data\shader\filmgrain.vert', 'data\shader\filmgrain.frag', ShaderManager);
    VFS.LoadShader('radialgradient', 'data\shader\radialgradient.vert', 'data\shader\radialgradient.frag', ShaderManager);
    VFS.LoadShader('blur', 'data\shader\blur.vert', 'data\shader\blur.frag', ShaderManager);
    VFS.LoadShader('stars', 'data\shader\stars.vert', 'data\shader\stars.frag', ShaderManager);
    VFS.LoadShader('grayscale', 'data\shader\grayscale.vert', 'data\shader\grayscale.frag', ShaderManager);
    VFS.LoadShader('color', 'data\shader\color.vert', 'data\shader\color.frag', ShaderManager);

    Game.LogMessage('Loading textures');
    VFS.LoadTexturesInDirectory('data\textures\', '.dds', TextureManager, True);
    CursorTex := TextureManager.GetTextureID('cursor_hand');

    Game.LogMessage('Loading fonts');
    VFS.LoadFont('data\fonts\philosopher.dds', 'data\fonts\philosopher.dat', '', 4, Font, TextureManager);
    VFS.LoadFont('data\fonts\philosopher_black.dds', 'data\fonts\philosopher_black.dat', '', 4, FontBlack, TextureManager);

    // Debug stuff
    Sway  := True;
    Noise := True;
  except
    on E: Exception do
    begin
      Game.LogMessage('Could not setup renderer!' + E.ToString + ' : ' + E.Message);
      MessageDlg('Could not setup renderer!' + #13 + E.ToString + ' : ' + E.Message, mtError, [mbOK], 0);
      Application.Terminate;
    end;
  end;
  Game.LogMessage('Renderer created');
end;


 // =====================================================================================================================
 // TRenderer.Destroy
 // =====================================================================================================================
destructor TRenderer.Destroy;
begin
  if (DC <> 0) and (RC <> 0) then
  begin
    if Assigned(FBO) then
      FBO.Free;
    if Assigned(FBOColSel) then
      FBOColSel.Free;
    if Assigned(FBOEffects) then
      FBOEffects.Free;
    if Assigned(FBOText) then
      FBOText.Free;
    DeactivateRenderingContext;
    wglDeleteContext(RC);
    ReleaseDC(GLForm.Handle, DC);
    if Assigned(ShaderManager) then
      ShaderManager.Free;
    if Assigned(TextureManager) then
      TextureManager.Free;
    if Assigned(Font) then
      Font.Free;
    if Assigned(FontBlack) then
      FontBlack.Free;
    //ChangeDisplaySettings(devmode(nil^), 0);
  end;
  inherited;
end;


 // =====================================================================================================================
 // TRenderer.ColorSelection
 // =====================================================================================================================
procedure TRenderer.ColorPicking;
var
  Pixel: array[0..2] of byte;
  Viewport: TVector4i;
  i: integer;
begin
  RenderToTexture(FBOColSel, True);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, GLForm.ClientWidth, GLForm.ClientHeight);
  glOrtho(0, GLForm.ClientWidth, GLForm.ClientHeight, 0, -128, 128);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);

  glGetIntegerv(GL_VIEWPORT, @viewport);

  glColor3f(1, 1, 1);
  FBOColSel.Bind;
  TextureManager.DrawBlankQuad(0, 0, 0, GLForm.ClientWidth, GLForm.ClientHeight);

  glReadBuffer(GL_BACK);
  glReadPixels(MousePos.x, {viewport[3]-}MousePos.y, 1, 1, GL_RGB, GL_UNSIGNED_BYTE, @Pixel[0]);

  GetCurrentDecision.Selection := -1;

  // Convert picked color to selected corridor number
  for i := 0 to High(GetCurrentDecision.Answers) do
    if Pixel[0] = ColSelStep + i * ColSelStep then
    begin
      GetCurrentDecision.Selection := i;
      break;
    end;

  GetCurrentDecision.Update(Stage.SpeedFactor);
end;


 // =====================================================================================================================
 // TRenderer.RenderOverlays
 // =====================================================================================================================
 //  All the stuff that get's overlay on top of the 3D scene on ortho modus (insanty display, health display, GUI, etc.)
 // =====================================================================================================================
procedure TRenderer.RenderOverlays;
begin
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, GLForm.ClientWidth, GLForm.ClientHeight);
  glOrtho(0, OrthoSize.x, OrthoSize.y, 0, -128, 128); // TODO : Adjust to screen ratio?

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glClear(GL_DEPTH_BUFFER_BIT);
  glDisable(GL_CULL_FACE);

  glDepthMask(False);

  if Game.State = gsMainMenu then
  begin
    glColor3f(1, 1, 1);
    // Radial gradient
    TextureManager.SetBlending(bmModulate);
    TextureManager.DrawQuad(0, 0, 0, OrthoSize.x, OrthoSize.y, 'radialgradientblack');

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
    TextureManager.DrawQuad(OrthoSize.x / 2, 128, 0, 512, 256, 'mainmenu_logo', (flCenter), True);
    TextureManager.DrawQuad(OrthoSize.x / 2, 128, 0, 512, 256, 'mainmenu_logo', (flCenter), True);
    TextureManager.DrawQuad(OrthoSize.x / 2 + 180, 200, 0, 512, 128, 'mainmenu_gameby', (flCenter), True);
    TextureManager.DrawQuad(OrthoSize.x / 2, OrthoSize.y - 40, 0, 500, 65, 'mainmenu_pgdedition', (flCenter), True);
    ShaderManager.DisableShader;
  end
  else
  begin
    // Use radial gradient to highlight player look direction
    glColor3f(1, 1, 1); // Hint : Use color to simulate dark lighting
    TextureManager.SetBlending(bmModulate);
    glDisable(GL_TEXTURE_2D);
    with ShaderManager.Shader['radialgradient'] do
    begin
      Bind;
      SetUniformf('pos', [MousePos.x, OrthoSize.y / 2{ + MousePos.y * 0.25}]);
      SetUniformf('dim', [768]);
      SetUniformf('ambient', [0.15 + Sin(DegToRad(SwayTimer)) * 0.25]);
      SetUniformf('orthosize', [GLForm.ClientWidth, OrthoSize.y]);
    end;
    glBegin(GL_QUADS);
    glTexCoord2f(0, 0);
    glVertex3f(0, 0, 0);
    glTexCoord2f(GLForm.ClientWidth, 0);
    glVertex3f(OrthoSize.x, 0, 0);
    glTexCoord2f(GLForm.ClientWidth, OrthoSize.y);
    glVertex3f(OrthoSize.x, OrthoSize.y, 0);
    glTexCoord2f(0, OrthoSize.y);
    glVertex3f(0, OrthoSize.y, 0);
    glEnd;
    ShaderManager.DisableShader;

    TextureManager.SetBlending(bmNone);

    Player.Render(1 - Stage.CurrentChapter.RealityFade);
  end;

  // Darken borders
  TextureManager.SetBlending(bmBlend);
  TextureManager.DrawQuad(0, 0, 0, OrthoSize.x, OrthoSize.y, 'darkborders');

  TextureManager.SetBlending(bmNone);

  // Current decision
  //  GetCurrentDecision.Render;

  glDepthMask(True);

  if Renderer.Debug then
  begin
    // Show display FBO
    FBO.Bind;
    TextureManager.DrawBlankQuad(0, 200, 0, 200, -200);
    // Show color selection FBO
    FBOColSel.Bind;
    TextureManager.DrawBlankQuad(200, 200, 0, 200, -200);
    // Show effects FBO
    FBOEffects.Bind;
    TextureManager.DrawBlankQuad(400, 200, 0, 200, -200);
    // Text FBO
    FBOText.Bind;
    TextureManager.DrawBlankQuad(600, 200, 0, 200, -200);
    // Reality scene FBO
    RealityScene.FBO.Bind;
    TextureManager.DrawBlankQuad(800, 0, 0, 200, 200);
    // Death scene FBO
    DeathScene.FBO.Bind;
    TextureManager.DrawBlankQuad(1000, 0, 0, 200, 200);
  end;

  // Debug text
  if GLForm.DebugOverlay then
  begin
    Font.Print2D('Player.Bias = ' + IntToStr(Player.Bias), [5, 5, 0], FontAlignLeft, 1, 1);
    Font.Print2D('Player.NumAnswers = ' + IntToStr(Player.AnswerHistory.Count), [5, 20, 0], FontAlignLeft, 1, 1);
    Font.Print2D('Stage.SpeedFactor = ' + FloatToStr(Stage.SpeedFactor), [5, 35, 0], FontAlignLeft, 1, 1);
  end;
  glDepthFunc(GL_ALWAYS);
end;


 // =====================================================================================================================
 // TRenderer.RenderToTexture
 // =====================================================================================================================
procedure TRenderer.RenderToTexture(AFBO: TFrameBufferObject; AForColorPicking: Boolean = False);
begin
  AFBO.Enable;
  Stage.Render(AFBO, AForColorPicking);
  AFBO.Disable;
end;


 // =====================================================================================================================
 // TRenderer.RenderScene
 // =====================================================================================================================
procedure TRenderer.Render;
var
  GLError: cardinal;
begin
  if Game.State = gsReality then
  begin
    glViewPort(0, 0, GLForm.ClientWidth, GLForm.ClientHeight);
    RealityScene.Render;
  end;

  if Game.State = gsEnding then
  begin
    glViewPort(0, 0, GLForm.ClientWidth, GLForm.ClientHeight);
    EndingScene.Render;
  end;

  if Game.State = gsAbout then
  begin
    glViewPort(0, 0, GLForm.ClientWidth, GLForm.ClientHeight);
    About.Render;
  end;

  if Game.State = gsInGame then
  begin
    ColorPicking;
    if Stage.CurrentChapter.RealityFade > 0 then
      DeathScene.UpdateFBO;
    RenderToTexture(FBO);
    RenderToTexture(FBOEffects);
    RenderToTexture(FBOText);
    glColor3f(1, 1, 1);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity;
    glViewPort(0, 0, GLForm.ClientWidth, GLForm.ClientHeight);
    glOrtho(0, 1, 1, 0, -256, 256);

    glClearColor(0, 0, 0, 0);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity;
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
    glDisable(GL_CULL_FACE);
    glDisable(GL_BLEND);
    glDisable(GL_LIGHTING);

    // Base scene
    FBO.Bind;
    if Noise then
      with ShaderManager.Shader['filmgrain'] do
      begin
        Bind;
        SetUniformf('m_Time', [Trunc(DegTimer / 10) + 1]);
        SetUniformf('uShift', [1, 0, 0.4, 1]);
        SetUniformf('m_Strength', [1 + (Player.StressLevel - 1)]);
        if GetCurrentDecision.Visual = visDoors then
          SetUniformf('m_Strength', [1 + (Player.StressLevel - 1)]);
        SetUniformi('m_Texture', [0]);
        SetUniformf('alpha', [1]);
        SetUniformi('blur', [0]);
        SetUniformi('alphamodulatesgrain', [0]);
      end;
    glBegin(GL_QUADS);
    glTexCoord2f(0, 0);
    glVertex3f(0, 0, 0);
    glTexCoord2f(0, 1);
    glVertex3f(0, 1, 0);
    glTexCoord2f(1, 1);
    glVertex3f(1, 1, 0);
    glTexCoord2f(1, 0);
    glVertex3f(1, 0, 0);
    glEnd;

    // Effects
    FBOEffects.Bind;
    TextureManager.SetBlending(bmAdd);
    if Noise then
      with ShaderManager.Shader['filmgrain'] do
      begin
        Bind;
        SetUniformf('m_Time', [Trunc(DegTimer / 10) + 1]);
        SetUniformf('color', [1, 1, 1, 1]);
        SetUniformf('m_Strength', [4 + (Player.StressLevel - 1)]);
        //              SetUniformf('m_Strength', [1 + (Player.StressLevel - 1)]);
        SetUniformi('m_Texture', [0]);
        SetUniformi('blur', [0]);
        SetUniformf('alpha', [1]);
        SetUniformi('alphamodulatesgrain', [0]);
        if GetCurrentDecision.Visual = visDoors then
          SetUniformi('alphamodulatesgrain', [1]);
      end;
    glColor3f(0.8, 0.8, 0.8);
    glBegin(GL_QUADS);
    glTexCoord2f(0, 0);
    glVertex3f(0, 0, 1);
    glTexCoord2f(0, 1);
    glVertex3f(0, 1, 1);
    glTexCoord2f(1, 1);
    glVertex3f(1, 1, 1);
    glTexCoord2f(1, 0);
    glVertex3f(1, 0, 1);
    glEnd;

    // Text
    FBOText.Bind;
    TextureManager.SetBlending(bmAdd);
    if Stage.CurrentChapter.BlurStrength > 0 then
      with ShaderManager.Shader['blur'] do
      begin
        Bind;
        SetUniformi('uTexture', [0]);
        SetUniformf('blurShift', [0.00025 * Stage.CurrentChapter.BlurStrength * Sin(DegToRad(DegTimer)), 0.00025 * Stage.CurrentChapter.BlurStrength * Cos(DegToRad(DegTimer))]);
      end;
    glBegin(GL_QUADS);
    glTexCoord2f(0, 0);
    glVertex3f(0, 0, 2);
    glTexCoord2f(0, 1);
    glVertex3f(0, 1, 2);
    glTexCoord2f(1, 1);
    glVertex3f(1, 1, 2);
    glTexCoord2f(1, 0);
    glVertex3f(1, 0, 2);
    glEnd;
    ShaderManager.DisableShader;

    RenderOverlays;

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity;
    glViewPort(0, 0, GLForm.ClientWidth, GLForm.ClientHeight);
    glOrtho(0, 1, 1, 0, -256, 256);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity;

    // Realityfade (for dying condition)
    if Stage.CurrentChapter.RealityFade > 0 then
    begin
      with ShaderManager.Shader['filmgrain'] do
      begin
        Bind;
        SetUniformf('m_Time', [Trunc(DegTimer / 10) + 1]);
        SetUniformf('color', [1, 1, 1, Stage.CurrentChapter.RealityFade]);
        SetUniformf('m_Strength', [8]);
        SetUniformi('m_Texture', [0]);
        SetUniformf('alpha', [Stage.CurrentChapter.RealityFade]);
        SetUniformi('blur', [0]);
        SetUniformf('blurShift', [0.00025 * Stage.CurrentChapter.BlurStrength * Sin(DegToRad(DegTimer)), 0.00025 * Stage.CurrentChapter.BlurStrength * Cos(DegToRad(DegTimer))]);
        SetUniformi('alphamodulatesgrain', [0]);
      end;

      DeathScene.FBO.Bind;
      TextureManager.SetBlending(bmBlend);
      glColor4f(1, 1, 1, Stage.CurrentChapter.RealityFade);
      glBegin(GL_QUADS);
      glTexCoord2f(0, 1);
      glVertex3f(0, 0, 3);
      glTexCoord2f(0, 0);
      glVertex3f(0, 1, 3);
      glTexCoord2f(1, 0);
      glVertex3f(1, 1, 3);
      glTexCoord2f(1, 1);
      glVertex3f(1, 0, 3);
      glEnd;

      ShaderManager.DisableShader;
    end;
  end;

  if Game.State = gsMainMenu then
  begin
    ColorPicking;
    RenderToTexture(FBO);
    RenderToTexture(FBOEffects);
    RenderToTexture(FBOText);
    glColor3f(1, 1, 1);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity;
    glViewPort(0, 0, GLForm.ClientWidth, GLForm.ClientHeight);
    glOrtho(0, 1, 1, 0, -256, 256);

    glClearColor(0, 0, 0, 0);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity;
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
    glDisable(GL_CULL_FACE);
    glDisable(GL_BLEND);
    glDisable(GL_LIGHTING);

    // Base scene
    FBO.Bind;
    if Noise then
      with ShaderManager.Shader['filmgrain'] do
      begin
        Bind;
        SetUniformf('m_Time', [Trunc(DegTimer / 10) + 1]);
        SetUniformf('uShift', [1, 0, 0.4, 1]);
        SetUniformf('m_Strength', [4]);
        SetUniformi('m_Texture', [0]);
        SetUniformf('alpha', [1]);
        SetUniformi('blur', [0]);
        SetUniformi('alphamodulatesgrain', [0]);
      end;
    glBegin(GL_QUADS);
    glTexCoord2f(0, 0);
    glVertex3f(0, 0, 0);
    glTexCoord2f(0, 1);
    glVertex3f(0, 1, 0);
    glTexCoord2f(1, 1);
    glVertex3f(1, 1, 0);
    glTexCoord2f(1, 0);
    glVertex3f(1, 0, 0);
    glEnd;

    // Effects
    FBOEffects.Bind;
    TextureManager.SetBlending(bmAdd);
    if Noise then
      with ShaderManager.Shader['filmgrain'] do
      begin
        Bind;
        SetUniformf('m_Time', [Trunc(DegTimer / 10) + 1]);
        SetUniformf('color', [1, 1, 1, 1]);
        SetUniformf('m_Strength', [4]);
        SetUniformi('m_Texture', [0]);
        SetUniformi('blur', [0]);
        SetUniformf('alpha', [1]);
        SetUniformi('alphamodulatesgrain', [0]);
      end;
    glColor3f(0.8, 0.8, 0.8);
    glBegin(GL_QUADS);
    glTexCoord2f(0, 0);
    glVertex3f(0, 0, 1);
    glTexCoord2f(0, 1);
    glVertex3f(0, 1, 1);
    glTexCoord2f(1, 1);
    glVertex3f(1, 1, 1);
    glTexCoord2f(1, 0);
    glVertex3f(1, 0, 1);
    glEnd;

    // Text
    FBOText.Bind;
    TextureManager.SetBlending(bmAdd);
    //      if Stage.BlurStrength > 0 then
    //        with ShaderManager.Shader['blur'] do // TODO : maybe blur-only shader without grain?
    //          begin
    //            Bind;
    //            SetUniformi('uTexture', [0]);
    //            SetUniformf('blurShift', [0.00025*Stage.BlurStrength*Sin(DegToRad(DegTimer)), 0.00025*Stage.BlurStrength*Cos(DegToRad(DegTimer))]);
    //          end;
    glBegin(GL_QUADS);
    glTexCoord2f(0, 0);
    glVertex3f(0, 0, 2);
    glTexCoord2f(0, 1);
    glVertex3f(0, 1, 2);
    glTexCoord2f(1, 1);
    glVertex3f(1, 1, 2);
    glTexCoord2f(1, 0);
    glVertex3f(1, 0, 2);
    glEnd;
    ShaderManager.DisableShader;

    RenderOverlays;
  end;

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, GLForm.ClientWidth, GLForm.ClientHeight);
  glOrtho(0, OrthoSize.x, OrthoSize.y, 0, -128, 128);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  glDepthFunc(GL_ALWAYS);

  // Screenfade
  Game.RenderFade;

  // Chapter title
  // Not yet, doesn't look that good
  //  if Game.State = gsInGame then
  //    with Stage.CurrentChapter do
  //      if TitleTimer > 0 then
  //        begin
  //          glColor3f(1, 1, 1);
  //          Font.Print2D(Name + ' : ' + Title + ' - "' + TagLine + '"', [OrthoSize.x / 2, 50, 0], FontAlignCenter, 3, 0.75 * TitleTimer, True);
  //          glColor3f(1, 1, 1);
  //        end;

  // Cursor
  TextureManager.SetBlending(bmBlend);
  TextureManager.BindTexture('cursor_hand');
  glPushMatrix;
  glTranslatef(MousePos.x * (OrthoSize.x / GLForm.ClientWidth), MousePos.y * (OrthoSize.y / GLForm.ClientHeight) + CursorDim / 2, 0);
  glRotatef(Player.Rotation.y * 10, 0, 0, 1);
  TextureManager.DrawQuad(0, 0, 0, CursorDim, CursorDim, 'cursor_hand', flCenter, True);
  glPopMatrix;
  glDepthFunc(GL_LESS);

  SwapBuffers(DC);

  GLError := glGetError;
  //  if GLError <> GL_NO_ERROR then
  //    GLForm.Caption := glGetErrorStr(GLError);
end;


 // =====================================================================================================================
 //  TRenderer.UpdateTimers
 // =====================================================================================================================
procedure TRenderer.UpdateTimers;
begin
  // Degree timer (used for misc things, maybe rename)
  DegTimer := DegTimer + TimeFactor * 10;
  if DegTimer > 360 then
    DegTimer := DegTimer - 360;

  // 0..1 timer
  Timer := Timer + TimeFactor * 0.25;
  if Timer > 360 then
    Timer := Timer - 360;

  // Sway timer (used to sway cemera angle depending on stress and time level?)
  SwayTimer := SwayTimer + TimeFactor * 5;
  if SwayTimer > 360 then
    SwayTimer := SwayTimer - 360;

  // Maybe add heart beat timer that makes effects stronger with higher heartbeat
end;


 // =====================================================================================================================
 // TGLForm
 // =====================================================================================================================


 // =====================================================================================================================
 // TGLForm.GameLoop
 // =====================================================================================================================
procedure TGLForm.GameLoop;
var
  QPCs, QPCe: int64;
begin
  Quit := False;
  repeat
    QueryPerformanceCounter(QPCs);
    Renderer.Render;
    Application.ProcessMessages;
    QueryPerformanceCounter(QPCe);
    TimeFactor := (QPCe - QPCs) / QPCf * 10;
    Renderer.UpdateTimers;
    Player.Update;
    Stage.Update;
    if Game.State = gsEnding then
      EndingScene.Update;
    MusicPlayer.Update(TimeFactor);
  until Quit;
  Close;
end;


 // =====================================================================================================================
 // TGLForm.GoToFullScreen
 // =====================================================================================================================
procedure TGLForm.GoToFullScreen(pWidth, pHeight, pBPP, pFrequency: word);
var
  dmScreenSettings: DevMode;
begin
  WindowState := wsMaximized;
  BorderStyle := bsNone;
  ZeroMemory(@dmScreenSettings, SizeOf(dmScreenSettings));
  with dmScreenSettings do
  begin
    dmSize       := SizeOf(dmScreenSettings);
    dmPelsWidth  := pWidth;
    dmPelsHeight := pHeight;
    dmBitsPerPel := pBPP;
    dmDisplayFrequency := pFrequency;
    dmFields     := DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL or DM_DISPLAYFREQUENCY;
  end;
  if (ChangeDisplaySettings(dmScreenSettings, CDS_FULLSCREEN) = DISP_CHANGE_FAILED) then
  begin
    MessageBox(0, 'Could not activate desired display mode!', 'Error', MB_OK or MB_ICONERROR);
    Exit;
  end;
end;


 // =====================================================================================================================
 // TGLForm.TimerStartGameLoopTimer
 // =====================================================================================================================
procedure TGLForm.TimerStartGameTimer(Sender: TObject);
begin
  TimerStartGame.Enabled := False;

  try
    Randomize;

    Game := TGame.Create;

    Game.LogMessage('Starting virtual file system');
    VFS := TVirtualFileSystem.Create;
    if FileExists(ExtractFilePath(Application.ExeName) + '\trugbild.dat') then
      VFS.LoadFromFile(ExtractFilePath(Application.ExeName) + '\trugbild.dat')
    else
      Game.LogMessage('No data file found, VFS will access physical files on disc...');

    Renderer     := TRenderer.Create;
    Stage        := TStage.Create;
    Player       := TPlayer.Create;
    MainMenu     := TMainMenu.Create;
    RealityScene := TRealityScene.Create;
    DeathScene   := TDeathScene.Create;
    EndingScene  := TEndingScene.Create(Renderer.FBO, Renderer.FBOEffects);
    About        := TAbout.Create(Renderer.FBO, Renderer.FBOEffects);
    Game.OnGameStateChange := Stage.StateChange;

    Game.LogMessage('Initializing sound system');
    SoundSystem := TSoundSystem.Create(self, Handle, False);
    MusicPlayer := TMusicPlayer.Create;
    Game.LogMessage('Getting track list');
    MusicPlayer.GetTrackList('data\music');
    MusicPlayer.PlayTrack('data\music\delirium.ogg', True);
    SoundSystem.SFXEnabled := True;
    SoundSystem.SFXVolume  := 100;
    SoundSystem.AddSamplesInDir('data\sounds\', '.ogg');
    Game.LogMessage('Soundsystem created');

    Cursor := crNone;

    Stage.LoadFromFile('data\stages\pgdchallenge2013.xml');

    Game.FadePos   := 1;
    Game.FadeDir   := -1;
    Game.FadeSpeed := FadeSpeed;

    QueryPerformanceFrequency(QPCf);
  except
    on E: Exception do
    begin
      Game.LogMessage('Could not create all game objects!' + E.ToString + ' : ' + E.Message);
      MessageDlg('Could not create all game objects!' + #13 + E.ToString + ' : ' + E.Message, mtError, [mbOK], 0);
      Application.Terminate;
    end;
  end;


  GameLoop;
end;


 // =====================================================================================================================
 // TGLForm.FormClick
 // =====================================================================================================================
procedure TGLForm.FormClick(Sender: TObject);
begin
  if Game.State in [gsMainMenu, gsInGame] then
    if GetCurrentDecision.Selection > -1 then
      if Game.State = gsMainMenu then
        MainMenu.Select
      else
        Stage.SelectAnswer;
  if Game.State = gsEnding then
    EndingScene.Click;
  if Game.State = gsAbout then
    About.Click;
end;


 // =====================================================================================================================
 // TGLForm.FormCloseQuery
 // =====================================================================================================================
procedure TGLForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  Quit := True;
end;


 // =====================================================================================================================
 //  TGLForm.CreateVFS
 // =====================================================================================================================
procedure GetDirectories(var pDirectoryList: TStringDynArray; pRootDirectory: string);
var
  SR: TSearchRec;
begin
  pRootDirectory := IncludeTrailingPathDelimiter(pRootDirectory);
  if Findfirst(pRootDirectory + '*.*', faAnyFile, SR) = 0 then
    repeat
      if SR.Attr and faDirectory = faDirectory then
        if (SR.Name <> '.') and (SR.Name <> '..') and (SR.Name <> '__history') and (SR.Name <> '_notneeded') then
        begin
          SetLength(pDirectoryList, Length(pDirectoryList) + 1);
          pDirectoryList[High(pDirectoryList)] := pRootDirectory + SR.Name;
          GetDirectories(pDirectoryList, pRootDirectory + SR.Name);
        end;
    until FindNext(SR) <> 0;
  FindClose(SR);
end;

procedure TGLForm.CreateVFS;
var
  TmpVFS: TVirtualFileSystem;
  VFile: TVirtualFile;
  BaseDir: string;
  SR: TSearchRec;
  DirList: TStringDynArray;
  TmpS: string;
begin
  ChDir(ExtractFilePath(Application.ExeName));
  SetLength(DirList, 1);
  DirList[0] := GetCurrentDir + '\data';
  GetDirectories(DirList, GetCurrentDir + '\data\');

  TmpVFS  := TVirtualFileSystem.Create;
  ChDir(ExtractFilePath(Application.ExeName));
  BaseDir := GetCurrentDir + '\';
  if Length(DirList) > 0 then
    for TmpS in DirList do
      TmpVFS.AddFilesInDirectory(BaseDir, TmpS + '\', '*.*');

  ChDir(ExtractFilePath(Application.ExeName));

  TmpVFS.Compile(ExtractFilePath(Application.ExeName) + '\trugbild.dat');

  TmpVFS.Free;
end;


 // =====================================================================================================================
 //  TGLForm.FormCreate
 // =====================================================================================================================
procedure TGLForm.FormCreate(Sender: TObject);
var
  i: integer;
begin
  if DebugHook = 1 then
    if ParamStr(1) = '-createvfs' then
    begin
      CreateVFS;
      ShowMessage('VFS file generated. Exiting...');
      Application.Terminate;
    end;

  Windowed  := False;
  DebugKeys := False;
  for i := 1 to ParamCount do
  begin
    if ParamStr(i) = '-window' then
      Windowed  := True;
    if ParamStr(i) = '-debugkeys' then
      DebugKeys := True;
  end;
end;

 // =====================================================================================================================
 //  TGLForm.FormDestroy
 // =====================================================================================================================
procedure TGLForm.FormDestroy(Sender: TObject);
begin
  if Assigned(SoundSystem) then
    SoundSystem.Free;
  if Assigned(MusicPlayer) then
    MusicPlayer.Free;
  if Assigned(Player) then
    Player.Free;
  if Assigned(Renderer) then
    Renderer.Free;
  if Assigned(RealityScene) then
    RealityScene.Free;
  if Assigned(DeathScene) then
    DeathScene.Free;
  if Assigned(EndingScene) then
    EndingScene.Free;
  if Assigned(About) then
    About.Free;
  if Assigned(Game) then
    Game.Free;
  if Assigned(VFS) then
    VFS.Free;
end;


 // =====================================================================================================================
 //  TGLForm.FormDestroy
 // =====================================================================================================================
procedure TGLForm.FormKeyPress(Sender: TObject; var Key: char);
var
  TmpStr: string;
  i: integer;
begin
  case Key of
    #27: if Game.State <> gsMainMenu then
        Game.ChangeState(gsMainMenu);
  end;

  if DebugKeys then
    case Key of
      #32: if Game.State = gsReality then
          Game.ChangeState(gsInGame);
      'i': Game.State     := gsInGame;
      't': Stage.CurrentChapter.TitleTimer := 1;
      'p': glSaveScreen(FormatDateTime('hh-nn-ss-zzz', Now) + '.jpg');
      'x': Renderer.Debug := not Renderer.Debug;
      's': Renderer.Sway  := not Renderer.Sway;

      'l': if GetCurrentDecision <> nil then
          GetCurrentDecision.Visual := visLadders;
      'h': if GetCurrentDecision <> nil then
          GetCurrentDecision.Visual := visHoles;
      'd': if GetCurrentDecision <> nil then
          GetCurrentDecision.Visual := visDoors;
      //      'c' : GetCurrentDecision.Visual := visCorridors;

      'c':
      begin
        Game.State := gsReality;
        TmpStr     := InputBox('Chapter', 'Number', '');

        if TryStrToInt(TmpStr, i) then
        begin
          Stage.CurrChapter := i;
          Game.LogMessage(Format('Starting chapter %d ("%s")', [i, Stage.CurrentChapter.Name]));
          Stage.CurrentChapter.Reset;
          RealityScene.LoadFromXML(Stage.XMLDoc.DocumentElement.ChildNodes[i].ChildNodes['realityscene']);
        end;

        if TmpStr = 'f' then
          RealityScene.LoadFromXML(Stage.XMLDoc.DocumentElement.ChildNodes['finalscene']);
      end;

      'o': DebugOverlay := not DebugOverlay;

      //      'n' : Renderer.Noise := not Renderer.Noise;
      //      'b' : Renderer.Blur := not Renderer.Blur;
      'm': Game.ChangeState(gsMainMenu);
      'n': if not Stage.CurrentChapter.NextDecision then
          Stage.NextChapter;
      'f': if WindowState = wsNormal then
        begin
          BorderStyle := bsNone;
          WindowState := wsMaximized;
        end
        else
        begin
          BorderStyle := bsSizeable;
          WindowState := wsNormal;
        end;
      'r': RealityScene.Reset;
      //    'r' : case Game.State of
      //            gsIngame : Game.State := gsReality;
      //            gsReality : Game.State := gsInGame;
      //          end;
      'b':
      begin
        if Player.DecisionHistory.Count = 0 then
        begin
          Player.DecisionHistory.Add('Debug ending...');
          Player.AnswerHistory.Add('bad');
          Player.DecisionHistory.Add('Ending line 2...');
          Player.AnswerHistory.Add('worse');
        end;
        Player.Bias := -Random(100);
        Game.Ending := geBad;
        Game.ChangeState(gsEnding);
      end;
      'g':
      begin
        if Player.DecisionHistory.Count = 0 then
        begin
          Player.DecisionHistory.Add('Debug ending...');
          Player.AnswerHistory.Add('good');
          Player.DecisionHistory.Add('Ending line 2...');
          Player.AnswerHistory.Add('better');
        end;
        Player.Bias := Random(100);
        Game.Ending := geGood;
        Game.ChangeState(gsEnding);
      end;
    end;
end;


 // =====================================================================================================================
 //  TGLForm.FormMouseMove
 // =====================================================================================================================
procedure TGLForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
begin
  if Assigned(Player) then
  begin
    Player.Rotation.y := (Width div 2 - x) * -0.0075;
    if Player.Rotation.y < -5 then
      Player.Rotation.y := -5;
    if Player.Rotation.y > 5 then
      Player.Rotation.y := 5;
    MousePos := Point(x, y);
  end;
end;


 // =====================================================================================================================
 //  TGLForm.FormResize
 // =====================================================================================================================
procedure TGLForm.FormResize(Sender: TObject);
begin
  OrthoSize   := Point(Round(720 * (GLForm.ClientWidth / GLForm.ClientHeight)), 720);
  AspectRatio := ClientWidth / ClientHeight;
end;


 // =============================================================================
 //  TForm1.FormKeyPress
 // =============================================================================
procedure TGLForm.FormShow(Sender: TObject);
begin
  if not Windowed then
  begin
    BorderStyle := bsNone;
    WindowState := wsMaximized;
  end;
  TimerStartGame.Enabled := True;
end;


 // =====================================================================================================================
 //  TStage
 // =====================================================================================================================


 // =====================================================================================================================
 //  TStage.Create
 // =====================================================================================================================
constructor TStage.Create;
begin
  Reset;
end;


 // =====================================================================================================================
 //  TStage.Reset
 // =====================================================================================================================
procedure TStage.Reset;
var
  i: integer;
begin
  if Assigned(Player) then
    Player.Reset;
  CurrChapter := 0;
  SpeedFactor := 1;
  for i := 0 to High(Chapters) do
    Chapters[i].Reset;
  if Assigned(XMLDoc) then
    RealityScene.LoadFromXML(XMLDoc.DocumentElement.ChildNodes[CurrChapter].ChildNodes['realityscene']);
end;


 // =====================================================================================================================
 //  TStage.LoadFromFile
 // =====================================================================================================================
procedure TStage.LoadFromFile(const AFileName: string);
var
  RootNode: IXMLNode;
  i: integer;
begin
  Game.LogMessage('Loading stage from "' + AFileName + '"');

  if not Assigned(XMLDoc) then
    XMLDoc := TXMLDocument.Create(nil);

  VFS.LoadXML(AFileName, XMLDoc);
  XMLDoc.Active := True;
  RootNode      := XMLDoc.DocumentElement;

  CurrChapter := 0;

  for i := 0 to High(Chapters) do
    Chapters[i].Free;
  SetLength(Chapters, 0);

  for i := 0 to RootNode.ChildNodes.Count - 1 do
    if SameText(RootNode.ChildNodes[i].NodeName, 'chapter') then
    begin
      SetLength(Chapters, Length(Chapters) + 1);
      Chapters[High(Chapters)] := TChapter.Create(RootNode.ChildNodes[i]);
    end;

  RealityScene.LoadFromXML(RootNode.ChildNodes[CurrChapter].ChildNodes['realityscene']);
end;


 // =====================================================================================================================
 //  TStage.CurrentChapter
 // =====================================================================================================================
function TStage.CurrentChapter: TChapter;
begin
  Result := Chapters[CurrChapter];
end;


 // =====================================================================================================================
 //  TStage.Destroy
 // =====================================================================================================================
destructor TStage.Destroy;
begin
  XMLDoc := nil;
end;


 // =====================================================================================================================
 //  TStage.NextChapter
 // =====================================================================================================================
 //  Select the next chapter. Returns FALSE if the current chapter is the last one
 // =====================================================================================================================
function TStage.NextChapter: Boolean;
begin
  Result := True;
  if CurrChapter < High(Chapters) then
  begin
    Inc(CurrChapter);
    Game.LogMessage(Format('Starting chapter %d ("%s")', [CurrChapter, CurrentChapter.Name]));
    CurrentChapter.Reset;
    RealityScene.LoadFromXML(XMLDoc.DocumentElement.ChildNodes[CurrChapter].ChildNodes['realityscene']);
  end
  else
  begin
    Result := False;
    // Load final ("happy ending") reality scene
    Game.LogMessage('Loading final reality scene');
    RealityScene.LoadFromXML(XMLDoc.DocumentElement.ChildNodes['finalscene']);
  end;
  // Fade to reality scene
  Game.FadePos   := 1;
  Game.FadeDir   := -1;
  Game.FadeSpeed := FadeSpeed;
  Game.State     := gsReality;
end;


 // =====================================================================================================================
 //  TStage.Render
 // =====================================================================================================================
procedure TStage.Render(AFBO: TFrameBufferObject; AForColorPicking: Boolean);
begin
  // Render depending on current visual type
  case GetCurrentDecision.Visual of
    visCorridors: RenderCorridors(AFBO, AForColorPicking);
    visHoles: RenderHoles(AFBO, AForColorPicking);
    visDoors: RenderDoors(AFBO, AForColorPicking);
    visLadders: RenderLadders(AFBO, AForColorPicking);
  end;

  if AFBO = Renderer.FBOText then
  begin
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity;
    glViewPort(0, 0, AFBO.Width, AFBO.Height);
    glOrtho(0, OrthoSize.x, 0, OrthoSize.y, -128, 128); // TODO : Adjust to screen ratio?

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity;
    glClear(GL_DEPTH_BUFFER_BIT);

    GetCurrentDecision.Render;
  end;
end;


 // =====================================================================================================================
 //  TStage.Update
 // =====================================================================================================================
procedure TStage.Update;
const
  FadeStart = 10;
begin
  // Speed factor increases with number of answers (TODO : balancing)
  SpeedFactor := Clamp(1 + Player.AnswerHistory.Count * 0.05, 1, 3.5);

  // Move player towards target
  if (Player.MoveDir.x <> 0) or (Player.MoveDir.y <> 0) or (Player.MoveDir.z <> 0) then
  begin
    Player.StressLevel := 1;
    Player.Position    := glAddVector(Player.Position, glScaleVector(Player.MoveDir, TimeFactor * 0.75));

    // Fade to black while reaching selected decision
    if Player.Position.z > 0 then
      Game.FadePos := 1 - ((FadeStart - Player.Position.z) / FadeStart);

    if Player.Position.z > FadeStart then
    begin
      Player.MoveDir := ZeroVector3f;
      if Game.State = gsInGame then
      begin
        Game.FadeDir   := -1;
        Game.FadeSpeed := 0.05;
      end;
      if Game.State = gsMainMenu then
      begin
        Player.Position := glVertex(0, 1, -22);
        if SameText(MainMenu.Decision.Answers[MainMenu.Selected].Text, 'Start') then
        begin
          // TODO : Create function to reset and start a new game...
          Stage.Reset;
          RealityScene.Reset;
          Game.State   := gsReality;
          Game.FadeDir := -1;
        end;

        if SameText(MainMenu.Decision.Answers[MainMenu.Selected].Text, 'Leave') then
          GLForm.Close;

        if SameText(MainMenu.Decision.Answers[MainMenu.Selected].Text, 'About') then
        begin
          Game.State   := gsAbout;
          Game.FadeDir := -1;
        end;
      end
      else if not Stage.CurrentChapter.NextDecision then
        Stage.NextChapter;
    end;
  end;

  BlurTimer := Wrap(BlurTimer + TimeFactor * (2 + 2 * Random), 360);

  if Game.State <> gsInGame then
    Exit;

  CurrentChapter.Update;
end;


 // =====================================================================================================================
 //  TStage.RenderCorridors
 // =====================================================================================================================
procedure TStage.RenderCorridors(AFBO: TFrameBufferObject; AForColorPicking: Boolean);
var
  i: integer;
  Center, PosOffset, DepthOffset, RotOffset, AnswerOffset: single;
begin
  glDisable(GL_BLEND);
  glDisable(GL_ALPHA_TEST);
  glDisable(GL_LIGHTING);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, AFBO.Width, AFBO.Height);
  if Renderer.Sway then
    gluPerspective(110 + (2 * Sin(DegToRad(DegTimer)) * Player.StressLevel), AFBO.Width / AFBO.Height, 1, 256) // Hint : Stronger delta makes for a hefty effect
  else
    gluPerspective(110, AFBO.Width / AFBO.Height, 1, 256);

  // Hint : Use FOV 60 for moving through a single corridor?

  if (AFBO = Renderer.FBOEffects) or (AFBO = Renderer.FBOText) then
    glClearColor(0, 0, 0, 1)
  else if AForColorPicking then
    glClearColor(0, 0, 0, 1)
  else
    glClearColor(0.2, 0.2, 0.2, 1);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);

  glColor3f(1, 1, 1);
  glDisable(GL_TEXTURE_2D);
  glRotatef(Player.Rotation.y, 0, 1, 0);
  glTranslatef(Player.Position.x, Player.Position.y, Player.Position.z);

  if Renderer.Sway then
  begin
    glRotatef(Sin(DegToRad(Renderer.SwayTimer)) * 2.5 * Player.StressLevel, 1, 0, 0);
    glRotatef(Cos(DegToRad(Renderer.SwayTimer)) * 2.5 * Player.StressLevel, 0, 1, 0);
    glRotatef(Sin(DegToRad(Renderer.SwayTimer)) * 2.5 * Player.StressLevel, 0, 0, 1);
  end;

  //  // Shake TODO : Sick effect, looks insane but could be too much
  //  glTranslatef(Random*2-Random*2, Random*2-Random*2, Random*2-Random*2);

  // Number of corridors (or other display types) depending on answers of current decision
  //  Note : Only certain configurations avaible (no need to make it dynamic?)

  // 1 answer
  PosOffset    := 0;
  DepthOffset  := 0;
  AnswerOffset := 0;
  Center       := 0;
  RotOffset    := 0;

  // 2 answers
  if Length(GetCurrentDecision.Answers) = 2 then
  begin
    PosOffset    := 20;
    DepthOffset  := 50;
    RotOffset    := 0.5;
    AnswerOffset := 75;
    Center       := 0.5;
  end;

  // 3 answers
  if Length(GetCurrentDecision.Answers) = 3 then
  begin
    PosOffset    := 20;
    DepthOffset  := 50;
    RotOffset    := 0.5;
    AnswerOffset := 75;
    Center       := 1;
  end;

  if AFBO <> Renderer.FBOText then
    for i := 0 to High(GetCurrentDecision.Answers) do
    begin
      // For effect FBO : Skip if not hovering or selected
      if (AFBO = Renderer.FBOEffects) then
      begin
        if Game.State = gsInGame then
        begin
          if Stage.CurrentChapter.Selected > -1 then
            if i <> Stage.CurrentChapter.Selected then
              continue;
          if Stage.CurrentChapter.Selected = -1 then
            if i <> GetCurrentDecision.Selection then
              continue;
        end;
        if Game.State = gsMainMenu then
        begin
          if MainMenu.Selected > -1 then
            if i <> MainMenu.Selected then
              continue;
          if MainMenu.Selected = -1 then
            if i <> GetCurrentDecision.Selection then
              continue;
        end;
      end;
      // Render Corridor
      glPushMatrix;
      if AForColorPicking then
        glColor3ub(ColSelStep + i * ColSelStep, 0, 0);
      glTranslatef((i - Center) * PosOffset, 0, 0);
      GetCurrentDecision.Answers[i].RenderCorridor(AFBO = Renderer.FBOEffects, 12, (i - Center) * DepthOffset - (Player.Rotation.y * (i - Center) * RotOffset), AForColorPicking);
      GetCurrentDecision.OffsetX := (i - Center) * DepthOffset;
      if Length(GetCurrentDecision.Answers) = 2 then
        GetCurrentDecision.OffsetX := (i - Center) * DepthOffset / 12;
      if Length(GetCurrentDecision.Answers) = 3 then
        GetCurrentDecision.OffsetX := (i - Center) * DepthOffset / 13.25;
      glPopMatrix;
    end;

  // Answers
  if (not AForColorPicking) then
  begin
    glColor3f(1, 1, 1);
    glDisable(GL_BLEND);
    for i := 0 to High(GetCurrentDecision.Answers) do
    begin
      // For effect FBO : skip if not selected
      if (AFBO = Renderer.FBOEffects) and (GetCurrentDecision.Selection <> i) then
        continue;
      if (AFBO = Renderer.FBO) and (GetCurrentDecision.Selection <> i) then
        continue;
      // Render answer text
      glPushMatrix;
      glTranslatef((i - Center) * AnswerOffset, 0, -15);
      GetCurrentDecision.RenderAnswer(i);
      glPopMatrix;
    end;
  end;
end;


 // =====================================================================================================================
 //  TStage.RenderAsDoors
 // =====================================================================================================================
procedure TStage.RenderDoors(AFBO: TFrameBufferObject; AForColorPicking: Boolean);

  procedure DoorScale;
  begin
    glScalef(1 + (Player.Position.z - Player.PosDef.z) * 0.05, 1 + (Player.Position.z - Player.PosDef.z) * 0.05, 1 + (Player.Position.z - Player.PosDef.z) * 0.05);
  end;

const
  DimX    = 525;
  DimY    = 450;
  OffsetX = 525;
  OffsetY = 85;
var
  i: integer;
  Center, PosOffset: single;
  HoleSize: single;
  h: single;
begin
  glDisable(GL_BLEND);
  glDisable(GL_ALPHA_TEST);
  glDisable(GL_LIGHTING);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, AFBO.Width, AFBO.Height);
  glOrtho(0, AFBO.Width, AFBO.Height, 0, -256, 256);

  glClearColor(0, 0, 0, 0);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);

  if AFBO = Renderer.FBO then
  begin
    // Star backdrop
    TextureManager.SetBlending(bmNone);
    glColor3f(1, 1, 1);
    with ShaderManager.Shader['stars'] do
    begin
      Bind;
      SetUniformf('time', [Timer]);
      SetUniformf('resolution', [AFBO.Width, AFBO.Width]);
    end;
    TextureManager.DrawBlankQuad(0, 0, 0, AFBO.Width, AFBO.Height);
    ShaderManager.DisableShader;

    // Dark gray background
    TextureManager.DisableTextureStage(GL_TEXTURe0);
    TextureManager.SetBlending(bmBlend);
    glBegin(GL_QUADS);
    glColor4f(0.1, 0.1, 0.1, 1);
    glVertex3f(0, 0, 1);
    glColor4f(0.1, 0.1, 0.1, 1);
    glVertex3f(AFBO.Width, 0, 1);
    glColor4f(0.1, 0.1, 0.1, 0);
    glVertex3f(AFBO.Width, AFBO.Height * 0.65, 1);
    glColor4f(0.1, 0.1, 0.1, 0);
    glVertex3f(0, AFBO.Height * 0.65, 1);
    glEnd;
    glColor3f(1, 1, 1);
  end;


  glColor3f(1, 1, 1);
  glDisable(GL_TEXTURE_2D);
  glRotatef(Player.Rotation.y, 0, 1, 0);
  glTranslatef(Player.Position.x * -10, Player.Position.y, 0);

  PosOffset := 0;
  Center    := 0;

  if Length(GetCurrentDecision.Answers) = 2 then
  begin
    PosOffset := 20;
    Center    := 0.5;
  end;

  if Length(GetCurrentDecision.Answers) = 3 then
  begin
    PosOffset := 20;
    Center    := 1;
  end;


  // Calculate movement offsets
  if GetCurrentDecision.Selection > -1 then
  begin
    if Length(GetCurrentDecision.Answers) = 2 then
      GetCurrentDecision.OffsetX := (GetCurrentDecision.Selection - Center) * 1.5;
    if Length(GetCurrentDecision.Answers) = 3 then
      GetCurrentDecision.OffsetX := (GetCurrentDecision.Selection - Center) * 2;
  end;

  glDepthFunc(GL_ALWAYS);
  glDepthMask(False);
  glColor3f(1, 1, 1);
  TextureManager.SetBlending(bmBlend);

  if AForColorPicking then
    ShaderManager.Shader['color'].Bind
  else
    with ShaderManager.Shader['grayscale'] do
    begin
      Bind;
      SetUniformi('utexture', [0]);
    end;
  if (AFBO <> Renderer.FBOText) and (AFBO <> Renderer.FBOEffects) then
    for i := 0 to High(GetCurrentDecision.Answers) do
    begin
      // For effect FBO : skip if not selected
      if (AFBO = Renderer.FBOEffects) and (GetCurrentDecision.Selection <> i) then
        continue;
      if AForColorPicking then
        glColor3ub(ColSelStep + i * ColSelStep, 0, 0);
      // Render door
      glPushMatrix;

      glTranslatef(AFBO.Width / 2 - ((i - Center) * OffsetX), AFBO.Height / 2 - Abs(i - Center) * OffsetY + Sin(DegToRad(GetCurrentDecision.Answers[i].SwayTimer)) * 15, 0);

      if (not AForColorPicking) and ((i = GetCurrentDecision.Selection) or (i = CurrentChapter.Selected)) then
        DoorScale;

      TextureManager.DrawQuad(0, 0, 0, DimX, DimY, 'doorborder', (flCenter));

      // TODO : Open door and highlight
      glTranslatef(-525 / 2, -450 / 2, 0);
      if (not AForColorPicking) and ((i = GetCurrentDecision.Selection) or (i = CurrentChapter.Selected)) then
      begin
        glColor3f(GetCurrentDecision.Answers[i].Highlight, GetCurrentDecision.Answers[i].Highlight, GetCurrentDecision.Answers[i].Highlight);
        TextureManager.DrawQuad(0, 0, 0, DimX, DimY, 'doorglowbackground');
        glColor3f(1, 1, 1);
      end;
      if (i = GetCurrentDecision.Selection) or (i = CurrentChapter.Selected) then
        TextureManager.DrawQuad(0, 0, 0, DimX, DimY, 'dooropen')
      else
        TextureManager.DrawQuad(0, 0, 0, DimX, DimY, 'door');
      glPopMatrix;
    end;
  glDepthMask(True);
  ShaderManager.DisableShader;

  Texturemanager.SetBlending(bmAdd);
  if AFBO = Renderer.FBOEffects then
    for i := 0 to High(GetCurrentDecision.Answers) do
      if (i = GetCurrentDecision.Selection) or (i = CurrentChapter.Selected) then
      begin
        glPushMatrix;
        glColor3f(GetCurrentDecision.Answers[i].Highlight, GetCurrentDecision.Answers[i].Highlight, GetCurrentDecision.Answers[i].Highlight);
        glTranslatef(AFBO.Width / 2 - ((i - Center) * OffsetX), AFBO.Height / 2 - Abs(i - Center) * OffsetY + Sin(DegToRad(GetCurrentDecision.Answers[i].SwayTimer)) * 15, 0);
        DoorScale;
        TextureManager.DrawQuad(0, 0, 0, DimX * 1.33, DimY * 1.33, 'doorglow', (flCenter));
        glPopMatrix;
      end;

  glDisable(GL_TEXTURE_2D);
  glDepthFunc(GL_LESS);

  // Answers
  if (not AForColorPicking) then
  begin
    glColor3f(1, 1, 1);
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_One_Minus_Src_Alpha, GL_One, GL_One);
    for i := 0 to High(GetCurrentDecision.Answers) do
    begin
      // For effect FBO : skip if not selected
      if (AFBO = Renderer.FBOEffects) and (GetCurrentDecision.Selection <> i) then
        continue;
      // Render answer text
      glPushMatrix;
      glTranslatef(AFBO.Width / 2 - ((i - Center) * OffsetX), AFBO.Height / 2 - Abs(i - Center) * OffsetY + 25, 0);
      glScalef(1, -1, 1);
      GetCurrentDecision.RenderAnswer(i);
      glPopMatrix;
    end;
  end;
end;


 // =====================================================================================================================
 //  TStage.RenderLadders
 // =====================================================================================================================
procedure TStage.RenderLadders(AFBO: TFrameBufferObject; AForColorPicking: Boolean);
const
  CeilPos    = -17;
  HoleSize   = 20;
  LadderSize = 15;
var
  i: integer;
  Center, PosOffset: single;
begin
  glDisable(GL_BLEND);
  glDisable(GL_ALPHA_TEST);
  glDisable(GL_LIGHTING);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, AFBO.Width, AFBO.Height);
  if Renderer.Sway then
    gluPerspective(60 + (0.75 * Sin(DegToRad(DegTimer)) * Player.StressLevel), AFBO.Width / AFBO.Height, 1, 256) // Hint : Stronger delta makes for a hefty effect
  else
    gluPerspective(60, AFBO.Width / AFBO.Height, 1, 256);

  glClearColor(0, 0, 0, 1);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);

  glColor3f(1, 1, 1);
  glDisable(GL_TEXTURE_2D);
  glRotatef(Player.Rotation.y, 0, 1, 0);
  glTranslatef(Player.Position.x, Player.Position.y, Player.Position.z - 35);

  // Ascend ladder
  if Player.Position.z > -10 then
    Player.Position.y := Player.Position.y + 0.175 * TimeFactor;

  PosOffset := 0;
  Center    := 0;

  if Length(GetCurrentDecision.Answers) = 2 then
  begin
    PosOffset := 20;
    Center    := 0.5;
  end;

  if Length(GetCurrentDecision.Answers) = 3 then
  begin
    PosOffset := 20;
    Center    := 1;
  end;

  // Plane
  if (not AForColorPicking) and (AFBO = Renderer.FBO) then
  begin
    glBegin(GL_QUADS);
    glColor3f(0, 0, 0);
    glVertex3f(-150, CeilPos, -100);
    glColor3f(0.25, 0.25, 0.25);
    glVertex3f(-5000, CeilPos, 200);
    glColor3f(0.25, 0.25, 0.25);
    glVertex3f(5000, CeilPos, 200);
    glColor3f(0, 0, 0);
    glVertex3f(150, CeilPos, -100);
    glEnd;
  end;

  // Movement offsets
  if GetCurrentDecision.Selection > -1 then
  begin
    if Length(GetCurrentDecision.Answers) = 2 then
      GetCurrentDecision.OffsetX := (GetCurrentDecision.Selection - Center) * 1.5;
    if Length(GetCurrentDecision.Answers) = 3 then
      GetCurrentDecision.OffsetX := (GetCurrentDecision.Selection - Center) * 2;
  end;

  for i := 0 to High(GetCurrentDecision.Answers) do
  begin
    // For effect FBO : skip if not selected
    if (AFBO = Renderer.FBOEffects) and (GetCurrentDecision.Selection <> i) then
      continue;
    // Render hole
    glPushMatrix;
    if AForColorPicking then
      glColor3ub(ColSelStep + i * ColSelStep, 0, 0);

    glDepthFunc(GL_ALWAYS);
    glColor3f(0, 0, 0);
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_BLEND);
    glTranslatef((i - Center) * PosOffset * 2, 0, Abs(i - Center) * 10);

    if AForColorPicking then
    begin
      ShaderManager.Shader['color'].Bind;
      glColor3ub(ColSelStep + i * ColSelStep, 0, 0);
    end
    else
    begin
      TextureManager.BindTexture('hole_ladder');
      glColor3f(1, 1, 1);
    end;

    if (AFBO = Renderer.FBO) or (AFBO = Renderer.FBOColSel) then
    begin
      // Hole
      TextureManager.SetBlending(bmBlend);
      glBegin(GL_QUADS);
      glTexCoord2f(0, 0);
      glVertex3f(-HoleSize, CeilPos, -10 + HoleSize);
      glTexCoord2f(1, 0);
      glVertex3f(HoleSize, CeilPos, -10 + HoleSize);
      glTexCoord2f(1, 1);
      glVertex3f(HoleSize, CeilPos, -10 - HoleSize);
      glTexCoord2f(0, 1);
      glVertex3f(-HoleSize, CeilPos, -10 - HoleSize);
      glEnd;

      // Ladder
      glPushMatrix;
      glRotatef((i - Center) * -20, 0, 1, 0);
      TextureManager.DrawQuad(-LadderSize / 2, CeilPos - 8.75, -10, LadderSize, LadderSize * 4, 'ladder', 0, True);
      glPopMatrix;
    end;

    if AForColorPicking then
      ShaderManager.DisableShader;

    // TODO : Different higlight than normal holes (see mockup)
    if (AFBO = Renderer.FBOEffects) and (GetCurrentDecision.Selection = i) then
    begin
      glColor3f(GetCurrentDecision.Answers[i].Highlight, GetCurrentDecision.Answers[i].Highlight, GetCurrentDecision.Answers[i].Highlight);
      TextureManager.SetBlending(bmAdd);
      TextureManager.BindTexture('radialgradientblack');
      glBegin(GL_QUADS);
      glTexCoord2f(0, 0);
      glVertex3f(-HoleSize * 1.2, CeilPos, -6 + HoleSize * 1.75);
      glTexCoord2f(1, 0);
      glVertex3f(HoleSize * 1.2, CeilPos, -6 + HoleSize * 1.75);
      glTexCoord2f(1, 1);
      glVertex3f(HoleSize * 1.2, CeilPos, -6 - HoleSize * 1.75);
      glTexCoord2f(0, 1);
      glVertex3f(-HoleSize * 1.2, CeilPos, -6 - HoleSize * 1.75);
      glEnd;

      glColor3f(1, 1, 1);
      TextureManager.SetBlending(bmBlend);
      TextureManager.BindTexture('hole_ladder_highlight');
      glBegin(GL_QUADS);
      glTexCoord2f(0, 0);
      glVertex3f(-HoleSize, CeilPos, -10 + HoleSize);
      glTexCoord2f(1, 0);
      glVertex3f(HoleSize, CeilPos, -10 + HoleSize);
      glTexCoord2f(1, 1);
      glVertex3f(HoleSize, CeilPos, -10 - HoleSize);
      glTexCoord2f(0, 1);
      glVertex3f(-HoleSize, CeilPos, -10 - HoleSize);
      glEnd;

      // Ladder
      glPushMatrix;
      glRotatef((i - Center) * -20, 0, 1, 0);
      TextureManager.DrawQuad(-LadderSize / 2, CeilPos - 8.75, -10, LadderSize, LadderSize * 4, 'ladder_highlight', 0, True);
      glPopMatrix;

      TextureManager.SetBlending(bmNone);
      TextureManager.DisableTextureStage(GL_TEXTURE0);
    end;

    glDisable(GL_TEXTURE_2D);

    glDepthFunc(GL_LESS);

    glPopMatrix;
  end;

  // Answers
  if (not AForColorPicking) then
  begin
    glColor3f(1, 1, 1);
    glDisable(GL_BLEND);
    for i := 0 to High(GetCurrentDecision.Answers) do
    begin
      // For effect FBO : skip if not selected
      if (AFBO = Renderer.FBOEffects) and (GetCurrentDecision.Selection <> i) then
        continue;
      // Render answer text
      glPushMatrix;
      glTranslatef((i - Center) * PosOffset * 1.86, 10 + Abs(i - Center), Abs(i - Center) * 10);
      GetCurrentDecision.RenderAnswer(i);
      glPopMatrix;
    end;
  end;
end;


 // =====================================================================================================================
 //  TStage.RenderHoles
 // =====================================================================================================================
procedure TStage.RenderHoles(AFBO: TFrameBufferObject; AForColorPicking: Boolean);
var
  i: integer;
  Center, PosOffset: single;
  HoleSize: single;
begin
  glDisable(GL_BLEND);
  glDisable(GL_ALPHA_TEST);
  glDisable(GL_LIGHTING);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, AFBO.Width, AFBO.Height);
  if Renderer.Sway then
    gluPerspective(60 + (2 * Sin(DegToRad(DegTimer)) * Player.StressLevel), AFBO.Width / AFBO.Height, 1, 256) // Hint : Stronger delta makes for a hefty effect
  else
    gluPerspective(60, AFBO.Width / AFBO.Height, 1, 256);

  glClearColor(0, 0, 0, 1);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  glDisable(GL_CULL_FACE);

  glColor3f(1, 1, 1);
  glDisable(GL_TEXTURE_2D);
  glRotatef(Player.Rotation.y, 0, 1, 0);
  glTranslatef(Player.Position.x, Player.Position.y, Player.Position.z - 35);

  if Renderer.Sway then
  begin
    glRotatef(Sin(DegToRad(Renderer.SwayTimer)) * 2.5 * Player.StressLevel, 1, 0, 0);
    glRotatef(Cos(DegToRad(Renderer.SwayTimer)) * 2.5 * Player.StressLevel, 0, 1, 0);
    glRotatef(Sin(DegToRad(Renderer.SwayTimer)) * 2.5 * Player.StressLevel, 0, 0, 1);
  end;

  PosOffset := 0;
  Center    := 0;

  if Length(GetCurrentDecision.Answers) = 2 then
  begin
    PosOffset := 20;
    Center    := 0.5;
  end;

  if Length(GetCurrentDecision.Answers) = 3 then
  begin
    PosOffset := 20;
    Center    := 1;
  end;

  // Plane
  if (not AForColorPicking) and (AFBO = Renderer.FBO) then
  begin
    glBegin(GL_QUADS);
    glColor3f(0, 0, 0);
    glVertex3f(-150, 10, -100);
    glColor3f(0.4, 0.4, 0.4);
    glVertex3f(-5000, 10, 200);
    glColor3f(0.4, 0.4, 0.4);
    glVertex3f(5000, 10, 200);
    glColor3f(0, 0, 0);
    glVertex3f(150, 10, -100);
    glEnd;
  end;

  // Movement offsets
  if GetCurrentDecision.Selection > -1 then
  begin
    if Length(GetCurrentDecision.Answers) = 2 then
      GetCurrentDecision.OffsetX := (GetCurrentDecision.Selection - Center) * 1.5;
    if Length(GetCurrentDecision.Answers) = 3 then
      GetCurrentDecision.OffsetX := (GetCurrentDecision.Selection - Center) * 2;
  end;

  for i := 0 to High(GetCurrentDecision.Answers) do
  begin
    // For effect FBO : skip if not selected
    if (AFBO = Renderer.FBOEffects) and (GetCurrentDecision.Selection <> i) then
      continue;
    if AFBO = Renderer.FBOText then
      continue;
    // Render hole
    glPushMatrix;
    if AForColorPicking then
      glColor3ub(ColSelStep + i * ColSelStep, 0, 0);

    glDepthFunc(GL_ALWAYS);
    glColor3f(0, 0, 0);
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_BLEND);
    glTranslatef((i - Center) * PosOffset * 2, 0, Abs(i - Center) * 10);

    if AForColorPicking then
    begin
      TextureManager.BindTexture('hole_white');
      glColor3ub(ColSelStep + i * ColSelStep, 0, 0);
    end
    else
    begin
      TextureManager.BindTexture('hole');
      glColor3f(1, 1, 1);
    end;

    HoleSize := 20;

    TextureManager.SetBlending(bmBlend);
    glBegin(GL_QUADS);
    glTexCoord2f(0, 1);
    glVertex3f(-HoleSize, 10, -10 + HoleSize);
    glTexCoord2f(1, 1);
    glVertex3f(HoleSize, 10, -10 + HoleSize);
    glTexCoord2f(1, 0);
    glVertex3f(HoleSize, 10, -10 - HoleSize);
    glTexCoord2f(0, 0);
    glVertex3f(-HoleSize, 10, -10 - HoleSize);
    glEnd;

    if (AFBO = Renderer.FBOEffects) and (GetCurrentDecision.Selection = i) then
    begin
      glColor3f(GetCurrentDecision.Answers[i].Highlight, GetCurrentDecision.Answers[i].Highlight, GetCurrentDecision.Answers[i].Highlight);
      TextureManager.SetBlending(bmAdd);
      TextureManager.BindTexture('radialgradientblack');
      glBegin(GL_QUADS);
      glTexCoord2f(0, 0);
      glVertex3f(-HoleSize * 1.2, 10, -6 + HoleSize * 1.75);
      glTexCoord2f(1, 0);
      glVertex3f(HoleSize * 1.2, 10, -6 + HoleSize * 1.75);
      glTexCoord2f(1, 1);
      glVertex3f(HoleSize * 1.2, 10, -6 - HoleSize * 1.75);
      glTexCoord2f(0, 1);
      glVertex3f(-HoleSize * 1.2, 10, -6 - HoleSize * 1.75);
      glEnd;

      glColor4f(1, 1, 1, 0.85);
      TextureManager.SetBlending(bmBlend);
      TextureManager.BindTexture('hole');
      glBegin(GL_QUADS);
      glTexCoord2f(0, 1);
      glVertex3f(-HoleSize, 10, -10 + HoleSize);
      glTexCoord2f(1, 1);
      glVertex3f(HoleSize, 10, -10 + HoleSize);
      glTexCoord2f(1, 0);
      glVertex3f(HoleSize, 10, -10 - HoleSize);
      glTexCoord2f(0, 0);
      glVertex3f(-HoleSize, 10, -10 - HoleSize);
      glEnd;

      TextureManager.SetBlending(bmNone);
      TextureManager.DisableTextureStage(GL_TEXTURE0);
    end;

    glDisable(GL_TEXTURE_2D);

    glDepthFunc(GL_LESS);

    glPopMatrix;
  end;

  // Answers
  if (not AForColorPicking) then
  begin
    glColor3f(1, 1, 1);
    glDisable(GL_BLEND);
    for i := 0 to High(GetCurrentDecision.Answers) do
    begin
      // For effect FBO : skip if not selected
      if (AFBO = Renderer.FBOEffects) and (GetCurrentDecision.Selection <> i) then
        continue;
      // Render answer text
      glPushMatrix;
      glTranslatef((i - Center) * PosOffset * 2, 4, Abs(i - Center) * 10);
      GetCurrentDecision.RenderAnswer(i);
      glPopMatrix;
    end;
  end;
end;


 // =====================================================================================================================
 //  TStage.SelectAnswer
 // =====================================================================================================================
procedure TStage.SelectAnswer;
begin
  CurrentChapter.Selected := CurrentChapter.Decision.Selection;
  Player.MoveDir          := glVertex(0, 0, 2);
  Player.MoveDir.x        := -GetCurrentDecision.OffsetX;
  Player.DecisionHistory.Add(CurrentChapter.Decision.Text);
  Player.AnswerHistory.Add(CurrentChapter.Decision.Answers[CurrentChapter.Selected].Text);
  Inc(Player.Bias, CurrentChapter.Decision.Answers[CurrentChapter.Selected].Bias);
  SoundSystem.PlaySample('heartbeat');
end;


 // =====================================================================================================================
 //  TStage.StateChange
 // =====================================================================================================================
procedure TStage.StateChange;
begin
  if (Game.State = gsInGame) and (CurrentChapter.Finished) then
    if not NextChapter then
      // TODO : End game if last chapter has been finished
  ;
  // Reset main menu when changing back from game
  if Game.State = gsMainMenu then
    MainMenu.Reset;
  // Generate ending lines
  if Game.State = gsEnding then
    EndingScene.GenerateEndingLines;
end;

end.

