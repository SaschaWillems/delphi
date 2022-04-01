// =============================================================================
//   OpenGL1.5 - VCL Template (opengl15_vcl_template.zip)
// =============================================================================
//   Copyright © 2003 by DGL - http://www.delphigl.com
// =============================================================================
//   Contents of this file are subject to the GNU Public License (GPL) which can
//   be obtained here : http://opensource.org/licenses/gpl-license.php
// =============================================================================
//   History :
//    Version 1.0 - Initial Release                            (Sascha Willems)
// =============================================================================

unit ExploTexGen;

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
  ShellAPI,

  Math,
  glPBuffer,
  glMisc,
  glTextureManager,
  dglOpenGL,

  glMath, StdCtrls, ExtCtrls, Grids, ValEdit, Buttons, ToolWin, ComCtrls;

type
  TGLForm = class(TForm)
    Panel1: TPanel;
    GLPanel: TPanel;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    ValueListEditorBase: TValueListEditor;
    ButtonLoadBaseTexture: TBitBtn;
    OpenDialogTexture: TOpenDialog;
    ValueListEditorGlobal: TValueListEditor;
    GroupBox3: TGroupBox;
    ValueListEditorSpark: TValueListEditor;
    ButtonLoadSparkTexture: TBitBtn;
    ButtonAbout: TBitBtn;
    ButtonFlipPreview: TBitBtn;
    ButtonGenerateExplosion: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ApplicationEventsIdle(Sender: TObject; var Done: Boolean);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure ButtonLoadBaseTextureClick(Sender: TObject);
    procedure ButtonLoadSparkTextureClick(Sender: TObject);
    procedure ButtonFlipPreviewClick(Sender: TObject);
    procedure ButtonGenerateExplosionClick(Sender: TObject);
    procedure ButtonAboutClick(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    ShowFPS   : Boolean;
    FontBase  : GLUInt;
    StartTick : Cardinal;
    Frames    : Integer;
    FPS       : Single;
    procedure Init;
    procedure GoToFullScreen(pWidth, pHeight, pBPP, pFrequency : Word);
    procedure BuildFont(pFontName : String);
    procedure PrintText(pX,pY : Integer; const pText : String);
    procedure ShowText;
    procedure OutputExplosion;
  end;

 // TParticle ==================================================================
 TParticle = record
   Position  : TglVertex3f;
   Velocity  : TglVertex3f;
   Color     : TglVertex3f;
   Rotation  : Single;
   RotDir    : SmallInt;
   State     : Byte;
  end;
 // TExplosion =================================================================
 TExplosion = class
   BaseParticle  : array of TParticle;
   Spark         : array of TParticle;
   Phase         : Byte;
   PhaseTime     : Single;
   // Settings
   Scale         : Single;
   BaseSpread    : Single;
   BaseCount     : Integer;
   BaseRange     : Integer;
   BaseRotSpeed  : Single;
   BaseVelocity  : Single;
   BaseSize      : Single;
   BaseTexture   : String;
   SparkSpread   : Single;
   SparkCount    : Integer;
   SparkRange    : Integer;
   SparkRotSpeed : Single;
   SparkVelocity : Single;
   SparkSize     : Single;
   SparkTexture  : String;
   function Init : Boolean;
   procedure Render;
  end;


var
 RC           : HGLRC;
 DC           : HDC;

 GLForm       : TGLForm;
 Explosion    : TExplosion;
 TmpPhase     : Single;
 QPCf         : Int64;
 TF           : Single;
 TmpB         : Boolean;
 PBO          : TPixelBuffer;
 LastGridSize : Byte;

 PreviewStyle : Byte = 0;

 MaxTexSize   : Integer;

implementation

{$R *.dfm}

function StringToInt(pString : String; var pValue : Integer; pValueName : String = '') : Boolean;
begin
Result :=  TryStrToInt(pString, pValue);
if (not Result) and (pValueName <> '') then
 MessageDlg('Please enter a valid integer value for "'+pValueName+'"!'+#13+'No explosion texture generated...', mtError, [mbOK], 0);
end;

function StringToFloat(pString : String; var pValue : Single; pValueName : String = '') : Boolean;
var
 i    : Integer;
 TmpS : String;
begin
TmpS := pString;
if Length(TmpS) > 0 then
 for i := 1 to Length(TmpS) do
  if TmpS[i] in ['.', ','] then
   TmpS[i] := DecimalSeparator;
Result := TryStrToFloat(TmpS, pValue);
if (not Result) and (pValueName <> '') then
 MessageDlg('Please enter a valid floating point value for "'+pValueName+'"!'+#13+'No explosion texture generated...', mtError, [mbOK], 0);
end;

// =============================================================================
//  TExplosion.Init
// =============================================================================
function TExplosion.Init : Boolean;
var
 i : Integer;
begin
Result    := False;
PhaseTime := 0;
if not StringToFloat(GLForm.ValueListEditorGlobal.Cells[1,3], Scale, GLForm.ValueListEditorGlobal.Cells[0,3]) then
 exit;
with GLForm.ValueListEditorBase do
 begin
 if not StringToInt(Cells[1,1],   BaseCount,    Cells[0,1]) then
  exit;
 if not StringToInt(Cells[1,2],   BaseRange,    Cells[0,2]) then
  exit;
 if not StringToFloat(Cells[1,3], BaseSpread,   Cells[0,3]) then
  exit;
 if not StringToFloat(Cells[1,4], BaseRotSpeed, Cells[0,4]) then
  exit;
 if not StringToFloat(Cells[1,5], BaseVelocity, Cells[0,5]) then
  exit;
 if not StringToFloat(Cells[1,6], BaseSize,     Cells[0,6]) then
  exit;
 end;
with GLForm.ValueListEditorSpark do
 begin
 if not StringToInt(Cells[1,1],   SparkCount,    Cells[0,1]) then
  exit;
 if not StringToInt(Cells[1,2],   SparkRange,    Cells[0,2]) then
  exit;
 if not StringToFloat(Cells[1,3], SparkSpread,   Cells[0,3]) then
  exit;
 if not StringToFloat(Cells[1,4], SparkRotSpeed, Cells[0,4]) then
  exit;
 if not StringToFloat(Cells[1,5], SparkVelocity, Cells[0,5]) then
  exit;
 if not StringToFloat(Cells[1,6], SparkSize,     Cells[0,6]) then
  exit;
 end;
Result := True;
SetLength(BaseParticle, BaseCount+Random(BaseRange));
for i := 0 to High(BaseParticle) do
 with BaseParticle[i] do
  begin
  Position  := glVertex(Sin(DegToRad(Random(360)))*(Random*(BaseSpread)-Random*(BaseSpread)), Cos(DegToRad(Random(360)))*(Random*(BaseSpread)-Random*(BaseSpread)), 0);
  Velocity  := glVertex(Position.x*BaseVelocity, Position.y*BaseVelocity, Position.z*BaseVelocity);
  Color     := glVertex(1, 1, 1);
  Rotation  := Random(360);
  if Random(2) = 0 then
   RotDir := -1
  else
   RotDir := 1;
  end;
SetLength(Spark, SparkCount+Random(SparkRange));
for i := 0 to High(Spark) do
 with Spark[i] do
  begin
  Position  := glVertex(Sin(DegToRad(Random(360)))*(Random*(SparkSpread/2)-Random*(SparkSpread/2)), Cos(DegToRad(Random(360)))*(Random*(SparkSpread/2)-Random*(SparkSpread/2)), 0);
  Velocity  := glVertex(Position.x*SparkVelocity, Position.y*SparkVelocity, Position.z*SparkVelocity);
  Color     := glVertex(1, 1, 1);
  Rotation  := Random(360);
  if Random(2) = 0 then
   RotDir := -1
  else
   RotDir := 1;
  end;
end;

// =============================================================================
//  TExplosion.Render
// =============================================================================
procedure TExplosion.Render;
var
 i : Integer;
begin
glDepthMask(False);
glDepthMask(False);
glDisable(GL_CULL_FACE);
TextureManager.BindTexture(BaseTexture, GL_TEXTURE0);
TextureManager.SetBlending(bmAdd);
if Length(BaseParticle) > 0 then
 for i := 0 to High(BaseParticle) do
  with BaseParticle[i] do
   begin
   Position := glVertex(Position.x + Velocity.x * TF, Position.y + Velocity.y * TF, Position.z + Velocity.z * TF);
   Rotation := Rotation + (RotDir * TF * 75 * BaseRotSpeed);
   glPushMatrix;
    glTranslatef(Position.x, Position.y, Position.z+i*0.01);
    glRotatef(Rotation, 0,0,1);
    glColor4f(Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)));
    TextureManager.DrawQuadExCenter(0, 0, 0, BaseSize, BaseSize, '');
   glPopMatrix;
   end;
// Sparks
TextureManager.BindTexture(SparkTexture, GL_TEXTURE0);
if Length(Spark) > 0 then
 for i := 0 to High(Spark) do
  with Spark[i] do
   begin
   Position := glVertex(Position.x + Velocity.x * TF, Position.y + Velocity.y * TF, Position.z + Velocity.z * TF);
   Rotation := Rotation + (RotDir * TF * 75 * SparkRotSpeed);
   glPushMatrix;
    glTranslatef(Position.x, Position.y, Position.z);
    glColor4f(Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)));
    TextureManager.DrawQuadExCenter(0, 0, 0, SparkSize, SparkSize, '');
   glPopMatrix;
   end;         
