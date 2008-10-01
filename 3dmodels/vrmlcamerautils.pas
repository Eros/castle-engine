{
  Copyright 2003-2008 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "Kambi VRML game engine"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  ----------------------------------------------------------------------------
}

{ Some utilities related to camera definition in VRML. }
unit VRMLCameraUtils;

interface

uses Math, KambiUtils, VectorMath, Boxes3d, VRMLNodes;

type
  { This is VRML major version for VRMLCameraUtils: either VRML 1.0 or 2.0.
    For Inventor you should treat it like VRML 1.0. }
  TVRMLCameraVersion = 1..2;

const
  { Standard camera settings. These values are defined by VRML specification,
    so you really shouldn't change these constants ever.

    For VRML 1.0 spec of PerspectiveCamera node determines these values.
    For VRML 97 spec part "4.4.5 Standard units and coordinate system"
    and default values for Viewpoint determines these values.

    Note that StdVRMLCamPos is indexed by TVRMLCameraVersion, since
    it's different for VRML 1.0 and 2.0, }
  StdVRMLCamPos: array [TVRMLCameraVersion] of TVector3Single =
    ( (0, 0, 1), (0, 0, 10) );
  StdVRMLCamDir: TVector3Single = (0, 0, -1);
  StdVRMLCamUp: TVector3Single = (0, 1, 0);
  StdVRMLGravityUp: TVector3Single = (0, 1, 0);

procedure CameraViewpointForWholeScene(const Box: TBox3d;
  out CameraPos, CameraDir, CameraUp, GravityUp: TVector3Single);

{ This constructs string with VRML node defining camera with given
  properties. }
function MakeVRMLCameraStr(Version: TVRMLCameraVersion;
  const CameraPos, CameraDir, CameraUp, GravityUp: TVector3Single): string;

{ This constructs TVRMLNode defining camera with given properties. }
function MakeVRMLCameraNode(Version: TVRMLCameraVersion;
  const WWWBasePath: string;
  const CameraPos, CameraDir, CameraUp, GravityUp: TVector3Single): TVRMLNode;

implementation

uses SysUtils, Quaternions;

{ Zamien CamDir i CamUp na orientation VRMLa 1.0.
  Orientation VRMLa wyraza CamDir i CamUp podajac wektor 4 elementowy
  (SFRotation) ktorego pierwsze 3 pola to Axis a czwarte pole to Angle.
  Obroc standardowe Dir i Up VRMLa w/g Axis o kat Angle a otrzymasz
  CamDir i CamUp. Zadaniem jest wyliczyc wlasnie takie Orientation dla
  zadanych juz CamDir i CamUp. Podane CamDir / Up musza byc prostopadle
  i niezerowe, ich dlugosci sa bez znaczenia. }
function CamDirUp2Orient(const CamDir, CamUp: TVector3Single): TVector4Single;
  forward; overload;
procedure CamDirUp2Orient(CamDir, CamUp: TVector3Single;
  out OrientAxis: TVector3Single; out OrientRadAngle: Single);
  forward; overload;

procedure CamDirUp2Orient(CamDir, CamUp: TVector3Single;
  out OrientAxis: TVector3Single; out OrientRadAngle: Single);
{ Poczatkowo byl tutaj kod based on Stephen Chenney's ANSI C code orient.c.
  Byl w nim bledzik (patrz testUnits.Test_VRMLFields - TestOrints[4])
  i nawet teraz nie wiem jaki bo ostatecznie zrozumialem sama idee tamtego kodu
  i zapisalem tutaj rzeczy po swojemu, i ku mojej radosci nie mam tego bledu.

  Tutejsze funkcje lokalne operujace na kwaternionach zamierzam
  odseparowac kiedys, jak tylko bede chcial gdzies jeszcze uzyc kwaternionow.

  Niniejszym ustalam sobie ze jesli gdzies potraktuje kwaternion jako wektor
  4 x skalar to bede mial na mysli ze pierwsze trzy skladowe okreslaja wektor
  a ostatnia skladowa - kat, albo (ogolniej) ze pierwsze trzy skladowe
  to wspolczynniki przy i, j, k a ostatnia skladowa to czesc rzeczywista.
  Widzialem rozne konwencje tego, ale bede sie trzymal powyzszego bo
  - tak jest podawane SFRotation VRMLa (ktore nie jest kwaternionem ale
    jest podobne)
  - tak bylo podawane na PGK gdzie pierwszy raz zobaczylem kwaternion

  Pomysl na ta funkcje: mamy CamDir i CamUp. Zeby je zamienic na
  orientation VRMLa, czyli axis i angle obrotu standardowego dir
  (0, 0, -1) i standardowego up (0, 1, 0), wyobrazamy sobie jaka transformacje
  musielibysmy zrobic standardowym dir/up zeby zamienic je na nasze CamDir/Up.
  1) najpierw bierzemy wektor prostop. do standardowego dir i CamDir.
     Obracamy sie wokol niego zeby standardowe dir nalozylo sie na CamDir.
  2) Teraz obracamy sie wokol CamDir tak zeby standardowe up (ktore juz
     zostalo obrocone przez transformacje pierwsza) nalozylo sie na CamUp.
     Mozemy to zrobic bo CamDir i CamUp sa prostopadle i maja dlugosc 1,
     podobnie jak standardowe dir i up.
  Zlozenie tych dwoch transformacji to jest nasza szukana transformacja.

  Jedyny problem jaki pozostaje to czym jest transformacja ? Jezeli mowimy
  o macierzy to jest prosto, macierze dwoch obrotow umiemy skonstruowac
  i wymnozyc ale na koncu dostajemy macierz. A chcemy miec axis+angle.
  A wiec quaternion.
  Moznaby to zrobic inaczej (np. wyciagnac z matrix quaternion lub
  wyciagajac z matrix katy eulera i konwertujac je na quaternion)
  ale najwygodniej jest skorzystac tutaj z mozliwosci mnozenia kwaternionow:
  przemnoz quaterniony obrotu q*p a orztymasz quaternion ktory za pomoca
  jednego obrotu wyraza zlozenie dwoch obrotow, p i q (najpierw p, potem q).
  To jest wlasnie idea z kodu Stephen Chenney's "orient.c".
}

  function QuatFromAxisAngleCos(const Axis: TVector3Single;
    const AngleRadCos: Single): TQuaternion;
  begin
    Result := QuatFromAxisAngle(Axis, ArcCos(Clamped(AngleRadCos, -1.0, 1.0)));
  end;

