// =============================================================================
//   glMath
// =============================================================================
//   Copyright © 2003-2004 by Sascha Willems - http://www.delphigl.de
//   visit the Delphi OpenGL Community - http://www.delphigl.com
// =============================================================================
//   Important note :
//    Contents of this file are subject to the GNU Public License (GPL) which can
//    be obtained here : http://opensource.org/licenses/gpl-license.php
//    So only use this file if you fully unterstand that license!!!
//   If you don't know what the GPL is about :
//    If you use this unit, the project it uses MUST be made open source and MUST
//    be made free to the public
//    Any changes made to this unit MUST be made freely available
// =============================================================================
//   Credits :
//    Maarten "McClaw" Kronenberger - For the line-polygon intersection
// =============================================================================

unit glMath;

interface

uses
 Math,
 dglOpenGL;

type
 PglVertex3f  = ^TglVertex3f;

 PglVertex3fa = ^TglVertex3fa;
 TglVertex3fa = array[0..2] of Single;

 TglPlane4f = record
   a,b,c,d : TglFloat;
  end;
 TglVertex2f = record
   x,y : Single;
  end;
 TglVertex3f = record
   x,y,z  : TglFloat;
   t,u    : TglFloat;
  end;
 TglVertex3d = record
   x,y,z : TglDouble;
  end;
 TglVertex4f = record
   x,y,z,w : TglFloat;
  end;
 TglNormal3f = record
   x,y,z : TglFloat;
  end;
 TglTexCoord2f = record
   u,v : TglFloat;
  end;
 TglTangentVertex = packed record
  Position          : TglVertex3f;
  S,T               : TGLFloat;
  sTangent          : TglVertex3f;
  tTangent          : TglVertex3f;
  Normal            : TglVertex3f;
  TangentSpaceLight : TglVertex3f;
  end;
 TglTriangle = object
   Vertex      : array[0..2] of TglVertex3f;
   TexCoord    : array[0..2] of tglTexCoord2f;
   Texture     : Integer;
   LightMapNr  : Integer;
   ID          : Integer;
   TexRepeat   : Single;
   procedure CalcUV;
   function Normal : TglVertex3f;                    
  end;

var
 Intersection     : TglVertex3f;
 ZeroVector2f     : TglVertex2f = (x:0; y:0);
 ZeroVector3f     : TglVertex4f = (x:0; y:0; z:0);
 ZeroVector4f     : TglVertex4f = (x:0; y:0; z:0; w:0);

 NullMatrix4f     : TMatrix4f = ((0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0));
 IdentityMatrix4f : TMatrix4f = ((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1));

const
 // Planes
 YZ = 0;
 XZ = 1;
 XY = 2;
 // Factor to compensate rounding errors
 Epsilon = 0.0001;

function Clamp(var pValue : Single; pMin, pMax : Single) : Single;

// =============================================================================
//  Vertex operations
// =============================================================================

// Compare functions ===========================================================
// Zero vector
function glIsZeroVertex(v : TglVertex2f) : Boolean; overload;
function glIsZeroVertex(v : TglVertex3f) : Boolean; overload;
function glIsZeroVertex(v : TglVertex4f) : Boolean; overload;
// Same vector
function glCompareVertex(v1, v2 : TglVertex4f; pEpsilon : Single = Epsilon) : Boolean; overload;
function glCompareVertex(v1, v2 : TglVertex3f; pEpsilon : Single = Epsilon) : Boolean; overload;

// Constructors ================================================================
// 2-Component vectors
function glVertex(x,y : Single) : TglVertex2f; overload;
function glVertex(v : TglVertex3f) : TglVertex2f; overload;
// 3-Component vectors
function glVertex(v : TglVertex4f) : TglVertex3f; overload;
function glVertex(x,y,z : Single) : TglVertex3f; overload;
// 4-Component vectors
function glVertex(v : TglVertex3f; w : Single = 1) : TglVertex4f; overload;
function glVertex(x,y,z,w : Single) : TglVertex4f; overload;
function glVertex(c : array of Single) : TglVertex4f; overload;

