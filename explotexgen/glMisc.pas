unit glMisc;

interface

uses
 SysUtils,
// JPEG,
 Windows,
 Graphics,
 Classes,
 Dialogs,

 GDIPAPI,
 GDIPOBJ,
 GDIPUTIL,

 Math,
 dglOpenGL;

type
 TMatrix16f = array[0..15] of Single;
 TVector4f  = array[0..3] of Single;

 PRGBQuad = ^TRGBQuad;
 TRGBQuad = packed record
   Red   : Byte;
   Green : Byte;
   Blue  : Byte;
   Alpha : Byte;
  end;

 TGammaRamp = packed record
   R : array[0..255] of Word;
   G : array[0..255] of Word;
   B : array[0..255] of Word;
  end;

var
 OldGamma       : TGammaRamp;
 CurrGamma      : TGammaRamp;
 ColorSelection : record
   RGB      : array[0..2] of Integer;
   RGBStep  : Integer;
   RGBIndex : Byte;
  end;

// Color selection
procedure ColorSelection_Init(pRGBStep : Integer);
procedure ColorSelection_SetAndInc;
function ColorSelection_GetIndex(pSelectedColor : array of Byte) : Integer;
// Misc
function glStringToEnum(pString : String) : glEnum;
function glGetErrorStr(pErrorCode : Integer = -1) : String;
function glIsExtSupported(fExtName : String) : Boolean;
function wglIsExtSupported(fExtName : String) : Boolean;
function VertexToStr(px,py,pZ : Single) : String;
//procedure glSaveScreen(pFilename : String);
procedure glSaveScreenAsPNG(pFilename : String; pWithAlpha : Boolean = True);
// GammaRamp
function IsGammaRampSupported : Boolean;
function SetGamma(Value : Single) : TGammaRamp;
procedure RestoreOldGamma;
procedure StoreOldGamma;

function CalculateShadowMatrix(fLightPos : TVector4f;fPlane : TVector4f) : TMatrix16f;

procedure RenderCircle(pDetail : Integer; pScale : Single);

implementation

// =============================================================================
//  ColorSelection_Init
// =============================================================================
procedure ColorSelection_Init(pRGBStep : Integer);
begin
ColorSelection.RGBStep  := pRGBStep;
ColorSelection.RGB[0]   := 0;
ColorSelection.RGB[1]   := 0;
ColorSelection.RGB[2]   := 0;
ColorSelection.RGBIndex := 0;
end;

// =============================================================================
//  ColorSelection_SetAndInc
// =============================================================================
procedure ColorSelection_SetAndInc;
begin
inc(ColorSelection.RGB[ColorSelection.RGBIndex], ColorSelection.RGBStep);
if ColorSelection.RGB[ColorSelection.RGBIndex] = 255 then
 begin
 ColorSelection.RGB[ColorSelection.RGBIndex] := 0;
 inc(ColorSelection.RGBIndex);
 ColorSelection.RGB[ColorSelection.RGBIndex] := ColorSelection.RGBStep;
 end;
if ColorSelection.RGBIndex > 2 then
 ColorSelection.RGBIndex := 2;
glColor3f(ColorSelection.RGB[0]/255, ColorSelection.RGB[1]/255, ColorSelection.RGB[2]/255);
end;

// =============================================================================
//  ColorSelection_GetIndex
// =============================================================================
function ColorSelection_GetIndex(pSelectedColor : array of Byte) : Integer;
var
 n : Integer;
begin
Result := -1;
n      := 0;
with ColorSelection do
 begin
 RGB[0]   := RGBStep;
 RGB[1]   := 0;
 RGB[2]   := 0;
 RGBIndex := 0;
 repeat
 if (RGB[0] = pSelectedColor[0]) and (RGB[1] = pSelectedColor[1]) and (RGB[2] = pSelectedColor[2]) then
  begin
  Result := n;
  exit;
  end;
 inc(RGB[RGBIndex], RGBStep);
 if (RGB[RGBIndex] = 255) and (RGBIndex < 2) then
  begin
  RGB[RGBIndex] := 0;
  inc(RGBIndex);
  end;
 inc(n);
 until RGB[2] = 255;
 end;
