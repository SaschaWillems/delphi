//10 02 2004//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DDS import routines for Delphi
//  written by Martin Waldegger
//  based on MyDDS by Jon Watte
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  This code is distributed in the hope that it will be useful but
//  WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
//  DISCLAMED. This includes but is not limited to warranties of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


unit DDS;

interface

uses
  Classes,
  Windows,
  SysUtils,
  dglOpenGL;

var
 DDSInfo : record
   Width  : TGLUInt;
   Height : TGLUInt;
   Depth  : TGLUInt;
   Format : Word;
  end;


function LoadDDS(Stream: TStream): boolean;

implementation

const
//  little-endian, of course
  DDS_MAGIC                   = $20534444;

//  DDS_header.dwFlags
  DDSD_CAPS                   = $00000001;
  DDSD_HEIGHT                 = $00000002;
  DDSD_WIDTH                  = $00000004;
  DDSD_PITCH                  = $00000008;
  DDSD_PIXELFORMAT            = $00001000;
  DDSD_MIPMAPCOUNT            = $00020000;
  DDSD_LINEARSIZE             = $00080000;
  DDSD_DEPTH                  = $00800000;

//  DDS_header.sPixelFormat.dwFlags
  DDPF_ALPHAPIXELS            = $00000001;
  DDPF_FOURCC                 = $00000004;
  DDPF_INDEXED                = $00000020;
  DDPF_RGB                    = $00000040;

//  DDS_header.sCaps.dwCaps1
  DDSCAPS_COMPLEX             = $00000008;
  DDSCAPS_TEXTURE             = $00001000;
  DDSCAPS_MIPMAP              = $00400000;

//  DDS_header.sCaps.dwCaps2
  DDSCAPS2_CUBEMAP            = $00000200;
  DDSCAPS2_CUBEMAP_POSITIVEX  = $00000400;
  DDSCAPS2_CUBEMAP_NEGATIVEX  = $00000800;
  DDSCAPS2_CUBEMAP_POSITIVEY  = $00001000;
  DDSCAPS2_CUBEMAP_NEGATIVEY  = $00002000;
  DDSCAPS2_CUBEMAP_POSITIVEZ  = $00004000;
  DDSCAPS2_CUBEMAP_NEGATIVEZ  = $00008000;
  DDSCAPS2_VOLUME             = $00200000;

  D3DFMT_DXT1                 = $31545844;    //  DXT1 compression texture format
  D3DFMT_DXT2                 = $32545844;    //  DXT2 compression texture format
  D3DFMT_DXT3                 = $33545844;    //  DXT3 compression texture format
  D3DFMT_DXT4                 = $34545844;    //  DXT4 compression texture format
  D3DFMT_DXT5                 = $35545844;    //  DXT5 compression texture format


type
  TDDSPixelFormat = record
    dwSize: Cardinal;
    dwFlags: Cardinal;
    dwFourCC: Cardinal;
    dwRGBBitCount: Cardinal;
    dwRBitMask: Cardinal;
    dwGBitMask: Cardinal;
    dwBBitMask: Cardinal;
    dwAlphaBitMask: Cardinal;
  end;

  TDDSCaps = record
    dwCaps1: Cardinal;
    dwCaps2: Cardinal;
    dwDDSX: Cardinal;
    dwReserved: Cardinal;
  end;

  TDDSHeader = record
    case boolean of
    TRUE:
    (
      dwMagic: Cardinal;
      dwSize: Cardinal;
      dwFlags: Cardinal;
      dwHeight: Cardinal;
      dwWidth: Cardinal;
      dwPitchOrLinearSize: Cardinal;
      dwDepth: Cardinal;
      dwMipMapCount: Cardinal;
      dwReserved: array[0..10] of Cardinal;
      PixelFormat: TDDSPixelFormat;
      Caps: TDDSCaps;
      dwReserved2: Cardinal;
    );
    FALSE:
    (
      Data: array[0..127] of byte;
    );
  end;


function PF_IS_DXT1(var pf: TDDSPixelFormat): boolean;
begin
  result := (((pf.dwFlags and DDPF_FOURCC)<>0) and
             (pf.dwFourCC = D3DFMT_DXT1));
end;

function PF_IS_DXT3(var pf: TDDSPixelFormat): boolean;
begin
  result := (((pf.dwFlags and DDPF_FOURCC)<>0) and
             (pf.dwFourCC = D3DFMT_DXT3));
end;

function PF_IS_DXT5(var pf: TDDSPixelFormat): boolean;
begin
  result := (((pf.dwFlags and DDPF_FOURCC)<>0) and
             (pf.dwFourCC = D3DFMT_DXT5));
end;

function PF_IS_BGRA8(var pf: TDDSPixelFormat): boolean;
begin
  result := (((pf.dwFlags and DDPF_RGB)<>0) and
             ((pf.dwFlags and DDPF_ALPHAPIXELS)<>0) and
             (pf.dwRGBBitCount = 32) and
             (pf.dwRBitMask = $ff0000) and
             (pf.dwGBitMask = $ff00) and
             (pf.dwBBitMask = $ff) and
             (pf.dwAlphaBitMask = $ff000000));
