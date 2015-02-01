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

unit TrugBild_DecisionClass;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, Math,glMisc, Types, ComObj,
  dglOpenGL, Vcl.ExtCtrls, glFrameBufferObject, glSlangShaderManager, glMath, glTextureManager, glFont,
  XMLDoc, XMLIntf,

  TrugBild_Global;

type
	TDecisionAnswer = class
  	public
      Text      : String;
      SwayTimer : Single;
      BlurTimer : Single;
      Rotation  : TGLVertex3f;
      Highlight : Single;
      Bias			: Integer;
      // Type : Negative, Positive, Neutral, etc.
      procedure RenderCorridor(ASelected : Boolean; ADepth : Single; AXEndOffset : Single = 0; AForColorPicking : Boolean = False);
      procedure RenderHole;
      procedure Reset;
  end;

  TDecisionVisual = (visCorridors, visHoles, visDoors, visLadders);
  TDecision = class
  	private
    	SwayTimer : Single;
      procedure LoadFromXML(AXMLNode : IXMLNode);
    public
      OffsetX	    : Single;
      Text        : String;
      PlayerText  : record
      					  	   Text : String;
                      CharPos : Integer;
                      CharTimer : Single;
      					  	 end;
      Visual      : TDecisionVisual;
      Answers     : array of TDecisionAnswer;
      Selection   : Integer;
      TimeLeft    : Single;
      MaxTime     : Single;
      NoShuffle	  : Boolean;
      procedure Render;
      procedure RenderAnswer(AIndex : Integer);
      procedure Update(AMultiplier : Single);
      procedure Reset;
    	constructor Create(AXMLNode : IXMLNode = nil; ANoShuffle : Boolean = False);
    	procedure ShuffleAnswers;
  end;

implementation

// =====================================================================================================================
//  TDecisionAnswer
// =====================================================================================================================


// =====================================================================================================================
// TDecisionAnswer.RenderCorridor
// =====================================================================================================================
procedure TDecisionAnswer.RenderCorridor(ASelected : Boolean; ADepth : Single; AXEndOffset : Single = 0; AForColorPicking : Boolean = False);
var
	Dim : array[0..2] of Single;
  ColStart : TglVertex4f;
  ColEnd : TglVertex4f;
  i : Integer;
  xoff,yoff,z : Single;
  nsteps : Byte;
begin
	Dim[0] := 10;
  Dim[1] := 10;
  Dim[2] := ADepth;

  if not AForColorPicking then
  	begin
    	ColStart := glVertex(0, 0, 0, 1);
      ColEnd 	 := glVertex(0.2, 0.2 ,0.2, 1);

      if ASelected then
      	begin
          // TODO : Selection timer per corridor
          ColStart := glVertex(Highlight*0.75, Highlight*0.75, Highlight*0.75, 1);
          ColEnd := glVertex(0, 0, 0, 1);
      	end;

      glBegin(GL_QUADS);
        glColor4fv(@ColStart); glVertex3f( Dim[0]+AXEndOffset, -Dim[1], -Dim[2]);
        glColor4fv(@ColStart); glVertex3f(-Dim[0]+AXEndOffset, -Dim[1], -Dim[2]);
        glColor4fv(@ColStart); glVertex3f(-Dim[0]+AXEndOffset,  Dim[1], -Dim[2]);
        glColor4fv(@ColStart); glVertex3f( Dim[0]+AXEndOffset,  Dim[1], -Dim[2]);

        glColor4fv(@ColStart); glVertex3f( Dim[0]+AXEndOffset, Dim[1], -Dim[2]);
        glColor4fv(@ColStart); glVertex3f(-Dim[0]+AXEndOffset, Dim[1], -Dim[2]);
        glColor4fv(@ColEnd);   glVertex3f(-Dim[0], Dim[1],  Dim[2]);
        glColor4fv(@ColEnd);   glVertex3f( Dim[0], Dim[1],  Dim[2]);

        glColor4fv(@ColStart); glVertex3f( Dim[0]+AXEndOffset, -Dim[1], -Dim[2]);
        glColor4fv(@ColStart); glVertex3f(-Dim[0]+AXEndOffset, -Dim[1], -Dim[2]);
        glColor4fv(@ColEnd);   glVertex3f(-Dim[0], -Dim[1],  Dim[2]);
        glColor4fv(@ColEnd);   glVertex3f( Dim[0], -Dim[1],  Dim[2]);

        glColor4fv(@ColEnd);   glVertex3f(-Dim[0],  Dim[1],  Dim[2]);
        glColor4fv(@ColStart); glVertex3f(-Dim[0]+AXEndOffset,  Dim[1], -Dim[2]);
        glColor4fv(@ColStart); glVertex3f(-Dim[0]+AXEndOffset, -Dim[1], -Dim[2]);
        glColor4fv(@ColEnd);   glVertex3f(-Dim[0], -Dim[1],  Dim[2]);

        glColor4fv(@ColEnd);   glVertex3f( Dim[0],  Dim[1],  Dim[2]);
        glColor4fv(@ColStart); glVertex3f( Dim[0]+AXEndOffset,  Dim[1], -Dim[2]);
        glColor4fv(@ColStart); glVertex3f( Dim[0]+AXEndOffset, -Dim[1], -Dim[2]);
        glColor4fv(@ColEnd);   glVertex3f( Dim[0], -Dim[1],  Dim[2]);
  		glEnd;

      if ASelected then
      	begin
          glColor3f(Highlight, Highlight, Highlight);
          glDepthFunc(GL_ALWAYS);
          TextureManager.SetBlending(bmAdd);
          TextureManager.DrawQuad(AXEndOffset, 0, -Dim[2]*0.95, Dim[0]*4, Dim[1]*4, 'radialgradientblack', flCenter);
          TextureManager.SetBlending(bmNone);
          TextureManager.DisableTextureStage(GL_TEXTURE0);
          glDepthFunc(GL_LESS);
        end;
    end
  else
  	begin
      // Only simple quad for color selection
      glBegin(GL_QUADS);
        glVertex3f( Dim[0]*3+AXEndOffset, -Dim[1]*3, -Dim[2]);
        glVertex3f(-Dim[0]*3+AXEndOffset, -Dim[1]*3, -Dim[2]);
        glVertex3f(-Dim[0]*3+AXEndOffset,  Dim[1]*3, -Dim[2]);
        glVertex3f( Dim[0]*3+AXEndOffset,  Dim[1]*3, -Dim[2]);
      glEnd;
    end;
