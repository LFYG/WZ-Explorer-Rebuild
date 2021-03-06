unit XMLWriter;

interface

uses SysUtils, Classes, WZArchive, WZDirectory, WZIMGFile, Forms,
     Generics.Collections;

type
  TGUIUpdateProc = procedure(Cur, Max: Integer; const CurFile: string) of object;

  TXMLWriter = class
  private
    FDataProv: TWZArchive;
    FRoot: TWZDirectory;
    FUpdateProc: TGUIUpdateProc;
    FPath: string;

    // Main dumping procedures
    procedure DumpDirectory(const Path: string; Root: TWZDirectory);
    procedure DumpImg(Img: TWZIMGEntry; Doc: TStringList);
    procedure DumpData(Data: TWZIMGEntry; Doc: TStringList; Level: Integer; const PathInImg: string);
    procedure DumpDataList(DataList: TList<TWZIMGEntry>; Doc: TStringList; Level: Integer; const PathInImg: string);

    // XML helper functions
    function Indent(Level: Integer): string;
    function OpenNamedTag(const Tag, Name: string; Finish: Boolean): string; overload;
    function OpenNamedTag(const Tag, Name: string; Finish: Boolean; Empty: Boolean): string; overload;
    function EmptyNamedTag(const Tag, Name: string): string;
    function EmptyNamedValuePair(const Tag, Name, Value: string): string;
    function CloseTag(const Tag: string): string;
    function Attrib(const Name, Value: string): string; overload;
    function Attrib(const Name, Value: string; CloseTag, Empty: Boolean): string; overload;
  public
    constructor Create(AUpdateProc: TGUIUpdateProc; const APath: string);

    procedure Dump(Archive: TWZArchive);
  end;

implementation

{ TXMLWriter }

constructor TXMLWriter.Create(AUpdateProc: TGUIUpdateProc; const APath: string);
begin
  FUpdateProc := AUpdateProc;
  FPath := APath;
end;

procedure TXMLWriter.Dump(Archive: TWZArchive);
begin
  FDataProv := Archive;
  FRoot := FDataProv.Root;

  DumpDirectory('', FRoot);
end;

function IncludeDelim(const Path: string): string;
begin
  Result := Path;
  if (Length(Result) > 0) and (Result[Length(Result)] <> '/') then
    Result := Result + '/';
end;

procedure TXMLWriter.DumpDirectory(const Path: string; Root: TWZDirectory);
var
  i: Integer;
  FilePath, SavePath: string;
  Doc: TStringList;
  IMG: TWZIMGFile;