var Rot1Axis, Rot2Axis, StdCamUpAfterRot1: TVector3Single;
    Rot1Quat, Rot2Quat, OrientQuat: TQuaternion;
    Rot1CosAngle, Rot2CosAngle: Single;
begin
 NormalizeTo1st(CamDir);
 NormalizeTo1st(CamUp);

 { evaluate Rot1Quat }
 Rot1Axis := Normalized( VectorProduct(StdVRMLCamDir, CamDir) );
 Rot1CosAngle := VectorDotProduct(StdVRMLCamDir, CamDir);
 Rot1Quat := QuatFromAxisAngleCos(Rot1Axis, Rot1CosAngle);

 { evaluate Rot2Quat }
 StdCamUpAfterRot1 := QuatRotate(Rot1Quat, StdVRMLCamUp);
 { wiemy ze Rot2Axis to CamDir lub -CamDir. Wyznaczamy je jednak w tak
   prosty sposob bo nie przychodzi mi teraz do glowy inny sposob jak rozpoznac
   czy powinnismy tu wziac CamDir czy -CamDir (chodzi o to zeby pozniej obrot
   o Rot2CosAngle byl w dobra strone) }
 Rot2Axis := Normalized( VectorProduct(StdCamUpAfterRot1, CamUp) );
 Rot2CosAngle := VectorDotProduct(StdCamUpAfterRot1, CamUp);
 Rot2Quat := QuatFromAxisAngleCos(Rot2Axis, Rot2CosAngle);

 { evaluate OrientQuat = zlozenie Rot1 i Rot2 (tak, kolejnosc mnozenia QQMul musi
   byc odwrotna) }
 OrientQuat := QuatMultiply(Rot2Quat, Rot1Quat);

 { Extract the axis and angle from the quaternion. }
 QuatToAxisAngle(OrientQuat, OrientAxis, OrientRadAngle);
