// =============================================================================
//   ExplosionTextureGenerator
//   Copyright © 2009-2013 by Sascha Willems - www.saschawillems.de
// =============================================================================

unit ExploTexGen_MainForm;

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

  glMath, StdCtrls, ExtCtrls, Grids, ValEdit, Buttons, ToolWin, ComCtrls, Vcl.Menus;

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
    ButtonGenerateExplosion: TBitBtn;
    Label1: TLabel;
    CheckBoxFlip: TCheckBox;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    loadsettings1: TMenuItem;
    savesettings1: TMenuItem;
    Quite1: TMenuItem;
    N1: TMenuItem;
    About1: TMenuItem;
    Settings1: TMenuItem;
    Flippreview1: TMenuItem;
    ComboBoxType: TComboBox;
    SaveDialogSettings: TSaveDialog;
    OpenDialogSettings: TOpenDialog;
    N2: TMenuItem;
    N3: TMenuItem;
    Showoutputdirectory1: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ApplicationEventsIdle(Sender: TObject; var Done: Boolean);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure ButtonLoadBaseTextureClick(Sender: TObject);
    procedure ButtonLoadSparkTextureClick(Sender: TObject);
    procedure ButtonGenerateExplosionClick(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure Quite1Click(Sender: TObject);
    procedure Flippreview1Click(Sender: TObject);
    procedure Showoutputdirectory1Click(Sender: TObject);
    procedure loadsettings1Click(Sender: TObject);
    procedure savesettings1Click(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    ShowFPS   : Boolean;
    FontBase  : GLUInt;
    StartTick : Cardinal;
    Frames    : Integer;
    FPS       : Single;
    Text		  : String;
    procedure Init;
    procedure BuildFont(pFontName : String);
    procedure PrintText(pX,pY : Integer; const pText : AnsiString);
    procedure ShowText;
    procedure OutputExplosionSingleFile;
    procedure OutputExplosionMultipleFiles;
    procedure SaveSettings(const AFile : String);
    procedure LoadSettings(const AFile : String);
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
 	 _Type         : Word;
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
   function Init(AType : Word = 0) : Boolean;
   procedure Render(ACurrentFrame, ANumFrames : Integer; ATimeFactor : Single);
  end;

const
	ExplosionTypeDefault  = 0;
  ExplosionTypeFireBall = 1;

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

 BGColor			: TglVertex3f;

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
function TExplosion.Init(AType : Word = 0) : Boolean;
var
 i : Integer;
begin
  _Type     := AType;
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
      	if _Type = ExplosionTypeDefault then begin
          Position  := glVertex(Sin(DegToRad(Random(360)))*(Random*(BaseSpread)-Random*(BaseSpread)), Cos(DegToRad(Random(360)))*(Random*(BaseSpread)-Random*(BaseSpread)), 0);
          Velocity  := glVertex(Position.x*BaseVelocity, Position.y*BaseVelocity, Position.z*BaseVelocity);
        end;
      	if _Type = ExplosionTypeFireBall then begin
          Position  := glVertex(Sin(DegToRad(Random(360)))*(Random*(BaseSpread*2)-Random*(BaseSpread*2)), Cos(DegToRad(Random(360)))*(Random*(BaseSpread*2)-Random*(BaseSpread*2)), 0);
          Velocity  := glVertex(0, 0, 0);
        end;
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
procedure TExplosion.Render(ACurrentFrame, ANumFrames : Integer; ATimeFactor : Single);
var
	i : Integer;
begin
  glDepthMask(False);
  glDepthMask(False);
  glDisable(GL_CULL_FACE);
  TextureManager.SetBlending(bmAdd);

  TextureManager.BindTexture(BaseTexture, GL_TEXTURE0);
    for i := 0 to High(BaseParticle) do
      with BaseParticle[i] do
        begin
          if _Type = ExplosionTypeDefault then
          	Position := glVertex(Position.x + Velocity.x * ATimeFactor, Position.y + Velocity.y * ATimeFactor, Position.z + Velocity.z * ATimeFactor);
          if _Type = ExplosionTypeDefault then
          	Rotation := Rotation + (RotDir * ATimeFactor * 75 * BaseRotSpeed);
          if _Type = ExplosionTypeFireball then
          	Rotation := RotDir * 360 / ANumFrames * ACurrentFrame * ATimeFactor;
          glPushMatrix;
            glTranslatef(Position.x, Position.y, Position.z+i*0.01);
            glRotatef(Rotation, 0,0,1);
            glColor4f(1, 1, 1, 0.8);
            if _Type = ExplosionTypeDefault then
	          	glColor4f(Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime))*0.8);
            TextureManager.DrawQuadExCenter(0, 0, 0, BaseSize, BaseSize, '');
          glPopMatrix;
        end;

  // Sparks
  glColor4f(1,1,1,1);
  TextureManager.BindTexture(SparkTexture, GL_TEXTURE0);
  for i := 0 to High(Spark) do
    with Spark[i] do
      begin
        Position := glVertex(Position.x + Velocity.x * ATimeFactor, Position.y + Velocity.y * ATimeFactor, Position.z + Velocity.z * ATimeFactor);
        Rotation := Rotation + (RotDir * ATimeFactor * 75 * SparkRotSpeed);
        glPushMatrix;
          glTranslatef(Position.x, Position.y, Position.z);
          glRotatef(Rotation, 0,0,1);
          glColor4f(Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)), Sin(DegToRad(PhaseTime)));
          TextureManager.DrawQuadExCenter(0, 0, 0, SparkSize, SparkSize, '');
        glPopMatrix;
      end;
  glEnable(GL_CULL_FACE);
  glDepthMask(True);
  glDisable(GL_BLEND);
  glColor3f(1,1,1);

  // Update phase
  if _Type = ExplosionTypeDefault then
    begin
      PhaseTime := PhaseTime + ATimeFactor * 250;
      if PhaseTime > 360 then
        begin
          Init;
          PhaseTime := 360 - PhaseTime;
        end;
    end;