end;

function PF_IS_BGR8(var pf: TDDSPixelFormat): boolean;
begin
  result := (((pf.dwFlags and DDPF_RGB)<>0) and
             ((pf.dwFlags and DDPF_ALPHAPIXELS)=0) and
             (pf.dwRGBBitCount = 24) and
             (pf.dwRBitMask = $ff0000) and
             (pf.dwGBitMask = $ff00) and
             (pf.dwBBitMask = $ff));
end;

function PF_IS_BGR5A1(var pf: TDDSPixelFormat): boolean;
begin
  result := (((pf.dwFlags and DDPF_RGB)<>0) and
             ((pf.dwFlags and DDPF_ALPHAPIXELS)<>0) and
             (pf.dwRGBBitCount = 16) and
             (pf.dwRBitMask = $00007c00) and
             (pf.dwGBitMask = $000003e0) and
             (pf.dwBBitMask = $0000001f) and
             (pf.dwAlphaBitMask = $00008000));
end;

function PF_IS_BGR565(var pf: TDDSPixelFormat): boolean;
begin
  result := (((pf.dwFlags and DDPF_RGB)<>0) and
             ((pf.dwFlags and DDPF_ALPHAPIXELS)=0) and
             (pf.dwRGBBitCount = 16) and
             (pf.dwRBitMask = $0000f800) and
             (pf.dwGBitMask = $000007e0) and
             (pf.dwBBitMask = $0000001f));
end;

function PF_IS_INDEX8(const pf: TDDSPixelFormat): boolean;
begin
  result := (((pf.dwFlags and DDPF_INDEXED)<>0) and
             (pf.dwRGBBitCount = 8));
end;

type
  TDDSLoadInfo = record
    compressed: boolean;
    swap: boolean;
    palette: boolean;
    divSize: Cardinal;
    blockBytes: Cardinal;
    internalFormat: GLenum;
    externalFormat: GLenum;
    typ: GLenum;
  end;


const
  GL_COMPRESSED_RGB_S3TC_DXT1                    = $83F0;
  GL_COMPRESSED_RGBA_S3TC_DXT1                   = $83F1;
  GL_COMPRESSED_RGBA_S3TC_DXT3                   = $83F2;
  GL_COMPRESSED_RGBA_S3TC_DXT5                   = $83F3;

var
  loadInfoDXT1 : TDDSLoadInfo =
  (compressed: true; swap: false; palette: false; divsize: 4; blockBytes: 8; internalFormat: GL_COMPRESSED_RGBA_S3TC_DXT1);

  loadInfoDXT3 : TDDSLoadInfo =
  (compressed: true; swap: false; palette: false; divsize: 4; blockBytes: 16; internalFormat: GL_COMPRESSED_RGBA_S3TC_DXT3);

  loadInfoDXT5 : TDDSLoadInfo =
  (compressed: true; swap: false; palette: false; divsize: 4; blockBytes: 16; internalFormat: GL_COMPRESSED_RGBA_S3TC_DXT5);

  loadInfoBGRA8 : TDDSLoadInfo =
  (compressed: false; swap: false; palette: false; divsize: 1; blockBytes: 4; internalFormat: GL_RGBA8; externalFormat: GL_BGRA; typ: GL_UNSIGNED_BYTE);

  loadInfoBGR8 : TDDSLoadInfo =
  (compressed: false; swap: false; palette: false; divsize: 1; blockBytes: 3; internalFormat: GL_RGB8; externalFormat: GL_BGR; typ: GL_UNSIGNED_BYTE);

  loadInfoBGR5A1 : TDDSLoadInfo =
  (compressed: false; swap: true; palette: false; divsize: 1; blockBytes: 2; internalFormat: GL_RGB5_A1; externalFormat: GL_BGRA; typ: GL_UNSIGNED_SHORT_1_5_5_5_REV);

  loadInfoBGR565 : TDDSLoadInfo =
  (compressed: false; swap: true; palette: false; divsize: 1; blockBytes: 2; internalFormat: GL_RGB5; externalFormat: GL_BGR; typ: GL_UNSIGNED_SHORT_5_6_5);

  loadInfoIndex8 : TDDSLoadInfo =
  (compressed: false; swap: false; palette: true; divsize: 1; blockBytes: 1; internalFormat: GL_RGB8; externalFormat: GL_BGRA; typ: GL_UNSIGNED_BYTE);

function max(v1,v2: Cardinal): Cardinal;
begin
  if v2>v1 then result:=v2 else result:=v1;
end;

type
  TBytes = array[0..9999] of Byte;
  PBytes = ^TBytes;
  TGLuints = array[0..9999] of Cardinal;
  PGLuints = ^TGLuints;

function LoadDDS(Stream: TStream): boolean;
var
  hdr: TDDSHeader;
  mipMapCount, x, y, xSize, ySize, zSize: Cardinal;
  li: ^TDDSLoadInfo;
  data: PBytes;
  unpacked: PGLuints;
  size, ix, zz: Cardinal;
  palette: array[0..255] of Cardinal;
