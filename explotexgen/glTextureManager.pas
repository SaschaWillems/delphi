unit glTextureManager;

interface

uses
 Windows,
 Forms,
 IniFiles,
 SysUtils,
 Graphics,
 Classes,

 glMisc,
 Textures,
 dglOpenGL,
 PackageUnit;

const
 TTexInfoFormat = $01;
 TTexInfoWidth  = $02;
 TTexInfoHeight = $03;
 TTexInfoID     = $04;

type
 TLogCallBackProc = procedure (pMessage : String; pAddToLog : Boolean = True);
 TBlendMode = (bmNone, bmBlend, bmAdd, bmModulate);

 // == TTextureManager =========================================================
 TTextureInfo = record
   Format : Cardinal;
   Target : Cardinal;
   ID     : Cardinal;
   Width  : Word;
   Height : Word;
  end;
 // == TTextureManager =========================================================
 TTextureManager  = class
   Texture          : array of TGLUInt;
   TextureInfo      : array of TTextureInfo;
   TextureName      : THashedStringList;
   Log              : TStringList;
   LogCallBack      : TLogCallBackProc;
   constructor Create; overload;
   destructor Destroy; override;
   function GetTextureInfo(pTextureName : String;pTexInfo : Word) : Integer;
   function GetTotalTextureMemoryConsumption : Int64;
   procedure DrawBlankQuad(pX, pY, pZ, pWidth, pHeight : Single);
   procedure DrawQuad(pX, pY, pZ : Single; pTexture : String); overload;
   procedure DrawQuadCenter(pX, pY, pZ : Single; pTexture : String; pScale : Single = 1);
   procedure DrawQuadEx(pX, pY, pZ, pWidth, pHeight : Single; pTexture : String); overload;
   procedure DrawQuadExCenter(pX, pY, pZ, pWidth, pHeight : Single; pTexture : String; pS : Single = 1; pT : Single = 1);
   procedure DrawQuadEx(pX, pY, pZ, pWidth, pHeight : Single; pTextureID : gluInt); overload;
   procedure DrawQuadEx2(pX, pY, pZ, pWidth, pHeight, pSStart,pSEnd,pTStart,pTEnd : Single; pTexture : String); overload;
   procedure DrawQuadEx2(pX, pY, pZ, pWidth, pHeight, pSStart,pSEnd,pTStart,pTEnd : Single; pTextureID : glUInt); overload;
   procedure DrawQuadEx2Center(pX, pY, pZ, pWidth, pHeight, pSStart,pSEnd,pTStart,pTEnd : Single; pTexture : String); overload;
   procedure AddTexturesInDir(pDirName, pFileMask : String;pUseTexCompression : Boolean;pExcludePrefix : String='');
   procedure AddTexturesInPackage(pPackage : TPackage; pExcludePrefix : String = ''; pDirName : String = '');
   function AddTexture(pFileName, pTextureName : String;pUseTexCompression : Boolean) : Word; overload;
   function AddTexture(pFileName, pTextureName : String;pPackage : TPackage; pUseTexCompression : Boolean) : Word; overload;
   procedure AddTextureByID(pID : glUInt; pTextureName : String);
   procedure BindTexture(pTextureName : String;pTextureUnit : Cardinal); overload;
   procedure BindTexture(pTextureID : glUInt;pTextureUnit : Cardinal); overload;
   procedure DisableTextureStage(pTextureStage : Cardinal);
   procedure SetWrapMode(pWrapModeS, pWrapModeT : glUInt; pTarget : glUInt = GL_TEXTURE_2D); overload;
   procedure SetWrapMode(pTextureID, pWrapModeS, pWrapModeT : glUInt; pTarget : glUInt = GL_TEXTURE_2D); overload;
   procedure SetFilterMode(pTextureID, pMinMode, pMagMode : glUInt);
   procedure SetBlending(pBlendMode : TBlendMode);
   procedure DeleteTexture(pTextureName : String);
   procedure Flush;
   procedure DrawEmptyQuad(pX, pY, pZ, pWidth, pHeight : Single);
  end;