end;

// =============================================================================
//  TForm1.BuildFont
// =============================================================================
//  Displaylisten für Bitmapfont erstellen
// =============================================================================
procedure TGLForm.ButtonGenerateExplosionClick(Sender: TObject);
begin
  if ValueListEditorGlobal.Values['Texture Output'] = 'Single' then
		OutputExplosionSingleFile
  else
		OutputExplosionMultipleFiles;
end;

procedure TGLForm.BuildFont(pFontName : String);
var
	Font : HFONT;
begin
  FontBase := glGenLists(96);
  Font     := CreateFont(12, 0, 0, 0, FW_MEDIUM, 0, 0, 0, ANSI_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY, FF_DONTCARE or DEFAULT_PITCH, PChar(pFontName));
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

procedure TGLForm.loadsettings1Click(Sender: TObject);
begin
	if OpenDialogSettings.Execute then
  	LoadSettings(OpenDialogSettings.FileName);
end;

// =============================================================================
//  TForm1.PrintText
// =============================================================================
//  Gibt einen Text an Position x/y aus
// =============================================================================
procedure TGLForm.PrintText(pX,pY : Integer; const pText : AnsiString);
begin
  if (pText = '') then
  	exit;
  glPushAttrib(GL_LIST_BIT);
    glRasterPos2i(pX, pY);
    glListBase(FontBase);
    glCallLists(Length(pText), GL_UNSIGNED_BYTE, PAnsiChar(pText));
  glPopAttrib;
end;

procedure TGLForm.Quite1Click(Sender: TObject);
begin
	Close;
end;

procedure TGLForm.Showoutputdirectory1Click(Sender: TObject);
begin
	ShellExecute(Handle, 'open', PChar(ExtractFilePath(Application.ExeName)+'\output'), '', '', sw_Show);
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
		PrintText(5, 15, 'No output texture generated. Click "generate" to see result here...');
  glEnable(GL_DEPTH_TEST);
  glEnable(GL_TEXTURE_2D);
end;

