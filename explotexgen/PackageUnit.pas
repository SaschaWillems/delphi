unit PackageUnit;

interface

uses
 SysUtils,
 Dialogs,
 Classes,
 Forms,

 zLib,

 dglOpenGL,
 Textures;

const
 PackageID = 666;

type
 TFileInfo = record
   FileName     : String;
   FileOffset   : Int64;
   // Nur beim Erstellen des Packages nötig :
   FullFileName : String;
   Dir          : String;
   FileSize     : Int64;
  end;
 TPackage = class
    FileInfo   : array of TFileInfo;
    Stream     : TFileStream;
    function EncryptFileName(pFileName : String) : String;
    function DecryptFileName(pFileName : String) : String;
    function GetFileSize(pFileName : String) : Int64;
    function GetFileIndex(pFileName : String) : Integer;
    constructor Create;
    destructor Destroy; override;
    procedure AddFile(pFullFileName, pFileName : String;pDirName : String='');
    procedure Compile(pOutputFileName : String; pUseCompression : Boolean = False);
    procedure LoadFromFile(pFileName : String);
    procedure LoadFromResource(pResName : String);
    function ExtractFile(pFileName, pOutputFileName : String) : Boolean;
    procedure SeekFile(pFileName : String);
    procedure LoadTextureFromFile(pFileName : String; var pTextureID : Cardinal);
    procedure CopyFileToStream(pFileName : String; pStream : TMemoryStream);
    procedure LoadStringListFromStream(pFileName : String;pStringList : TStringList);
  end;

implementation

// =============================================================================
//  TPackage.Create
// =============================================================================
constructor TPackage.Create;
begin
inherited Create;
end;

// =============================================================================
//  TPackage.Destroy
// =============================================================================
destructor TPackage.Destroy;
begin
SetLength(FileInfo, 0);
if Assigned(Stream) then
 Stream.Free;
inherited;
end;

// =============================================================================
//  TPackage.GetFileSize
// =============================================================================
function TPackage.GetFileSize(pFileName : String) : Int64;
var
 i : Integer;
begin
Result := 0;
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  if LowerCase(FileInfo[i].FileName) = LowerCase(pFileName) then
   if i = High(FileInfo) then
    Result := Stream.Size-FileInfo[i].FileOffset
   else
    Result := FileInfo[i+1].FileOffset-FileInfo[i].FileOffset;
end;

// =============================================================================
//  TPackage.GetFileIndex
// =============================================================================
function TPackage.GetFileIndex(pFileName : String) : Integer;
var
 i : Integer;
begin
Result := -1;
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  if LowerCase(FileInfo[i].FileName) = LowerCase(pFileName) then
   begin
   Result := i;
   exit;
   end;
end;

// =============================================================================
//  TPackage.EncryptFileName
// =============================================================================
function TPackage.EncryptFileName(pFileName : String) : String;
var
 i : Integer;
begin
Result := pFileName;
for i := 1 to Length(pFileName) do
 Result[i] := Chr(Ord(pFileName[i]) shl 1);
end;

// =============================================================================
//  TPackage.DecryptFileName
// =============================================================================
function TPackage.DecryptFileName(pFileName : String) : String;
var
 i : Integer;
begin
Result := pFileName;
for i := 1 to Length(pFileName) do
 Result[i] := Chr(Ord(pFileName[i]) shr 1);
end;

// =============================================================================
//  TPackage.AddFile
// =============================================================================
procedure TPackage.AddFile(pFullFileName, pFileName : String;pDirName : String = '');
var
 FStream : TFileStream;
begin
SetLength(FileInfo, Length(FileInfo)+1);
with FileInfo[High(FileInfo)] do
 begin
 FileName     := pFileName;
 FullFileName := pFullFileName;
 FStream      := TFileStream.Create(FullFileName, fmOpenRead);
 FileSize     := FStream.Size;
 Dir          := pDirName;
 FStream.Free;
 end;
end;

// =============================================================================
//  TPackage.Compile
// =============================================================================
procedure TPackage.Compile(pOutputFileName : String; pUseCompression : Boolean = False);
var
 FStream : TFileStream;
 SStream : TFileStream;
 Header  : TFileStream;
 Writer  : TWriter;
 i       : Integer;
 Offset  : Int64;
begin
// Headergröße berechnen
Header := TFileStream.Create('header.tmp', fmCreate);
Writer := TWriter.Create(Header, 128);
Writer.WriteInteger(PackageID);
Writer.WriteInteger(Length(FileInfo));
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  with FileInfo[i] do
   begin
   Writer.WriteString(EncryptFileName(FileName));
   Writer.WriteString(EncryptFileName(Dir));
   // Workaround, da WriteInteger je nach Wert anderes Format wählt
   Writer.Write(FileOffset, SizeOf(Int64));
   end;
Writer.Free;
Offset := Header.Size;
//ShowMessage('Headersize = '+IntToStr(Offset));
Header.Free;
DeleteFile('header.tmp');

// Dateigrößen und Offsets ermitteln
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  with FileInfo[i] do
   begin
   FileOffset := Offset;
   SStream := TFileStream.Create(FullFileName, fmOpenRead);
   inc(Offset, SStream.Size);
   SStream.Free;
   end;
// Package erstellen
FStream := TFileStream.Create(pOutputFileName, fmCreate);
Writer  := TWriter.Create(FStream, 128);
// Header (Dateinamen und Position)
Writer.WriteInteger(PackageID);
Writer.WriteInteger(Length(FileInfo));
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  with FileInfo[i] do
   begin
   Writer.WriteString(EncryptFileName(FileName));
   Writer.WriteString(EncryptFileName(Dir));
   Writer.Write(FileOffset, SizeOf(Int64));
   end;
