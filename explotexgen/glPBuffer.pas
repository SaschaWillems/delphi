// =============================================================================
//
//   glPBuffer.pas
//
//    Wrapper class for pixel buffers
//
// =============================================================================
//   Copyright © 2003-2009 by Sascha Willems - http://www.saschawillems.de
// =============================================================================
//
//   "The contents of this file are subject to the Mozilla Public License
//   Version 1.1 (the "License"); you may not use this file except in
//   compliance with the License. You may obtain a copy of the License at
//   http://www.mozilla.org/MPL/
//
//   Software distributed under the License is distributed on an "AS IS"
//   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
//   License for the specific language governing rights and limitations
//   under the License.
//
// =============================================================================

unit glPBuffer;

interface

uses
 Windows,
 Classes,
 SysUtils,

 dglOpenGL;

type
 TPixelBuffer = class(TComponent)
  public
   Log       : TStringList;
   DC        : HDC;
   RC        : HGLRC;
   ParentDC  : HDC;
   ParentRC  : HGLRC;
   Handle    : glUInt;
   Width     : glUInt;
   Height    : glUInt;
   TextureID : glUInt;
   function IsLost : Boolean;
   procedure Enable;
   procedure Disable;
   procedure Bind;
   procedure Release;
   constructor Create(pWidth, pHeight : Integer;pParentDC, pParentRC : Cardinal; pAOwner : TComponent; pMipMap : Boolean = True; pCubeMap : Boolean = False); reintroduce;
   destructor Destroy; override;
  end;

var
 PixelBuffer : TPixelBuffer;

implementation

constructor TPixelBuffer.Create(pWidth, pHeight : Integer;pParentDC, pParentRC : Cardinal;pAOwner : TComponent;pMipMap : Boolean = True;  pCubeMap : Boolean = False);
const
 PixelFormatAttribs  : array[0..18] of TGLUInt = (WGL_SUPPORT_OPENGL_ARB, GL_TRUE,
                                                  WGL_DRAW_TO_PBUFFER_ARB, GL_TRUE,
                                                  WGL_BIND_TO_TEXTURE_RGBA_ARB, GL_TRUE,
                                                  WGL_RED_BITS_ARB, 8,
                                                  WGL_GREEN_BITS_ARB, 8,
                                                  WGL_BLUE_BITS_ARB, 8,
                                                  WGL_ALPHA_BITS_ARB, 8,
                                                  WGL_DEPTH_BITS_ARB, 24,
                                                  WGL_DOUBLE_BUFFER_ARB, GL_FALSE,
                                                  0);

{ PixelFormatAttribs  : array[0..12] of TGLUInt = (WGL_SUPPORT_OPENGL_ARB, GL_TRUE,
                                                  WGL_DRAW_TO_PBUFFER_ARB, GL_TRUE,
                                                  WGL_COLOR_BITS_ARB, 24,
                                                  WGL_ALPHA_BITS_ARB, 8,
                                                  WGL_DEPTH_BITS_ARB, 24,
                                                  WGL_DOUBLE_BUFFER_ARB, GL_FALSE, 0);}

 EmptyF              : TGLFLoat = 0;
var
 PFormat       : array[0..64] of TGLUInt;
 PixelBufferAttribs : array[0..6] of TGLUInt;
 NumPFormat    : TGLUInt;
 TempW, TempH  : TGLUInt;
 TempDC        : TGLUInt;
begin
inherited Create(pAOWner);
{if pCubeMap then
 begin
 PixelBufferAttribs[3] := WGL_TEXTURE_CUBE_MAP_ARB;
 end;}
PixelBufferAttribs[0] := WGL_TEXTURE_FORMAT_ARB;
PixelBufferAttribs[1] := WGL_TEXTURE_RGBA_ARB;
PixelBufferAttribs[2] := WGL_TEXTURE_TARGET_ARB;
PixelBufferAttribs[3] := WGL_TEXTURE_2D_ARB;
PixelBufferAttribs[4] := WGL_MIPMAP_TEXTURE_ARB;
if pMipMap then
 PixelBufferAttribs[5] := GL_TRUE