var
 TextureManager : TTextureManager;

implementation

function IsPOT(pWidth, pHeight : Word) : Boolean;
const
 Size : array[0..11] of Word = (2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096);
var
 i        : Integer;
 WOK, HOK : Boolean;
begin
Result := False;
WOK    := False;
HOK    := False;
for i := 0 to High(Size) do
 if pWidth = Size[i] then
  WOK := True;
for i := 0 to High(Size) do
 if pHeight = Size[i] then
  HOK := True;
if WOK and HOK then
 Result := True;
end;

// =============================================================================
// =============================================================================
//  TTextureManager
// =============================================================================
// =============================================================================

// =============================================================================
//  TTextureManager.Create                                       - CONSTRUCTOR -
// =============================================================================
constructor TTextureManager.Create;
begin
inherited;
TextureName := THashedStringList.Create;
Log         := TStringList.Create;
end;

// =============================================================================
//  TTextureManager.Destroy                                       - DESTRUCTOR -
// =============================================================================
destructor TTextureManager.Destroy;
var
 i : Integer;
begin
if Length(Texture) > 0 then
 for i := Low(Texture) to High(Texture) do
  glDeleteTextures(1, @Texture[i]);
TextureName.Free;
//Log.SaveToFile(ExtractFilePath(Application.ExeName)+'\texturemanager_log.html');
Log.Free;
inherited;
end;

// =============================================================================
//  TTextureManager.GetTextureInfo
// =============================================================================
function TTextureManager.GetTextureInfo(pTextureName : String;pTexInfo : Word) : Integer;
var
 TexIndex : Integer;
begin
Result   := 0;
if pTexInfo = TTexInfoID then
 Result := -1;
TexIndex := TextureName.IndexOf(pTextureName);
if TexIndex = -1 then
 exit
else
 case pTexInfo of
  TTexInfoFormat : Result := TextureInfo[TexIndex].Format;
  TTexInfoWidth  : Result := TextureInfo[TexIndex].Width;
  TTexInfoHeight : Result := TextureInfo[TexIndex].Height;
  TTexInfoID     : Result := TextureInfo[TexIndex].ID;
 end;
end;

// =============================================================================
//  TTextureManager.GetTotalTextureMemoryConsumption
// =============================================================================
function TTextureManager.GetTotalTextureMemoryConsumption : Int64;
var
 i : Integer;
begin
Result := 0;
if Length(TextureInfo) > 0 then
 for i := 0 to High(TextureInfo) do
  case TextureInfo[i].Format of
   GL_RGB  : inc(Result, TextureInfo[i].Width*TextureInfo[i].Height*3);
   GL_RGBA : inc(Result, TextureInfo[i].Width*TextureInfo[i].Height*4);
  end;
end;

// =============================================================================
//  TTextureManager.DrawBlankQuad
// =============================================================================
procedure TTextureManager.DrawBlankQuad(pX, pY, pZ, pWidth, pHeight : Single);
begin
glBegin(GL_QUADS);
 glTexCoord2f(0,0); glVertex3f(pX,        pY+pHeight, pZ);
 glTexCoord2f(0,1); glVertex3f(pX,        pY,         pZ);
 glTexCoord2f(1,1); glVertex3f(pX+pWidth, pY,         pZ);
 glTexCoord2f(1,0); glVertex3f(pX+pWidth, pY+pHeight, pZ);
glEnd;
end;

// =============================================================================
//  TTextureManager.DrawQuad
// =============================================================================
procedure TTextureManager.DrawQuad(pX, pY, pZ : Single; pTexture : String);
var
 Tex : Integer;
begin
glActiveTexture(GL_TEXTURE0);
Tex := TextureName.IndexOf(pTexture);
if Tex < 0 then
 exit;