// =============================================================================
//  TGLForm.OutputExplosionSingleFiles
// =============================================================================
//  Generate a single file containing a grid for the explosion animation
// =============================================================================
procedure TGLForm.OutputExplosionSingleFile;
var
 x,y,n     : Integer;
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

  if not Explosion.Init(ComboBoxType.ItemIndex) then
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

  n := 0;
  for y := 0 to GridSize do
    for x := 0 to GridSize do
    begin
      glPushMatrix;
      	if CheckBoxFlip.Checked then
        	glTranslatef(10 +x*20, 20*(GridSize+1) - 10 - y*20, 0)
        else
        	glTranslatef(10+x*20, 10+y*20, 0);
        glScalef(Explosion.Scale, Explosion.Scale, 1);
        if Explosion._Type = ExplosionTypeDefault then
        	Explosion.Render(n, (GridSize+1)*(GridSize+1), TF)
        else
        	Explosion.Render(n, (GridSize+1)*(GridSize+1), 1);
      glPopMatrix;
      inc(n);
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
//  TGLForm.OutputExplosionMultipleFiles
// =============================================================================
//  Generates a single image for each explosion animation frame
// =============================================================================
procedure TGLForm.OutputExplosionMultipleFiles;
var
 x,y,n     : Integer;
 GridSize  : Byte;
 TmpSize   : Integer;
 TmpS      : String;
 FileIndex : Integer;
 DirName   : String;
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

  if not Explosion.Init(ComboBoxType.ItemIndex) then
  	exit;

  DirName := ExtractFilePath(Application.ExeName)+'\output\' + FormatDateTime('yyyy-mm-dd_hh-nn-ss', Now) + '_single';
  ForceDirectories(DirName);

  PBO := TPixelBuffer.Create(TmpSize, TmpSize, DC, RC, nil, False, False);
  PBO.Enable;

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewPort(0, 0, TmpSize, TmpSize);
  glOrtho(0, 20, 20, 0, -1,1);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glClearColor(0,0,0,0);
 	glTranslatef(10, 10, 0);

  for n := 0 to GridSize*GridSize - 1 do
  	begin
      PBO.Disable;

      glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
      glDisable(GL_DEPTH_TEST);
      glDisable(GL_TEXTURE_2D);
      glMatrixMode(GL_PROJECTION);
      glLoadIdentity;
      glOrtho(0,640,480,0, -1,1);
      glMatrixMode(GL_MODELVIEW);
      glLoadIdentity;
      PrintText(5, 15, 'Generating texture for frame no. ' + IntToStr(n));
      glEnable(GL_DEPTH_TEST);
      glEnable(GL_TEXTURE_2D);
      SwapBuffers(DC);

    	PBO.Enable;
  		glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
      if Explosion._Type = ExplosionTypeDefault then
        Explosion.Render(n, (GridSize+1)*(GridSize+1), TF)
      else
        Explosion.Render(n, (GridSize+1)*(GridSize+1), 1);
  		glSaveScreenAsPNG(DirName + '\' + IntToStr(n) + '.png');
    end;

  PBO.Disable;
  PBO.Free;

	OutputExplosionSingleFile;
end;

procedure TGLForm.Flippreview1Click(Sender: TObject);
begin
	PreviewStyle := not PreviewStyle;
end;

// =============================================================================
//  TGLForm.FormCreate
// =============================================================================
procedure TGLForm.FormCreate(Sender: TObject);
begin
	Init;
  OpenDialogSettings.InitialDir := ExtractFilePath(ParamStr(0));
  SaveDialogSettings.InitialDir := ExtractFilePath(ParamStr(0));
  BGColor.x := 0;
  BGColor.y := 0;
  BGColor.z := 0;
end;

// =============================================================================
//  TGLForm.Init
// =============================================================================
procedure TGLForm.savesettings1Click(Sender: TObject);
begin
	if SaveDialogSettings.Execute then
  	SaveSettings(SaveDialogSettings.FileName);
end;

procedure TGLForm.Init;
var
 SettingFile : TStringList;
begin
  QueryPerformanceFrequency(QPCf);
  InitOpenGL;
  try
    DC := GetDC(GlPanel.Handle);
    RC := CreateRenderingContext(DC, [opDoubleBuffered], 32, 24, 0, 0, 0, 0);
    ActivateRenderingContext(DC, RC);
    if (not wglIsExtSupported('WGL_ARB_pbuffer')) and (not wglIsExtSupported('WGL_EXT_pbuffer')) then
      begin
        MessageDlg('Your OpenGL implementation does not support pixel buffer for offscreen rendering (WGL_ARB_PBUFFER or WGL_EXT_PBUFFER) which are necessary for the application to work. Please update your OpenGL drivers!', mtError, [mbOK], 0);
        Application.Terminate;
      end;
  except
  	MessageDlg('Could not create OpenGL rendering context!' +#13 + 'OpenGL drivers installed?', mtError, [mbOK], 0);
    Application.Terminate;
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
      with ItemProps['Texture Output'] do
        begin
          EditStyle := esPickList;
          PickList.Add('Single');
          PickList.Add('One per frame');
        end;
      Values['Texture Output'] := 'Single';
  	end;

  if FileExists(ExtractFilePath(Application.ExeName)+'\settings.cfg') then
  	LoadSettings(ExtractFilePath(Application.ExeName)+'\settings.cfg');
end;

procedure TGLForm.SaveSettings(const AFile: String);
begin
	with TStringList.Create do begin
  	// Basics
    Add(GLForm.ValueListEditorGlobal.Cells[1,1]);
    Add(GLForm.ValueListEditorGlobal.Cells[1,2]);
    Add(GLForm.ValueListEditorGlobal.Cells[1,3]);

    // Explosion
    Add(Explosion.BaseTexture);
    Add(GLForm.ValueListEditorBase.Cells[1,1]);
    Add(GLForm.ValueListEditorBase.Cells[1,2]);
    Add(GLForm.ValueListEditorBase.Cells[1,3]);
    Add(GLForm.ValueListEditorBase.Cells[1,4]);
    Add(GLForm.ValueListEditorBase.Cells[1,5]);
    Add(GLForm.ValueListEditorBase.Cells[1,6]);

    // Sparks
    Add(Explosion.SparkTexture);
    Add(GLForm.ValueListEditorSpark.Cells[1,1]);
    Add(GLForm.ValueListEditorSpark.Cells[1,2]);
    Add(GLForm.ValueListEditorSpark.Cells[1,3]);
    Add(GLForm.ValueListEditorSpark.Cells[1,4]);
    Add(GLForm.ValueListEditorSpark.Cells[1,5]);
    Add(GLForm.ValueListEditorSpark.Cells[1,6]);

    // New properties in 1.1
    Add(IntToStr(ComboBoxType.ItemIndex));
    Add(BoolToStr(CheckBoxFlip.Checked));

  	SaveToFile(AFile);
    Free;
  end;
end;


procedure TGLForm.LoadSettings(const AFile: String);
var
	SettingFile : TStringList;
begin
	SettingFile :=  TStringList.Create;
	SettingFile.LoadFromFile(AFile);

  // Basics
  ValueListEditorGlobal.Cells[1,1] := SettingFile[ 0];
  ValueListEditorGlobal.Cells[1,2] := SettingFile[ 1];
  ValueListEditorGlobal.Cells[1,3] := SettingFile[ 2];

  // Explosion
  Explosion.BaseTexture            := SettingFile[ 3];
  ValueListEditorBase.Cells[1,1]   := SettingFile[ 4];
  ValueListEditorBase.Cells[1,2]   := SettingFile[ 5];
  ValueListEditorBase.Cells[1,3]   := SettingFile[ 6];
  ValueListEditorBase.Cells[1,4]   := SettingFile[ 7];
  ValueListEditorBase.Cells[1,5]   := SettingFile[ 8];
  ValueListEditorBase.Cells[1,6]   := SettingFile[ 9];

  // Sparks
  Explosion.SparkTexture           := SettingFile[10];
  ValueListEditorSpark.Cells[1,1]  := SettingFile[11];
  ValueListEditorSpark.Cells[1,2]  := SettingFile[12];
  ValueListEditorSpark.Cells[1,3]  := SettingFile[13];
  ValueListEditorSpark.Cells[1,4]  := SettingFile[14];
  ValueListEditorSpark.Cells[1,5]  := SettingFile[15];
  ValueListEditorSpark.Cells[1,6]  := SettingFile[16];

  // New properties in 1.1
  if SettingFile.Count > 17 then begin
  	ComboBoxType.ItemIndex := StrToIntDef(SettingFile[17], 0);
    CheckBoxFlip.Checked	 := StrToBoolDef(SettingFile[18], False);
  end;

  SettingFile.Free;
end;

// =============================================================================
//  TGLForm.FormDestroy
// =============================================================================
procedure TGLForm.FormDestroy(Sender: TObject);
begin
  SaveSettings(ExtractFilePath(Application.ExeName)+'\settings.cfg');
  if Assigned(TextureManager) then
  	TextureManager.Free;
  if Assigned(Explosion) then
  	Explosion.Free;
  if RC <> 0 then begin
    DeactivateRenderingContext;
    wglDeleteContext(RC);
    ReleaseDC(Handle, DC);
  end;
end;

procedure TGLForm.About1Click(Sender: TObject);
begin
	ShellExecute(Handle, 'open', PChar(ExtractFilePath(Application.ExeName)+'\readme.html'), '', '', sw_Show);
end;

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
glClearColor(BGColor.x, BGColor.y, BGColor.z, 0);
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

if Explosion._Type = ExplosionTypeDefault then
	TF := (QPCe-QPCs) / QPCf
else
	TF := (QPCe-QPCs) / QPCf * 0.35;

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