end;

// =============================================================================
//  glStringToEnum
// =============================================================================
function glStringToEnum(pString : String) : glEnum;
var
 i : Integer;
begin
Result := 0;
for i := 0  to 31 do
 if pString = 'GL_TEXTURE'+IntToStr(i) then
  begin
  Result := GL_TEXTURE0+i;
  exit;
  end;
if pString = 'GL_TEXTURE_3D' then Result := GL_TEXTURE_3D;
if pString = 'GL_TEXTURE_2D' then Result := GL_TEXTURE_2D;
if pString = 'GL_TEXTURE_1D' then Result := GL_TEXTURE_1D;
end;

// =============================================================================
//  glGetErrorStr
// =============================================================================
//  Gibt den letzten OpenGL-Fehler als String zurück
// =============================================================================
function glGetErrorStr(pErrorCode : Integer = -1) : String;
var
 glError : TGLUInt;
begin
if pErrorCode > -1 then
 glError := pErrorCode
else
 glError := glGetError;
case glError of
 GL_NO_ERROR          : Result := 'GL_NO_ERROR';
 GL_INVALID_ENUM      : Result := 'GL_INVALID_ENUM';
 GL_INVALID_VALUE     : Result := 'GL_INVALID_VALUE';
 GL_INVALID_OPERATION : Result := 'GL_INVALID_OPERATION';
 GL_STACK_OVERFLOW    : Result := 'GL_STACK_OVERFLOW';
 GL_STACK_UNDERFLOW   : Result := 'GL_STACK_UNDERFLOW';
 GL_OUT_OF_MEMORY     : Result := 'GL_OUT_OF_MEMORY';
end;
end;

// =============================================================================
//  glIsExtSupported
// =============================================================================
//  Gibt TRUE zurück, falls die angefragte Extension unterstützt wird
// =============================================================================
function glIsExtSupported(fExtName : String) : Boolean;
var
 Ext       : array[1..512] of String;
 ExtString : String;
 ExtT      : String;
 i,k       : Integer;
begin
ExtString := glGetString(GL_EXTENSIONS);
k := 1;
for i := 1 to Length(ExtString) do
 begin
 if ExtString[i] = ' ' then
  begin
  Ext[k] := ExtT;
  inc(k);
  ExtT := '';
  end
 else
  ExtT := ExtT+ExtString[i];
 end;
Result := false;
for i := 1 to 512 do
 if UpperCase(Ext[i]) = UpperCase(fExtName) then
  Result := true;
end;

// =============================================================================
//  wglIsExtSupported
// =============================================================================
function wglIsExtSupported(fExtName : String) : Boolean;
var
 Ext       : array[1..512] of String;
 ExtString : String;
 ExtT      : String;
 i,k       : Integer;
begin
Result := False;
//if not Assigned(wglGetExtensionsString) then
// exit;
ExtString := wglGetExtensionsStringARB(wglGetCurrentDC);
k := 1;
for i := 1 to Length(ExtString) do
 begin
 if ExtString[i] = ' ' then
  begin
  Ext[k] := ExtT;
  inc(k);
  ExtT := '';
  end
 else
  ExtT := ExtT+ExtString[i];
 end;
Result := False;
for i := 1 to 512 do
 if UpperCase(Ext[i]) = UpperCase(fExtName) then
  Result := true;
end;

// =============================================================================
//  VertexToStr
// =============================================================================
function VertexToStr(px,py,pZ : Single) : String;
begin
Result := FloatToStrF(pX,ffNumber,8,3)+' | '+FloatToStrF(pY,ffNumber,8,3)+' | '+FloatToStrF(pZ,ffNumber,8,3);
end;

