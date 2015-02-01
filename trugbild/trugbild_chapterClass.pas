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

unit TrugBild_ChapterClass;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, Math,glMisc, Types, ComObj,
  dglOpenGL, Vcl.ExtCtrls, glFrameBufferObject, glSlangShaderManager, glMath, glTextureManager, glFont,
  XMLDoc, XMLIntf, bassSoundSystem,

  TrugBild_Global, TrugBild_GameClass, TrugBild_DecisionClass, TrugBild_PlayerClass, TrugBild_RealityScene,
  TrugBild_DeathScene;

type
	TChapter = class
    Decisions    : array of TDecision;
    Decision     : TDecision;
    CurrDecision : Integer;
    Selected     : Integer;
  	Name         : String;
//    Title        : String;
//    TagLine      : String;
    TitleTimer	 : Single;
    BlurStrength : Single;
    RealityFade  : Single;
    Finished		 : Boolean;
    procedure LoadFromXML(AXMLNode : IXMLNode);
    procedure Reset;
    constructor Create(AXMLNode : IXMLNode = nil);
    destructor Destroy; override;
    function GetDecision : TDecision;
    function NextDecision : Boolean;
    procedure Update;
    procedure ShuffleDecisions;
  end;

implementation

// =====================================================================================================================
// TChapter
// =====================================================================================================================


// =====================================================================================================================
// TChapter.Create
// =====================================================================================================================
constructor TChapter.Create(AXMLNode : IXMLNode = nil);
begin
	if Assigned(AXMLNode) then
  	LoadFromXML(AXMLNode);
end;


// =====================================================================================================================
// TChapter.Create
// =====================================================================================================================
destructor TChapter.Destroy;
var
	i : Integer;
begin
	for i := 0 to High(Decisions) do
  	Decisions[i].Free;
  inherited;
end;


// =====================================================================================================================
// TChapter.GetDecision
// =====================================================================================================================
function TChapter.GetDecision: TDecision;
begin
	Result := Decisions[CurrDecision];
end;


// =====================================================================================================================
// TChapter.LoadFromXML
// =====================================================================================================================
procedure TChapter.LoadFromXML(AXMLNode : IXMLNode);
var
	i : Integer;
begin
  Name        := AXMLNode.Attributes['name'];
//  Title       := AXMLNode.Attributes['title'];
//  TagLine     := AXMLNode.Attributes['tagline'];

  // Load Decisions
  for i := 0 to AXMLNode.ChildNodes['decisions'].ChildNodes.Count - 1 do
  	if SameText(AXMLNode.ChildNodes['decisions'].ChildNodes[i].NodeName, 'decision') then
    	begin
        SetLength(Decisions, Length(Decisions)+1);
   			Decisions[i] := TDecision.Create(AXMLNode.ChildNodes['decisions'].ChildNodes[i]);
      end;

	ShuffleDecisions;

  Decision := Decisions[0];
  Decision.Reset;

  Selected   := -1;
  TitleTimer := 1;
end;


// =====================================================================================================================
// TChapter.NextDecision
// =====================================================================================================================
function TChapter.NextDecision : Boolean;
begin
	Result := True;
  Player.Position := glVertex(0, 1, -22);
  Selected := -1;
  inc(CurrDecision);
  // If last decision has been reached, move to reality scene
  if CurrDecision > High(Decisions) then
    begin
      CurrDecision   := 0;
      Finished       := True;
      Result 				 := False;
    end;
  Decision := Decisions[CurrDecision];
  Decision.Reset;
  BlurStrength := 0;
  RealityFade := 0;
  Player.StressLevel := 1;
end;


// =====================================================================================================================
// TChapter.ShuffleDecisions
// =====================================================================================================================
procedure TChapter.ShuffleDecisions;
var
	TmpDecisions : array of TDecision;
  i,j : Integer;
  Index : Integer;
  OK : Boolean;
begin
	SetLength(TmpDecisions, Length(Decisions));
  for i := 0 to High(TmpDecisions) do
  	TmpDecisions[i] := nil;
	for i := 0 to High(Decisions) do
  	repeat
			OK := False;
      Index := Random(Length(TmpDecisions));
      if not Assigned(TmpDecisions[Index]) then
      	begin
          TmpDecisions[Index] := Decisions[i];
          OK := True;
        end;
    until OK;

	for i := 0 to High(Decisions) do
  	Decisions[i] := TmpDecisions[i];
end;


// =====================================================================================================================
// TChapter.Reset
// =====================================================================================================================
procedure TChapter.Reset;
var
	i : Integer;
begin
  ShuffleDecisions;
	for i := 0 to High(Decisions) do
  	Decisions[i].Reset;
	CurrDecision := 0;
	Decision     := Decisions[0];
  BlurStrength := 0;
  RealityFade  := 0;
  Selected     := -1;
  TitleTimer	 := 1;
  Finished		 := False;
end;


// =====================================================================================================================
// TChapter.Update
// =====================================================================================================================
procedure TChapter.Update;
begin
	if TitleTimer > 0 then
  	TitleTimer := Clamp(TitleTimer - TimeFactor * 0.05, 0, 1);

  // Effect with multiple steps :
  // 10 seconds left : Start to increase player stress level
  //  0 seconds left : Start to blur screen
  // 10 seconds over : Start to blend in reality scene (TODO : with death as a shape in backround, or white tunnel?)
  // 15 seconds over : Fade in light of "death" before player dies
  // 25 seconds over : Fade to black and end game... TODO

  if Decision.TimeLeft < -25 then
  	begin
    	if Game.State <> gsEnding then
      	begin
        	Game.Ending := geBad;
   				Game.ChangeState(gsEnding);
        end;
    end
  else
    if Decision.TimeLeft < -15 then
      begin
        DeathScene.LightFade := Abs(Decision.TimeLeft+15)/10;
        RealityFade := 1-(Decision.TimeLeft+20)/10;
      end
    else
      if Decision.TimeLeft < -10 then
        begin
          // Show reality scene (TODO : with death hint, see above)
          RealityFade := 1-(Decision.TimeLeft+20)/10;
        end
      else
        if Decision.TimeLeft < 0 then
          begin
            // Start to blur sceen
            BlurStrength := Clamp(BlurStrength + TimeFactor * 0.15, 0, 15);
          end
        else
          if Decision.TimeLeft < 10 then
            begin
              // Increase stress level
              if Decision.TimeLeft > 0 then
                Player.StressLevel := Clamp(1 + (10-Decision.TimeLeft) * 0.4, 1, 4);
            end;
end;

end.