// Calculations ================================================================
// Addition
function glAddVector(v1, v2 : TglVertex2f) : TglVertex2f; overload;
function glAddVector(v1, v2 : TglVertex3f) : TglVertex3f; overload;
function glAddVector(v1, v2 : TglVertex4f) : TglVertex4f; overload;
// Subtraction
function glSubtractVector(v1, v2 : TglVertex2f) : TglVertex2f; overload;
function glSubtractVector(v1, v2 : TglVertex3f) : TglVertex3f; overload;
function glSubtractVector(v1, v2 : TglVertex4f) : TglVertex4f; overload;
// Scale
function glScaleVector(v : TglVertex2f; factor : Single) : TglVertex2f; overload;
function glScaleVector(v : TglVertex3f; factor : Single) : TglVertex3f; overload;
function glScaleVector(v : TglVertex4f; factor : Single) : TglVertex4f; overload;
function glScaleVector(v1, v2 : TglVertex2f) : TglVertex2f; overload;
function glScaleVector(v1, v2 : TglVertex3f) : TglVertex3f; overload;
function glScaleVector(v1, v2 : TglVertex4f) : TglVertex4f; overload;
// Vector length
function glVectorLength(const v : TglVertex2f) : Single; overload;
function glVectorLength(const v : TglVertex3f) : Single; overload;
function glVectorLength(const v : TglVertex4f) : Single; overload;
// Normalize
procedure glNormalizeVector(var v : TglVertex2f); overload;
procedure glNormalizeVector(var v : TglVertex3f); overload;
procedure glNormalizeVector(var v : TglVertex4f); overload;
// Distance
function glVectorDistance(v1, v2 : TglVertex2f) : Single; overload;
function glVectorDistance(v1, v2 : TglVertex3f) : Single; overload;
function glVectorDistance(v1, v2 : TglVertex4f) : Single; overload;
// Cross product
function glCrossProduct(v1, v2 : TglVertex3f) : TglVertex3f; overload;
function glCrossProduct(v1, v2 : TglVertex4f) : TglVertex4f; overload;
// Dot product
function glDotProduct(v1, v2 : TglVertex3f) : Single; overload;
function glDotProduct(v1, v2 : TglVertex4f) : Single; overload;
// Angles
function glVectorVectorAngle(v1, v2 : TglVertex3f) : Single; overload;
function glVectorVectorAngle(v1, v2 : TglVertex4f) : Single; overload;
// Rotations around a single axis
function glGetRotatedX(v : TglVertex3f; fAngle : Single) : TglVertex3f; overload;
function glGetRotatedY(v : TglVertex3f; fAngle : Single) : TglVertex3f; overload;
function glGetRotatedZ(v : TglVertex3f; fAngle : Single) : TglVertex3f; overload;
function glGetRotatedX(v : TglVertex4f; fAngle : Single) : TglVertex4f; overload;
function glGetRotatedY(v : TglVertex4f; fAngle : Single) : TglVertex4f; overload;
function glGetRotatedZ(v : TglVertex4f; fAngle : Single) : TglVertex4f; overload;

// Triangle/Polygon functions
// Normal
function glGetNormalVector(v1, v2, v3 : TglVertex3f) : TglVertex3f; overload;
function glGetNormalVector(v1, v2, v3 : TglVertex4f) : TglVertex3f; overload;
// Alignement
function glGetTriangleAlignement(pVertex : array of TglVertex3f) : ShortInt;
// Tangentspace
procedure glCalculateTSB(v0,v1,v2 : TglTangentVertex; var Normal,sTangent,tTangent : TglVertex3f);

// =============================================================================
//  Plane operations
// =============================================================================
function glPlane(fA, fB, fC, fD : Single) : TglPlane4f;
function glPlaneFromPoints(const v1, v2, v3 : TGLVertex3f) : TglPlane4f;
function glPlaneVectorDistance(pPlane: TglPlane4f; pV : TglVertex4f) : Single;

// =============================================================================
//  Matrix operations
// =============================================================================
function glMatrixMakeYawMatrix(Angle : Single) : TMatrix4f;
function glMatrixMakeRollMatrix(Angle : Single) : TMatrix4f;
function glMatrixMultiply(m1 : TMatrix4f; m2 : TMatrix4f) : TMatrix4f;
procedure glMatrixSetTransform(var M : TMatrix4f; V : TglVertex3f);
procedure glMatrixSetRotation(var M : TMatrix4f; V : TglVertex3f);
procedure glMatrixRotateVector(const M : TMatrix4f; var pVect : TglVertex3f); overload;
procedure glMatrixRotateVector(const M : TMatrix4f; var pVect : TglVertex4f); overload;
procedure glMatrixSetIdentity(var M : TMatrix4f);

// =============================================================================
//  Intersections
// =============================================================================
function SphereSphereIntersection(pPos1 : TglVertex3f; pRadius1 : Single; pPos2 : TglVertex3f; pRadius2 : Single) : Boolean;
function IntersectedPolygon(vPoly : array of TglVertex3f; vLine : array of TglVertex3f; verticeCount : integer):boolean;
function glGetIntersectionPoint(vPoly : array of TglVertex3f; vLine : array of TglVertex3f; verticeCount : integer;var vIntersection : TglVertex3f) : Boolean;


implementation

function Clamp(var pValue : Single; pMin, pMax : Single) : Single;
begin
if pValue < pMin then
 pValue := pMin
else
 if pValue > pMax then
  pValue := pMax;
end;

// =============================================================================
//  Vectors
// =============================================================================

// =============================================================================
//  glIsZeroVertex
// =============================================================================
function glIsZeroVertex(v : TglVertex2f) : Boolean; overload;
begin
Result := (Abs(v.x) < Epsilon) and (Abs(v.y) < Epsilon);
end;

function glIsZeroVertex(v : TglVertex3f) : Boolean; overload;
begin
Result := (Abs(v.x) < Epsilon) and (Abs(v.y) < Epsilon) and (Abs(v.z) < Epsilon);
end;

function glIsZeroVertex(v : TglVertex4f) : Boolean; overload;
begin
Result :=(Abs(v.x) < Epsilon) and (Abs(v.y) < Epsilon) and (Abs(v.z) < Epsilon) and (Abs(v.w) < Epsilon);
end;

// =============================================================================
//  glVertex
// =============================================================================
function glVertex(x,y : Single) : TglVertex2f; overload;
begin
Result.x := x;
Result.y := y;
end;

function glVertex(v : TglVertex3f) : TglVertex2f; overload;
begin
Result.x := v.x;
Result.y := v.y;
end;

function glVertex(x,y,z : Single) : TglVertex3f;
begin
Result.x := x;
Result.y := y;
Result.z := z;
end;

function glVertex(c : array of Single) : TglVertex4f;
begin
Result.x := c[0];
Result.y := c[1];
Result.z := c[2];
Result.w := c[3];
end;

function glVertex(v : TglVertex4f) : TglVertex3f; overload;
begin
Result.x := v.x;
Result.y := v.y;
Result.z := v.z;
end;

