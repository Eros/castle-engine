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

{ @section(Very very basic types that are needed by many included files) }

{$ifdef read_interface}

type
  { Floating-point type with best precision. }
  Float = {$ifdef FPC} Math.Float {$else} Extended {$endif};
  PFloat = {$ifdef FPC} Math.PFloat {$else} PExtended {$endif};

  PCardinal = ^Cardinal;
  PLongWord = ^LongWord;
  PShortint = ^Shortint;

  {$ifdef FPC}
  { Pointer to a boolean.
    Defined as ^Byte in some Delphi Windows unit,
    for FPC 1.0.x PBoolean is not available at all. }
  PBoolean = ^Boolean;
  {$endif}

  {$ifdef FPC}
  { Infinite array of bytes. }
  PByteArray = ^TByteArray;
  TByteArray = array[0..MaxInt div SizeOf(Byte)-1] of Byte;
  {$endif}

  PString = ^AnsiString;

  { Pointer to TObject.
    Don't call this PObject or PTObject to avoid possible name clashes
    with other units (pointers are often used in situations that prevent
    good type-checking, so better to avoid name clashes to avoid some
    nasty errors). }
  PtrObject = ^TObject;

{$endif}