glEnable(GL_CULL_FACE);
glDepthMask(True);
glDisable(GL_BLEND);
glColor3f(1,1,1);
// Update phase
PhaseTime := PhaseTime + TF * 250;
if PhaseTime > 360 then
 begin
 Init;
 PhaseTime := 0;
 end;
end;

// =============================================================================
//  TForm1.GoToFullScreen
// =============================================================================
//  Wechselt in den mit den Parametern angegebenen Vollbildmodus
// =============================================================================
procedure TGLForm.GoToFullScreen(pWidth, pHeight, pBPP, pFrequency : Word);
var
 dmScreenSettings : DevMode;
begin
// Fenster vor Vollbild vorbereiten
WindowState := wsMaximized;
BorderStyle := bsNone;
ZeroMemory(@dmScreenSettings, SizeOf(dmScreenSettings));
with dmScreenSettings do
 begin
 dmSize              := SizeOf(dmScreenSettings);
 dmPelsWidth         := pWidth;                    // Breite
 dmPelsHeight        := pHeight;                   // Höhe
 dmBitsPerPel        := pBPP;                      // Farbtiefe
 dmDisplayFrequency  := pFrequency;                // Bildwiederholfrequenz
 dmFields            := DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL or DM_DISPLAYFREQUENCY;
 end;