glEnable(TextureInfo[Tex].Target);
glBindTexture(GL_TEXTURE_2D, TextureInfo[Tex].ID);
//glBindTexture(TextureInfo[Tex].Target, TextureInfo[Tex].ID);
glBegin(GL_QUADS);
 glTexCoord2f(0,0); glVertex3f(pX,                        pY+TextureInfo[Tex].Height, pZ);
 glTexCoord2f(0,1); glVertex3f(pX,                        pY,   pZ);
 glTexCoord2f(1,1); glVertex3f(pX+TextureInfo[Tex].Width, pY,   pZ);
 glTexCoord2f(1,0); glVertex3f(pX+TextureInfo[Tex].Width, pY+TextureInfo[Tex].Height, pZ);
glEnd;
end;

// =============================================================================
//  TTextureManager.DrawQuadCenter
// =============================================================================
procedure TTextureManager.DrawQuadCenter(pX, pY, pZ : Single; pTexture : String; pScale : Single = 1);
var
 Tex : Integer;
begin
glActiveTexture(GL_TEXTURE0);
Tex := TextureName.IndexOf(pTexture);
if Tex < 0 then
 exit;
glEnable(TextureInfo[Tex].Target);
glBindTexture(TextureInfo[Tex].Target, TextureInfo[Tex].ID);
glBegin(GL_QUADS);
 glTexCoord2f(0,0); glVertex3f(pX-TextureInfo[Tex].Width/2*pScale,  pY+TextureInfo[Tex].Height/2*pScale, pZ);
 glTexCoord2f(0,1); glVertex3f(pX-TextureInfo[Tex].Width/2*pScale,  pY-TextureInfo[Tex].Height/2*pScale, pZ);
 glTexCoord2f(1,1); glVertex3f(pX+TextureInfo[Tex].Width/2*pScale,  pY-TextureInfo[Tex].Height/2*pScale, pZ);
 glTexCoord2f(1,0); glVertex3f(pX+TextureInfo[Tex].Width/2*pScale,  pY+TextureInfo[Tex].Height/2*pScale, pZ);
glEnd;
end;

// =============================================================================
//  TTextureManager.DrawQuadEx
// =============================================================================
procedure TTextureManager.DrawQuadEx(pX, pY, pZ, pWidth, pHeight : Single; pTexture : String);
var
 Tex : Integer;
begin
if pTexture <> '' then
 begin
 Tex :=  TextureName.IndexOf(pTexture);
 if Tex < 0 then
  exit;
 glActiveTexture(GL_TEXTURE0);
 glEnable(GL_TEXTURE_2D);
 glBindTexture(GL_TEXTURE_2D, TextureInfo[Tex].ID);
 end;
//glEnable(TextureInfo[Tex].Target);
//glBindTexture(TextureInfo[Tex].Target, TextureInfo[Tex].ID);
glBegin(GL_QUADS);
 glTexCoord2f(0,0); glVertex3f(pX,        pY+pHeight, pZ);
 glTexCoord2f(0,1); glVertex3f(pX,        pY,         pZ);
 glTexCoord2f(1,1); glVertex3f(pX+pWidth, pY,         pZ);
 glTexCoord2f(1,0); glVertex3f(pX+pWidth, pY+pHeight, pZ);
glEnd;
end;

// =============================================================================
//  TTextureManager.DrawQuadExCenter
// =============================================================================
procedure TTextureManager.DrawQuadExCenter(pX, pY, pZ, pWidth, pHeight : Single; pTexture : String; pS : Single = 1; pT : Single = 1);
var
 Tex : Integer;
begin
if pTexture <> '' then
 begin
 Tex :=  TextureName.IndexOf(pTexture);
 if Tex < 0 then
  exit;
 glActiveTexture(GL_TEXTURE0);
 glEnable(GL_TEXTURE_2D);
 glBindTexture(GL_TEXTURE_2D, TextureInfo[Tex].ID);
 end;