function glVertex(x,y,z,w : Single) : TglVertex4f;
begin
Result.x := x;
Result.y := y;
Result.z := z;
Result.w := w;
end;

function glVertex(v : TglVertex3f; w : Single = 1) : TglVertex4f; overload;
begin
Result.x := v.x;
Result.y := v.y;
Result.z := v.z;
Result.w := W;
end;

// =============================================================================
//  glCompareVertex
// =============================================================================
function glCompareVertex(v1, v2 : TglVertex3f; pEpsilon : Single = Epsilon) : Boolean;
begin
Result := (Abs(v1.x - v2.x) < pEpsilon) and (Abs(v1.y - v2.y) < pEpsilon) and (Abs(v1.z - v2.z) < pEpsilon);
end;

function glCompareVertex(v1, v2 : TglVertex4f; pEpsilon : Single = Epsilon) : Boolean;
begin
Result := (Abs(v1.x - v2.x) < pEpsilon) and (Abs(v1.y - v2.y) < pEpsilon) and (Abs(v1.z - v2.z) < pEpsilon) and (Abs(v1.w - v2.w) < pEpsilon);
end;

// =============================================================================
//  glVectorLength
// =============================================================================
function glVectorLength(const v : TglVertex2f) : Single;
begin
Result := Sqrt(v.x*v.x + v.y*v.y);
end;

function glVectorLength(const v : TglVertex3f) : Single;
begin
Result := Sqrt(v.x*v.x + v.y*v.y + v.z*v.z);
end;

function glVectorLength(const v : TglVertex4f) : Single;
begin
Result := Sqrt(v.x*v.x + v.y*v.y + v.z*v.z + v.w*v.w);
end;

// =============================================================================
//  glSubtractVector
// =============================================================================
function glSubtractVector(v1, v2 : TglVertex2f) : TglVertex2f;
begin
Result.x := v1.x-v2.x;
Result.y := v1.y-v2.y;
end;

function glSubtractVector(v1, v2 : TglVertex3f) : TglVertex3f;
begin
Result.x := v1.x-v2.x;
Result.y := v1.y-v2.y;
Result.z := v1.z-v2.z;
end;

function glSubtractVector(v1, v2 : TglVertex4f) : TglVertex4f;
begin
Result.x := v1.x-v2.x;
Result.y := v1.y-v2.y;
Result.z := v1.z-v2.z;
end;

// =============================================================================
//  glAddVector
// =============================================================================
function glAddVector(v1, v2 : TglVertex2f) : TglVertex2f;
begin
Result.x := v1.x+v2.x;
Result.y := v1.y+v2.y;
end;

function glAddVector(v1, v2 : TglVertex3f) : TglVertex3f;
begin
Result.x := v1.x+v2.x;
Result.y := v1.y+v2.y;
Result.z := v1.z+v2.z;
end;

function glAddVector(v1, v2 : TglVertex4f) : TglVertex4f;
begin
Result.x := v1.x+v2.x;
Result.y := v1.y+v2.y;
Result.z := v1.z+v2.z;
Result.w := v1.w+v2.w;
end;

// =============================================================================
//  glScaleVector
// =============================================================================
function glScaleVector(v : TglVertex2f; factor : Single) : TglVertex2f;
begin
Result.x := v.x * factor;
Result.y := v.y * factor;
end;

function glScaleVector(v : TglVertex3f; factor : Single) : TglVertex3f;
begin
Result.x := v.x * factor;
Result.y := v.y * factor;
Result.z := v.z * factor;
end;

function glScaleVector(v : TglVertex4f; factor : Single) : TglVertex4f;
begin
Result.x := v.x * factor;
Result.y := v.y * factor;
Result.z := v.z * factor;
Result.w := v.w * factor;
end;

function glScaleVector(v1, v2 : TglVertex2f) : TglVertex2f;
begin
Result.x := v1.x*v2.x;
Result.y := v1.y*v2.y;
end;

function glScaleVector(v1, v2 : TglVertex3f) : TglVertex3f;
begin
Result.x := v1.x*v2.x;
Result.y := v1.y*v2.y;
Result.z := v1.z*v2.z;
end;

function glScaleVector(v1, v2 : TglVertex4f) : TglVertex4f;
begin
Result.x := v1.x*v2.x;
Result.y := v1.y*v2.y;
Result.z := v1.z*v2.z;
Result.w := v1.w*v2.w;
end;

// =============================================================================
//  glGetRotatedX
// =============================================================================
function glGetRotatedX(v : TglVertex3f; fAngle : Single) : TglVertex3f;
var
 SinAngle,CosAngle : Single;
begin
if fAngle = 0 then
 Result := v;
SinAngle := Sin(PI*fAngle/180);
CosAngle := Cos(PI*fAngle/180);
Result   := glVertex(v.x, v.y*CosAngle+v.z*(-SinAngle), v.y*SinAngle+v.z*CosAngle);
end;

function glGetRotatedX(v : TglVertex4f; fAngle : Single) : TglVertex4f;
var
 SinAngle,CosAngle : Single;
begin
if fAngle = 0 then
 Result := v;
SinAngle := Sin(PI*fAngle/180);
CosAngle := Cos(PI*fAngle/180);
Result   := glVertex(v.x, v.y*CosAngle+v.z*(-SinAngle), v.y*SinAngle+v.z*CosAngle, v.w);
end;

// =============================================================================
//  glGetRotatedY
// =============================================================================
function glGetRotatedY(v : TglVertex3f; fAngle : Single) : TglVertex3f;
var
 SinAngle,CosAngle : Single;