begin
  // Empty directories, e.g. in Base.wz
  if Root.Files.Count = 0 then
    ForceDirectories(FPath + FRoot.Name + '\' + Root.Name + '\');

  for i := 0 to Root.Files.Count - 1 do
  begin
    Doc := TStringList.Create;

    FilePath := Path;
    if (Length(FilePath) > 0) and (FilePath[Length(FilePath)] <> '/') then
      FilePath := FilePath + '/';
    FilePath := FilePath + TWZFile(Root.Files[i]).Name;

    IMG := FDataProv.GetImgFile(FilePath);
    try
      FUpdateProc(i + 1, Root.Files.Count, IMG.Root.Name);

      DumpImg(IMG.Root, Doc);

      SavePath := FPath + FRoot.Name + '\';
      FilePath  := StringReplace(FilePath, '/', PathDelim, [rfReplaceAll]);
      if Pos(PathDelim, FilePath) > 0 then
        SavePath := SavePath + ExtractFilePath(FilePath);

      // Make sure that the path where the XML file will be saved exists
      ForceDirectories(SavePath);

      Doc.SaveToFile(SavePath + IMG.Root.Name + '.xml');
    finally
      FreeAndNil(Doc);
      FreeAndNil(IMG);
    end;

    Application.ProcessMessages;
  end;

  for i := 0 to Root.SubDirs.Count - 1 do
    if Path = '' then
      DumpDirectory(TWZEntry(Root.SubDirs[i]).Name, Root.SubDirs[i])
    else
      DumpDirectory(IncludeDelim(Path) + TWZEntry(Root.SubDirs[i]).Name, Root.SubDirs[i]);
end;

procedure TXMLWriter.DumpImg(Img: TWZIMGEntry; Doc: TStringList);
begin
  Doc.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
  DumpData(Img, Doc, 0, '');
end;

procedure TXMLWriter.DumpData(Data: TWZIMGEntry; Doc: TStringList; Level: Integer; const PathInImg: string);
begin
  case Data.DataType of
    mdtProperty:
    begin
      Doc.Append(Indent(Level) + OpenNamedTag('imgdir', Data.Name, True));
      DumpDataList(Data.Children, Doc, Level + 1, PathInImg + Data.Name + '\');
      Doc.Append(Indent(Level) + CloseTag('imgdir'));
    end;

    mdtExtended:
    begin
      Doc.Append(Indent(Level) + OpenNamedTag('extended', Data.Name, True));
      DumpDataList(Data.Children, Doc, Level + 1, PathInImg + Data.Name + '\');
      Doc.Append(Indent(Level) + CloseTag('extended'));
    end;

    mdtCanvas:
    begin
			Doc.Append(Indent(Level) + openNamedTag('canvas', Data.Name, False, False) +
			      	    	Attrib('width', IntToStr(Data.Canvas.Width)) +
			          		Attrib('height', IntToStr(Data.Canvas.Height), True, False));

      DumpDataList(Data.Children, Doc, Level + 1, PathInImg + Data.Name + '\');
      Doc.Append(Indent(Level) + CloseTag('canvas'));
    end;

    mdtConvex:
    begin
      Doc.Append(Indent(Level) + OpenNamedTag('convex', Data.Name, True));
      DumpDataList(Data.Children, Doc, Level + 1, PathInImg + Data.Name + '\');
      Doc.Append(Indent(Level) + CloseTag('convex'));
    end;

    mdtSound: Doc.Append(Indent(Level) + EmptyNamedTag('sound', Data.Name));

    mdtUOL: Doc.Append(Indent(Level) + EmptyNamedValuePair('uol', Data.Name, Data.Data));

    mdtDouble:  Doc.Append(Indent(Level) + EmptyNamedValuePair('double', Data.Name, Data.Data));

    mdtFloat: Doc.Append(Indent(Level) + EmptyNamedValuePair('float', Data.Name, Data.Data));

    mdtInt: Doc.Append(Indent(Level) + EmptyNamedValuePair('int', Data.Name, Data.Data));

    mdtShort: Doc.Append(Indent(Level) + EmptyNamedValuePair('short', Data.Name, Data.Data));

    mdtString: Doc.Append(Indent(Level) + EmptyNamedValuePair('string', Data.Name, Data.Data));

    mdtVector: Doc.Append(Indent(Level) +
                              OpenNamedTag('vector', Data.Name, False, False) +
                              Attrib('x', IntToStr(Data.Vector.X)) +
                              Attrib('y', IntToStr(Data.Vector.Y), True, True));

    mdtIMG_0x00: Doc.Append(Indent(Level) + EmptyNamedTag('null', Data.Name));
  end;
end;

procedure TXMLWriter.DumpDataList(DataList: TList<TWZIMGEntry>; Doc: TStringList; Level: Integer; const PathInImg: string);
var
  i: Integer;
begin
  for i := 0 to DataList.Count - 1 do
    DumpData(DataList[i], Doc, Level, PathInImg);
end;

function TXMLWriter.Indent(Level: Integer): string;
begin
  if Level = 0 then
    Result := ''
  else
    Result := StringOfChar('	', Level);
end;

function TXMLWriter.OpenNamedTag(const Tag, Name: string; Finish: Boolean): string;
begin
  Result := OpenNamedTag(Tag, Name, Finish, False);
end;

function TXMLWriter.OpenNamedTag(const Tag, Name: string; Finish, Empty: Boolean): string;
begin
  Result := Format('<%s name="%s"', [Tag, Name]);
  if Finish then
    if Empty then
      Result := Result + '/>'
    else
      Result := Result + '>'
  else
    Result := Result + ' ';
end;

function TXMLWriter.EmptyNamedTag(const Tag, Name: string): string;
begin
  Result := OpenNamedTag(Tag, Name, True, True);
end;

function TXMLWriter.EmptyNamedValuePair(const Tag, Name, Value: string): string;
begin
  Result := OpenNamedTag(Tag, Name, False, False) + Attrib('value', Value, True, True);
end;

function TXMLWriter.CloseTag(const Tag: string): string;
begin
  Result := '</' + Tag + '>';
end;

function SanitizeText(const S: string): string;
const
  SpecialChars: array[0..4] of string = (  '&'  ,   '"',      '''',    '<',    '>'  );
  Replacements: array[0..4] of string = ('&amp;', '&quot;', '&apos;', '&lt;', '&gt;');
var
  i: Integer;

  // Make it ????? so Java is happy...
  function ParseUnicodeStr(const Uni: string): string;
  var
    i, UniCounter: Integer;
  begin
    UniCounter := 43690;   // $AAAA

    Result := '';

    for i := 0 to Length(Uni) do
      Result := Result + '&#' + IntToStr(UniCounter) + ';'   // Quests get fucked up if we just put IntToStr(Ord(Uni[i])) here.
  end;

begin
  Result := S;

  for i := 0 to High(SpecialChars) do
    Result := StringReplace(Result, SpecialChars[i], Replacements[i], [rfReplaceAll]);

  for i := 1 to Length(Result) do
    if Ord(Result[i]) > 128 then
      Exit(ParseUnicodeStr(Result));
end;

function TXMLWriter.Attrib(const Name, Value: string): string;
begin
  Result := Attrib(Name, Value, False, False);
end;

function TXMLWriter.Attrib(const Name, Value: string; CloseTag, Empty: Boolean): string;
begin
  Result := Format('%s="%s"', [Name, SanitizeText(Value)]);

  if CloseTag then
    if Empty then
      Result := Result + '/>'
    else
      Result := Result + '>'
  else
    Result := Result + ' ';
end;

end.
