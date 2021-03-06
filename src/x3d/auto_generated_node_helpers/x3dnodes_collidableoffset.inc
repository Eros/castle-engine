{ -*- buffer-read-only: t -*-

  Copyright 2015-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Automatically generated node properties.

  Do not edit this file manually!
  To add new properties:
  - add them to the text files in nodes_specification/components/ ,
  - and regenerate include files by running
    nodes_specification/x3d-nodes-to-pascal/x3d-nodes-to-pascal.lpr .

  The documentation for properties should go to x3dnodes_documentation.txt . }

{$ifdef read_interface}

  strict private
    function GetCollidable: TAbstractNBodyCollidableNode;
    procedure SetCollidable(const Value: TAbstractNBodyCollidableNode);
  public
    property Collidable: TAbstractNBodyCollidableNode read GetCollidable write SetCollidable;

{$endif read_interface}

{$ifdef read_implementation}

{ TCollidableOffsetNode ----------------------------------------------- }

function TCollidableOffsetNode.GetCollidable: TAbstractNBodyCollidableNode;
begin
  if FdCollidable.Value is TAbstractNBodyCollidableNode then
    Result := TAbstractNBodyCollidableNode(FdCollidable.Value)
  else
    Result := nil;
end;

procedure TCollidableOffsetNode.SetCollidable(const Value: TAbstractNBodyCollidableNode);
begin
  FdCollidable.Send(Value);
end;

{$endif read_implementation}