glBegin(GL_QUADS);
 glTexCoord2f(0,  0);  glVertex3f(pX-pWidth/2, pY+pHeight/2, pZ);
 glTexCoord2f(0,  pT); glVertex3f(pX-pWidth/2, pY-pHeight/2, pZ);
 glTexCoord2f(pS, pT); glVertex3f(pX+pWidth/2, pY-pHeight/2, pZ);
 glTexCoord2f(pS, 0);  glVertex3f(pX+pWidth/2, pY+pHeight/2, pZ);
glEnd;
end;


// =============================================================================
//  TTextureManager.DrawQuadEx
// =============================================================================
procedure TTextureManager.DrawQuadEx(pX, pY, pZ, pWidth, pHeight : Single; pTextureID : gluInt);
begin
glEnable(GL_TEXTURE_2D);
glBindTexture(GL_TEXTURE_2D, pTextureID);
glBegin(GL_QUADS);
 glTexCoord2f(0,0); glVertex3f(pX,        pY+pHeight, pZ);
 glTexCoord2f(0,1); glVertex3f(pX,        pY,         pZ);
 glTexCoord2f(1,1); glVertex3f(pX+pWidth, pY,         pZ);
 glTexCoord2f(1,0); glVertex3f(pX+pWidth, pY+pHeight, pZ);
glEnd;
end;


// =============================================================================
//  TTextureManager.DrawQuadEx2
// =============================================================================
procedure TTextureManager.DrawQuadEx2(pX, pY, pZ, pWidth, pHeight, pSStart,pSEnd,pTStart,pTEnd : Single; pTexture : String);
var
 Tex : Integer;
begin
Tex :=  TextureName.IndexOf(pTexture);
if Tex < 0 then
 exit;
glBindTexture(TextureInfo[Tex].Target, TextureInfo[Tex].ID);
glBegin(GL_QUADS);
 glTexCoord2f(pSEnd,  pTStart); glVertex3f(pX+pWidth, pY+pHeight, pZ);
 glTexCoord2f(pSEnd,  pTEnd);   glVertex3f(pX+pWidth, pY,         pZ);
 glTexCoord2f(pSStart,pTEnd);   glVertex3f(pX,        pY,         pZ);
 glTexCoord2f(pSStart,pTStart); glVertex3f(pX,        pY+pHeight, pZ);
glEnd;
end;

// =============================================================================
//  TTextureManager.DrawQuadEx2
// =============================================================================
procedure TTextureManager.DrawQuadEx2(pX, pY, pZ, pWidth, pHeight, pSStart,pSEnd,pTStart,pTEnd : Single; pTextureID : glUInt);
begin
glBindTexture(GL_TEXTURE_2D, pTextureID);
glBegin(GL_QUADS);
 glTexCoord2f(pSStart,pTStart); glVertex3f(pX,        pY+pHeight, pZ);
 glTexCoord2f(pSStart,pTEnd);   glVertex3f(pX,        pY,         pZ);
 glTexCoord2f(pSEnd,  pTEnd);   glVertex3f(pX+pWidth, pY,         pZ);
 glTexCoord2f(pSEnd,  pTStart); glVertex3f(pX+pWidth, pY+pHeight, pZ);
glEnd;
end;

// =============================================================================
//  TTextureManager.DrawQuadEx2Center
// =============================================================================
procedure TTextureManager.DrawQuadEx2Center(pX, pY, pZ, pWidth, pHeight, pSStart,pSEnd,pTStart,pTEnd : Single; pTexture : String);
var
 Tex : Integer;
begin
Tex :=  TextureName.IndexOf(pTexture);
if Tex < 0 then
 exit;
glBindTexture(TextureInfo[Tex].Target, TextureInfo[Tex].ID);
glBegin(GL_QUADS);
 glTexCoord2f(pSStart,pTStart); glVertex3f(pX-pWidth/2, pY+pHeight/2, pZ);
 glTexCoord2f(pSStart,pTEnd);   glVertex3f(pX-pWidth/2, pY-pHeight/2, pZ);
 glTexCoord2f(pSEnd,  pTEnd);   glVertex3f(pX+pWidth/2, pY-pHeight/2, pZ);
 glTexCoord2f(pSEnd,  pTStart); glVertex3f(pX+pWidth/2, pY+pHeight/2, pZ);
