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

unit TrugBild_PlayerClass;

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
  bass,
  Trugbild_Global;

type
  TPlayerGender = (genderMale, genderFemale);

  TPlayer = class
  private
    ChannelHeartBeat: HCHANNEL;
  public
    DecisionHistory: TStringList;
    AnswerHistory: TStringList;
    Position: TGLVertex3f;
    PosDef: TGlVertex3f;
    Rotation: TGLVertex3f;
    MoveDir: TGLVertex3f;
    StressLevel: single;
    Shape: string;
    BreatheTimer: single;
    Bias: integer;    // negative < 0 > positive answers
    IsDead: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    procedure Update;
    procedure Render(AAlpha: single);
  end;

var
  Player: TPlayer;

implementation


 // =====================================================================================================================
 //  TPlayer
 // =====================================================================================================================


 // =====================================================================================================================
 //  TPlayer.Reset
 // =====================================================================================================================
procedure TPlayer.Reset;
begin
  Position     := PosDef;
  StressLevel  := 1;
  Bias         := 0;
  Shape        := 'playershape_male';
  BreatheTimer := Random(360);
  IsDead       := False;
  DecisionHistory.Clear;
  AnswerHistory.Clear;
end;


 // =====================================================================================================================
 //  TPlayer.Create
 // =====================================================================================================================
constructor TPlayer.Create;
begin
  DecisionHistory := TStringList.Create;
  AnswerHistory   := TStringList.Create;
  PosDef          := glVertex(0, 1, -22);
  Reset;
end;


 // =====================================================================================================================
 //  TPlayer.Destroy
 // =====================================================================================================================
destructor TPlayer.Destroy;
begin
  DecisionHistory.Free;
  AnswerHistory.Free;
  inherited;
end;


 // =====================================================================================================================
 //  TPlayer.Render
 // =====================================================================================================================
procedure TPlayer.Render(AAlpha: single);
begin
  // Playershape TODO : Move to player class
  TextureManager.SetBlending(bmBlend);
  glColor4f(1, 1, 1, AAlpha);
  glPushMatrix;
  glTranslatef(OrthoSize.x / 2 + Player.Rotation.y * 20, OrthoSize.y + 250{ - Sin(DegToRad(DegTimer))*5}, 0);
  glScalef(1 + Sin(DegToRad(BreatheTimer)) * 0.025 * Player.StressLevel, 1 + Sin(DegToRad(BreatheTimer)) * 0.005 * Player.StressLevel, 1);
  glRotatef(Rotation.y * 8, 0, 1, 0);
  TextureManager.DrawQuad(0, 0, 0, 512, 1024, Shape, flCenter, True);
  glPopMatrix;
end;


 // =====================================================================================================================
 //  TPlayer.Update
 // =====================================================================================================================
procedure TPlayer.Update;
begin
  if StressLevel > 1 then
  begin
    StressLevel := StressLevel - TimeFactor * 0.025;
    if StressLevel < 1 then
      StressLevel := 1;
    //      if BASS_ChannelIsActive(ChannelHeartBeat) <> BASS_ACTIVE_PLAYING then
    //        ChannelHeartBeat := SoundSystem.PlaySample('heartbeat', True, 0)
    //      else
    //        BASS_ChannelSetAttribute(ChannelHeartBeat, BASS_ATTRIB_VOL, StressLevel * 0.25);
  end;
  BreatheTimer := Wrap(BreatheTimer + TimeFactor * 10, 360);
end;

end.