begin
if fAngle = 0 then
 Result := v;
SinAngle := Sin(PI*fAngle/180);
CosAngle := Cos(PI*fAngle/180);
Result   := glVertex(v.x*CosAngle+v.z*SinAngle, v.y, -v.x*SinAngle+v.z*CosAngle);
end;

function glGetRotatedY(v : TglVertex4f; fAngle : Single) : TglVertex4f;
var
 SinAngle,CosAngle : Single;
begin
if fAngle = 0 then
 Result := v;
SinAngle := Sin(PI*fAngle/180);
CosAngle := Cos(PI*fAngle/180);
Result   := glVertex(v.x*CosAngle+v.z*SinAngle, v.y, -v.x*SinAngle+v.z*CosAngle, v.w);
end;

// =============================================================================
//  glGetRotatedZ
// =============================================================================
function glGetRotatedZ(v : TglVertex3f; fAngle : Single) : TglVertex3f;
var
 SinAngle,CosAngle : Single;
begin
if fAngle = 0 then
 Result := v;
SinAngle := Sin(PI*fAngle/180);
CosAngle := Cos(PI*fAngle/180);
Result   := glVertex(v.x*CosAngle-v.y*SinAngle, v.x*SinAngle+v.y*CosAngle, v.z);
end;

function glGetRotatedZ(v : TglVertex4f; fAngle : Single) : TglVertex4f;
var
 SinAngle,CosAngle : Single;
begin
if fAngle = 0 then
 Result := v;
SinAngle := Sin(PI*fAngle/180);
CosAngle := Cos(PI*fAngle/180);
Result   := glVertex(v.x*CosAngle-v.y*SinAngle, v.x*SinAngle+v.y*CosAngle, v.z, v.w);
end;

// =============================================================================
//  glNormalizeVector
// =============================================================================
procedure glNormalizeVector(var v : TglVertex2f);
var
 l : Single;
begin
l := glVectorLength(v);
if l <> 0 then
 with v do
  begin
  x := x/l;
  y := y/l;
  end;
end;

procedure glNormalizeVector(var v : TglVertex3f);
var
 l : Single;
begin
l := glVectorLength(v);
if l <> 0 then
 with v do
  begin
  x := x/l;
  y := y/l;
  z := z/l;
  end;
end;

procedure glNormalizeVector(var v : TglVertex4f);
var
 l : Single;
begin
l := glVectorLength(v);
if l <> 0 then
 with v do
  begin
  x := x/l;
  y := y/l;
  z := z/l;
  w := 1;
  end;
end;

// =============================================================================
//  glCrossProduct
// =============================================================================
function glCrossProduct(v1, v2 : TglVertex3f) : TglVertex3f;
begin
with Result do
 begin
 x := (v1.y*v2.z) - (v1.z*v2.y);
 y := (v1.z*v2.x) - (v1.x*v2.z);
 z := (v1.x*v2.y) - (v1.y*v2.x);
 end;
end;

function glCrossProduct(v1, v2 : TglVertex4f) : TglVertex4f;
begin
with Result do
 begin
 x := (v1.y*v2.z) - (v1.z*v2.y);
 y := (v1.z*v2.x) - (v1.x*v2.z);
 z := (v1.x*v2.y) - (v1.y*v2.x);
 w := 1;
 end;
end;

// =============================================================================
//  glDotProduct
// =============================================================================
function glDotProduct(v1, v2 : TglVertex3f) : Single;
begin
Result := (v1.x*v2.x) + (v1.y*v2.y) + (v1.z*v2.z);
end;

function glDotProduct(v1, v2 : TglVertex4f) : Single;
begin
Result := (v1.x*v2.x) + (v1.y*v2.y) + (v1.z*v2.z);
end;

// =============================================================================
//  glGetNormalVector
// =============================================================================
function glGetNormalVector(v1, v2, v3: TglVertex3f) : TglVertex3f;
var
 tv1, tv2, tn : TglVertex3f;
begin
tv1 := glSubtractVector(v1, v2);
tv2 := glSubtractVector(v2, v3);
tn  := glCrossProduct(tv1, tv2);
glNormalizeVector(tn);
tn  := glVertex(-tn.x, -tn.y, -tn.z);
Result := tn;
end;

function glGetNormalVector(v1, v2, v3 : TglVertex4f) : TglVertex3f;
var
 tV1, tV2, tn : TglVertex4f;
begin
tv1 := glSubtractVector(v1, v2);
tv2 := glSubtractVector(v2, v3);
tn  := glCrossProduct(tv1, tv2);
glNormalizeVector(tn);
tn  := glVertex(-tn.x, -tn.y, -tn.z, 1);
Result := glVertex(tn);
end;

// =============================================================================
//  glGetTriangleAlignement
// =============================================================================
function glGetTriangleAlignement(pVertex : array of TglVertex3f) : ShortInt;
var
 PlaneNormal : TglVertex3f;
 aV,bV       : TglVertex3f;
begin
Result      := -1;
aV          := glSubtractVector(pVertex[0], pVertex[1]);
bV          := glSubtractVector(pVertex[2], pVertex[1]);
PlaneNormal := glCrossProduct(aV, bV);
glNormalizeVector(PlaneNormal);
if (Abs(PlaneNormal.x) > Abs(PlaneNormal.y)) and (Abs(PlaneNormal.x) > Abs(PlaneNormal.z)) then
 Result := YZ;