glEnd;
end;

// =============================================================================
//  TTextureManager.AddTexturesInDir
// =============================================================================
procedure TTextureManager.AddTexturesInDir(pDirName, pFileMask : String;pUseTexCompression : Boolean;pExcludePrefix : String='');
var
 SR      : TSearchRec;
 i       : Integer;
 TexName : String;
 OldDir  : String;
begin
OldDir := GetCurrentDir;
ChDir(pDirName);
if FindFirst(pFileMask, faAnyFile, SR) = 0 then
 repeat
 TexName := '';
 for i := 1 to Length(SR.Name) do
  begin
  if SR.Name[i] = '.' then
   break;
  TexName := TexName+SR.Name[i];
  end;
 //Log.Add(SR.Name+'/'+TexName);
 if pExcludePrefix <> '' then
  if Pos(pExcludePrefix, TexName) = 1 then
   continue;
 AddTexture(SR.Name, TexName, pUseTexCompression);
 until FindNext(SR) <> 0;
FindClose(SR);
ChDir(OldDir);
end;

// =============================================================================
//  TTextureManager.AddTexturesInPackage
// =============================================================================
procedure TTextureManager.AddTexturesInPackage(pPackage : TPackage; pExcludePrefix : String = '';pDirName : String = '');
var
 i,j     : Integer;
 TexName : String;
 TexID   : Cardinal;
begin
if Length(pPackage.FileInfo) > 0 then
 for i := 0 to High(pPackage.FileInfo) do
  if (LowerCase(ExtractFileExt(pPackage.FileInfo[i].FileName)) = '.jpg') or
     (LowerCase(ExtractFileExt(pPackage.FileInfo[i].FileName)) = '.tga') or
     (LowerCase(ExtractFileExt(pPackage.FileInfo[i].FileName)) = '.bmp') then
      begin
      if pDirName <> '' then
       if pPackage.FileInfo[i].Dir <> pDirName then
        continue;
      TexName := '';
      for j := 1 to Length(pPackage.FileInfo[i].FileName) do
       begin
       if pPackage.FileInfo[i].FileName[j] = '.' then
        break;
       TexName := TexName+pPackage.FileInfo[i].FileName[j];
       end;
      // Prefix testen und ggf. überspringen
      if pExcludePrefix <> '' then
       if Pos(pExcludePrefix, pPackage.FileInfo[i].FileName) = 1 then
        continue;
      pPackage.SeekFile(pPackage.FileInfo[i].FileName);
      if (LowerCase(ExtractFileExt(pPackage.FileInfo[i].FileName)) = '.jpg') then
       begin
       LoadJPGTextureFromStream(pPackage.Stream, TexID, GL_LINEAR, GL_LINEAR_MIPMAP_LINEAR, False);
       AddTextureByID(TexID, TexName);
       end;
      if (LowerCase(ExtractFileExt(pPackage.FileInfo[i].FileName)) = '.tga') then
       begin
       Textures.CurrFileSize := pPackage.GetFileSize(pPackage.FileInfo[i].FileName);
       LoadTGATextureFromStream(pPackage.Stream, TexID, GL_LINEAR, GL_LINEAR_MIPMAP_LINEAR, False);
       AddTextureByID(TexID, TexName);
       end;
      if (LowerCase(ExtractFileExt(pPackage.FileInfo[i].FileName)) = '.bmp') then
       begin
       pPackage.ExtractFile(pPackage.FileInfo[i].FileName, '_tmp'+LowerCase(ExtractFileExt(pPackage.FileInfo[i].FileName)));
       AddTexture('_tmp'+LowerCase(ExtractFileExt(pPackage.FileInfo[i].FileName)), TexName, False);
       DeleteFile('_tmp'+LowerCase(ExtractFileExt(pPackage.FileInfo[i].FileName)));
       end;
      end;
end;