if (ChangeDisplaySettings(dmScreenSettings, CDS_FULLSCREEN) = DISP_CHANGE_FAILED) then
 begin
 MessageBox(0, 'Konnte Vollbildmodus nicht aktivieren!', 'Error', MB_OK or MB_ICONERROR);
 exit
 end;
end;

// =============================================================================
//  TForm1.BuildFont
// =============================================================================
//  Displaylisten für Bitmapfont erstellen
// =============================================================================
procedure TGLForm.ButtonAboutClick(Sender: TObject);
begin
ShellExecute(Handle, 'open', PChar(ExtractFilePath(Application.ExeName)+'\readme.html'), '', '', sw_Show);
end;

procedure TGLForm.ButtonFlipPreviewClick(Sender: TObject);
begin
PreviewStyle := not PreviewStyle;
end;

procedure TGLForm.ButtonGenerateExplosionClick(Sender: TObject);
begin
OutPutExplosion;
end;

procedure TGLForm.BuildFont(pFontName : String);
var
 Font : HFONT;
begin
FontBase := glGenLists(96);
Font     := CreateFont(12, 0, 0, 0, FW_MEDIUM, 0, 0, 0, ANSI_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
                       ANTIALIASED_QUALITY, FF_DONTCARE or DEFAULT_PITCH, PChar(pFontName));
SelectObject(DC, Font);
wglUseFontBitmaps(DC, 0, 256, FontBase);
DeleteObject(Font)
end;

