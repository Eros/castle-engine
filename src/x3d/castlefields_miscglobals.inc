{
  Copyright 2002-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Global utilities related to X3D fields. }
{$ifdef read_interface}

{ Decode color from integer value, following VRML/X3D SFImage specification.
  @groupBegin }
procedure DecodeX3DColor(const Pixel: LongWord; var G: Byte);
procedure DecodeX3DColor(const Pixel: LongWord; var GA: TVector2Byte);
procedure DecodeX3DColor(const Pixel: LongWord; var RGB: TVector3Byte);
procedure DecodeX3DColor(const Pixel: LongWord; var RGBA: TVector4Byte);

procedure DecodeX3DColor(const Pixel: LongInt; var G: Byte);
procedure DecodeX3DColor(const Pixel: LongInt; var GA: TVector2Byte);
procedure DecodeX3DColor(const Pixel: LongInt; var RGB: TVector3Byte);
procedure DecodeX3DColor(const Pixel: LongInt; var RGBA: TVector4Byte);
{ @groupEnd }

const
  X3DChangeToStr: array [TX3DChange] of string =
  ( 'Visible Geometry',
    'Visible Non-Geometry',
    'Redisplay',
    'Transform',
    'Coordinate',
    'VRML 1.0 State (but not affecting geometry or Coordinate)',
    'VRML 1.0 State (affecting geometry, but not Coordinate)',
    'Material',
    'Blending',
    'Light active property',
    'Light location/direction',
    'Light for shadow volumes',
    'Switch choice',
    'Color node',
    'Texture coordinate',
    'Texture transform',
    'Geometry',
    'Environmental sensor bounds',
    'Time stop/start/pause/resume',
    'Viewpoint vectors',
    'Viewpoint projection',
    'Texture image',
    'Texture renderer properties',
    'TextureProperties node',
    'Shadow caster',
    'Generated texture update',
    'FontStyle',
    'HeadLight on',
    'ClipPlane',
    'X3DDragSensorNode.enabled',
    'NavigationInfo',
    'ScreenEffect.enabled',
    'Background',
    'Everything',
    'Shadow maps',
    'Wireframe');

function X3DChangesToStr(const Changes: TX3DChanges): string;

{$endif read_interface}

{$ifdef read_implementation}

procedure DecodeX3DColor(const Pixel: LongWord; var G: Byte);
begin
  G := Pixel and $FF;
end;

procedure DecodeX3DColor(const Pixel: LongWord; var GA: TVector2Byte);
begin
  GA[0] := (pixel shr 8) and $FF;
  GA[1] := pixel and $FF;
end;

procedure DecodeX3DColor(const Pixel: LongWord; var RGB: TVector3Byte);
begin
  RGB[0] := (pixel shr 16) and $FF;
  RGB[1] := (pixel shr 8) and $FF;
  RGB[2] := pixel and $FF;
end;

procedure DecodeX3DColor(const Pixel: LongWord; var RGBA: TVector4Byte);
begin
  RGBA[0] := (pixel shr 24) and $FF;
  RGBA[1] := (pixel shr 16) and $FF;
  RGBA[2] := (pixel shr 8) and $FF;
  RGBA[3] := pixel and $FF;
end;

{ We have to turn range checking off, because converting from LongInt
  to LongWord below may cause range check errors. Yes, we want to
  directly treat LongInt as 4 bytes here, because DecodeX3DColor
  works on separate bytes. See
  http://castle-engine.sourceforge.net/x3d_implementation_texturing3d.php
  comments about PixelTexture3D. }

{$include norqcheckbegin.inc}

procedure DecodeX3DColor(const Pixel: LongInt; var G: Byte);
begin
  DecodeX3DColor(LongWord(Pixel), G);
end;

procedure DecodeX3DColor(const Pixel: LongInt; var GA: TVector2Byte);
begin
  DecodeX3DColor(LongWord(Pixel), GA);
end;

procedure DecodeX3DColor(const Pixel: LongInt; var RGB: TVector3Byte);
begin
  DecodeX3DColor(LongWord(Pixel), RGB);
end;

procedure DecodeX3DColor(const Pixel: LongInt; var RGBA: TVector4Byte);
begin
  DecodeX3DColor(LongWord(Pixel), RGBA);
end;

{$include norqcheckend.inc}

function X3DChangesToStr(const Changes: TX3DChanges): string;
var
  C: TX3DChange;
begin
  Result := '';
  for C := Low(C) to High(C) do
    if C in Changes then
    begin
      if Result <> '' then Result += ',';
      Result += X3DChangeToStr[C];
    end;
  Result := '[' + Result + ']';
end;

{$endif read_implementation}
