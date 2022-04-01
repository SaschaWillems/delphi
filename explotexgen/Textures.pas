// First release by Jan Horn
// Changes made by me (Sascha Willems) :
//  - PNG Loading via GraphicEX (only when Symbol PNG is defined)
//  - Loading from streams
//  - Textureproperties for getting them outside of this unit
//  - Automatic mip-map generation (GL_GENERATE_MIPMAP_SGIS)
//  - Texturecompression
//  - Fixed memoryleaks :
//     * in LoadTGATexture/LoadTGATextureFromStream (CompImage now gets freed)

unit Textures;

interface

{$DEFINE PNG}

uses
  {$IFDEF WINDOWS}
    Windows,
  {$ENDIF}
  {$IFDEF LINUX}
    x, xlib, xutil, unix, baseunix, unixtype, GLGtkGlxContext,
  {$ENDIF}
  Forms,
  dglOpenGL,
  Graphics,
  Classes,
  {$IFNDEF FPC}
  JPEG,
  {$ENDIF}
  DDS,
  SysUtils,
  {$IFDEF PNG}
    {$IFNDEF FPC}
	    GDIPOBJ,
      GDIPAPI,
      MMSystem,
    {$ELSE}
      fpimage, IntfGraphics,
    {$ENDIF}
  {$ENDIF}
  Dialogs;

var
 LastFormat   : Cardinal;
 LastID       : Cardinal;
 Target       : Cardinal;
 LastBinding  : Cardinal;
 LastWidth    : Word;
 LastHeight   : Word;
 LastDepth    : Word;
 LastFile     : String;
 LastAlpha    : Boolean;
 AutoMipMap   : Boolean; // Für automatische MipMap-Generierung -> GL_SGIS_generate_mipmap
 CurrFileSize : Int64;  // Needed for loading compressed TGA from packagestream

function LoadTexture(Filename: String; var Texture: TGLuint;
                     pUseTexCompression : Boolean = False;
                     LoadFromRes : Boolean = False;
                     pMagFilter : glUInt = GL_LINEAR;
                     pMinFilter : glUInt = GL_LINEAR_MIPMAP_LINEAR;
                     pGenTexture : Boolean = False): Boolean;
function LoadJPGTextureFromStream(const Stream : TStream; var Texture: TGLuint;
                                  pMagFilter : glUInt = GL_LINEAR;
                                  pMinFilter : glUInt = GL_LINEAR_MIPMAP_LINEAR;
                                  pUseTexCompression : Boolean = False): Boolean;
{$IFDEF PNG}
function LoadPNGTextureFromStream(const Stream : TStream; var Texture: TGLuint; pMagFilter : glUInt = GL_LINEAR; pMinFilter : glUInt = GL_LINEAR_MIPMAP_LINEAR; pUseTexCompression : Boolean = False): Boolean;
{$ENDIF}

function LoadTGATextureFromStream(const Stream : TStream; var Texture: TGLuint;
                                  pMagFilter : glUInt = GL_LINEAR;
                                  pMinFilter : glUInt = GL_LINEAR_MIPMAP_LINEAR;
                                  pUseTexCompression : Boolean = False): Boolean;
function LoadDDSTextureFromStream(const Stream : TStream; var Texture : TGLUInt; pGenTexture : Boolean = True) : Boolean;
function LoadFromResource(var Texture : glUInt; pResName, pResType : String) : Boolean;

function CreateTexture(Width, Height, Format : Cardinal; pData : Pointer;pMagFilter, pMinFilter : TGLUInt;pUseTexCompression : Boolean) : Integer;

implementation

function LoadFromResource(var Texture : glUInt; pResName, pResType : String) : Boolean;
var
 RS : TResourceStream;
begin
{$IFDEF WINDOWS} OutputDebugString(PChar(pResName+'/'+pResType)); {$ENDIF}
LastFile := pResName;
Result := False;
RS := TResourceStream.Create(HInstance, pResName, PChar(pResType));
if pResType = 'TGA' then
 begin
 CurrFileSize := RS.Size;
 Result := LoadTGATextureFromStream(RS, Texture);
 end;
if pResType = 'JPG' then
 Result := LoadJPGTextureFromStream(RS, Texture);
RS.Free;
end;


{------------------------------------------------------------------}
{  Swap bitmap format from BGR to RGB                              }
{------------------------------------------------------------------}
{$IFDEF WIN32}
procedure SwapRGB(data : Pointer; Size : Integer);
asm
  mov ebx, eax
  mov ecx, size

@@loop :
  mov al,[ebx+0]
  mov ah,[ebx+2]
  mov [ebx+2],al
  mov [ebx+0],ah
  add ebx,3
  dec ecx
  jnz @@loop
end;
{$ENDIF}


{------------------------------------------------------------------}
{  Create the Texture                                              }
{------------------------------------------------------------------}
function CreateTexture(Width, Height, Format : Cardinal; pData : Pointer;pMagFilter, pMinFilter : TGLUInt;pUseTexCompression : Boolean) : Integer;
var
 Texture       : TGLuint;
 GLError       : glEnum;
 MaxAnisotropy : Single;
begin
glDisable(GL_TEXTURE_1D);
glDisable(GL_TEXTURE_2D);
glDeleteTextures(1, @Texture);
glGenTextures(1, @Texture);
if (Format = GL_RGBA) or (Format = GL_RGBA8) or (Format = GL_BGRA) then
 LastFormat  := GL_RGBA;
if (Format = GL_RGB) or (Format = GL_RGB8) or (Format = GL_BGR) then
 LastFormat  := GL_RGB;