if (Abs(PlaneNormal.y) > Abs(PlaneNormal.x)) and (Abs(PlaneNormal.y) > Abs(PlaneNormal.z)) then
 Result := XZ;
if (Abs(PlaneNormal.z) > Abs(PlaneNormal.x)) and (Abs(PlaneNormal.z) > Abs(PlaneNormal.y)) then
 Result := XY;
end;

// =============================================================================
//  glVectorDistance
// =============================================================================
function glVectorDistance(v1, v2 : TglVertex2f) : Single;
begin
Result := Sqrt(Sqr(v1.x-v2.x)+Sqr(v1.y-v2.y));
end;

function glVectorDistance(v1, v2 : TglVertex3f) : Single;
begin
Result := Sqrt(Sqr(v1.x-v2.x)+Sqr(v1.y-v2.y)+Sqr(v1.z-v2.z));
end;

function glVectorDistance(v1, v2 : TglVertex4f) : Single;
begin
Result := Sqrt(Sqr(v1.x-v2.x)+Sqr(v1.y-v2.y)+Sqr(v1.z-v2.z));
end;

// =============================================================================
//  glVectorVectorAngle
// =============================================================================
function glVectorVectorAngle(v1, v2 : TglVertex3f) : Single;
var
 PointProduct : Single;
 VectorLength : Single;
begin
PointProduct := glDotProduct(v1, v2);
VectorLength := glVectorLength(v1)*glVectorLength(v2);
Result       := ArcCos(PointProduct/VectorLength);
end;

function glVectorVectorAngle(v1, v2 : TglVertex4f) : Single;
var
 PointProduct : Single;
 VectorLength : Single;
begin
PointProduct := glDotProduct(v1, v2);
VectorLength := glVectorLength(v1)*glVectorLength(v2);
Result       := ArcCos(PointProduct/VectorLength);
end;

// =============================================================================
//  Planes
// =============================================================================

// =============================================================================
//  glPlane
// =============================================================================
function glPlane(fA, fB, fC, fD : Single) : TglPlane4f;
begin
Result.a := fA;
Result.b := fB;
Result.c := fC;
Result.d := fD;
end;

// =============================================================================
//  glPlaneFromPoints
// =============================================================================
function glPlaneFromPoints(const v1, v2, v3 : TglVertex3f) : TglPlane4f;
var
 n : TglVertex3f;
begin
n := glCrossProduct(glSubtractVector(v2,v1), glSubtractVector(v3, v1));
glNormalizeVector(n);
with Result do
 begin
 a := n.x;
 b := n.y;
 c := n.z;
 d := -(a*v1.x + b*v1.y + c*v1.z);
 end;
end;

// =============================================================================
//  glPlaneVectorDistance
// =============================================================================
function glPlaneVectorDistance(pPlane: TglPlane4f; pV : TglVertex4f) : Single;
begin
Result := (pPlane.a * pV.x) + (pPlane.b * pV.y) + (pPlane.c * pV.z) + pPlane.d;
end;

// =============================================================================
//  Intersections
// =============================================================================

// =============================================================================
//  SphereSphereIntersection
// =============================================================================
function SphereSphereIntersection(pPos1 : TglVertex3f; pRadius1 : Single; pPos2 : TglVertex3f; pRadius2 : Single) : Boolean;
var
 DeltaX, DeltaY, DeltaZ : Single;
 Sum                    : Single;
begin
DeltaX := Abs(pPos1.x - pPos2.x);
DeltaY := Abs(pPos1.y - pPos2.y);
DeltaZ := Abs(pPos1.z - pPos2.z);
Sum    := Sqr(DeltaX) + Sqr(DeltaY) + Sqr(DeltaZ);
Result := (Sum <= Sqr(pRadius1 + pRadius2));
end;

// =============================================================================
//  glGetIntersectionPoint
// =============================================================================
function glGetIntersectionPoint(vPoly : array of TglVertex3f; vLine : array of TglVertex3f; verticeCount : integer;var vIntersection : TglVertex3f) : Boolean;
begin
Result        := IntersectedPolygon(vPoly, vLine, VerticeCount);
vIntersection := Intersection;
end;

// =============================================================================
//  McClaw's all-in-one-collision
// =============================================================================

{------------------------------------------------------------------}
{  Test for intersection on polygon with line                      }
{------------------------------------------------------------------}
function IntersectedPolygon(vPoly : array of TglVertex3f; vLine : array of TglVertex3f; verticeCount : integer):boolean;
const
  // Used to cover up the error in floating point
//  MATCH_FACTOR : Extended = 0.9999999999;
  MATCH_FACTOR : Extended = 0.9999999998;
var
  vNormal          : TglVertex3f;
  vIntersection    : TglVertex3f;
  originDistance   : Extended;
  distance1        : Extended;
  distance2        : Extended;
  vVector1         : TglVertex3f;
  vVector2         : TglVertex3f;
  m_magnitude      : Double;
  vPoint           : TglVertex3f;
  vLineDir         : TglVertex3f;
  Numerator        : Extended;
  Denominator      : Extended;
  dist             : Extended;
  Angle,tempangle  : Extended;						// Initialize the angle
	vA, vB           : TglVertex3f;						// Create temp vectors
  I                : integer;
  dotProduct       : Extended;
  vectorsMagnitude : Extended;