procedure TGLForm.ButtonLoadBaseTextureClick(Sender: TObject);
begin
OpenDialogTexture.Title := 'Select texture for base particles';
if OpenDialogTexture.Execute then
 begin
 TextureManager.AddTexture(OpenDialogTexture.FileName, ExtractFileName(OpenDialogTexture.FileName), False);
 Explosion.BaseTexture := ExtractFileName(OpenDialogTexture.FileName);
 ButtonLoadBaseTexture.Caption := ExtractRelativePath(ExtractFilePath(Application.ExeName), OpenDialogTexture.FileName);
 end;
end;

procedure TGLForm.ButtonLoadSparkTextureClick(Sender: TObject);
begin
OpenDialogTexture.Title := 'Select texture for sparks';
if OpenDialogTexture.Execute then
 begin
 TextureManager.AddTexture(OpenDialogTexture.FileName, ExtractFileName(OpenDialogTexture.FileName), False);
 Explosion.SparkTexture := ExtractFileName(OpenDialogTexture.FileName);
 ButtonLoadSparkTexture.Caption := ExtractRelativePath(ExtractFilePath(Application.ExeName), OpenDialogTexture.FileName);
 end;
end;

// =============================================================================
//  TForm1.PrintText
// =============================================================================
//  Gibt einen Text an Position x/y aus
// =============================================================================
procedure TGLForm.PrintText(pX,pY : Integer; const pText : String);
begin
if (pText = '') then
 exit;
glPushAttrib(GL_LIST_BIT);
 glRasterPos2i(pX, pY);
 glListBase(FontBase);
 glCallLists(Length(pText), GL_UNSIGNED_BYTE, PChar(pText));
glPopAttrib;
end;

// =============================================================================
//  TForm1.ShowText
// =============================================================================
procedure TGLForm.ShowText;
begin
glDisable(GL_DEPTH_TEST);
glDisable(GL_TEXTURE_2D);
glMatrixMode(GL_PROJECTION);
glLoadIdentity;
glOrtho(0,640,480,0, -1,1);
glMatrixMode(GL_MODELVIEW);
glLoadIdentity;
if TextureManager.GetTextureInfo('explosion_result', TTexInfoID) = -1 then
 PrintText(5,15, 'No output texture generated. Click "generate" to see result here...');
glEnable(GL_DEPTH_TEST);
glEnable(GL_TEXTURE_2D);
end;

// =============================================================================
//  TForm1.OutputExplosion
// =============================================================================
procedure TGLForm.OutputExplosion;
var
 x,y       : Integer;
 GridSize  : Byte;
 TmpSize   : Integer;
 TmpS      : String;
 FileIndex : Integer;
begin
TmpS := ValueListEditorGlobal.Values['Gridsize'];
if TmpS = '4x4' then
 begin
 GridSize := 3;
 TF       := 0.05;
 end;
if TmpS = '8x8' then
 begin
 GridSize := 7;
 TF       := 0.0115;
 end;
if TmpS = '16x16' then
 begin
 GridSize := 15;
 TF       := 0.00275;
 end;
LastGridSize := GridSize;
TmpSize      := StrToInt(ValueListEditorGlobal.Values['Texturesize']);
if TmpSize > MaxTexSize then
 begin
 MessageDlg('Your OpenGL implementation (i.e. graphics card) does not support a texture resolution of "'+IntToStr(TmpSize)+'x'+IntToStr(TmpSize)+'"!'+#13+'Please select a lower resolution.', mtError, [mbOK], 0);
 exit;
 end;

if not Explosion.Init then
 exit;

PBO := TPixelBuffer.Create(TmpSize, TmpSize, DC, RC, nil, False, False);

PBO.Enable;
glMatrixMode(GL_PROJECTION);
glLoadIdentity;
glViewPort(0, 0, TmpSize, TmpSize);
glOrtho(0, 20*(GridSize+1), 20*(GridSize+1), 0, -1,1);

glMatrixMode(GL_MODELVIEW);
glLoadIdentity;
glClearColor(0,0,0,0);
glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);