Writer.Free;
//ShowMessage('Header loaded = '+IntToStr(FStream.Position));

// Inhalte der Dateien
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  with FileInfo[i] do
   begin
   SStream := TFileStream.Create(FullFileName, fmOpenRead);
   FStream.CopyFrom(SStream, 0);
   SStream.Free;
   end;

FStream.Free;
end;

// =============================================================================
//  TPackage.LoadFromFile
// =============================================================================
procedure TPackage.LoadFromFile(pFileName : String);
var
 Reader     : TReader;
 i          : Integer;
begin
if Assigned(Stream) then
 Stream.Free;
Stream := TFileStream.Create(pFileName, fmOpenRead);
//Stream.LoadFromFile(pFileName);
Reader := TReader.Create(Stream, 128);
i := Reader.ReadInteger;
if i <> PackageID then
 begin
 ShowMessage('Wrong PackageID!');
 Reader.Free;
 Stream.Free;
 exit;
 end;
SetLength(FileInfo, Reader.ReadInteger);
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  with FileInfo[i] do
   begin
   FileName := DecryptFileName(Reader.ReadString);
   Dir      := DecryptFileName(Reader.ReadString);
   Reader.Read(FileOffset, SizeOf(Int64));
   end;
Reader.Free;
end;

// =============================================================================
//  TPackage.LoadFromResource
// =============================================================================
procedure TPackage.LoadFromResource(pResName : String);
var
 Reader    : TReader;
 i         : Integer;
 ResStream : TResourceStream;
begin
if Assigned(Stream) then
 Stream.Free;
Stream    := TFileStream.Create(0);
ResStream := TResourceStream.Create(hInstance, pResName, 'TPACKAGE');
Stream.CopyFrom(ResStream, ResStream.Size);
Reader := TReader.Create(Stream, 128);
i := Reader.ReadInteger;
if i <> PackageID then
 begin
 ShowMessage('Wrong PackageID!');
 Reader.Free;
 Stream.Free;
 exit;
 end;
SetLength(FileInfo, Reader.ReadInteger);
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  with FileInfo[i] do
   begin
   FileName   := DecryptFileName(Reader.ReadString);
   Reader.Read(FileOffset, SizeOf(Int64));
   end;
Reader.Free;
ResStream.Free;
end;

// =============================================================================
//  TPackage.ExtractFile
// =============================================================================
function TPackage.ExtractFile(pFileName, pOutputFileName : String) : Boolean;
var
 i       : Integer;
 OStream : TFileStream;
begin
Result := True;
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  if LowerCase(FileInfo[i].FileName) = LowerCase(pFileName) then
   begin
   Stream.Seek(FileInfo[i].FileOffset, soFromBeginning);
   OStream := TFileStream.Create(pOutputFileName, fmCreate);
   if i = High(FileInfo) then
    OStream.CopyFrom(Stream, Stream.Size-FileInfo[i].FileOffset)
   else
    OStream.CopyFrom(Stream, FileInfo[i+1].FileOffset-FileInfo[i].FileOffset);
   OStream.Free;
   exit;
   end;
Result := False;
end;

// =============================================================================
//  TPackage.SeekFile
// =============================================================================
procedure TPackage.SeekFile(pFileName : String);
var
 i : Integer;
begin
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  if LowerCase(FileInfo[i].FileName) = LowerCase(pFileName) then
   Stream.Seek(FileInfo[i].FileOffset, soFromBeginning);
end;

// =============================================================================
//  TPackage.LoadTextureFromFile
// =============================================================================
procedure TPackage.LoadTextureFromFile(pFileName : String; var pTextureID : Cardinal);
begin
if ExtractFile(pFileName, '_'+pFileName) then
 begin
 //LoadTexture('_'+pFileName, pTextureID, False, GL_LINEAR, GL_LINEAR_MIPMAP_LINEAR, False);
 DeleteFile('_'+pFileName);
 end;
end;

// =============================================================================
//  TPackage.CopyFileToStream
// =============================================================================
procedure TPackage.CopyFileToStream(pFileName : String;pStream : TMemoryStream);
var
 i : Integer;
begin
if Length(FileInfo) > 0 then
 for i := 0 to High(FileInfo) do
  if LowerCase(FileInfo[i].FileName) = LowerCase(pFileName) then
   begin
   Stream.Seek(FileInfo[i].FileOffset, soFromBeginning);
   if i = High(FileInfo) then
    pStream.CopyFrom(Stream, Stream.Size-FileInfo[i].FileOffset)
   else
    pStream.CopyFrom(Stream, FileInfo[i+1].FileOffset-FileInfo[i].FileOffset);
   exit;
   end;
end;

// =============================================================================
//  TPackage.LoadStringListFromStream
// =============================================================================
procedure TPackage.LoadStringListFromStream(pFileName : String;pStringList : TStringList);
var
 TmpStream : TMemoryStream;
begin
TmpStream := TMemoryStream.Create;
CopyFileToStream(pFileName, TmpStream);
if TmpStream.Size = 0 then
 raise Exception.Create('TPackage->LoadStringListFromStream->Stream is empty!');
TmpStream.Seek(0, soFromBeginning);
if TmpStream.Size > 0 then
 pStringList.LoadFromStream(TmpStream);
TmpStream.Free;
end;

end.