begin
	vNormal.X := 0;
  vNormal.Y := 0;
  vNormal.Z := 0;

	//originDistance := 0;
  //distance1 := 0;
  //distance2 := 0;	 // The distances from the 2 points of the line from the plane
  vPoint.X := 0;
  vPoint.Y := 0;
  vPoint.Z := 0;

  vLineDir.X := 0;
  vLineDir.Y := 0;
  vLineDir.Z := 0;

	//Numerator := 0.0;
  //Denominator := 0.0;
  //dist := 0.0;
  Angle := 0.0;

  //vector
  vVector1.x := vPoly[2].x - vPoly[0].x;    // Get the X value of our new vector
	vVector1.y := vPoly[2].y - vPoly[0].y;    // Get the Y value of our new vector
	vVector1.z := vPoly[2].z - vPoly[0].z;    // Get the Z value of our new vector
  //vector
  vVector2.x := vPoly[1].x - vPoly[0].x;    // Get the X value of our new vector
	vVector2.y := vPoly[1].y - vPoly[0].y;		// Get the Y value of our new vector
	vVector2.z := vPoly[1].z - vPoly[0].z;		// Get the Z value of our new vector

  //cross

  // The X value for the vector is:  (V1.y * V2.z) - (V1.z * V2.y)
	vNormal.x := ((vVector1.y * vVector2.z) - (vVector1.z * vVector2.y));
  // The Y value for the vector is:  (V1.z * V2.x) - (V1.x * V2.z)
	vNormal.y := ((vVector1.z * vVector2.x) - (vVector1.x * vVector2.z));
  // The Z value for the vector is:  (V1.x * V2.y) - (V1.y * V2.x)
	vNormal.z := ((vVector1.x * vVector2.y) - (vVector1.y * vVector2.x));

  //normalize

  // Get the magnitude of our normal
  m_magnitude := sqrt((vNormal.x * vNormal.x) + (vNormal.y * vNormal.y) + (vNormal.z * vNormal.z) );

	vNormal.x := vNormal.x/m_magnitude; // Divide the X value of our normal by it's magnitude
	vNormal.y := vNormal.y/m_magnitude;	// Divide the Y value of our normal by it's magnitude
	vNormal.z := vNormal.z/m_magnitude;	// Divide the Z value of our normal by it's magnitude

  //plane distance

  originDistance := -1 * ((vNormal.x * vPoly[0].x) + (vNormal.y * vPoly[0].y) + (vNormal.z * vPoly[0].z));

  // Get the distance from point1 from the plane using:
  //Ax + By + Cz + D = (The distance from the plane)
	distance1 := ((vNormal.x * vLine[0].x)  +         // Ax +
		         (vNormal.y * vLine[0].y)  +            // Bx +
				 (vNormal.z * vLine[0].z)) + originDistance;// Cz + D

  // Get the distance from point2 from the plane using
  //Ax + By + Cz + D = (The distance from the plane)
	distance2 := ((vNormal.x * vLine[1].x)  +         // Ax +
		         (vNormal.y * vLine[1].y)  +            // Bx +
				 (vNormal.z * vLine[1].z)) + originDistance;// Cz + D


  // Check to see if both point's distances are both negative or both positive
	if(distance1 * distance2 >= 0) then
  begin
    // Return false if each point has the same sign.
    //-1 and 1 would mean each point is on either side of the plane.
    //-1 -2 or 3 4 wouldn't...
	  result := false;
    exit;
  end;

  //vector

  vLineDir.x := vLine[1].x - vLine[0].x;    // Get the X value of our new vector
	vLineDir.y := vLine[1].y - vLine[0].y;    // Get the Y value of our new vector
	vLineDir.z := vLine[1].z - vLine[0].z;    // Get the Z value of our new vector

  //normalize

  // Get the magnitude of our normal
  m_magnitude := sqrt((vLineDir.x * vLineDir.x) +
                      (vLineDir.y * vLineDir.y) +
                      (vLineDir.z * vLineDir.z) );

	vLineDir.x := vLineDir.x/m_magnitude;// Divide the X value of our normal by it's magnitude
	vLineDir.y := vLineDir.y/m_magnitude;// Divide the Y value of our normal by it's magnitude
	vLineDir.z := vLineDir.z/m_magnitude;// Divide the Z value of our normal by it's magnitude

  // Use the plane equation with the normal and the line
	Numerator := -1 * (vNormal.x * vLine[0].x +
          				   vNormal.y * vLine[0].y +
				             vNormal.z * vLine[0].z + originDistance);

  // Get the dot product of the line's vector and the normal of the plane
	Denominator := ( (vNormal.x * vLineDir.x) + (vNormal.y * vLineDir.y) + (vNormal.z * vLineDir.z) );

	if( Denominator = 0.0) then	 // Check so we don't divide by zero
  begin
		vIntersection := vLine[0]; // Return an arbitrary point on the line
  end
  else
  begin
    // Divide to get the multiplying (percentage) factor
  	dist := Numerator / Denominator;
  	vPoint.x := (vLine[0].x + (vLineDir.x * dist));
  	vPoint.y := (vLine[0].y + (vLineDir.y * dist));
  	vPoint.z := (vLine[0].z + (vLineDir.z * dist));

  	vIntersection := vPoint;								// Return the intersection point
  end;
  // Go in a circle to each vertex and get the angle between
  for i := 0 to verticeCount-1 do
  begin

    // Subtract the intersection point from the current vertex
    // Get the X value of our new vector
    vA.x := vPoly[i].x - vIntersection.x;
    // Get the Y value of our new vector
	  vA.y := vPoly[i].y - vIntersection.y;
    // Get the Z value of our new vector
	  vA.z := vPoly[i].z - vIntersection.z;

    // Subtract the point from the next vertex
    // Get the X value of our new vector
    vB.x := vPoly[(i + 1) mod verticeCount].x - vIntersection.x;
    // Get the Y value of our new vector
	  vB.y := vPoly[(i + 1) mod verticeCount].y - vIntersection.y;
    // Get the Z value of our new vector
	  vB.z := vPoly[(i + 1) mod verticeCount].z - vIntersection.z;

  	// Get the dot product of the vectors
    dotProduct := ( (vA.x * vB.x) + (vA.y * vB.y) + (vA.z * vB.z) );

  	// Get the product of both of the vectors magnitudes
	  vectorsMagnitude := sqrt(extended(vA.x * vA.x) + extended(vA.y * vA.y) + extended(vA.z * vA.z))*
                        sqrt(extended(vB.x * vB.x) + extended(vB.y * vB.y) + extended(vB.z * vB.z)
                          );

	 tempangle := arccos( dotProduct / vectorsMagnitude );

	  if(isnan(tempangle)) then
    begin
  		tempangle := 0;
    end;

  	// add the current tempangle to Angle in radians
	  Angle := Angle + tempangle;
  end;

  Intersection := vIntersection;

  // If the angle is greater than 2 PI, (360 degrees)
	if(Angle >= (MATCH_FACTOR * (2.0 * PI)) ) then
  begin
		result := TRUE;							// The point is inside of the polygon
    exit;                       // We collided!	  Return success
  end;


	// If we get here, we must have NOT collided

	result := false; // There was no collision, so return false