for y := 0 to GridSize do
 for x := 0 to GridSize do
  begin
  glPushMatrix;
   glTranslatef(10+x*20, 10+y*20, 0);
   glScalef(Explosion.Scale, Explosion.Scale, 1);
   Explosion.Render;
  glPopMatrix;
  end;

if not DirectoryExists(ExtractFilePath(Application.ExeName)+'\output') then
 MkDir(ExtractFilePath(Application.ExeName)+'\output');
FileIndex := -1;
repeat
inc(FileIndex);
until not FileExists(ExtractFilePath(Application.ExeName)+'\output\explosion'+IntToStr(FileIndex)+'.png');
glSaveScreenAsPNG(ExtractFilePath(Application.ExeName)+'\output\explosion'+IntToStr(FileIndex)+'.png');
TextureManager.DeleteTexture('explosion_result');
TextureManager.AddTexture(ExtractFilePath(Application.ExeName)+'\output\explosion'+IntToStr(FileIndex)+'.png', 'explosion_result', True);
PBO.Disable;
PBO.Free;
end;

// =============================================================================
//  TGLForm.FormCreate
// =============================================================================
procedure TGLForm.FormCreate(Sender: TObject);
begin
Init;
end;

// =============================================================================
//  TGLForm.Init
// =============================================================================
procedure TGLForm.Init;
begin
QueryPerformanceFrequency(QPCf);
InitOpenGL;
DC := GetDC(GlPanel.Handle);
RC := CreateRenderingContext(DC, [opDoubleBuffered], 32, 24, 0, 0, 0, 0);
ActivateRenderingContext(DC, RC);
if (not wglIsExtSupported('WGL_ARB_pbuffer')) and (not wglIsExtSupported('WGL_EXT_pbuffer')) then
 begin
 MessageDlg('Your OpenGL implementation does not support pixel buffer for offscreen rendering (WGL_ARB_PBUFFER or WGL_EXT_PBUFFER) which are necessary for the application to work. Please update your OpenGL drivers!', mtError, [mbOK], 0);
 Destroy;
 halt(0);
 end;
glGetIntegerv(GL_MAX_TEXTURE_SIZE, @MaxTexSize);
glEnable(GL_DEPTH_TEST);
glDepthFunc(GL_LESS);
glClearColor(0,0,0,0);
BuildFont('MS Sans Serif');
Application.OnIdle := ApplicationEventsIdle;
StartTick := GetTickCount;
Randomize;
Explosion := TExplosion.Create;
Explosion.Init;
Explosion.BaseTexture  := 'particle_default';
Explosion.SparkTexture := 'spark_default';
TmpPhase := 0;
TextureManager := TTextureManager.Create;
TextureManager.AddTexturesInDir('particles', '*.dds', True);
with ValueListEditorGlobal do
 begin
 with ItemProps['Texturesize'] do
  begin
  EditStyle := esPickList;
  PickList.Add('512');
  PickList.Add('1024');
  PickList.Add('2048');
  PickList.Add('4096');
  end;
 Values['Texturesize'] := '1024';
 with ItemProps['Gridsize'] do
  begin
  EditStyle := esPickList;
  PickList.Add('4x4');
  PickList.Add('8x8');
  PickList.Add('16x16');
  end;
 Values['Gridsize'] := '8x8';
 end;
end;

// =============================================================================
//  TGLForm.FormDestroy
// =============================================================================
procedure TGLForm.FormDestroy(Sender: TObject);
begin
if Assigned(TextureManager) then
 TextureManager.Free;
if Assigned(Explosion) then
 Explosion.Free;
DeactivateRenderingContext;
wglDeleteContext(RC);
ReleaseDC(Handle, DC);
end;

// =============================================================================
//  TForm1.ApplicationEventsIdle
// =============================================================================
//  Hier wird gerendert. Der Idle-Event wird bei Done=False permanent aufgerufen
// =============================================================================
procedure TGLForm.ApplicationEventsIdle(Sender: TObject; var Done: Boolean);
var
 QPCs, QPCe : Int64;
 TmpS, TmpT : Single;
 TmpSize    : Single;
 i          : Integer;
 x,y        : Integer;
 StartPos   : Single;
 Size       : Single;