end;

function CamDirUp2Orient(const CamDir, CamUp: TVector3Single): TVector4Single;
var OrientAxis: TVector3Single;
    OrientAngle: Single;
begin
 CamDirUp2Orient(CamDir, CamUp, OrientAxis, OrientAngle);
 result := Vector4Single(OrientAxis, OrientAngle);
end;

procedure CameraViewpointForWholeScene(const Box: TBox3d;
  out CameraPos, CameraDir, CameraUp, GravityUp: TVector3Single);
var
  AvgSize: Single;
begin
  if IsEmptyBox3d(Box) then
  begin
    CameraPos := StdVRMLCamPos[1];
    CameraDir := StdVRMLCamDir;
    CameraUp := StdVRMLCamUp;
  end else
  begin
    AvgSize := Box3dAvgSize(Box);
    CameraPos[0] := Box[0, 0] - AvgSize;
    CameraPos[1] := (Box[0, 1] + Box[1, 1]) / 2;
    CameraPos[2] := (Box[0, 2] + Box[1, 2]) / 2;
    CameraDir := UnitVector3Single[0];
    CameraUp := UnitVector3Single[2];
  end;

  { Nothing more intelligent to do with GravityUp is possible... }
  GravityUp := CameraUp;
end;

function MakeVRMLCameraStr(Version: TVRMLCameraVersion;
  const CameraPos, CameraDir, CameraUp, GravityUp: TVector3Single): string;
const
  UntransformedViewpoint: array [TVRMLCameraVersion] of string = (
    'PerspectiveCamera {' +nl+
    '  position %s' +nl+
    '  orientation %s' +nl+
    '}',
    'Viewpoint {' +nl+
    '  position %s' +nl+
    '  orientation %s' +nl+
    '}'
  );
  TransformedViewpoint: array [TVRMLCameraVersion] of string = (
    'Separator {' +nl+
    '  Transform {' +nl+
    '    translation %s' +nl+
    '    rotation %s %s' +nl+
    '  }' +nl+
    '  PerspectiveCamera {' +nl+
    '    position 0 0 0 # camera position is expressed by translation' +nl+
    '    orientation %s' +nl+
    '  }' +nl+
    '}',
    'Transform {' +nl+
    '  translation %s' +nl+
    '  rotation %s %s' +nl+
    '  children Viewpoint {' +nl+
    '    position 0 0 0 # camera position is expressed by translation' +nl+
    '    orientation %s' +nl+
    '  }' +nl+
    '}'
  );

var
  RotationVectorForGravity: TVector3Single;
  AngleForGravity: Single;
begin
  Result := Format(
    '# Camera settings "encoded" in the VRML declaration below :' +nl+
    '# direction %s' +nl+
    '# up %s' +nl+
    '# gravityUp %s' + nl,
    [ VectorToRawStr(CameraDir),
      VectorToRawStr(CameraUp),
      VectorToRawStr(GravityUp) ]);

  RotationVectorForGravity := VectorProduct(StdVRMLGravityUp, GravityUp);
  if IsZeroVector(RotationVectorForGravity) then
  begin
    { Then GravityUp is parallel to StdVRMLGravityUp, which means that it's
      just the same. So we can use untranslated Viewpoint node. }
    Result := Result +
      Format(
        UntransformedViewpoint[Version],
        [ VectorToRawStr(CameraPos),
          VectorToRawStr( CamDirUp2Orient(CameraDir, CameraUp) ) ]);
  end else
  begin
    { Then we must transform Viewpoint node, in such way that
      StdVRMLGravityUp affected by this transformation will give
      desired GravityUp. }
    AngleForGravity := AngleRadBetweenVectors(StdVRMLGravityUp, GravityUp);
    Result := Result +
      Format(
        TransformedViewpoint[Version],
        [ VectorToRawStr(CameraPos),
          VectorToRawStr(RotationVectorForGravity),
          FloatToRawStr(AngleForGravity),
          { I want
            1. standard VRML dir/up vectors
            2. rotated by orientation
            3. rotated around RotationVectorForGravity
            will give MatrixWalker.CameraDir/Up.
            CamDirUp2Orient will calculate the orientation needed to
            achieve given up/dir vectors. So I have to pass there
            MatrixWalker.CameraDir/Up *already rotated negatively
            around RotationVectorForGravity*. }
          VectorToRawStr( CamDirUp2Orient(
            RotatePointAroundAxisRad(-AngleForGravity, CameraDir, RotationVectorForGravity),
            RotatePointAroundAxisRad(-AngleForGravity, CameraUp , RotationVectorForGravity)
            )) ]);
  end;
