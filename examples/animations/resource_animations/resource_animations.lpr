{
  Copyright 2009-2020 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Play the animations of resources (creatures/items). }
uses SysUtils, Generics.Collections,
  CastleFilesUtils, CastleWindow, CastleResources, CastleScene,
  CastleProgress, CastleWindowProgress, CastleControls, CastleUIControls,
  CastleUtils, CastleTransform, CastleCreatures, CastleLog,
  CastleURIUtils, CastleViewport, CastleLevels, CastleVectors;

var
  Window: TCastleWindowBase;
  Viewport: TCastleViewport;
  BaseScene: TCastleScene;
  Level: TLevel;
  LastCreature: TCreature;
  LastResource: TCreatureResource;
  ResourceButtonsGroup: TCastleVerticalGroup;

procedure UpdateResourceButtons; forward;

type
  TResourceButton = class(TCastleButton)
  public
    ButtonResource: TCreatureResource;
    procedure DoClick; override;
  end;

  TLoadResourceButton = class(TCastleButton)
  public
    { remember this only to make repeated usage of FileDialog more comfortable }
    LastChosenURL: string;
    procedure DoClick; override;
  end;

  TResourceButtonList = specialize TObjectList<TResourceButton>;

var
  ResourceButtons: TResourceButtonList;
  LoadResourceButton: TLoadResourceButton;

procedure TResourceButton.DoClick;
var
  I: Integer;
begin
  FreeAndNil(LastCreature); // remove previous creature

  { CreateCreature creates TCreature instance and adds it to Viewport.Items }
  LastResource := ButtonResource;
  LastCreature := LastResource.CreateCreature(Level,
    { Translation } Vector3(0, 0, 0),
    { Direction } Vector3(0, 0, 1));

  { update Pressed of buttons }
  for I := 0 to ResourceButtons.Count - 1 do
    ResourceButtons[I].Pressed := ResourceButtons[I].ButtonResource = LastResource;
end;

procedure TLoadResourceButton.DoClick;
begin
  if Window.FileDialog('Resource file to load', LastChosenURL, true,
    'All Files|*|*Resource files (resource.xml)|resource.xml|') then
  begin
    Resources.AddFromFile(LastChosenURL);
    { directly prepare new resource }
    Resources.Prepare(Viewport.PrepareParams, 'resources');

    UpdateResourceButtons;
    ResourceButtons.Last.DoClick; // newly added resource is the last, activate it
  end;
end;

{ Create buttons in ResourceButtons and ResourceButtonsGroup to reflect current Resources. }
procedure UpdateResourceButtons;
var
  ResButton: TResourceButton;
  I: Integer;
begin
  { easily destroy all existing buttons using the XxxButtons list,
    destroying them also automatically removed them from Window.Controls list }
  ResourceButtons.Clear;

  for I := 0 to Resources.Count - 1 do
  begin
    ResButton := TResourceButton.Create(nil);
    ResButton.ButtonResource := Resources[I] as TCreatureResource;
    ResButton.Caption := 'Spawn creature ' + ResButton.ButtonResource.Name;
    ResButton.Toggle := true;
    ResourceButtons.Add(ResButton);
    ResourceButtonsGroup.InsertFront(ResButton);
  end;
  if Resources.Count = 0 then
    raise Exception.CreateFmt('No resources found. Make sure we search in proper path (current data path is detected as "%s")',
      [ResolveCastleDataURL('castle-data:/')]);
end;

{ TestAddingResourceByCode --------------------------------------------------- }

{ An example of creating a resource (TStillCreatureResource in this case)
  without resource.xml file. You just create an instance of TXxxResource by hand,
  fill the properties you need, and add it to global Resources list. }
procedure TestAddingResourceByCode;
var
  Res: TStillCreatureResource;
begin
  Res := TStillCreatureResource.Create('KnightCreatedFromCodeTest');
  Res.ModelURL := 'castle-data:/knight_single_gltf/knight.gltf';
  Res.Animations.FindName('idle').AnimationName := 'Idle';
  Resources.Add(Res);
end;

{ Main program --------------------------------------------------------------- }

begin
  InitializeLog;

  Window := TCastleWindowBase.Create(Application);
  Application.MainWindow := Window;
  Progress.UserInterface := WindowProgressInterface;
  Window.Open;

  Viewport := TCastleViewport.Create(Application);
  Viewport.FullSize := true;
  Viewport.AutoCamera := true;
  Viewport.AutoNavigation := true;
  Window.Controls.InsertFront(Viewport);

  Resources.LoadFromFiles;

  TestAddingResourceByCode;

  { load basic 3D scene where creature is shown. This isn't necessary,
    but it's an easy way to add a camera with headlight,
    and some grid to help with orientation. }
  BaseScene := TCastleScene.Create(Application);
  BaseScene.Load('castle-data:/base.x3d');
  { turn on headlight, as base.x3d exported from Blender has always headlight=false }
  BaseScene.NavigationInfoStack.Top.FdHeadlight.Send(true);
  Viewport.Items.MainScene := BaseScene;
  Viewport.Items.Add(BaseScene);

  { Prepare (load animations) for all resources.
    In a normal game, you would not call this directly, instead you would
    depend on TLevel.Load doing this for you. }
  Resources.Prepare(Viewport.PrepareParams, 'resources');

  { Level refers to a Viewport.
    We need to create Level, as creature can be spawned only within a Level,
    using LastResource.CreateCreature(Level, ...),
    placing it inside "Viewport.Items". }
  Level := TLevel.Create(Application);
  Level.Viewport := Viewport;

  ResourceButtonsGroup := TCastleVerticalGroup.Create(Application);
  ResourceButtonsGroup.Anchor(hpLeft, 10);
  ResourceButtonsGroup.Anchor(vpTop, -10);
  ResourceButtonsGroup.Spacing := 10;
  Window.Controls.InsertFront(ResourceButtonsGroup);

  LoadResourceButton := TLoadResourceButton.Create(Application);
  LoadResourceButton.Caption := 'Add resource...';
  ResourceButtonsGroup.InsertFront(LoadResourceButton);

  ResourceButtons := TResourceButtonList.Create(true);
  UpdateResourceButtons;
  ResourceButtons.First.DoClick;

  Application.Run;

  FreeAndNil(ResourceButtons);
end.