end;


// =====================================================================================================================
//  TDecisionAnswer.RenderHole
// =====================================================================================================================
procedure TDecisionAnswer.RenderHole;
begin
	//
end;


// =====================================================================================================================
//  TDecisionAnswer.Reset
// =====================================================================================================================
procedure TDecisionAnswer.Reset;
begin
  SwayTimer := Random(360);
  BlurTimer := 0;
  Highlight := 0;
end;


// =====================================================================================================================
//  TDecision
// =====================================================================================================================


// =====================================================================================================================
//  TDecision.Create
// =====================================================================================================================
constructor TDecision.Create(AXMLNode: IXMLNode = nil; ANoShuffle : Boolean = False);
begin
	NoShuffle := ANoShuffle;
	if Assigned(AXMLNode) then
  	LoadFromXML(AXMLNode);
end;


// =====================================================================================================================
//  TDecision.LoadFromXML
// =====================================================================================================================
procedure TDecision.LoadFromXML(AXMLNode: IXMLNode);
var
	i : Integer;
  Vis : String;
begin
	Text := AXMLNode.Attributes['text'];

  Vis  := AXMLNode.Attributes['visual'];
  if Vis = 'corridors' then
  	Visual := visCorridors;
  if Vis = 'holes' then
  	Visual := visHoles;
  if Vis = 'doors' then
  	Visual := visDoors;
  if Vis = 'ladders' then
  	Visual := visLadders;

  PlayerText.Text      := AXMLNode.Attributes['playertext'];
  PlayerText.CharPos   := 0;
  PlayerText.CharTimer := 0;

  MaxTime := 5;  // TODO : Maybe tweak? Was 20 initially (far too long)

  for i := 0 to High(Answers) do
  	Answers[i].Free;

  for i := 0 to AXMLNode.ChildNodes.Count - 1 do
  	if SameText(AXMLNode.ChildNodes[i].NodeName, 'answer') then
      begin
				SetLength(Answers, Length(Answers)+1);
        Answers[High(Answers)]           := TDecisionAnswer.Create;
        Answers[High(Answers)].Text      := AXMLNode.ChildNodes[i].Attributes['text'];
        Answers[High(Answers)].Bias      := AXMLNode.ChildNodes[i].Attributes['bias'];
        Answers[High(Answers)].SwayTimer := Random(360);
      end;

	ShuffleAnswers;
end;


// =====================================================================================================================
//  TDecision.Render
// =====================================================================================================================
procedure TDecision.Render;
begin
  glColor3f(1, 1, 1);
	Font.Print2D(Text, [OrthoSize.x / 2 + Sin(DegToRad(SwayTimer)) * 20, 100{ + Cos(DegToRad(SwayTimer)) * 3}, 0], FontAlignCenter, 4, 0.75, False);
  SwayTimer := Wrap(SwayTimer + TimeFactor * 10, 360);

  if PlayerText.Text <> '' then
  	begin
    	Font.Print2D(Copy(PlayerText.Text, 1, PlayerText.CharPos), [OrthoSize.x / 2, OrthoSize.y - 50, 0], FontAlignCenter, 2, 0.5, True);
    end;
end;