// =============================================================================
//  glSaveScreen
// =============================================================================
//  Speichert einen Screenshot des aktuellen Pufferinhaltes
// =============================================================================
(*
procedure glSaveScreen(pFilename : String);
var
 Viewport : array[0..3] of TGLint;
 JPG      : TJPEGImage;
 RGBBits  : PRGBQuad;
 Pixel    : PRGBQuad;
 BMP      : TBitmap;
 Header   : PBitmapInfo;
 x,y      : Integer;
 Temp     : Byte;
begin
glGetIntegerv(GL_VIEWPORT, @Viewport);
GetMem(RGBBits, Viewport[2]*Viewport[3]*4);
glFinish;
glPixelStorei(GL_PACK_ALIGNMENT, 4);
glPixelStorei(GL_PACK_ROW_LENGTH, 0);
glPixelStorei(GL_PACK_SKIP_ROWS, 0);
glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
glReadPixels(0, 0, Viewport[2], Viewport[3], GL_RGBA, GL_UNSIGNED_BYTE, RGBBits);
// Screenshot als JPG speichern
JPG := TJPEGImage.Create;
BMP := TBitmap.Create;
BMP.PixelFormat := pf32Bit;
BMP.Width       := Viewport[2];
BMP.Height      := Viewport[3];
GetMem(Header, SizeOf(TBitmapInfoHeader));
with Header^.bmiHeader do
 begin
 biSize        := SizeOf(TBitmapInfoHeader);
 biWidth       := Viewport[2];
 biHeight      := Viewport[3];
 biPlanes      := 1;
 biBitCount    := 32;
 biCompression := BI_RGB;
 biSizeImage   := Viewport[2]*Viewport[3]*4;
 end;
// Rot und Blau vertauschen
Pixel := RGBBits;
for x := 0 to Viewport[2]-1 do
 for y := 0 to Viewport[3]-1 do
  begin
  Temp       := Pixel.Red;
  Pixel.Red  := Pixel.Blue;
  Pixel.Blue := Temp;
  inc(Pixel);
  end;
SetDIBits(Bmp.Canvas.Handle, Bmp.Handle, 0, Viewport[3], RGBBits, TBitmapInfo(Header^), DIB_RGB_COLORS);
//BMP.SaveToFile(pFileName);
JPG.CompressionQuality := 100;
JPG.Compress;
JPG.Assign(BMP);
JPG.SaveToFile(pFileName);
FreeMem(Header);
FreeMem(RGBBits);
JPG.Free;
BMP.Free;
end;
*)

// =============================================================================
//  glSaveScreenAsPNG
// =============================================================================
procedure glSaveScreenAsPNG(pFilename : String; pWithAlpha : Boolean = True);
var
 Viewport : array[0..3] of TGLint;
 RGBBits  : PRGBQuad;
 Pixel    : PRGBQuad;
 x,y      : Integer;
 Temp     : Byte;
 GPBMP    : TGPBitmap;
 GPGUID   : TGUID;
// TmpS     : TMemoryStream;
begin
glGetIntegerv(GL_VIEWPORT, @Viewport);
GetMem(RGBBits, Viewport[2]*Viewport[3]*4);
//glFinish;
glPixelStorei(GL_PACK_ALIGNMENT, 4);
glPixelStorei(GL_PACK_ROW_LENGTH, 0);
glPixelStorei(GL_PACK_SKIP_ROWS, 0);
glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
glReadPixels(0, 0, Viewport[2], Viewport[3], GL_RGBA, GL_UNSIGNED_BYTE, RGBBits);
GPBMP := TGPBitmap.Create(Viewport[2], Viewport[3]);
Pixel := RGBBits;
for x := 0 to Viewport[3]-1 do
 for y := 0 to Viewport[2]-1 do
  begin
  if pWithAlpha then
   GPBMP.SetPixel(y, GPBMP.GetHeight-x-1, MakeColor(Pixel.Alpha, Pixel.Red, Pixel.Green, Pixel.Blue))
  else
   GPBMP.SetPixel(y, GPBMP.GetHeight-x-1, MakeColor(255, Pixel.Red, Pixel.Green, Pixel.Blue));
  inc(Pixel);
  end;