// =============================================================================
//  TTextureManager.AddTextureByID
// =============================================================================
procedure TTextureManager.AddTextureByID(pID : glUInt; pTextureName : String);
begin
pTextureName := UpperCase(pTextureName);
SetLength(Texture, Length(Texture)+1);
TextureName.Add(pTextureName);
SetLength(TextureInfo, Length(TextureInfo)+1);
Texture[High(Texture)] := pID;
with TextureInfo[High(TextureInfo)] do
 begin
 Format := LastFormat;
 Width  := LastWidth;
 Height := LastHeight;
 ID     := pID;
 Target := LastBinding;
 end;
Log.Add(TimeToStr(Now)+' : TextureManager->AddTextureByID->"'+pTextureName+'(ID='+IntToStr(pID)+')"<br>');
//if Assigned(LogCallBack) then
// LogCallBack('TextureManager->AddTexture->'+pTextureName, False);
end;

// =============================================================================
//  TTextureManager.AddTexture
// =============================================================================
function TTextureManager.AddTexture(pFileName, pTextureName : String;pUseTexCompression : Boolean) : Word;
begin
if not FileExists(pFileName) then
 begin
 Result := 0;
 Log.Add(TimeToStr(Now)+' : TextureManager->AddTexture->"'+pTextureName+'"->File not found<br>');
 exit;
 end;
if not glIsExtSupported('GL_ARB_texture_compression') then
 pUseTexCompression := False;
if (TextureName.IndexOf(pTextureName) > -1) or (TextureName.IndexOf(pTextureName) > -1) then
 begin
 Result := TextureName.IndexOf(pTextureName);
 Log.Add(TimeToStr(Now)+' : TextureManager->AddTexture->"'+pTextureName+'"->Already in list<br>');
 exit;
 end;
SetLength(Texture, Length(Texture)+1);
TextureName.Add(pTextureName);
LoadTexture(pFileName, Texture[High(Texture)], pUseTexCompression);
SetLength(TextureInfo, Length(TextureInfo)+1);
with TextureInfo[High(TextureInfo)] do
 begin
 Format := LastFormat;
 Width  := LastWidth;
 Height := LastHeight;
 ID     := LastID;
 Target := LastBinding;
 if not IsPOT(Width, Height) then
  if Assigned(LogCallBack) then
   LogCallBack('TextureManager->AddTexture->WARNING : Texture "'+pFileName+'" is NPOT!');
 end;
Log.Add(TimeToStr(Now)+' : TextureManager->AddTexture->"'+pTextureName+'" (Size = '+IntToStr(Textures.LastWidth)+'x'+IntToStr(Textures.LastHeight)+')<br>');
if Assigned(LogCallBack) then
 if pUseTexCompression then
  LogCallBack('TextureManager->AddTexture->'+pTextureName+' [compressed]', False)
 else
  LogCallBack('TextureManager->AddTexture->'+pTextureName, False);
Result := High(TextureInfo);
end;

// =============================================================================
//  TTextureManager.AddTexture                                       - PACKAGE -
// =============================================================================
function TTextureManager.AddTexture(pFileName, pTextureName : String;pPackage : TPackage; pUseTexCompression : Boolean) : Word;
begin
if not glIsExtSupported('GL_ARB_texture_compression') then
 pUseTexCompression := False;
if (TextureName.IndexOf(pTextureName) > -1) or (TextureName.IndexOf(copy(pTextureName, 1, Length(pTextureName))) > -1) then
 begin
 Result := TextureName.IndexOf(pTextureName);
 Log.Add(TimeToStr(Now)+' : TextureManager->AddTexture->"'+pTextureName+'"->Already in list');
 exit;
 end;
SetLength(Texture, Length(Texture)+1);
SetLength(TextureInfo, Length(TextureInfo)+1);
TextureName.Add(pTextureName);
pFileName := LowerCase(pFileName);
if Pos('.tga', pFileName) > 0 then
 begin
 CurrFileSize := pPackage.GetFileSize(pFileName);
 pPackage.SeekFile(pFileName);
 LoadTGATextureFromStream(pPackage.Stream, Texture[High(Texture)], GL_LINEAR, GL_LINEAR_MIPMAP_LINEAR, pUseTexCompression);
 end