LastWidth   := Width;
LastHeight  := Height;
LastID      := Texture;
LastAlpha   := (LastFormat = GL_RGBA);
// 2D-Textur
if Height > 1 then
 begin
 glEnable(GL_TEXTURE_2D);
 glBindTexture(Target, Texture);
 glTexParameteri(Target, GL_TEXTURE_MAG_FILTER, pMagFilter);
 glTexParameteri(Target, GL_TEXTURE_MIN_FILTER, pMinFilter);
 // Set anisotropic filter
 glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, @MaxAnisotropy);
 glTexParameterf(Target, GL_TEXTURE_MAX_ANISOTROPY_EXT, MaxAnisotropy/2);
 // Automatic MipMap generation
 if AutoMipMap then
  begin
  glGetError;
  glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP_SGIS, GL_TRUE);
  if pUseTexCompression then
   case Format of
    GL_RGB  : glTexImage2D(GL_TEXTURE_2D, 0, GL_COMPRESSED_RGB,  Width, Height, 0, GL_RGB,  GL_UNSIGNED_BYTE, pData);
    GL_RGBA : glTexImage2D(GL_TEXTURE_2D, 0, GL_COMPRESSED_RGBA, Width, Height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pData);
    GL_BGRA : glTexImage2D(GL_TEXTURE_2D, 0, GL_COMPRESSED_RGBA, Width, Height, 0, GL_BGRA, GL_UNSIGNED_BYTE, pData);
    GL_BGR  : glTexImage2D(GL_TEXTURE_2D, 0, GL_COMPRESSED_RGB,  Width, Height, 0, GL_BGR,  GL_UNSIGNED_BYTE, pData);
   end
  else
   case Format of
    GL_RGB  : glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,  Width, Height, 0, GL_RGB,  GL_UNSIGNED_BYTE, pData);
    GL_RGBA : glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, Width, Height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pData);
    GL_BGRA : glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, Width, Height, 0, GL_BGRA, GL_UNSIGNED_BYTE, pData);
    GL_BGR  : glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8,  Width, Height, 0, GL_BGR,  GL_UNSIGNED_BYTE, pData);
   end;
  GLError := glGetError;
  {$IFDEF WINDOWS} if GLError <> GL_NO_ERROR then
   OutputDebugString(PChar(LastFile+' is '+IntToStr(LastWidth)+'x'+IntToStr(LastHeight)));{$ENDIF}
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
  end
 else
  // Texture compression viar ARB-Extension
  if pUseTexCompression then
   case Format of
    GL_BGR  : gluBuild2DMipmaps(Target, GL_COMPRESSED_RGB_ARB, Width, Height, GL_BGR, GL_UNSIGNED_BYTE, pData);
    GL_BGRA : gluBuild2DMipmaps(Target, GL_COMPRESSED_RGBA_ARB, Width, Height, GL_BGRA, GL_UNSIGNED_BYTE, pData);
    GL_RGBA : gluBuild2DMipmaps(Target, GL_COMPRESSED_RGBA_ARB, Width, Height, GL_RGBA, GL_UNSIGNED_BYTE, pData);
    GL_RGB  : gluBuild2DMipmaps(Target, GL_COMPRESSED_RGB_ARB, Width, Height, GL_RGB, GL_UNSIGNED_BYTE, pData);
   end
  // Plain normal mipmaps
  else
   case Format of
    GL_BGR   : gluBuild2DMipmaps(Target, GL_RGB8, Width, Height, GL_BGR, GL_UNSIGNED_BYTE, pData);
    GL_BGRA  : gluBuild2DMipmaps(Target, GL_RGBA8, Width, Height, GL_BGRA, GL_UNSIGNED_BYTE, pData);
    GL_RGBA  : gluBuild2DMipmaps(Target, GL_RGBA8, Width, Height, GL_RGBA, GL_UNSIGNED_BYTE, pData);
    GL_RGB   : gluBuild2DMipmaps(Target, GL_RGB8,  Width, Height, GL_RGB,  GL_UNSIGNED_BYTE, pData);
   end;
 LastBinding := Target;
 end;
// 1D-Textur
if Height = 1 then
 begin
 glEnable(GL_TEXTURE_1D);
 glBindTexture(GL_TEXTURE_1D, Texture);
 gluBuild1DMipmaps(GL_TEXTURE_1D, Format, Width, Format, GL_UNSIGNED_BYTE, pData);
 glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
 glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
 glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
 LastBinding := GL_TEXTURE_1D;
 end;
Result := Texture;
end;

// =============================================================================
//  Load DDS textures
// =============================================================================
//  Added 22.05.2007 by Sascha Willems
// =============================================================================
function LoadDDSTexture(Filename: String; var Texture : TGLuint; pGenTexture : Boolean = True) : Boolean;
var
 TmpStream : TFileStream;
begin
Result := False;
if not FileExists(FileName) then
 exit;
TmpStream := TFileStream.Create(FileName, fmOpenRead);
LoadDDSTextureFromStream(TmpStream, Texture);
TmpStream.Free;
Result := True;
end;

// =============================================================================
//  Load DDS textures
// =============================================================================
//  Added 22.05.2007 by Sascha Willems
// =============================================================================
function LoadDDSTextureFromStream(const Stream : TStream; var Texture : TGLUInt; pGenTexture : Boolean = True) : Boolean;
begin
Result := False;
if Stream.Size = 0 then
 exit;
Result := True;
if pGenTexture then
 glGenTextures(1, @Texture);
