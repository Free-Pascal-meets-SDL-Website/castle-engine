{
  Copyright 2018-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Various castle-editor utilities. }
unit EditorUtils;

{$mode objfpc}{$H+}

interface

uses Classes, Types, Controls, StdCtrls, Process, Menus, Generics.Collections,
  CastleStringUtils;

type
  TMenuItemHelper = class helper for TMenuItem
  public
    procedure SetEnabledVisible(const Value: Boolean);
  end;

type
  TOutputKind = (
    okInfo,
    okImportantInfo,
    okWarning,
    okError
  );

  { Instance of this takes control of your TListBox to display messages. }
  TOutputList = class
  strict private
    type
      TOutputInfo = class
        Kind: TOutputKind;
      end;
    var
      OutputInfoPerKind: array [TOutputKind] of TOutputInfo;
      FList: TListBox;
    procedure DrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
  public
    constructor Create(const AList: TListBox);
    destructor Destroy; override;
    property List: TListBox read FList;

    procedure AddLine(const S: String; const Kind: TOutputKind);
    { Split S into multiple lines.
      Add each of them as separate line.
      Avoids adding empty lines at the very end (since they would
      make the look uglier; instead,
      we make nice separators with AddSeparator). }
    procedure SplitAddLines(const S: String; const Kind: TOutputKind);
    procedure AddSeparator;
    procedure Clear;
  end;

  { Call external process asynchronously (doesn't hang this process at any point),
    sending output to TOutputList. }
  TAsynchronousProcess = class
  strict private
    Process: TProcess;
    { Text read from Process output, but not passed to OutputList yet. }
    PendingLines: String;
    FRunning: Boolean;
    FExitStatus: Integer;
    Environment: TStringList;
  public
    { Set before @link(Start), do not change later.
      @groupBegin }
    ExeName, CurrentDirectory: String;
    Parameters: TCastleStringList;
    OutputList: TOutputList;
    { @groupEnd }

    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Update;
    property Running: Boolean read FRunning;

    { Defined only after callling Start, once Running turned false. }
    property ExitStatus: Integer read FExitStatus;
  end;

  { Call asynchronous processes, one after another, until the end
    or until one of them exits with non-zero status.

    This has deliberately similar API to TAsynchronousProcess,
    since (from the outside) calling a sequence of processes
    should have the same features as calling a single process. }
  TAsynchronousProcessQueue = class
  strict private
    FQueuePosition: Integer;
    AsyncProcess: TAsynchronousProcess;
    procedure CreateAsyncProcess;
  public
    type
      TQueueItem = class
        ExeName, CurrentDirectory: String;
        Parameters: TCastleStringList;
        constructor Create;
        destructor Destroy; override;
      end;

      TQueueItemList = specialize TObjectList<TQueueItem>;

    var
      Queue: TQueueItemList;
      OutputList: TOutputList;
      OnSuccessfullyFinishedAll: TNotifyEvent;

    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Update;
    function Running: Boolean;
  end;

procedure ErrorBox(const Message: String);
procedure WarningBox(const Message: String);
function YesNoBox(const Message: String): Boolean;
function YesNoBox(const Caption, Message: String): Boolean;

{ Set both C.Enabled and C.Exists. }
procedure SetEnabledVisible(const C: TControl; const Value: Boolean);

const
  ApiReferenceUrl = 'https://castle-engine.io/apidoc-unstable/html/';
  FpcRtlApiReferenceUrl = 'https://www.freepascal.org/docs-html/rtl/';
  LclApiReferenceUrl = 'https://lazarus-ccr.sourceforge.io/docs/lcl/';

{ Get full URL to display API reference of a given property in the given
  PropertyObject.

  PropertyName may be '', in which case the link leads to the whole class reference.
  In this case PropertyNameForLink must also be ''.
  Both PropertyName and PropertyNameForLink should be '',
  or both should be non-empty.
}
function ApiReference(const PropertyObject: TObject;
  const PropertyName, PropertyNameForLink: String): String;

{ Add to given submenus (TMenuItem) items for each registered serializable
  component. Thus it allows to construct menu to add all possible
  TCastleTransform instances, all possible TCastleUserInterface instances etc.
  Any ParentXxx may be nil, then relevant components are not added.

  All created menu items have OnClick set to OnClickEvent. }
procedure BuildComponentsMenu(
  const ParentUserInterface, ParentTransform, ParentBehavior, ParentNonVisual: TMenuItem;
  const OnClickEvent: TNotifyEvent);

type
  TCodeEditor = (
    { Use hardcoded logic suitable for Lazarus. }
    ceLazarus,
    { Use custom commands from CodeEditor, CodeEditorProject. }
    ceCustom
  );

const
  DefaultCodeEditor = ceLazarus;

var
  { Which code editor to use. Current user preference. }
  CodeEditor: TCodeEditor;
  { Code editor used to open Pascal files, when CodeEditor = ceCustom. }
  CodeEditorCommand: String;
  { Code editor used to open project, when CodeEditor = ceCustom. }
  CodeEditorCommandProject: String;

implementation

uses SysUtils, Dialogs, Graphics, TypInfo, Generics.Defaults,
  CastleUtils, CastleLog,
  CastleComponentSerialize, CastleUiControls, CastleCameras, CastleTransform,
  ToolCompilerInfo;

procedure TMenuItemHelper.SetEnabledVisible(const Value: Boolean);
begin
  Visible := Value;
  Enabled := Value;
end;

{ TAsynchronousProcessQueue.TQueueItem --------------------------------------- }

constructor TAsynchronousProcessQueue.TQueueItem.Create;
begin
  inherited;
  Parameters := TCastleStringList.Create;
end;

destructor TAsynchronousProcessQueue.TQueueItem.Destroy;
begin
  FreeAndNil(Parameters);
  inherited;
end;

{ TAsynchronousProcessQueue -------------------------------------------------- }

constructor TAsynchronousProcessQueue.Create;
begin
  inherited;
  Queue := TQueueItemList.Create(true);
  FQueuePosition := -1;
end;

destructor TAsynchronousProcessQueue.Destroy;
begin
  FreeAndNil(AsyncProcess);
  FreeAndNil(Queue);
  inherited;
end;

procedure TAsynchronousProcessQueue.Start;
begin
  if Queue.Count = 0 then
    Exit; // nothing to do

  FQueuePosition := 0;
  CreateAsyncProcess;
end;

procedure TAsynchronousProcessQueue.CreateAsyncProcess;
begin
  AsyncProcess := TAsynchronousProcess.Create;
  AsyncProcess.ExeName := Queue[FQueuePosition].ExeName;
  AsyncProcess.CurrentDirectory := Queue[FQueuePosition].CurrentDirectory;
  AsyncProcess.Parameters.Assign(Queue[FQueuePosition].Parameters);
  AsyncProcess.OutputList := OutputList;
  AsyncProcess.Start;
end;

procedure TAsynchronousProcessQueue.Update;
var
  LastLineKind: TOutputKind;
  SuccessfullyFinishedAll: Boolean;
begin
  if AsyncProcess <> nil then
  begin
    AsyncProcess.Update;
    if not AsyncProcess.Running then
    begin
      SuccessfullyFinishedAll := false;

      if AsyncProcess.ExitStatus <> 0 then
      begin
        LastLineKind := okError;
        FQueuePosition := Queue.Count; // abort executing rest
      end else
      begin
        Inc(FQueuePosition);
        LastLineKind := okImportantInfo;
        // if we just finished the last queue item, then success
        SuccessfullyFinishedAll := FQueuePosition = Queue.Count;
      end;
      OutputList.AddSeparator;
      OutputList.AddLine('Command finished with status ' + IntToStr(AsyncProcess.ExitStatus) + '.',
        LastLineKind);
      FreeAndNil(AsyncProcess);

      // create next process in queue
      if FQueuePosition < Queue.Count then
        CreateAsyncProcess;

      if SuccessfullyFinishedAll and Assigned(OnSuccessfullyFinishedAll) then
        OnSuccessfullyFinishedAll(Self);
    end;
  end;
end;

function TAsynchronousProcessQueue.Running: Boolean;
begin
  Result := (FQueuePosition >= 0) and (FQueuePosition < Queue.Count);
end;

{ TAsynchronousProcess ------------------------------------------------------- }

constructor TAsynchronousProcess.Create;
begin
  inherited;
  Parameters := TCastleStringList.Create;
end;

destructor TAsynchronousProcess.Destroy;
begin
  FreeAndNil(Parameters);
  if (Process <> nil) and Process.Running then
    { stop the process, TProcess destructor doesn't do it
      (https://www.freepascal.org/docs-html/fcl/process/tprocess.destroy.html) }
    Process.Terminate(0);
  FreeAndNil(Process);
  FreeAndNil(Environment);
  inherited;
end;

procedure TAsynchronousProcess.Start;
var
  S, LogLine: String;
  I: Integer;
begin
  { copy environment }
  Environment := TStringList.Create;
  for I := 1 to GetEnvironmentVariableCount do
    Environment.Add(GetEnvironmentString(I));

  { Extend PATH, to effectively use FpcCustomPath and LazarusCustomPath
    in the build tool.
    Initially we used to just pass them in special environment variables,
    and restore in ToolCompilerInfo initialization, but this is not enough:
    on Windows, calling "windres" requires that "cpp" is also on PATH.
    It seems more reliable to just add them to PATH. }
  Environment.Values['PATH'] := PathExtendForFpcLazarus(Environment.Values['PATH']);
  WritelnLog('Calling process with extended PATH: ' + Environment.Values['PATH']);

  { create Process and call Process.Execute }
  Process := TProcess.Create(nil);
  Process.Executable := ExeName;
  if CurrentDirectory <> '' then
    Process.CurrentDirectory := CurrentDirectory;
  for S in Parameters do
    Process.Parameters.Add(S);
  { on Windows, we need swoHide, otherwise console appears for build tool.
    Note that poNoConsole is not a solution, as it prevents castle-engine
    console, but FPC (called by castle-engine) console is still visible. }
  Process.ShowWindow := swoHide;
  Process.Options := [poUsePipes, poStderrToOutput];
  Process.Environment := Environment;
  Process.Execute;

  { since the process is executed independently, in theory it *could*
    finish before we get to next line, possibly? }
  //if not Process.Running then
  //  raise EInternalError.Create('Process not running right after Execute?');

  { log in OutputList }
  LogLine := 'Running "' + ExeName;
  for S in Parameters do
    LogLine += ' ' + S;
  LogLine += '"';
  OutputList.AddLine(LogLine, okImportantInfo);
  OutputList.AddSeparator;

  FRunning := true;
end;

procedure TAsynchronousProcess.Update;
const
  ReadMaxSize = 65536;
var
  Buffer: array [0..ReadMaxSize - 1] of Byte;
  ReadBytes: LongInt;
  NewLinePos, OldPendingLinesLen, ProcessedLength: Integer;
  Line: String;
begin
  { In case Process.Running=false, set our own FRunning and FExitStatus.
    Note that we don't make a method like TAsynchronousProcess.Running that
    simply returnsProcess.Running, as then we could report as Running=false
    a processthat didn't yet dump all it's output to OutputList. }
  if not Process.Running then
  begin
    FRunning := false;
    FExitStatus := Process.ExitStatus;
  end;

  { Read Process.Output.
    This must never hang waiting for process, so we check NumBytesAvailable. }
  if Process.Output.NumBytesAvailable <> 0 then
    ReadBytes := Process.Output.Read(Buffer[0], ReadMaxSize)
  else
    ReadBytes := 0;

  // early exit for most usual case when ReadBytes = 0
  if ReadBytes = 0 then
  begin
    { Once the process is not running, and we read everything (ReadBytes = 0),
      dump the remaining PendingLines as last line. }
    if (not Process.Running) and (Length(PendingLines) <> 0) then
    begin
      OutputList.AddLine(PendingLines, okInfo);
      PendingLines := '';
    end;
    Exit;
  end;

  // add Buffer to PendingLines
  OldPendingLinesLen := Length(PendingLines);
  SetLength(PendingLines, OldPendingLinesLen + ReadBytes);
  Move(Buffer[0], PendingLines[OldPendingLinesLen + 1], ReadBytes);

  // extract from PendingLines complete lines (as many as possible)
  repeat
    { Note: it's tempting to try to detect #13#10 (Windows),
      or #10 (Unix),
      or #13 (nothing supported),
      or #10#13 (nothing supported)
      sequence,
      by detecting first char (#13 or #10) and then remove the following
      (if #10 is followed or #13, or #13 is followed by #10).
      But that's risky: if the read chunks will be split right in the middle
      of #13#10, we would introduce an extra newline in the intepreted output.

      It's easier *and* more reliable to just detect newlines as #10,
      and simply ignore any #13 character if it is followed by #10.
      This works for Windows and Unix, which is OK for us. }

    NewLinePos := Pos(#10, PendingLines);
    if NewLinePos <> 0 then
    begin
      ProcessedLength := NewLinePos;

      if SCharIs(PendingLines, NewLinePos - 1, #13) then
        Dec(NewLinePos);
      Line := Copy(PendingLines, 1, NewLinePos - 1);
      OutputList.AddLine(Line, okInfo);

      PendingLines := SEnding(PendingLines, ProcessedLength + 1);
    end else
      Break;
  until false;

  // if we get a lot of output, maybe more than ReadMaxSize, then keep reading!
  if ReadMaxSize = ReadBytes then
    Update;
end;

{ TOutputList --------------------------------------------------------------- }

procedure TOutputList.DrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);

  { Copied from LCL stdctrls.pp }
  procedure InternalDrawItem(Control: TControl;
    Canvas: TCanvas; ARect: TRect; const Text: string);
  var
    OldBrushStyle: TBrushStyle;
    OldTextStyle: TTextStyle;
    NewTextStyle: TTextStyle;
  begin
    OldBrushStyle := Canvas.Brush.Style;
    Canvas.Brush.Style := bsClear;

    OldTextStyle := Canvas.TextStyle;
    NewTextStyle := OldTextStyle;
    NewTextStyle.Layout := tlCenter;
    NewTextStyle.RightToLeft := Control.UseRightToLeftReading;
    if Control.UseRightToLeftAlignment then
    begin
      NewTextStyle.Alignment := taRightJustify;
      ARect.Right := ARect.Right - 2;
    end
    else
    begin
      NewTextStyle.Alignment := taLeftJustify;
      ARect.Left := ARect.Left + 2;
    end;

    Canvas.TextStyle := NewTextStyle;

    Canvas.TextRect(ARect, ARect.Left, ARect.Top, Text);
    Canvas.Brush.Style := OldBrushStyle;
    Canvas.TextStyle := OldTextStyle;
  end;

var
  C: TCanvas;
  OutputInfo: TOutputInfo;
begin
  C := List.Canvas;
  OutputInfo := List.Items.Objects[Index] as TOutputInfo;

  case OutputInfo.Kind of
    okImportantInfo: C.Font.Bold := true;
    okWarning      : C.Brush.Color := clYellow;
    okError        : C.Brush.Color := clRed;
  end;

  C.FillRect(ARect);
  InternalDrawItem(List, C, ARect, List.Items[Index]);
end;

constructor TOutputList.Create(const AList: TListBox);

  { Measure font height in pixels. }
  function GetRowHeight: Integer;
  begin
    FList.Canvas.Font := FList.Font;
    Result := FList.Canvas.TextHeight('Wg');
  end;

var
  Kind: TOutputKind;
begin
  inherited Create;

  FList := AList;
  FList.Style := lbOwnerDrawFixed;
  FList.OnDrawItem := @DrawItem;
  FList.ItemHeight := GetRowHeight + 4;

  { Create OutputInfoPerKind instances.
    The idea is that every AddLine call should not construct new
    TOutputInfo, this could eat quite some memory for a lot of lines.
    Instead most AddLine calls can just take OutputInfoPerKind[Kind]. }
  for Kind in TOutputKind do
  begin
    OutputInfoPerKind[Kind] := TOutputInfo.Create;
    OutputInfoPerKind[Kind].Kind := Kind;
  end;
end;

destructor TOutputList.Destroy;
var
  Kind: TOutputKind;
begin
  for Kind in TOutputKind do
    FreeAndNil(OutputInfoPerKind[Kind]);
  inherited;
end;

procedure TOutputList.AddLine(const S: String; const Kind: TOutputKind);
var
  IsBottom: Boolean;
begin
  {
  IsBottom :=
    (List.Items.Count = 0) or

    // TODO: doesn't work reliably
    // List.ItemFullyVisible(List.Items.Count - 1)

    // TODO: doesn't work reliably
    // checking is visible "List.Items.Count - 1" is not good enough
    (List.Items.Count = 1) or
    List.ItemVisible(List.Items.Count - 2);
  }
  IsBottom := true;

  List.Items.AddObject(S, OutputInfoPerKind[Kind]);

  { scroll to bottom once new message received,
    but only if already looking at bottom (otherwise we would prevent
    user from easily browsing past messages). }
  if IsBottom then
    List.TopIndex := List.Items.Count - 1;
end;

procedure TOutputList.SplitAddLines(const S: String; const Kind: TOutputKind);
var
  SL: TStringList;
  Line: String;
begin
  SL := TStringList.Create;
  try
    SL.Text := S;
    { remove empty lines at end }
    while (SL.Count <> 0) and (SL[SL.Count - 1] = '') do
      SL.Delete(SL.Count - 1);
    for Line in SL do
      AddLine(Line, Kind);
  finally FreeAndNil(SL) end;
end;

procedure TOutputList.AddSeparator;
begin
  AddLine('', okInfo);
end;

procedure TOutputList.Clear;
begin
  List.Items.Clear;
end;

{ global routines ------------------------------------------------------------ }

procedure ErrorBox(const Message: String);
begin
  MessageDlg('Error', Message, mtError, [mbOK], 0);
end;

procedure WarningBox(const Message: String);
begin
  MessageDlg('Warning', Message, mtWarning, [mbOK], 0);
end;

function YesNoBox(const Message: String): Boolean;
begin
  Result := MessageDlg('Question', Message, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

function YesNoBox(const Caption, Message: String): Boolean;
begin
  Result := MessageDlg(Caption, Message, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

procedure SetEnabledVisible(const C: TControl; const Value: Boolean);
begin
  C.Enabled := Value;
  C.Visible := Value;
end;

function ApiReference(const PropertyObject: TObject;
  const PropertyName, PropertyNameForLink: String): String;

  { Knowing that property PropInfo is part of class C,
    determine the class where it's actually declared (C or ancestor of C).

    Note that we search for property using PropInfo, not a string PropertyName,
    this means that we don't mix a property with the same name that
    obscures ancestor property (same name, but actually different property). }
  function ClassOfPropertyDeclaration(const C: TClass; const PropInfo: PPropInfo): TClass;
  var
    ParentC: TClass;
    PropList: PPropList;
    PropCount, I: Integer;
  begin
    ParentC := C.ClassParent;
    if ParentC = nil then
      Exit(C); // no ancestor

    PropCount := GetPropList(ParentC, PropList);
    for I := 0 to PropCount - 1 do
      if PropList^[I] = PropInfo then
        // property found in ancestor
        Exit(ClassOfPropertyDeclaration(ParentC, PropInfo));

    // property not found in ancestor
    Exit(C);
  end;

  function FpDocSuffix(const LinkUnitName, LinkClassName, LinkPropertyName: String): String;
  begin
    Result := LowerCase(LinkUnitName) + '/' + LowerCase(LinkClassName) + '.';
    if LinkPropertyName <> '' then
      Result := Result + LowerCase(LinkPropertyName) + '.';
    Result := Result + 'html';
  end;

  function PasDocSuffix(const LinkUnitName, LinkClassName, LinkPropertyName: String): String;
  begin
    Result := LinkUnitName + '.' + LinkClassName + '.html';
    if LinkPropertyName <> '' then
      Result := Result + '#' + LinkPropertyName;
  end;

var
  LinkUnitName, LinkClassName, LowerLinkUnitName, LinkPropertyName: String;
  PropInfo: PPropInfo;
  ClassOfProperty: TClass;
begin
  LinkUnitName := PropertyObject.UnitName;
  LinkClassName := PropertyObject.ClassName;
  LinkPropertyName := '';

  if PropertyName <> '' then
  begin
    { PropertyName doesn't necessarily belong to the exact PropertyObject class,
      it may belong to ancestor. E.g. TCastleScene.Url is actually from
      TCastleSceneCore.
      This is important to construct API links.
      Unfortunately GetPropInfo doesn't have this info directly. }

     PropInfo := GetPropInfo(PropertyObject, PropertyName);
     if PropInfo <> nil then
     begin
       ClassOfProperty := ClassOfPropertyDeclaration(PropertyObject.ClassType, PropInfo);
       LinkClassName := ClassOfProperty.ClassName;
       LinkUnitName := ClassOfProperty.UnitName;
       LinkPropertyName := PropertyNameForLink;
     end else
       WritelnWarning('Cannot get property info "%s"', [PropertyName]);
  end;

  { construct UrlSuffix, knowing LinkUnit/Class/MemberName }
  LowerLinkUnitName := LowerCase(LinkUnitName);
  if (LowerLinkUnitName = 'sysutils') or
     (LowerLinkUnitName = 'math') or
     (LowerLinkUnitName = 'system') or
     (LowerLinkUnitName = 'classes') then
  begin
    // adjust for fpdoc links in FPC
    Result := FpcRtlApiReferenceUrl + FpDocSuffix(LinkUnitName, LinkClassName, LinkPropertyName);
  end else
  if (LowerLinkUnitName = 'controls') then
  begin
    // adjust for fpdoc links in LCL
    Result := LclApiReferenceUrl + FpDocSuffix(LinkUnitName, LinkClassName, LinkPropertyName);
  end else
  begin
    // adjust for PasDoc links in CGE
    Result := ApiReferenceUrl + PasDocSuffix(LinkUnitName, LinkClassName, LinkPropertyName);
  end;
end;

function CompareRegisteredComponent(constref Left, Right: TRegisteredComponent): Integer;
begin
  Result := AnsiCompareStr(Left.Caption, Right.Caption);
end;

procedure BuildComponentsMenu(
  const ParentUserInterface, ParentTransform, ParentBehavior, ParentNonVisual: TMenuItem;
  const OnClickEvent: TNotifyEvent);

  function CreateMenuItemForComponent(const OwnerAndParent: TMenuItem;
    const R: TRegisteredComponent): TMenuItem;
  var
    S: String;
  begin
    if OwnerAndParent = nil then
      Exit; // exit if relevant ParentXxx is nil
    Result := TMenuItem.Create(OwnerAndParent);
    S := R.Caption + ' (' + R.ComponentClass.ClassName + ')';
    if R.IsDeprecated then
      S := '(Deprecated) ' + S;
    Result.Caption := S;
    Result.Tag := PtrInt(Pointer(R));
    Result.OnClick := OnClickEvent;
    OwnerAndParent.Add(Result);
  end;

type
  TRegisteredComponentComparer = specialize TComparer<TRegisteredComponent>;
var
  R: TRegisteredComponent;
begin
  { While RegisteredComponents is documented as "read-only",
    we knowingly break it here for internal CGE purposes.
    We need some reliable order of this list (as "RegisterSerializableComponent" may be called in any order),
    for now alphabetic order seems good enough. }
  RegisteredComponents.Sort(TRegisteredComponentComparer.Construct(@CompareRegisteredComponent));

  { add non-deprecated components }
  for R in RegisteredComponents do
    if not R.IsDeprecated then
    begin
      if R.ComponentClass.InheritsFrom(TCastleNavigation) then
      begin
        { do nothing, TCastleNavigation are in viewport "hamburger" menu }
      end else
      if R.ComponentClass.InheritsFrom(TCastleUserInterface) then
        CreateMenuItemForComponent(ParentUserInterface, R)
      else
      if R.ComponentClass.InheritsFrom(TCastleTransform) then
        CreateMenuItemForComponent(ParentTransform, R)
      else
      if R.ComponentClass.InheritsFrom(TCastleBehavior) then
        CreateMenuItemForComponent(ParentBehavior, R)
      else
        CreateMenuItemForComponent(ParentNonVisual, R);
    end;

  (*
  Don't show deprecated for now, keep the menu clean.

  { add separators from deprecated }
  MenuItem := TMenuItem.Create(ParentUserInterface);
  MenuItem.Caption := '-';
  ParentUserInterface.Add(MenuItem);

  MenuItem := TMenuItem.Create(ParentTransform);
  MenuItem.Caption := '-';
  ParentTransform.Add(MenuItem);

  { add deprecated components }
  for R in RegisteredComponents do
    if R.IsDeprecated then
    begin
      ... same code as above
    end;
  *)
end;

end.