else
 if Pos('.jpg', pFileName) > 0 then
  begin
  CurrFileSize := pPackage.GetFileSize(pFileName);
  pPackage.SeekFile(pFileName);
  LoadJPGTextureFromStream(pPackage.Stream, Texture[High(Texture)], GL_LINEAR, GL_LINEAR_MIPMAP_LINEAR, pUseTexCompression);
  end
 else
  raise Exception.Create('TTextureManager->AddTexture->Only JPG or TGA can be loaded from package!');
with TextureInfo[High(TextureInfo)] do
 begin
 Format := LastFormat;
 Width  := LastWidth;
 Height := LastHeight;
 ID     := LastID;
 Target := LastBinding;
 end;
Log.Add(TimeToStr(Now)+' : TextureManager->AddTexture->"'+copy(pTextureName, 0, Length(pTextureName)-4)+'"');
Result := High(TextureInfo);
end;

// =============================================================================
//  TTextureManager.BindTexture
// =============================================================================
procedure TTextureManager.BindTexture(pTextureName : String; pTextureUnit : Cardinal);
var
 TexIndex : Integer;
begin
TexIndex := TextureName.IndexOf(pTextureName);
if TexIndex < 0 then
 begin
 if Pos('.', pTextureName) > 0 then
  begin
  pTextureName := Copy(pTextureName, 1, Pos('.', pTextureName)-1);
  TexIndex     := TextureName.IndexOf(pTextureName);
  end;
 if TexIndex < 0 then
  exit;
 end;
glActiveTexture(pTextureUnit);
//glEnable(TextureInfo[TexIndex].Target);
glEnable(GL_TEXTURE_2D);
glBindTexture(GL_TEXTURE_2D, Texture[TexIndex]);
//glBindTexture(TextureInfo[TexIndex].Target, Texture[TexIndex]);
if TextureInfo[TexIndex].Format = GL_RGBA then
 begin
 glEnable(GL_ALPHA_TEST);
 glAlphaFunc(GL_GREATER, 0.1);
 end
else
 glDisable(GL_ALPHA_TEST);
end;

procedure TTextureManager.BindTexture(pTextureID : glUInt;pTextureUnit : Cardinal);
var
 TexIndex : Integer;
 i        : Integer;
begin
TexIndex := -1;
for i := 0 to High(TextureInfo) do
 if TextureInfo[i].ID = pTextureID then
  TexIndex := i;
glActiveTexture(pTextureUnit);
if TexIndex > -1 then
 begin
 glEnable(GL_TEXTURE_2D);
 glBindTexture(GL_TEXTURE_2D, Texture[TexIndex]);
// glEnable(TextureInfo[TexIndex].Target);
// glBindTexture(TextureInfo[TexIndex].Target, Texture[TexIndex]);
 if TextureInfo[TexIndex].Format = GL_RGBA then
  begin
  glEnable(GL_ALPHA_TEST);
  glAlphaFunc(GL_GREATER, 0.1);
  end
 else
  glDisable(GL_ALPHA_TEST);
 end
else
 begin
 glEnable(GL_TEXTURE_2D);
 glBindTexture(GL_TEXTURE_2D, pTextureID);
 end;
end;

// =============================================================================
//  TTextureManager.DisableTextureStage
// =============================================================================
procedure TTextureManager.DisableTextureStage(pTextureStage : Cardinal);
begin
glActiveTexture(pTextureStage);
glDisable(GL_TEXTURE_1D);
glDisable(GL_TEXTURE_2D);
glDisable(GL_TEXTURE_3D);
glDisable(GL_ALPHA_TEST);
glDisable(GL_BLEND);
end;