// =====================================================================================================================
//  TDecision.RenderAnswer
// =====================================================================================================================
procedure TDecision.RenderAnswer(AIndex: Integer);
begin
	if AIndex > High(Answers) then
  	exit;
  glDepthFunc(GL_ALWAYS);
  TextureManager.SetBlending(bmNone);
  glColor3f(1, 1, 1);
  with Answers[AIndex] do
  	begin

	      if Visual = visCorridors then
          begin
            glPushMatrix;
              glTranslatef(Sin(DegToRad(SwayTimer)) * 3, Cos(DegToRad(SwayTimer)) * 3, Sin(DegToRad(SwayTimer)) * 1);
              glRotatef(Rotation.x, 1, 0, 0);
              glRotatef(Rotation.y, 0, 1, 0);
              glRotatef(Rotation.z, 0, 0, 1);
              Font.Print2D(Text, [0, 0, 0], FontAlignCenter, 0.5, 1, True);
            glPopMatrix;
          end;

	      if Visual = visHoles then
          begin
            glPushMatrix;
            	TextShadowOffset := 0.75;
              glRotatef(Rotation.x, 1, 0, 0);
              glRotatef(Rotation.y, 0, 1, 0);
              glRotatef(Rotation.z, 0, 0, 1);
              Font.Print2D(Text, [0, 0, 0], FontAlignCenter, 0.25, 1, True);
            	TextShadowOffset := 0;
            glPopMatrix;
          end;

				if Visual = visDoors then
        	begin
            glPushMatrix;
              glRotatef(Rotation.x, 1, 0, 0);
              glRotatef(Rotation.y, 0, 1, 0);
              glRotatef(Rotation.z, 0, 0, 1);
              FontBlack.Print2D(Text, [0, 0, 0], FontAlignCenter, 3.5, 1, False);
            glPopMatrix;
          end;

				if Visual = visLadders then
        	begin
            glPushMatrix;
              glRotatef(Rotation.x, 1, 0, 0);
              glRotatef(Rotation.y, 0, 1, 0);
              glRotatef(Rotation.z, 0, 0, 1);
              FontBlack.Print2D(Text, [0, 0, 0], FontAlignCenter, 0.25, 1, False);
            glPopMatrix;
          end;

			// Timer
      SwayTimer := SwayTimer + TimeFactor * 4;
      if SwayTimer > 360 then
        SwayTimer := SwayTimer - 360;
    end;
  glDepthFunc(GL_LESS);
  glDisable(GL_TEXTURE_2D);
end;


// =====================================================================================================================
//  TDecision.Reset
// =====================================================================================================================
procedure TDecision.Reset;
var
	i : Integer;
begin
	TimeLeft             := MaxTime;
  Selection            := -1;
  PlayerText.CharPos   := 0;
  PlayerText.CharTimer := 0;
  for i := 0 to High(Answers) do
  	Answers[i].Reset;
  ShuffleAnswers;
end;


// =====================================================================================================================
//  TDecision.ShuffleAnswers
// =====================================================================================================================
//  Rearranges the order of answers
// =====================================================================================================================
procedure TDecision.ShuffleAnswers;
var
	TmpAnswers : array of TDecisionAnswer;
  i,j : Integer;
  Index : Integer;
  OK : Boolean;
begin
	if NoShuffle then
  	exit;
	if Length(Answers) = 1 then
  	exit;
	SetLength(TmpAnswers, Length(Answers));
  for i := 0 to High(TmpAnswers) do
  	TmpAnswers[i] := nil;
	for i := 0 to High(Answers) do
  	repeat
			OK := False;
      Index := Random(Length(TmpAnswers));
      if not Assigned(TmpAnswers[Index]) then
      	begin
          TmpAnswers[Index] := Answers[i];
          OK := True;
        end;
    until OK;
	for i := 0 to High(Answers) do
  	Answers[i] := TmpAnswers[i];
end;


// =====================================================================================================================
//  TDecision.Update
// =====================================================================================================================
procedure TDecision.Update(AMultiplier : Single);
var
	i : Integer;
begin
	for i := 0 to High(Answers) do
  	if i = Selection then
    	begin
				Answers[i].Highlight := Answers[i].Highlight + 0.5 * TimeFactor;
        if Answers[i].Highlight > 1 then
        	Answers[i].Highlight := 1;
      end
    else
    	begin
				Answers[i].Highlight := Answers[i].Highlight - 0.05 * TimeFactor;
        if Answers[i].Highlight < 0 then
        	Answers[i].Highlight := 0;
      end;

	TimeLeft := TimeLeft - 0.1 * (TimeFactor * AMultiplier);

  with PlayerText do
  	begin
      CharTimer := CharTimer - TimeFactor * 0.5;
      if CharTimer < 0 then
        begin
          CharTimer := 1;
          inc(CharPos);
          if CharPos > Length(Text) then
            CharPos := Length(Text);
        end;
    end;
end;

end.
