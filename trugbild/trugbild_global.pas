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

unit TrugBild_Global;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, Math,glMisc, Types, ComObj,
  dglOpenGL, Vcl.ExtCtrls, glFrameBufferObject, glSlangShaderManager, glMath, glTextureManager, glFont,
  XMLDoc, XMLIntf;

var
  ShaderManager : TGLSLShaderManager;
  MousePos 			: TPoint;
  OrthoSize			: TPoint;

  DegTimer		  : Single;
  Timer					: Single;
  TimeFactor    : Single;

  Font					: TTexFont;
  FontBlack     : TTexFont;

  AspectRatio		: Single;

	Quit 					: Boolean;

const
 CursorDim      = 80;
 ColSelStep			= 25;
 FadeSpeed      = 0.075;

function Clamp(AValue : Single; AMin, AMax : Single) : Single;
function Wrap(AVAlue : Single; AWrapAround : Single) : Single;
procedure RenderLoadingScreen(ADC : HDC);

implementation


function Clamp(AValue : Single; AMin, AMax : Single) : Single;
begin
	Result := AValue;
  if AValue < AMin then
  	exit(AMin);
  if AValue > AMax then
  	exit(AMax);
end;


function Wrap(AVAlue : Single; AWrapAround : Single) : Single;
begin
	Result := AValue;
	if AValue > AWrapAround then
  	Result := AValue - AWrapAround;
end;


procedure RenderLoadingScreen(ADC : HDC);
begin
	glClearColor(0.05, 0.05, 0.05, 1);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
	glViewPort(0, 0, Application.MainForm.ClientWidth, Application.MainForm.ClientHeight);
  glOrtho(0, OrthoSize.x, OrthoSize.y, 0, -128, 128);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glDisable(GL_CULL_FACE);

  glTranslatef(0, OrthoSize.Y / 2 - 150, 0);
  TextureManager.SetBlending(bmBlend);
  TextureManager.DrawQuad(OrthoSize.x / 2, 128, 0, 512, 256, 'mainmenu_logo', (flCenter), True);
  TextureManager.DrawQuad(OrthoSize.x / 2, 128, 1, 512, 256, 'mainmenu_logo', (flCenter), True);
  TextureManager.DrawQuad(OrthoSize.x / 2 + 180, 200, 2, 512, 128, 'mainmenu_gameby', (flCenter), True);

  glDepthMask(False);

  SwapBuffers(ADC);
end;

end.