begin
  result := false;
  //  DDS is so simple to read, too
  Stream.Read(hdr, sizeof(hdr));
  if (hdr.dwMagic<>DDS_MAGIC) or (hdr.dwSize<>124) or
     ((hdr.dwFlags and DDSD_PIXELFORMAT)=0) or ((hdr.dwFlags and DDSD_CAPS)=0) then exit;

  if (addr(glTexParameteri)=NIL) or
     (addr(glCompressedTexImage2D)=NIL) or
     (addr(glPixelStorei)=NIL) then exit;
  xSize := hdr.dwWidth;
  ySize := hdr.dwHeight;
  // for loading volume textures
  if hdr.dwFlags and DDSD_DEPTH <> 0 then
   zSize := hdr.dwDepth
  else
   zSize := 0;
  //
  DDSInfo.Width  := xSize;
  DDSInfo.Height := ySize;
  DDSInfo.Depth  := zSize;
  DDSInfo.Format := GL_RGB;
  //
  if zSize > 0 then
   //if ((hdr.Caps.dwCaps1 and DDSCAPS_COMPLEX)<>0) then and ((hdr.Caps.dwCaps2 and DDSCAPS2_VOLUME)<>0) then
    begin
    Size := xSize * ySize * zSize;
    GetMem(Data, Size);
    Stream.Read(Data^, Size);
    glTexImage3D(GL_TEXTURE_3D, 0, GL_LUMINANCE8, xSize, ySize, zSize, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, Data);
    FreeMem(Data);
    Result := True;
    exit;
    end;

  if (PF_IS_DXT1(hdr.PixelFormat)) then li := @loadInfoDXT1 else
  if (PF_IS_DXT3(hdr.PixelFormat)) then li := @loadInfoDXT3 else
  if (PF_IS_DXT5(hdr.PixelFormat)) then li := @loadInfoDXT5 else
  if (PF_IS_BGRA8(hdr.PixelFormat)) then li := @loadInfoBGRA8 else
  if (PF_IS_BGR8(hdr.PixelFormat)) then li := @loadInfoBGR8 else
  if (PF_IS_BGR5A1(hdr.PixelFormat)) then li := @loadInfoBGR5A1 else
  if (PF_IS_BGR565(hdr.PixelFormat)) then li := @loadInfoBGR565 else
  if (PF_IS_INDEX8(hdr.PixelFormat)) then li := @loadInfoIndex8 else
  exit;

  DDSInfo.Format := li.internalFormat;

  x := xSize;
  y := ySize;
{$IFDEF GL_14}
  if GL_14 then
    glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE);
{$ENDIF}
  if hdr.dwFlags and DDSD_MIPMAPCOUNT<>0 then mipMapCount := hdr.dwMipMapCount else mipMapCount := 1;

  if li.compressed then
   begin
    size := max(li.divSize, x ) div li.divSize * max(li.divSize, y) div li.divSize * li.blockBytes;
    GetMem(data, size);
    for ix:=0 to mipMapCount-1 do begin
      Stream.Read(data^, size);
      glCompressedTexImage2D(GL_TEXTURE_2D, ix, li.internalFormat, x, y, 0, size, data);
      x := (x+1) shr 1;
      y := (y+1) shr 1;
      size := max(li.divSize, x ) div li.divSize * max(li.divSize, y ) div li.divSize * li.blockBytes;
    end;
    FreeMem(data);
  end
  else if li.palette then begin
    size := hdr.dwPitchOrLinearSize * ySize;
    GetMem(data, size);
    GetMem(unpacked, size * sizeof(cardinal));
    Stream.Read(palette, 1024);
    for ix:=0 to mipMapCount-1 do begin
      Stream.Read(data^, size);
      for zz:=0 to size-1 do
        unpacked[zz] := palette[data[zz]];
      glPixelStorei(GL_UNPACK_ROW_LENGTH, y);
      glTexImage2D(GL_TEXTURE_2D, ix, li.internalFormat, x, y, 0, li.externalFormat, li.typ, unpacked);
      x := (x+1) shr 1;
      y := (y+1) shr 1;
      size := x * y * li.blockBytes;
    end;
    FreeMem(data);
    FreeMem(unpacked);
  end
  else begin
    if li.swap then
      glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_TRUE);
    size := x * y * li.blockBytes;
    GetMem(data, size);
    for ix:=0 to mipMapCount-1 do begin
      Stream.Read(data^, size);
      glPixelStorei(GL_UNPACK_ROW_LENGTH, y);
      glTexImage2D(GL_TEXTURE_2D, ix, li.internalFormat, x, y, 0, li.externalFormat, li.typ, data);
      x := (x+1) shr 1;
      y := (y+1) shr 1;
      size := x * y * li.blockBytes;
    end;
    FreeMem(data);
    glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_FALSE);
  end;
{$IFDEF GL_12}
  if GL_12 then
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, mipMapCount-1);
{$ENDIF}
  result := true;
end;


end.