end;


// =============================================================================
//  TTriangle
// =============================================================================

// =============================================================================
//  TTriangle.CalcUV
// =============================================================================
procedure TglTriangle.CalcUV;
var
 i       : Integer;
 uMin    : Single;
 uMax    : Single;
 vMin    : Single;
 vMax    : Single;
 uDelta  : Single;
 vDelta  : Single;
begin
for i := 0 to 2 do
 begin
 if glGetTriangleAlignement(Vertex) = YZ then
  begin
  TexCoord[i].u := Vertex[i].z;
  TexCoord[i].v := Vertex[i].y;
  end;
 if glGetTriangleAlignement(Vertex) = XZ then
  begin
  TexCoord[i].u := Vertex[i].x;
  TexCoord[i].v := Vertex[i].z;
  end;
 if glGetTriangleAlignement(Vertex) = XY then
  begin
  TexCoord[i].u := Vertex[i].x;
  TexCoord[i].v := Vertex[i].y;
  end;
 end;
uMin := TexCoord[0].u;
uMax := TexCoord[0].u;
vMin := TexCoord[1].v;
vMax := TexCoord[1].v;
for i := 0 to 2 do
 begin
 if TexCoord[i].u < uMin then
  uMin := TexCoord[i].u;
 if TexCoord[i].v < vMin then
  vMin := TexCoord[i].v;
 if TexCoord[i].u > uMax then
  uMax := TexCoord[i].u;
 if TexCoord[i].v > vMax then
  vMax := TexCoord[i].v;
 end;
uDelta := uMax-uMin;
vDelta := vMax-vMin;
for i := 0 to 2 do
 begin
 TexCoord[i].u := TexCoord[i].u-uMin;
 TexCoord[i].v := TexCoord[i].v-vMin;
 TexCoord[i].u := TexCoord[i].u/uDelta;
 TexCoord[i].v := TexCoord[i].v/vDelta;
 end;
end;

// =============================================================================
//  TglTriangle.Normal
// =============================================================================
function TglTriangle.Normal : TglVertex3f;
begin
Result := glGetNormalVector(Vertex[0], Vertex[1], Vertex[2]);
end;

// =============================================================================
//  glCalculateTSB
// =============================================================================
procedure glCalculateTSB(v0,v1,v2 : TglTangentVertex;var Normal,sTangent,tTangent : TglVertex3f);
var
 Side0,Side1     : TglVertex3f;
 DeltaT0,DeltaT1 : TGLFloat;
 TangentCross    : Single;
begin
// side0 is the vector along one side of the triangle of vertices passed in, and side1 is
// the vector along another side. Taking the cross product of these returns the normal.
Side0 := glSubtractVector(v0.Position,v1.Position);
Side1 := glSubtractVector(v2.Position,v1.Position);
// Calculate normal
Normal := glCrossProduct(Side1,Side0);
glNormalizeVector(Normal);
// Now we use a formula to calculate the s tangent . We then use the same formula for the t tangent.
// Calculate s tangent
DeltaT0  := v0.T-v1.T;
DeltaT1  := v2.T-v0.T;
sTangent := glSubtractVector(glScaleVector(Side0,glVertex(DeltaT1,DeltaT1,DeltaT1)),glScaleVector(Side1,glVertex(DeltaT0,DeltaT0,DeltaT0)));
glNormalizeVector(sTangent);
// Calculate t tangent
DeltaT0  := v0.S-v1.S;
DeltaT1  := v2.S-v0.S;
tTangent := glSubtractVector(glScaleVector(Side0,glVertex(DeltaT1,DeltaT1,DeltaT1)),glScaleVector(Side1,glVertex(DeltaT0,DeltaT0,DeltaT0)));
glNormalizeVector(tTangent);
// Now, we take the cross product of the tangents to get a vector which should point in the same
// direction as our normal calculated above. If it points in the opposite direction (the dot product
// between the normals is less than zero), then we need to reverse the s and t tangents. This is
// because the triangle has been mirrored when going from tangent space to object space.
// reverse tangents if necessary
TangentCross := glDotProduct(sTangent,tTangent);
if TangentCross < 0 then
 begin
 sTangent := glVertex(-sTangent.x,-sTangent.y,-sTangent.z);
 tTangent := glVertex(-tTangent.x,-tTangent.y,-tTangent.z);
 end;