begin
QueryPerformanceCounter(QPCs);
glMatrixMode(GL_PROJECTION);
glLoadIdentity;
glViewPort(0, 0, GLPanel.Width, GLPanel.Height);
glOrtho(0, 1, 1, 0, -1,1);

glMatrixMode(GL_MODELVIEW);
glLoadIdentity;
glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

glDisable(GL_CULL_FACE);
if TextureManager.GetTextureInfo('explosion_result', TTexInfoID) <> -1 then
 begin
 case PreviewStyle of
  0   : begin
        StartPos := 0.2;
        Size     := 0.8;
        end;
  255 : begin
        StartPos := 0.8;
        Size     := 0.2;
        end;
 end;
 // Preview texture
 TextureManager.DisableTextureStage(GL_TEXTURE0);
 glBegin(GL_LINE_STRIP);
  glVertex3f(StartPos,      StartPos+Size, 0.75);
  glVertex3f(StartPos,      StartPos, 0.75);
  glVertex3f(StartPos+Size, StartPos, 0.75);
  glVertex3f(StartPos+Size, StartPos+Size, 0.75);
 glEnd;
 glAlphaFunc(GL_ALWAYS, 0);
 PBO.Bind;
 TextureManager.DrawQuadEx(StartPos, StartPos, 0, Size, Size, 'explosion_result');
 TextureManager.SetBlending(bmBlend);
 // Preview animation
 case PreviewStyle of
   0  : begin
        StartPos := 0;
        Size     := 0.2;
        end;
  255 : begin
        StartPos := 0;
        Size     := 0.8;
        end;
 end;
 TmpSize := 1 / (LastGridSize+1);
 TmpS    := 0;
 TmpT    := 1;
 i       := 0;
 repeat
 TmpS := TmpS + TmpSize;
 if TmpS > 1-TmpSize then
  begin
  TmpS := 0;
  TmpT := TmpT - TmpSize;
  end;
 inc(i);
 if TmpT-TmpSize < 0 then
  break;
 until i = Round(TmpPhase);
 TextureManager.SetBlending(bmBlend);
 TextureManager.BindTexture('explosion_result', GL_TEXTURE0);
 glBegin(GL_QUADS);
  glTexCoord2f(TmpS,         TmpT);         glVertex3f(StartPos,      StartPos,      0.5);
  glTexCoord2f(TmpS+TmpSize, TmpT);         glVertex3f(StartPos+Size, StartPos,      0.5);
  glTexCoord2f(TmpS+TmpSize, TmpT-TmpSize); glVertex3f(StartPos+Size, StartPos+Size, 0.5);
  glTexCoord2f(TmpS,         TmpT-TmpSize); glVertex3f(StartPos,      StartPos+Size, 0.5);
 glEnd;
 TextureManager.DisableTextureStage(GL_TEXTURE0);
 glBegin(GL_LINE_STRIP);
  glVertex3f(StartPos,      StartPos,      0.75);
  glVertex3f(StartPos+Size, StartPos,      0.75);
  glVertex3f(StartPos+Size, StartPos+Size, 0.75);
  glVertex3f(StartPos,      StartPos+Size, 0.75);
  glVertex3f(StartPos,      StartPos,      0.75);
 glEnd;
 end;


ShowText;

SwapBuffers(DC);
QueryPerformanceCounter(QPCe);
TF := (QPCe-QPCs) / QPCf;
case LastGridSize of
  3 : TmpPhase := TmpPhase + TF * 10;
  7 : TmpPhase := TmpPhase + TF * 40;
 15 : TmpPhase := TmpPhase + TF * 140;
end;
if TmpPhase > (LastGridSize+1)*(LastGridSize+1) then
 TmpPhase := 0;

Done := False;

inc(Frames);
if GetTickCount - StartTick >= 500 then
 begin
 FPS       := Frames/(GetTickCount-StartTick)*1000;
 Frames    := 0;
 StartTick := GetTickCount
 end;
end;

// =============================================================================
//  TForm1.FormKeyPress
// =============================================================================
procedure TGLForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
case Key of
 #27 : Close;
end;
end;

end.