// =============================================================================
//  TTextureManager.DeleteTexture
// =============================================================================
procedure TTextureManager.SetWrapMode(pWrapModeS, pWrapModeT : glUInt; pTarget : glUInt = GL_TEXTURE_2D);
begin
glTexParameteri(pTarget, GL_TEXTURE_WRAP_S, pWrapModeS);
glTexParameteri(pTarget, GL_TEXTURE_WRAP_T, pWrapModeT);
end;

procedure TTextureManager.SetWrapMode(pTextureID, pWrapModeS, pWrapModeT : glUInt; pTarget : glUInt = GL_TEXTURE_2D);
begin
glBindTexture(GL_TEXTURE_2D, pTextureID);
glTexParameteri(pTarget, GL_TEXTURE_WRAP_S, pWrapModeS);
glTexParameteri(pTarget, GL_TEXTURE_WRAP_T, pWrapModeT);
end;

// =============================================================================
//  TTextureManager.SetFilterMode
// =============================================================================
procedure TTextureManager.SetFilterMode(pTextureID, pMinMode, pMagMode : glUInt);
begin
glBindTexture(GL_TEXTURE_2D, pTextureID);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, pMagMode);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, pMinMode);
end;

// =============================================================================
//  TTextureManager.SetBlending
// =============================================================================
procedure TTextureManager.SetBlending(pBlendMode : TBlendMode);
begin
case pBlendMode of
 bmNone     : glDisable(GL_BLEND);
 bmBlend    : begin
              glEnable(GL_BLEND);
              glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
              end;
 bmAdd      : begin
              glEnable(GL_BLEND);
              glBlendFunc(GL_SRC_ALPHA, GL_ONE);
//              glBlendFunc(GL_ONE, GL_ONE);
              end;
 bmModulate : begin
              glEnable(GL_BLEND);
              glBlendFunc(GL_DST_COLOR, GL_ZERO);
              end;
end;
end;

// =============================================================================
//  TTextureManager.DeleteTexture
// =============================================================================
procedure TTextureManager.DeleteTexture(pTextureName : String);
var
 TmpIndex : Integer;
 i        : Integer;
begin
TmpIndex := TextureName.IndexOf(LowerCase(pTextureName));
if TmpIndex = -1 then
 exit;
glDeleteTextures(1, @Texture[TmpIndex]);
if Length(TextureInfo) > 1 then
 for i := TmpIndex to High(TextureInfo)-1 do
  begin
  TextureInfo[i].Format := TextureInfo[i+1].Format;
  TextureInfo[i].Target := TextureInfo[i+1].Target;
  TextureInfo[i].ID     := TextureInfo[i+1].ID;
  TextureInfo[i].Width  := TextureInfo[i+1].Width;
  TextureInfo[i].Height := TextureInfo[i+1].Height;
  Texture[i]            := Texture[i+1];
  end;
SetLength(TextureInfo, Length(TextureInfo)-1);
SetLength(Texture, Length(Texture)-1);
TextureName.Delete(TmpIndex);
end;

// =============================================================================
//  TTextureManager.Flush
// =============================================================================
procedure TTextureManager.Flush;
var
 i : Integer;
begin
if Length(TextureInfo) > 0 then
 for i := 0 to High(TextureInfo) do
  glDeleteTextures(1, @TextureInfo[i].ID);
SetLength(TextureInfo, 0);
SetLength(Texture, 0);
TextureName.Clear;
//Log.SaveToFile(ExtractFilePath(Application.ExeName)+'cleartexman.txt');
end;

// =============================================================================
//  TTextureManager.DrawEmptyQuad
// =============================================================================
procedure TTextureManager.DrawEmptyQuad(pX, pY, pZ, pWidth, pHeight : Single);
begin
glBegin(GL_QUADS);
 glVertex3f(pX,        pY,         pZ);
 glVertex3f(pX,        pY+pHeight, pZ);
 glVertex3f(pX+pWidth, pY+pHeight, pZ);
 glVertex3f(pX+pWidth, pY,         pZ);
glEnd;
end;


end.