end;

// =============================================================================
//  Matrix Operations
// =============================================================================

// =============================================================================
//  glMatrixSetIdentity
// =============================================================================
procedure glMatrixSetIdentity(var M : TMatrix4f);
begin
M[0,0] := 1; M[1,0] := 0; M[2,0] := 0; M[3,0] := 0;
M[0,1] := 0; M[1,1] := 1; M[2,1] := 0; M[3,1] := 0;
M[0,2] := 0; M[1,2] := 0; M[2,2] := 1; M[3,2] := 0;
M[0,3] := 0; M[1,3] := 0; M[2,3] := 0; M[3,3] := 1;
end;

// =============================================================================
//  glMatrixSetTransform
// =============================================================================
procedure glMatrixSetTransform(var M : TMatrix4f; V : TglVertex3f);
begin
M[3][0] := V.x;
M[3][1] := V.y;
M[3][2] := V.z;
end;

// =============================================================================
//  glMatrixSetRotation
// =============================================================================
procedure glMatrixSetRotation(var M : TMatrix4f; V : TglVertex3f);
var
 cr , sr , cp , sp , cy , sy , srsp , crsp : single;
begin
V.x := V.x * 180/PI;
V.y := V.y * 180/PI;
V.z := V.z * 180/PI;

cr := cos(V.x);
sr := sin(V.x);
cp := cos(V.y);
sp := sin(V.y);
cy := cos(V.z);
sy := sin(V.z);

M[0,0] := cp*cy;
M[1,0] := cp*sy;
M[2,0] := -sp;
if M[2,0] = -0 then
 M[2,0] := 0;

srsp := sr*sp;
crsp := cr*sp;

M[0,1] := srsp*cy-cr*sy ;
M[1,1] := srsp*sy+cr*cy ;
M[2,1] := sr*cp ;
M[0,2] := crsp*cy+sr*sy ;
M[1,2] := crsp*sy-sr*cy ;
M[2,2] := cr*cp ;
end;

// =============================================================================
//  glMatrixRotateVector
// =============================================================================
procedure glMatrixRotateVector(const M : TMatrix4f; var pVect : TglVertex3f);
var
 vec : array [0..2] of single;
begin
vec[0] := pVect.x*M[0,0] + pVect.y*M[1,0] + pVect.z*M[2,0];
vec[1] := pVect.x*M[0,1] + pVect.y*M[1,1] + pVect.z*M[2,1];
vec[2] := pVect.x*M[0,2] + pVect.y*M[1,2] + pVect.z*M[2,2];
pVect.x := vec[0];
pVect.y := vec[1];
pVect.z := vec[2];
end;

procedure glMatrixRotateVector(const M : TMatrix4f; var pVect : TglVertex4f);
var
 vec : array [0..2] of single;
begin
vec[0] := pVect.x*M[0,0] + pVect.y*M[1,0] + pVect.z*M[2,0];
vec[1] := pVect.x*M[0,1] + pVect.y*M[1,1] + pVect.z*M[2,1];
vec[2] := pVect.x*M[0,2] + pVect.y*M[1,2] + pVect.z*M[2,2];
pVect.x := vec[0];
pVect.y := vec[1];
pVect.z := vec[2];
end;

// =============================================================================
//  glMatrixMakeYawMatrix
// =============================================================================
function glMatrixMakeYawMatrix(Angle : Single) : TMatrix4f;
var
 CA : Single;
 SA : Single;
 M  : TMatrix4f;
begin
SA := Sin(Angle);
CA := Cos(Angle);
M[0,0] := CA; M[1,0] := 0; M[2,0] := -SA; M[3,0] := 0;
M[0,1] := 0;  M[1,1] := 1; M[2,1] := 0;   M[3,1] := 0;
M[0,2] := SA; M[1,2] := 0; M[2,2] := CA;  M[3,2] := 0;
M[0,3] := 0;  M[1,3] := 0; M[2,3] := 0;   M[3,3] := 1;
Result := M;
end;

// =============================================================================
//  glMatrixMakeRollMatrix
// =============================================================================
function glMatrixMakeRollMatrix(Angle : Single) : TMatrix4f;
var
 CA : Single;
 SA : Single;
 M  : TMatrix4f;
begin
SA := Sin(Angle);
CA := Cos(Angle);
M[0,0] := CA;  M[1,0] := SA; M[2,0] := 0; M[3,0] := 0;
M[0,1] := -SA; M[1,1] := CA; M[2,1] := 0; M[3,1] := 0;
M[0,2] := 0;   M[1,2] := 0;  M[2,2] := 1; M[3,2] := 0;
M[0,3] := 0;   M[1,3] := 0;  M[2,3] := 0; M[3,3] := 1;
Result := M;
end;

// =============================================================================
//  glMatrixMultiply
// =============================================================================
function glMatrixMultiply(m1 : TMatrix4f; m2 : TMatrix4f) : TMatrix4f;
var
  r, c, i: Byte;
  t: TMatrix4f;
begin
// Multiply two matrices.
t := NullMatrix4f;
for r := 0 to 3 do
 for c := 0 to 3 do
  for i := 0 to 3 do
   t[r,c] := t[r,c] + (m1[r,i]*m2[i,c]);
Result := t;
end;

initialization

finalization


end.