end;

function MakeVRMLCameraNode(Version: TVRMLCameraVersion;
  const WWWBasePath: string;
  const CameraPos, CameraDir, CameraUp, GravityUp: TVector3Single): TVRMLNode;
var
  RotationVectorForGravity: TVector3Single;
  AngleForGravity: Single;
  ViewpointNode: TVRMLViewpointNode;
  Separator: TNodeSeparator;
  Transform_1: TNodeTransform_1;
  Transform_2: TNodeTransform_2;
  Rotation, Orientation: TVector4Single;
begin
  RotationVectorForGravity := VectorProduct(StdVRMLGravityUp, GravityUp);
  if IsZeroVector(RotationVectorForGravity) then
  begin
    { Then GravityUp is parallel to StdVRMLGravityUp, which means that it's
      just the same. So we can use untranslated Viewpoint node. }
    case Version of
      1: ViewpointNode := TNodePerspectiveCamera.Create('', '');
      2: ViewpointNode := TNodeViewpoint.Create('', '');
      else raise EInternalError.Create('MakeVRMLCameraNode Version incorrect');
    end;
    ViewpointNode.Position.Value := CameraPos;
    ViewpointNode.FdOrientation.Value := CamDirUp2Orient(CameraDir, CameraUp);
    Result := ViewpointNode;
  end else
  begin
    { Then we must transform Viewpoint node, in such way that
      StdVRMLGravityUp affected by this transformation will give
      desired GravityUp. }
    AngleForGravity := AngleRadBetweenVectors(StdVRMLGravityUp, GravityUp);
    Rotation := Vector4Single(RotationVectorForGravity, AngleForGravity);
    { I want
      1. standard VRML dir/up vectors
      2. rotated by orientation
      3. rotated around RotationVectorForGravity
      will give MatrixWalker.CameraDir/Up.
      CamDirUp2Orient will calculate the orientation needed to
      achieve given up/dir vectors. So I have to pass there
      MatrixWalker.CameraDir/Up *already rotated negatively
      around RotationVectorForGravity*. }
    Orientation := CamDirUp2Orient(
      RotatePointAroundAxisRad(-AngleForGravity, CameraDir, RotationVectorForGravity),
      RotatePointAroundAxisRad(-AngleForGravity, CameraUp , RotationVectorForGravity));
    case Version of
      1: begin
           Transform_1 := TNodeTransform_1.Create('', '');
           Transform_1.FdTranslation.Value := CameraPos;
           Transform_1.FdRotation.Value := Rotation;

           ViewpointNode := TNodePerspectiveCamera.Create('', '');
           ViewpointNode.Position.Value := ZeroVector3Single;
           ViewpointNode.FdOrientation.Value := Orientation;

           Separator := TNodeSeparator.Create('', '');
           Separator.AddChild(Transform_1);
           Separator.AddChild(ViewpointNode);

           Result := Separator;
         end;

      2: begin
           Transform_2 := TNodeTransform_2.Create('', '');
           Transform_2.FdTranslation.Value := CameraPos;
           Transform_2.FdRotation.Value := Rotation;

           ViewpointNode := TNodeViewpoint.Create('', '');
           ViewpointNode.Position.Value := ZeroVector3Single;
           ViewpointNode.FdOrientation.Value := Orientation;

           Transform_2.FdChildren.AddItem(ViewpointNode);

           Result := Transform_2;
         end;
      else raise EInternalError.Create('MakeVRMLCameraNode Version incorrect');
    end;
  end;
end;

end.