GetEncoderClsid('image/png', GPGUID);
GPBMP.Save(pFileName, GPGUID);
FreeMem(RGBBits);
GPBMP.Free;
end;


// =============================================================================
//  CalculateShadowMatrix
// =============================================================================
function CalculateShadowMatrix(fLightPos : TVector4f;fPlane : TVector4f) : TMatrix16f;
var
 Dot : Single;
begin
// Get the dot product of the light and the plane vectors
Dot := fPlane[0]*fLightPos[0] + fPlane[1]*fLightPos[1] + fPlane[2]*fLightPos[2] + fPlane[3]*fLightPos[3];
// First column
Result[ 0] := Dot - fLightPos[0] * fPlane[0];
Result[ 4] :=   0 - fLightPos[0] * fPlane[1];
Result[ 8] :=   0 - fLightPos[0] * fPlane[2];
Result[12] :=   0 - fLightPos[0] * fPlane[3];
// second column
Result[1]  :=   0 - fLightPos[1] * fPlane[0];
Result[5]  := Dot - fLightPos[1] * fPlane[1];
Result[9]  :=   0 - fLightPos[1] * fPlane[2];
Result[13] :=   0 - fLightPos[1] * fPlane[3];
// third column
Result[2]  :=   0 - fLightPos[2] * fPlane[0];
Result[6]  :=   0 - fLightPos[2] * fPlane[1];
Result[10] := Dot - fLightPos[2] * fPlane[2];
Result[14] :=   0 - fLightPos[2] * fPlane[3];
// fourth column
Result[3]  :=   0 - fLightPos[3] * fPlane[0];
Result[7]  :=   0 - fLightPos[3] * fPlane[1];
Result[11] :=   0 - fLightPos[3] * fPlane[2];
Result[15] := Dot - fLightPos[3] * fPlane[3];
end;

// =============================================================================
//  IsGammaRampSupported
// =============================================================================
function IsGammaRampSupported : Boolean;
var
 TmpRamp : TGammaRamp;
 DC      : HDC;
begin
DC := GetDC(0);
Result := GetDeviceGammaRamp(DC, TmpRamp);
ReleaseDC(0, DC);
end;

// =============================================================================
//  StoreOldGamma
// =============================================================================
procedure StoreOldGamma;
var
 DC : HDC;
begin
DC := GetDC(0);
GetDeviceGammaRamp(DC, OldGamma);
ReleaseDC(0, DC);
end;

// =============================================================================
//  RestoreOldGamma
// =============================================================================
procedure RestoreOldGamma;
var
DC : HDC;
begin
DC := GetDC(0);
SetDeviceGammaRamp(DC, OldGamma);
ReleaseDC(0, DC);
end;

// =============================================================================
//  SetGamma
// =============================================================================
function SetGamma(Value : Single) : TGammaRamp;
var
 I  : integer;
 DC : HDC;
 Tmp : TGammaRamp;
begin
for I := 0 to 255 do
 begin
 Tmp.R[I] := Min(255, Round(Floor(255*Power(i/255, Value)))) shl 8;
 Tmp.G[I] := Min(255, Round(Floor(255*Power(i/255, Value)))) shl 8;
 Tmp.B[I] := Min(255, Round(Floor(255*Power(i/255, Value)))) shl 8;
 end;
DC := GetDC(0);
SetDeviceGammaRamp(DC, Tmp);
ReleaseDC(0, DC);
end;

// =============================================================================
//  RenderCircle
// =============================================================================
procedure RenderCircle(pDetail : Integer; pScale : Single);
var
 i          : Integer;
 TmpX, TmpY : Single;
begin
glBegin(GL_POLYGON);
 for i := 0 to pDetail-1 do
  begin
  TmpX := Sin(DegToRad(360/pDetail)*(i+1));
  TmpY := Cos(DegToRad(360/pDetail)*(i+1));
  glNormal3f(0, 1, 0);
  glTexCoord3f(TmpX, TmpY, 0);
  glVertex3f(TmpX*pScale, TmpY*pScale, 0);
  end;
glEnd;
end;

end.