glBindTexture(GL_TEXTURE_2D, Texture);
glTexParameteri(Target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
glTexParameteri(Target, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
LoadDDS(Stream);
LastWidth  := DDSInfo.Width;
LastHeight := DDSInfo.Height;
LastDepth  := DDSInfo.Depth;
LastFormat := DDSInfo.Format;
LastID     := Texture;
if (DDSInfo.Format = GL_COMPRESSED_RGBA_S3TC_DXT1_EXT) or
   (DDSInfo.Format = GL_COMPRESSED_RGBA_S3TC_DXT3_EXT) or
   (DDSInfo.Format = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT) or
   (DDSInfo.Format = GL_RGBA8) or
   (DDSInfo.Format = GL_RGB5_A1) then
 LastAlpha := True
else
 LastAlpha := False;
end;

// =============================================================================
//  Load PNG textures (GDI+)
// =============================================================================
//  Added 24.12.2004 by Sascha Willems
// =============================================================================
{$IFDEF PNG}
// =============================================================================
//  Load PNG textures (GDI+)
// =============================================================================
//  Added 24.12.2004 by Sascha Willems
// =============================================================================
function LoadPNGTexture(Filename: String; var Texture : TGLuint; pMagFilter, pMinFilter : TGLUInt; pUseTexCompression : Boolean) : Boolean;
var
  {$IFDEF FPC}
    png: TPortableNetworkGraphic;
    IntfImg: TLazIntfImage;
    y: Integer;
    x: Integer;
    c: TFPColor;
    p: PByte;
    ImgDat : Pointer;
  {$ELSE}
    PNGImage : TGPBitmap;
    BMPData  : BitmapData;
    Rect     : TGPRect;
  {$ENDIF}
begin
  {$IFDEF FPC}
  png:=TPortableNetworkGraphic.Create;
  IntfImg:=nil;
  try
    png.LoadFromFile(Filename);
    IntfImg:=png.CreateIntfImage;
    GetMem(ImgDat, IntfImg.Width*IntfImg.Height * 3);
    p:=PByte(ImgDat);
    for y:=0 to IntfImg.Height-1 do begin
      for x:=0 to IntfImg.Width-1 do begin
        c:=IntfImg.Colors[x,y];
        p^:=c.red shr 8;
        inc(p);
        p^:=c.green shr 8;
        inc(p);
        p^:=c.blue shr 8;
        inc(p);
      end;
    end;
	  Texture := CreateTexture(IntfImg.Width, IntfImg.Height, GL_BGRA, ImgDat, pMagFilter, pMinFilter, pUseTexCompression);
  finally
    png.Free;
    IntfImg.Free;
  end;
  {$ELSE}
    PNGImage    := TGPBitmap.Create(FileName);
    Rect.X      := 0;
    Rect.Y      := 0;
    Rect.Width  := PNGImage.GetWidth;
    Rect.Height := PNGImage.GetHeight;
    PNGImage.RotateFlip(RotateNoneFlipY);
    PNGImage.LockBits(Rect, ImageLockModeRead, PixelFormat32bppARGB, BMPData);
	  Texture := CreateTexture(PNGImage.GetWidth, PNGImage.GetHeight, GL_BGRA, BmpData.Scan0, pMagFilter, pMinFilter, pUseTexCompression);
	  PNGImage.UnlockBits(BMPData);
	  PNGImage.Free;
	  Result := True;
  {$ENDIF}
end;

// =============================================================================
//  LoadPNGTextureFromStream
// =============================================================================
//  Added 29.01.2007 - Sascha Willems
// =============================================================================
//  Problems with StreamAdapter of delphi, needs the fixed one found here :
//   http://lummie.co.uk/category/delphi/
// =============================================================================
function LoadPNGTextureFromStream(const Stream : TStream; var Texture: TGLuint; pMagFilter, pMinFilter : TGLUInt;pUseTexCompression : Boolean): Boolean;
var
  {$IFDEF FPC}
    png: TPortableNetworkGraphic;
    IntfImg: TLazIntfImage;
    y: Integer;
    x: Integer;
    c: TFPColor;
    p: PByte;
    ImgDat : Pointer;
  {$ELSE}
    PNGImage : TGPBitmap;
    BMPData  : BitmapData;
    Rect     : TGPRect;
  {$ENDIF}
begin
  {$IFDEF FPC}
  png:=TPortableNetworkGraphic.Create;
  IntfImg:=nil;
  try
    png.LoadFromStream(Stream);
    IntfImg:=png.CreateIntfImage;
    ShowMessage(IntToStr(IntfImg.Width) + ' x ' + IntToStr(IntfImg.Height));
    GetMem(ImgDat, IntfImg.Width*IntfImg.Height * 3);
    p:=PByte(ImgDat);
    for y:=0 to IntfImg.Height-1 do begin
      for x:=0 to IntfImg.Width-1 do begin
        c:=IntfImg.Colors[x,y];
        p^:=c.red shr 8;
        inc(p);
        p^:=c.green shr 8;
        inc(p);
        p^:=c.blue shr 8;
        inc(p);
      end;
    end;
	  Texture := CreateTexture(IntfImg.Width, IntfImg.Height, GL_RGB, ImgDat, pMagFilter, pMinFilter, pUseTexCompression);
  finally
    png.Free;
    IntfImg.Free;
  end;
  {$ELSE}
    PNGImage    := TGPBitmap.Create(TStreamAdapter.Create(Stream));
    Rect.X      := 0;
    Rect.Y      := 0;
    Rect.Width  := PNGImage.GetWidth;
    Rect.Height := PNGImage.GetHeight;
    PNGImage.RotateFlip(RotateNoneFlipY);
    PNGImage.LockBits(Rect, ImageLockModeRead, PixelFormat32bppARGB, BMPData);
    Texture := CreateTexture(PNGImage.GetWidth, PNGImage.GetHeight, GL_BGRA, BmpData.Scan0, pMagFilter, pMinFilter, pUseTexCompression);
    PNGImage.UnlockBits(BMPData);
    PNGImage.Free;
    Result := True;
  {$ENDIF}
end;
{$ENDIF}

// =============================================================================
//  Load BMP textures
// =============================================================================
{$IFDEF WINDOWS}
function LoadBMPTexture(Filename: String; var Texture : TGLuint; LoadFromResource : Boolean;pMagFilter, pMinFilter : TGLUInt;pUseTexCompression : Boolean) : Boolean;
var
  FileHeader: BITMAPFILEHEADER;
  InfoHeader: BITMAPINFOHEADER;
  Palette: array of RGBQUAD;
  BitmapFile: THandle;
  BitmapLength: LongWord;
  PaletteLength: LongWord;
  ReadBytes: LongWord;
  Width, Height : Integer;
  pData : Pointer;

  // used for loading from resource
  ResStream : TResourceStream;
begin
  result :=FALSE;

  if LoadFromResource then // Load from resource
  begin
    try
      ResStream := TResourceStream.Create(hInstance, PChar(copy(Filename, 1, Pos('.', Filename)-1)), 'BMP');
      ResStream.ReadBuffer(FileHeader, SizeOf(FileHeader));  // FileHeader
      ResStream.ReadBuffer(InfoHeader, SizeOf(InfoHeader));  // InfoHeader
      PaletteLength := InfoHeader.biClrUsed;
      SetLength(Palette, PaletteLength);
      ResStream.ReadBuffer(Palette, PaletteLength);          // Palette

      Width := InfoHeader.biWidth;
      Height := InfoHeader.biHeight;

      BitmapLength := InfoHeader.biSizeImage;
      if BitmapLength = 0 then
        BitmapLength := Width * Height * InfoHeader.biBitCount Div 8;

      GetMem(pData, BitmapLength);
      ResStream.ReadBuffer(pData^, BitmapLength);            // Bitmap Data
      ResStream.Free;
    except on
      EResNotFound do
      begin
        MessageBox(0, PChar('File not found in resource - ' + Filename), PChar('BMP Texture'), MB_OK);
        Exit;
      end
      else
      begin
        MessageBox(0, PChar('Unable to read from resource - ' + Filename), PChar('BMP Unit'), MB_OK);
        Exit;
      end;
    end;
  end
  else
  begin   // Load image from file
    BitmapFile := CreateFile(PChar(Filename), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0);
    if (BitmapFile = INVALID_HANDLE_VALUE) then begin
      MessageBox(0, PChar('Error opening ' + Filename), PChar('BMP Unit'), MB_OK);
      Exit;
    end;

    // Get header information
    ReadFile(BitmapFile, FileHeader, SizeOf(FileHeader), ReadBytes, nil);
    ReadFile(BitmapFile, InfoHeader, SizeOf(InfoHeader), ReadBytes, nil);

    // Get palette
    PaletteLength := InfoHeader.biClrUsed;
    SetLength(Palette, PaletteLength);
    ReadFile(BitmapFile, Palette, PaletteLength, ReadBytes, nil);
    if (ReadBytes <> PaletteLength) then begin
      MessageBox(0, PChar('Error reading palette'), PChar('BMP Unit'), MB_OK);
      Exit;
    end;

    Width  := InfoHeader.biWidth;
    Height := InfoHeader.biHeight;
    BitmapLength := InfoHeader.biSizeImage;
    if BitmapLength = 0 then
      BitmapLength := Width * Height * InfoHeader.biBitCount Div 8;

    // Get the actual pixel data
    GetMem(pData, BitmapLength);
    ReadFile(BitmapFile, pData^, BitmapLength, ReadBytes, nil);
    if (ReadBytes <> BitmapLength) then begin
      MessageBox(0, PChar('Error reading bitmap data'), PChar('BMP Unit'), MB_OK);
      Exit;
    end;
    CloseHandle(BitmapFile);
  end;

  // Bitmaps are stored BGR and not RGB, so swap the R and B bytes.
  {$IFDEF WIN32} SwapRGB(pData, Width*Height); {$ENDIF}

  Texture :=CreateTexture(Width, Height, GL_RGB, pData, pMagFilter, pMinFilter, pUseTexCompression);
  FreeMem(pData);
  result :=TRUE;
end;
{$ENDIF}

// =============================================================================
//  LoadJPGTextureFromStream
// =============================================================================
//  Added 05.01.2004 - Sascha Willems
// =============================================================================
function LoadJPGTextureFromStream(const Stream : TStream; var Texture: TGLuint; pMagFilter, pMinFilter : TGLUInt;pUseTexCompression : Boolean): Boolean;
var
 Data      : array of LongWord;
 W, Width  : Integer;
 H, Height : Integer;
 BMP       : TBitmap;
 JPG       : TJPEGImage;
 C         : LongWord;
 Line      : ^LongWord;
begin
Result := False;
exit; // TODO : Gives SIGSEV in FPC
Result := True;
JPG    := TJPEGImage.Create;
JPG.LoadFromStream(Stream);
// Create Bitmap
BMP := TBitmap.Create;
BMP.pixelformat := pf32bit;
BMP.width       := JPG.width;
BMP.height      := JPG.height;
BMP.canvas.draw(0,0,JPG);
Width  := BMP.Width;
Height := BMP.Height;
SetLength(Data, Width*Height);
for H:=0 to Height-1 do
 begin
 // flip JPEG
 {$IFNDEF FPC}
  Line := BMP.scanline[Height-H-1];
 {$ELSE}
  // TODO : FPC
 {$ENDIF}
 for W:=0 to Width-1 do
  begin
  // Need to do a color swap
  c := Line^ and $FFFFFF;
  // 4 channel
  Data[W+(H*Width)] :=(((c and $FF) shl 16)+(c shr 16)+(c and $FF00)) or $FF000000;
  inc(Line);
  end;
 end;
BMP.free;
JPG.free;
Texture    := CreateTexture(Width, Height, GL_RGBA, addr(Data[0]), pMagFilter, pMinFilter, pUseTexCompression);
LastFormat := GL_RGB;
Finalize(Data);
end;

// =============================================================================
//  LoadJPGTexture
// =============================================================================
function LoadJPGTexture(Filename: String; var Texture: TGLuint; LoadFromResource : Boolean;pMagFilter, pMinFilter : TGLUInt;pUseTexCompression : Boolean): Boolean;
var
 Data      : array of LongWord;
 W, Width  : Integer;
 H, Height : Integer;
 BMP       : TBitmap;
 JPG       : TJPEGImage;
 C         : LongWord;
 Line      : ^LongWord;
 ResStream : TResourceStream;      // used for loading from resource
begin
Result := False;
JPG    := TJPEGImage.Create;
if LoadFromResource then
 begin
 try
  ResStream := TResourceStream.Create(hInstance, PChar(copy(Filename, 1, Pos('.', Filename)-1)), 'JPEG');
  JPG.LoadFromStream(ResStream);
  ResStream.Free;
 except
  on EResNotFound do
   begin
    {$IFDEF WINDOWS} MessageBox(0, PChar('File not found in resource - ' + Filename), PChar('JPG Texture'), MB_OK);  {$ENDIF}
   exit;
   end
  else
   begin
    {$IFDEF WINDOWS} MessageBox(0, PChar('Couldn''t load JPG Resource - "'+ Filename +'"'), PChar('BMP Unit'), MB_OK);  {$ENDIF}
   exit;
   end;
 end;
 end
else
 begin
 try
  JPG.LoadFromFile(Filename);
  except
   {$IFDEF WINDOWS} MessageBox(0, PChar('Couldn''t load JPG - "'+ Filename +'"'), PChar('BMP Unit'), MB_OK); {$ENDIF}
   exit;
   end;
 end;
// Create Bitmap
BMP := TBitmap.Create;
BMP.pixelformat := pf32bit;
BMP.width       := JPG.width;
BMP.height      := JPG.height;
BMP.canvas.draw(0,0,JPG);
Width  := BMP.Width;
Height := BMP.Height;
SetLength(Data, Width*Height);
for h := 0 to Height-1 do
 begin
 // flip JPEG
 {$IFNDEF FPC}
  Line := BMP.scanline[Height-H-1];
 {$ELSE}
  // TODO : FPC
 {$ENDIF}
 for w :=0 to Width-1 do
  begin
  c := Line^ and $FFFFFF; // Need to do a color swap
  Data[W+(H*Width)] :=(((c and $FF) shl 16)+(c shr 16)+(c and $FF00)) or $FF000000;  // 4 channel.
  inc(Line);
  end;
 end;
BMP.Free;
JPG.Free;
Texture    := CreateTexture(Width, Height, GL_RGBA, addr(Data[0]), pMagFilter, pMinFilter, pUseTexCompression);
LastFormat := GL_RGB;
result     := True;
Finalize(Data);
end;


{------------------------------------------------------------------}
{  Loads 24 and 32bpp (alpha channel) TGA textures                 }
{------------------------------------------------------------------}
function LoadTGATexture(Filename: String; var Texture: TGLuint; LoadFromResource : Boolean;pMagFilter, pMinFilter : TGLUInt;pUseTexCompression : Boolean): Boolean;
var
  TGAHeader : packed record   // Header type for TGA images
    FileType     : Byte;
    ColorMapType : Byte;
    ImageType    : Byte;
    ColorMapSpec : Array[0..4] of Byte;
    OrigX  : Array [0..1] of Byte;
    OrigY  : Array [0..1] of Byte;
    Width  : Array [0..1] of Byte;
    Height : Array [0..1] of Byte;
    BPP    : Byte;
    ImageInfo : Byte;
  end;
  TGAFile   : File;
  bytesRead : Integer;
  image     : Pointer;    {or PRGBTRIPLE}
  CompImage : Pointer;
  Width, Height : Integer;
  ColorDepth    : Integer;
  ImageSize     : Integer;
  BufferIndex : Integer;
  currentByte : Integer;
  CurrentPixel : Integer;
  I : Integer;
  Front: ^Byte;
  Back: ^Byte;
  Temp: Byte;

  ResStream : TResourceStream;      // used for loading from resource

  // Copy a pixel from source to dest and Swap the RGB color values
  {$IFDEF WIN32}
  procedure CopySwapPixel(const Source, Destination : Pointer);
  asm
    push ebx
    mov bl,[eax+0]
    mov bh,[eax+1]
    mov [edx+2],bl
    mov [edx+1],bh
    mov bl,[eax+2]
    mov bh,[eax+3]
    mov [edx+0],bl
    mov [edx+3],bh
    pop ebx
  end;
  {$ENDIF}

begin
Result    := False;
ResStream := NIL;
CompImage := NIL;
Image     := NIL;
// Load from resource
if LoadFromResource then
 begin
 try
  ResStream := TResourceStream.Create(hInstance, PChar(copy(Filename, 1, Pos('.', Filename)-1)), 'TGA');
  ResStream.ReadBuffer(TGAHeader, SizeOf(TGAHeader));
  result := True;
 except
  on EResNotFound do
   begin
   {$IFDEF WINDOWS}MessageBox(0, PChar('File not found in resource - ' + Filename), PChar('TGA Texture'), MB_OK);{$ENDIF}
   exit;
   end
  else
   begin
   {$IFDEF WINDOWS}MessageBox(0, PChar('Unable to read from resource - ' + Filename), PChar('BMP Unit'), MB_OK);{$ENDIF}
   exit;
   end;
 end;
 end
else
 begin
 if FileExists(Filename) then
  begin
  AssignFile(TGAFile, Filename);
  Reset(TGAFile, 1);
  // Read in the bitmap file header
  BlockRead(TGAFile, TGAHeader, SizeOf(TGAHeader));
  Result := TRUE;
  end
 else
  begin
  {$IFDEF WINDOWS}MessageBox(0, PChar('File not found  - ' + Filename), PChar('TGA Texture'), MB_OK);{$ENDIF}
  exit;
  end;
 end;
if Result then
 begin
 Result := False;
 // Only support 24, 32 bit images { TGA_RGB } + { Compressed RGB }
 if (TGAHeader.ImageType <> 2) and (TGAHeader.ImageType <> 10) then
  begin
  Result := False;
  CloseFile(tgaFile);
  {$IFDEF WINDOWS}MessageBox(0, PChar('Couldn''t load "'+ Filename +'". Only 24 and 32bit TGA supported.'), PChar('TGA File Error'), MB_OK);{$ENDIF}
  exit;
  end;
 // Don't support colormapped files
 if TGAHeader.ColorMapType <> 0 then
  begin
  Result := False;
  CloseFile(TGAFile);
  {$IFDEF WINDOWS}MessageBox(0, PChar('Couldn''t load "'+ Filename +'". Colormapped TGA files not supported.'), PChar('TGA File Error'), MB_OK);{$ENDIF}
  exit;
  end;
 // Get the width, height, and color depth
 Width      := TGAHeader.Width[0]  + TGAHeader.Width[1]  * 256;
 Height     := TGAHeader.Height[0] + TGAHeader.Height[1] * 256;
 ColorDepth := TGAHeader.BPP;
 ImageSize  := Width*Height*(ColorDepth div 8);
 if ColorDepth < 24 then
  begin
  Result := False;
  CloseFile(TGAFile);
  {$IFDEF WINDOWS}MessageBox(0, PChar('Couldn''t load "'+ Filename +'". Only 24 and 32 bit TGA files supported.'), PChar('TGA File Error'), MB_OK);{$ENDIF}
  exit;
  end;
 GetMem(Image, ImageSize);
 // Standard 24, 32 bit TGA file
 if TGAHeader.ImageType = 2 then
  begin
  // Load from resource
  if LoadFromResource then
   begin
   try
    ResStream.ReadBuffer(Image^, ImageSize);
    ResStream.Free;
   except
    {$IFDEF WINDOWS}MessageBox(0, PChar('Unable to read from resource - ' + Filename), PChar('BMP Unit'), MB_OK);{$ENDIF}
    exit;
   end;
   end
  else
   // Read in the image from file
   begin
   BlockRead(TGAFile, image^, ImageSize, bytesRead);
   if bytesRead <> ImageSize then
    begin
    Result := False;
    FreeMem(Image);
    CloseFile(TGAFile);
    {$IFDEF WINDOWS}MessageBox(0, PChar('Couldn''t read file "'+ Filename +'".'), PChar('TGA File Error'), MB_OK);{$ENDIF}
    exit;
    end
   end;
  // TGAs are stored BGR and not RGB, so swap the R and B bytes.
  // 32 bit TGA files have alpha channel and gets loaded differently
  if TGAHeader.BPP = 24 then
   begin
   for i := 0 to Width * Height - 1 do
    begin
    Front  := Pointer(Integer(Image) + I*3);
    Back   := Pointer(Integer(Image) + I*3 + 2);
    Temp   := Front^;
    Front^ := Back^;
    Back^  := Temp;
    end;
   Texture := CreateTexture(Width, Height, GL_RGB, Image, pMagFilter, pMinFilter, pUseTexCompression);
   end
  else
   begin
   for i := 0 to Width * Height - 1 do
    begin
    Front  := Pointer(Integer(Image) + I*4);
    Back   := Pointer(Integer(Image) + I*4 + 2);
    Temp   := Front^;
    Front^ := Back^;
    Back^  := Temp;
    end;
   Texture := CreateTexture(Width, Height, GL_RGBA, Image, pMagFilter, pMinFilter, pUseTexCompression);
   end;
 end;
 // Compressed 24, 32 bit TGA files
 if TGAHeader.ImageType = 10 then
  begin
  ColorDepth   := ColorDepth DIV 8;
  CurrentByte  := 0;
  CurrentPixel := 0;
  BufferIndex  := 0;
  if LoadFromResource then
   begin
   try
    GetMem(CompImage, ResStream.Size-sizeOf(TGAHeader));
    ResStream.ReadBuffer(CompImage^, ResStream.Size-sizeOf(TGAHeader));   // load compressed date into memory
    ResStream.Free;
   except
//    MessageBox(0, PChar('Unable to read from resource - ' + Filename), PChar('BMP Unit'), MB_OK);
    exit;
   end;
   end
  else
   begin
   GetMem(CompImage, FileSize(TGAFile)-sizeOf(TGAHeader));
   BlockRead(TGAFile, CompImage^, FileSize(TGAFile)-sizeOf(TGAHeader), BytesRead);   // load compressed data into memory
   if bytesRead <> FileSize(TGAFile)-sizeOf(TGAHeader) then
    begin
    Result := False;
    FreeMem(CompImage);
    CloseFile(TGAFile);
//    MessageBox(0, PChar('Couldn''t read file "'+ Filename +'".'), PChar('TGA File Error'), MB_OK);
    exit;
    end
   end;
  // Extract pixel information from compressed data
  repeat
  Front := Pointer(Integer(CompImage) + BufferIndex);
  inc(BufferIndex);
  if Front^ < 128 then
   begin
   for i := 0 to Front^ do
    begin
    {$IFDEF WIN32} CopySwapPixel(Pointer(Integer(CompImage)+BufferIndex+I*ColorDepth), Pointer(Integer(image)+CurrentByte)); {$ENDIF}
    CurrentByte := CurrentByte + ColorDepth;
    inc(CurrentPixel);
    end;
   BufferIndex := BufferIndex + (Front^+1)*ColorDepth
   end
  else
   begin
   for i := 0 to Front^ -128 do
    begin
    {$IFDEF WIN32} CopySwapPixel(Pointer(Integer(CompImage)+BufferIndex), Pointer(Integer(image)+CurrentByte)); {$ENDIF}
    CurrentByte := CurrentByte + ColorDepth;
    inc(CurrentPixel);
    end;
   BufferIndex := BufferIndex + ColorDepth
   end;
  until CurrentPixel >= Width*Height;
  if ColorDepth = 3 then
   Texture := CreateTexture(Width, Height, GL_RGB, Image, pMagFilter, pMinFilter, pUseTexCompression)
  else
   Texture := CreateTexture(Width, Height, GL_RGBA, Image, pMagFilter, pMinFilter, pUseTexCompression);
  end;
  Result := TRUE;
  CloseFile(TGAFile);
  end;
if Assigned(Image) then
 FreeMem(Image);
if Assigned(CompImage) then
 FreeMem(CompImage);
if TGAHeader.BPP = 32 then
 LastFormat := GL_RGBA
else
 LastFormat := GL_RGB;
end;

// =============================================================================
//  LoadTGATextureFromStream
// =============================================================================
//  Added 05.01.2004 - Sascha Willems
// =============================================================================
function LoadTGATextureFromStream(const Stream : TStream; var Texture: TGLuint; pMagFilter, pMinFilter : TGLUInt; pUseTexCompression : Boolean): Boolean;
var
 TGAHeader : packed record   // Header type for TGA images
   FileType     : Byte;
   ColorMapType : Byte;
   ImageType    : Byte;
   ColorMapSpec : Array[0..4] of Byte;
   OrigX  : Array [0..1] of Byte;
   OrigY  : Array [0..1] of Byte;
   Width  : Array [0..1] of Byte;
   Height : Array [0..1] of Byte;
   BPP    : Byte;
   ImageInfo : Byte;
  end;
 image     : Pointer;    {or PRGBTRIPLE}
 CompImage : Pointer;
 Width, Height : Integer;
 ColorDepth    : Integer;
 ImageSize     : Integer;
 BufferIndex : Integer;
 currentByte : Integer;
 CurrentPixel : Integer;
 I : Integer;
 Front: ^Byte;
 Back: ^Byte;
 Temp: Byte;

// Copy a pixel from source to dest and Swap the RGB color values
{$IFDEF WIN32}
procedure CopySwapPixel(const Source, Destination : Pointer);
 asm
 push ebx
 mov bl,[eax+0]
 mov bh,[eax+1]
 mov [edx+2],bl
 mov [edx+1],bh
 mov bl,[eax+2]
 mov bh,[eax+3]
 mov [edx+0],bl
 mov [edx+3],bh
 pop ebx
 end;
{$ENDIF}

begin
CompImage := NIL;
// Read TGA Header
Stream.ReadBuffer(TGAHeader, SizeOf(TGAHeader));
// Only support 24, 32 bit images
 // TGA_RGB & Compressed RGB are not supported
if (TGAHeader.ImageType <> 2) and (TGAHeader.ImageType <> 10) then
 begin
 Result := False;
// MessageBox(0, PChar('Couldn''t load TGA. Only 24 and 32bit TGA supported.'), PChar('TGA File Error'), MB_OK);
 exit;
 end;
// Don't support colormapped files
if TGAHeader.ColorMapType <> 0 then
 begin
 Result := False;
// MessageBox(0, PChar('Couldn''t load TGA. Colormapped TGA files not supported.'), PChar('TGA File Error'), MB_OK);
 exit;
 end;
// Get the width, height, and color depth
Width      := TGAHeader.Width[0]  + TGAHeader.Width[1]  * 256;
Height     := TGAHeader.Height[0] + TGAHeader.Height[1] * 256;
ColorDepth := TGAHeader.BPP;
ImageSize  := Width*Height*(ColorDepth div 8);
// No support for 8&16 Bit TGAs
if ColorDepth < 24 then
 begin
 Result := False;
// MessageBox(0, PChar('Couldn''t load TGA. Only 24 and 32 bit TGA files supported.'), PChar('TGA File Error'), MB_OK);
 exit;
 end;
GetMem(Image, ImageSize);
// Standard 24, 32 bit TGA file
if TGAHeader.ImageType = 2 then
 begin
 Stream.ReadBuffer(Image^, ImageSize);
 // TGAs are stored BGR and not RGB, so swap the R and B bytes.
 // 32 bit TGA files have alpha channel and gets loaded differently
 if TGAHeader.BPP = 24 then
  begin
  for i := 0 to Width * Height - 1 do
   begin
   Front  := Pointer(Integer(Image) + I*3);
   Back   := Pointer(Integer(Image) + I*3 + 2);
   Temp   := Front^;
   Front^ := Back^;
   Back^  := Temp;
   end;
  Texture :=CreateTexture(Width, Height, GL_RGB, Image, pMagFilter, pMinFilter, pUseTexCompression);
  end
 else
  begin
  for i :=0 to Width * Height - 1 do
   begin
   Front  := Pointer(Integer(Image) + I*4);
   Back   := Pointer(Integer(Image) + I*4 + 2);
   Temp   := Front^;
   Front^ := Back^;
   Back^  := Temp;
   end;
  Texture :=CreateTexture(Width, Height, GL_RGBA, Image, pMagFilter, pMinFilter, pUseTexCompression);
  end;
 end;
// Compressed 24, 32 bit TGA files
if TGAHeader.ImageType = 10 then
 begin
 ColorDepth   := ColorDepth DIV 8;
 CurrentByte  := 0;
 CurrentPixel := 0;
 BufferIndex  := 0;
 GetMem(CompImage, CurrFileSize-SizeOf(TGAHeader));
 Stream.ReadBuffer(CompImage^, CurrFileSize-SizeOf(TGAHeader));
 // Extract pixel information from compressed data
 repeat
 Front := Pointer(Integer(CompImage) + BufferIndex);
 Inc(BufferIndex);
 if Front^ < 128 then
  begin
  for I := 0 to Front^ do
   begin
   {$IFDEF WIN32} CopySwapPixel(Pointer(Integer(CompImage)+BufferIndex+I*ColorDepth), Pointer(Integer(image)+CurrentByte)); {$ENDIF}
   CurrentByte := CurrentByte + ColorDepth;
   inc(CurrentPixel);
   end;
  BufferIndex :=BufferIndex + (Front^+1)*ColorDepth
  end
 else
  begin
  For I := 0 to Front^ -128 do
   begin
   {$IFDEF WIN32} CopySwapPixel(Pointer(Integer(CompImage)+BufferIndex), Pointer(Integer(image)+CurrentByte)); {$ENDIF}
   CurrentByte := CurrentByte + ColorDepth;
   inc(CurrentPixel);
   end;
  BufferIndex :=BufferIndex + ColorDepth
  end;
 until CurrentPixel >= Width*Height;
 end;
if ColorDepth = 3 then
 Texture := CreateTexture(Width, Height, GL_RGB, Image, pMagFilter, pMinFilter, pUseTexCompression)
else
 Texture := CreateTexture(Width, Height, GL_RGBA, Image, pMagFilter, pMinFilter, pUseTexCompression);
if Assigned(Image) then
 FreeMem(Image);
if Assigned(CompImage) then
 FreeMem(CompImage);
Result := True;
end;


// =============================================================================
//  LoadTGATextureFromStream
// =============================================================================
//  Added 05.01.2004 - Sascha Willems
// =============================================================================
{function LoadTGATextureFromStream(const Stream : TStream; var Texture: TGLuint; pMagFilter, pMinFilter : TGLUInt; pUseTexCompression : Boolean): Boolean;
var
 TGAHeader : packed record   // Header type for TGA images
   FileType     : Byte;
   ColorMapType : Byte;
   ImageType    : Byte;
   ColorMapSpec : Array[0..4] of Byte;
   OrigX  : Array [0..1] of Byte;
   OrigY  : Array [0..1] of Byte;
   Width  : Array [0..1] of Byte;
   Height : Array [0..1] of Byte;
   BPP    : Byte;
   ImageInfo : Byte;
  end;
 image     : Pointer;
 CompImage : Pointer;
 Width, Height : Integer;
 ColorDepth    : Integer;
 ImageSize     : Integer;
 BufferIndex : Integer;
 currentByte : Integer;
 CurrentPixel : Integer;
 I : Integer;
 Front: ^Byte;
 Back: ^Byte;
 Temp: Byte;

// Copy a pixel from source to dest and Swap the RGB color values
procedure CopySwapPixel(const Source, Destination : Pointer);
 asm
 push ebx
 mov bl,[eax+0]
 mov bh,[eax+1]
 mov [edx+2],bl
 mov [edx+1],bh
 mov bl,[eax+2]
 mov bh,[eax+3]
 mov [edx+0],bl
 mov [edx+3],bh
 pop ebx
 end;

begin
CompImage := NIL;
// Read TGA Header
Stream.ReadBuffer(TGAHeader, SizeOf(TGAHeader));
// Only support 24, 32 bit images
 // TGA_RGB & Compressed RGB are not supported
if (TGAHeader.ImageType <> 2) and (TGAHeader.ImageType <> 10) then
 begin
 Result := False;
 MessageBox(0, PChar('Couldn''t load TGA. Only 24 and 32bit TGA supported.'), PChar('TGA File Error'), MB_OK);
 exit;
 end;
// Don't support colormapped files
if TGAHeader.ColorMapType <> 0 then
 begin
 Result := False;
 MessageBox(0, PChar('Couldn''t load TGA. Colormapped TGA files not supported.'), PChar('TGA File Error'), MB_OK);
 exit;
 end;
// Get the width, height, and color depth
Width      := TGAHeader.Width[0]  + TGAHeader.Width[1]  * 256;
Height     := TGAHeader.Height[0] + TGAHeader.Height[1] * 256;
ColorDepth := TGAHeader.BPP;
ImageSize  := Width*Height*(ColorDepth div 8);
// No support for 8&16 Bit TGAs
if ColorDepth < 24 then
 begin
 Result := False;
 MessageBox(0, PChar('Couldn''t load TGA. Only 24 and 32 bit TGA files supported.'), PChar('TGA File Error'), MB_OK);
 exit;
 end;
GetMem(Image, ImageSize);
// Standard 24, 32 bit TGA file
if TGAHeader.ImageType = 2 then
 begin
 Stream.ReadBuffer(Image^, ImageSize);
 // TGAs are stored BGR and not RGB, so swap the R and B bytes.
 // 32 bit TGA files have alpha channel and gets loaded differently
 if TGAHeader.BPP = 24 then
  begin
  for i := 0 to Width * Height - 1 do
   begin
   Front  := Pointer(Integer(Image) + I*3);
   Back   := Pointer(Integer(Image) + I*3 + 2);
   Temp   := Front^;
   Front^ := Back^;
   Back^  := Temp;
   end;
  Texture :=CreateTexture(Width, Height, GL_RGB, Image, pMagFilter, pMinFilter, pUseTexCompression);
  end
 else
  begin
  for i :=0 to Width * Height - 1 do
   begin
   Front  := Pointer(Integer(Image) + I*4);
   Back   := Pointer(Integer(Image) + I*4 + 2);
   Temp   := Front^;
   Front^ := Back^;
   Back^  := Temp;
   end;
  Texture :=CreateTexture(Width, Height, GL_RGBA, Image, pMagFilter, pMinFilter, pUseTexCompression);
  end;
 end;
// Compressed 24, 32 bit TGA files
if TGAHeader.ImageType = 10 then
 begin
 ColorDepth   := ColorDepth DIV 8;
 CurrentByte  := 0;
 CurrentPixel := 0;
 BufferIndex  := 0;
 GetMem(CompImage, CurrFileSize-SizeOf(TGAHeader));
 Stream.ReadBuffer(CompImage^, CurrFileSize-SizeOf(TGAHeader));
 // Extract pixel information from compressed data
 repeat
 Front := Pointer(Integer(CompImage) + BufferIndex);
 Inc(BufferIndex);
 if Front^ < 128 then
  begin
  for I := 0 to Front^ do
   begin
   CopySwapPixel(Pointer(Integer(CompImage)+BufferIndex+I*ColorDepth), Pointer(Integer(image)+CurrentByte));
   CurrentByte := CurrentByte + ColorDepth;
   inc(CurrentPixel);
   end;
  BufferIndex :=BufferIndex + (Front^+1)*ColorDepth
  end
 else
  begin
  For I := 0 to Front^ -128 do
   begin
   CopySwapPixel(Pointer(Integer(CompImage)+BufferIndex), Pointer(Integer(image)+CurrentByte));
   CurrentByte := CurrentByte + ColorDepth;
   inc(CurrentPixel);
   end;
  BufferIndex :=BufferIndex + ColorDepth
  end;
 until CurrentPixel >= Width*Height;
 end;
if ColorDepth = 3 then
 Texture := CreateTexture(Width, Height, GL_RGB, Image, pMagFilter, pMinFilter, pUseTexCompression)
else
 Texture := CreateTexture(Width, Height, GL_RGBA, Image, pMagFilter, pMinFilter, pUseTexCompression);
if Assigned(Image) then
 FreeMem(Image);
if Assigned(CompImage) then
 FreeMem(CompImage);
Result := True;
end;       }


{------------------------------------------------------------------}
{  Determines file type and sends to correct function              }
{------------------------------------------------------------------}
function LoadTexture(Filename: String; var Texture : TGLuint; pUseTexCompression : Boolean; LoadFromRes : Boolean;pMagFilter, pMinFilter : TGLUInt; pGenTexture : Boolean) : Boolean;
var
 Ext : String;
begin
LastFile := FileName;
Result   := False;
Ext      := UpperCase(Copy(Uppercase(filename), length(filename)-3, 4));
{$IFDEF PNG}
if Ext = '.PNG' then
 Result := LoadPNGTexture(Filename, Texture, pMagFilter, pMinFilter{, pUseTexCompression}, False);
{$ENDIF}
if Ext = '.DDS' then
 Result := LoadDDSTexture(Filename, Texture, pGenTexture)
else
 if Ext = '.TGA' then
  Result := LoadTGATexture(Filename, Texture, LoadFromRes, pMagFilter, pMinFilter, pUseTexCompression)
 else
  if Ext = '.JPG' then
   Result := LoadJPGTexture(Filename, Texture, LoadFromRes, pMagFilter, pMinFilter, pUseTexCompression)
  {$IFDEF WINDOWS}
  else
   if Ext = '.BMP' then
    Result := LoadBMPTexture(Filename, Texture, LoadFromRes, pMagFilter, pMinFilter, pUseTexCompression);
{$ENDIF}
end;

initialization
 Target := GL_TEXTURE_2D;

end.
