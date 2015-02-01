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

unit TrugBild_MainMenu;

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
  Trugbild_Global,
  TrugBild_GameClass,
  TrugBild_DecisionClass,
  TrugBild_PlayerClass;

type
  TMainMenu = class
  private
  public
    Decision: TDecision;
    Selected: integer;
    constructor Create;
    destructor Destroy; override;
    procedure Select;
    procedure Reset;
  end;

var
  MainMenu: TMainMenu;


implementation

 // =====================================================================================================================
 // TMainMenu
 // =====================================================================================================================


 // =====================================================================================================================
 // TMainMenu.Create
 // =====================================================================================================================
constructor TMainMenu.Create;
const
  AnswerText: array[0..2] of string = ('About', 'Start', 'Leave');
var
  i: integer;
begin
  Selected := -1;
  Decision := TDecision.Create(nil, True);
  with Decision do
  begin
    Visual := visCorridors;
    SetLength(Answers, 3);
    for i := 0 to High(Answers) do
    begin
      Answers[i]      := TDecisionAnswer.Create;
      Answers[i].Text := AnswerText[i];
    end;
  end;
end;


 // =====================================================================================================================
 // TMainMenu.Destroy
 // =====================================================================================================================
destructor TMainMenu.Destroy;
begin
  Decision.Free;
  inherited;
end;


 // =====================================================================================================================
 // TMainMenu.Reset
 // =====================================================================================================================
procedure TMainMenu.Reset;
begin
  Decision.Reset;
  Selected := -1;
end;


 // =====================================================================================================================
 // TMainMenu.Select
 // =====================================================================================================================
procedure TMainMenu.Select;
begin
  Player.MoveDir   := glVertex(0, 0, 2);
  Player.MoveDir.x := -Decision.OffsetX;
  Selected         := Decision.Selection;
end;

end.