else
 PixelBufferAttribs[5] := GL_FALSE;
PixelBufferAttribs[6] := 0;
ParentDC := pParentDC;
ParentRC := pParentRC;
Width    := pWidth;
Height   := pHeight;
Log := TStringList.Create;
Log.Add('PixelBuffer->Creating->Width='+IntToStr(Width)+' Height='+IntToStr(Height));
TempDC := wglGetCurrentDC;
if TempDC > 0 then
 Log.Add('PixelBuffer->wglGetCurrentDC->Obtained valid DC : '+IntToStr(TempDC))
else
 begin
 Log.Add('PixelBuffer->wglGetCurrentDC->Couldn''t obtain valid device context');
 exit;
 end;
if wglChoosePixelFormatARB(TempDC, @PixelFormatAttribs, @EmptyF, Length(PFormat), @PFormat, @NumPFormat) then
 begin
 Log.Add('PixelBuffer->wglChoosePixelFormatARB->'+IntToStr(NumPFormat)+' suitable pixelformats found');
 end
else
 begin
 Log.Add('PixelBuffer->wglChoosePixelFormatARB->No suitable pixelformat found');
 exit;
 end;
Handle := wglCreatePBufferARB(TempDC, PFormat[0], Width, Height, @PixelBufferAttribs);
if Handle > 0 then
 begin
 wglQueryPbufferARB(Handle, WGL_PBUFFER_WIDTH_ARB, @TempW);
 wglQueryPbufferARB(Handle, WGL_PBUFFER_HEIGHT_ARB, @TempH);
 Log.Add('PixelBuffer->wglCreatePBufferARB->PixelBuffer successfully created.Received size : Width='+IntToStr(TempW)+' Height='+IntToStr(TempH));
 end
else
 begin
 Log.Add('PixelBuffer->wglCreatePBufferARB->Couldn''t obtain valid handle');
 exit;
 end;
DC := wglGetPBufferDCARB(Handle);
if DC > 0 then
 Log.Add('PixelBuffer->wglGetPBufferDCARB->Recieved valid DC for PBuffer : '+IntToStr(DC))
else
 begin
 Log.Add('PixelBuffer->wglGetPBufferDCARB->Couldn''t obtain valid DC for PBuffer');
 exit;
 end;
RC := wglCreateContext(DC);
if RC > 0 then
 Log.Add('PixelBuffer->wglCreateContext->Created rendercontext for PBuffer : '+IntToStr(RC))
else
 begin
 Log.Add('PixelBuffer->wglGetPBufferDCARB->Couldn''t create rendercontext for PBuffer');
 exit;
 end;
glGenTextures(1, @TextureID);
glBindTexture(GL_TEXTURE_2D, TextureID);
glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//
glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP_SGIS, GL_TRUE);
glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
//
wglShareLists(pParentRC, RC);
end;

destructor TPixelBuffer.Destroy;
begin
wglDeleteContext(RC);
wglReleasePbufferDCARB(Handle, DC);
wglDestroyPbufferARB(Handle);
//Log.SaveToFile('puffer_log.txt');
Log.Free;
inherited;
end;

function TPixelBuffer.IsLost : Boolean;
var
 Flag : TGLUInt;
begin
Result := False;
wglQueryPbufferARB(Handle, WGL_PBUFFER_LOST_ARB, @Flag);
if Flag <> 0 then
 Result := True;
end;

procedure TPixelBuffer.Enable;
begin
wglMakeCurrent(DC, RC);
end;

procedure TPixelBuffer.Disable;
begin
wglMakeCurrent(ParentDC, ParentRC);
end;

procedure TPixelBuffer.Bind;
begin
glBindTexture(GL_TEXTURE_2D, TextureID);
wglBindTexImageARB(Handle, WGL_FRONT_LEFT_ARB);
end;

procedure TPixelBuffer.Release;
begin
wglReleaseTexImageARB(Handle, WGL_FRONT_LEFT_ARB);
end;

end.
