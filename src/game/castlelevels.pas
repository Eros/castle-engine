{
  Copyright 2006-2012 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Scene manager that can easily load game levels (TGameSceneManager),
  management of available game levels (TLevelInfo, @link(Levels)). }
unit CastleLevels;

interface

uses VectorMath, CastleSceneCore, CastleScene, Boxes3D,
  X3DNodes, X3DFields, Cameras, SectorsWaypoints,
  CastleUtils, CastleClassUtils, CastlePlayer, CastleResources,
  ProgressUnit, PrecalculatedAnimation,
  DOM, CastleSoundEngine, Base3D, CastleShape, GL, CastleConfig, Images,
  Classes, CastleTimeUtils, CastleSceneManager, GLRendererShader, FGL;

type
  TLevelLogic = class;
  TLevelLogicClass = class of TLevelLogic;
  TCastleSceneClass = class of TCastleScene;
  TCastlePrecalculatedAnimationClass = class of TCastlePrecalculatedAnimation;
  TGameSceneManager = class;

  TLevelInfo = class
  private
    { We keep XML Document reference through the lifetime of this object,
      to allow the particular level logic (TLevelLogic descendant)
      to read some level-logic-specific variables from it. }
    Document: TXMLDocument;
    DocumentBasePath: string;
    FMusicSound: TSoundType;
    LevelResources: T3DResourceList;
    procedure LoadFromDocument;
  public
    constructor Create;
    destructor Destroy; override;
  public
    { Level logic class. }
    LogicClass: TLevelLogicClass;

    { Unique identifier for this level.
      Should be a suitable identifier in Pascal.
      @noAutoLinkHere }
    Name: string;

    { Main level 3D model. This is used for TCastleSceneManager.MainScene,
      so it determines the default viewpoint, background and such.

      Usually it also contains the most (if not all) of 3D level geometry,
      scripts and such. Although level logic (TLevelLogic descendant determined
      by LevelClass) may also add any number of additional 3D objects
      (T3D instances) to the 3D world. }
    SceneFileName: string;

    { Nice name of the level for user.

      The CastleLevels unit uses this title only for things like log messages.

      How the level title is presented to the user (if it's presented at all)
      is not handled in the CastleLevels unit. The engine doesn't dictate
      how to show the levels to the player. You implement game menus,
      like "New Game" or similar screens, yourself --- to fit the mood
      and user interface of your game. Of course the engine gives you
      2D controls to do this easily, like TCastleOnScreenMenu --- a typical
      on-screen menu as seen in many games.
      See also "The Castle" sources for examples how to use this. }
    Title: string;

    { Additional text that may be displayed near level title.

      The engine doesn't use this property at all, it's only loaded from level.xml
      file. It is available for your "New Game" (or similar screen) implementation
      (see @link(Title) for more comments about this). }
    TitleHint: string;

    { Level number.

      The engine doesn't use this property at all, it's only loaded from level.xml
      file. It is available for your "New Game" (or similar screen) implementation
      (see @link(Title) for more comments about this).

      For example level number may be used to order levels in the menu.
      This @italic(does not) determine the order in which levels are played,
      as levels do not have to be played in a linear order. }
    Number: Integer;

    { Is it a demo level.

      The engine doesn't use this property at all, it's only loaded from level.xml
      file. It is available for your "New Game" (or similar screen) implementation
      (see @link(Title) for more comments about this). }
    Demo: boolean;

    { Was the level played.

      This is automatically managed. Basically, we set it to @true
      when the level is played, and we save it to disk.

      Details:
      @unorderedList(
        @item(It is set to @true when loading level.)

        @item(It is saved to disk (user preferences file) when game exits,
          and loaded when game starts. As long as you call @code(Config.Load),
          @code(Config.Save) from CastleConfig unit. To load, you must
          also call explicitly @link(TLevelInfoList.LoadFromConfig Levels.LoadFromConfig) now.)

        @item(The default value comes from DefaultPlayed property,
          which in turn is loaded from level.xml file, and by default is @false.
          To allows you to artificially mark some levels as "Played" on
          the first game run, which may be helpful if you use this property
          e.g. to filter the levels in "New Game" menu.)
      )

      The engine doesn't look at this property for anything,
      whether the level is Played or not has no influence over how it works.
      It is just available for your game, for example to use in your
      "New Game" (or similar screen) implementation
      (see @link(Title) for more comments about this). }
    Played: boolean;

    { Whether to consider the level @link(Played) by default. }
    DefaultPlayed: boolean;

    { Background image shown when loading level, @nil if none. }
    LoadingImage: TRGBImage;

    { Position of the progress bar when loading level, suitable for
      TProgressUserInterface.BarYPosition.
      Used only if LoadingImage <> @nil (as the only purpose of this property
      is to match LoadingImage look). }
    LoadingImageBarYPosition: Single;

    Element: TDOMElement;

    { Placeholder detection method. See TPlaceholderName, and see
      TGameSceneManager.LoadLevel for a description when we use placeholders. }
    PlaceholderName: TPlaceholderName;

    PlaceholderDefaultDirectionSpecified: boolean;
    PlaceholderDefaultDirection: TVector3Single;

    { Music played when entering the level. }
    property MusicSound: TSoundType read FMusicSound write FMusicSound
      default stNone;
  end;

  TLevelInfoList = class(specialize TFPGObjectList<TLevelInfo>)
  private
    { How many TGameSceneManager have references to our children by
      TGameSceneManager.Info? }
    References: Cardinal;
    procedure LoadLevelXml(const FileName: string);
    { Save Played properties of every level. }
    procedure SaveToConfig(const Config: TCastleConfig);
  public
    { raises Exception if such Name is not on the list. }
    function FindName(const AName: string): TLevelInfo;

    { Add all available levels found by scanning for level.xml inside data directory.
      Overloaded version without parameter just looks inside ProgramDataPath.
      For the specification of level.xml format see
      http://svn.code.sf.net/p/castle-engine/code/trunk/castle_game_engine/doc/README_about_index_xml_files.txt .

      This should be called after resources (creatures and items) are known,
      as they may be referenced by level.xml files.
      So call @link(T3DResourceList.LoadFromFiles Resources.LoadFromFiles)
      @italic(before) calling this (if you
      want to use any creatures / items at all, of course).

      All TLevelInfo.Played values are initially set to @false.
      You must call LoadFromConfig @italic(after) calling this
      to read TLevelInfo.Played values from user preferences file.
      @groupBegin }
    procedure LoadFromFiles(const LevelsPath: string);
    procedure LoadFromFiles;
    { @groupEnd }

    { For all available levels, read their TLevelInfo.Played
      from user preferences.

      This is useful only if you actually look at
      TLevelInfo.Played for any purpose (for example,
      to decide which levels are displayed in the menu). By default,
      our engine doesn't look at TLevelInfo.Played for anything. }
    procedure LoadFromConfig;
  end;

  { Scene manager that can comfortably load and manage a 3D game level.
    It really adds only one new method to TCastleSceneManager:
    @link(LoadLevel), see it's documentation to know what it gives you.
    It also exposes @link(Logic) and @link(Info) properties
    corresponding to the currently loaded level. }
  TGameSceneManager = class(TCastleSceneManager)
  private
    FLogic: TLevelLogic;
    FInfo: TLevelInfo;

    { Like LoadLevel, but doesn't care about AInfo.LoadingImage. }
    procedure LoadLevelCore(const AInfo: TLevelInfo);
    function Placeholder(Shape: TShape; PlaceholderName: string): boolean;
  public
    destructor Destroy; override;

    { Load game level.

      @unorderedList(
        @item(@bold(Set scene manager 3D items):

          Clear all 3D items from @link(TCastleSceneManager.Items)
          list (except @link(TCastleSceneManager.Player)), clear
          @link(TCastleAbstractViewport.Camera Camera)
          and @link(TCastleSceneManager.MainScene) as well.
          Then load a new main scene and camera, adding to
          @link(TCastleSceneManager.Items) all 3D resources (creatures and items)
          defined by placeholders named CasRes* in the main level 3D file.)

        @item(@bold(Make sure 3D resources are ready:)

          Resources are T3DResource instances on @link(Resources) list.
          They are heavy (in terms of memory use and preparation time),
          so you don't want to just load everything for every level.
          This method makes sure that all resources required by this level
          are prepared. All resources requested in level.xml file
          (in <resources> element in level.xml),
          as well as resources requested in player.xml file,
          as well as resources with AlwaysPrepared (usually: all possible items
          that can be dropped from player inventory on any level)
          will be prepared.)

        @item(@bold(Initialize move limits and water volume from placeholders).
          Special object names CasMoveLimit and CasWater (in the future:
          CasWater* with any suffix) in the main scene 3D model
          determine the places where player can go and where water is.

          When CasMoveLimit object is missing,
          we calculate it to include the level bounding box, with some
          additional space above (to allow flying).)

        @item(@bold(Initialize sectors and waypoints from placeholders).
          Special shape names CasSector* and CasWaypoint* can be used
          in level 3D model to help creature AI.
          You can add and name such shapes in 3D modeler, like Blender,
          and they will be automatically understood by the engine when loading level.

          Objects named CasSector<index>[_<ignored>] define sectors.
          The geometry of a sector with given <index> is set to be the sum
          of all CasSector<index>* boxes.
          Sectors are numbered from 0.

          Objects named CasWaypoint[<ignored>] define waypoints.
          Each waypoint is stored as a 3D point, this point is the middle of the
          bounding box of the object named CasWaypoint[<ignored>].

          After extracting from level 3D model,
          sectors and waypoints are then connected together by
          TSectorList.LinkToWaypoints. The idea is that you can go from
          one sector to the other through the waypoint that is placed on
          the border of both of them.)

        @item(@bold(Prepare everything possible for rendering and collision
          detection) to avoid later preparing things on-demand (which would cause
          unpleasant delay during gameplay).
          E.g. prepares octree and OpenGL resources.)
      )

      The overloaded version with a LevelName string searches the @link(Levels)
      list for a level with given name (and raises exception if it cannot
      be found). It makes sense if you filled the @link(Levels) list before,
      usually by @link(TLevelInfoList.LoadFromFiles Levels.LoadFromFiles)
      call. So you can easily define a level in your data with @code(name="xxx")
      in the @code(level.xml) file, and then you can load it
      by @code(LoadLevel('xxx')) call.

      It's important to note that @bold(you do not have to use
      this method to make a 3D game). You may as well just load the 3D scene
      yourself, and add things to TCastleSceneManager.Items and
      TCastleSceneManager.MainScene directly.
      This method is just a very comfortable way to set your 3D world in one call
      --- but it's not the only way.

      @groupBegin }
    procedure LoadLevel(const LevelName: string);
    procedure LoadLevel(const AInfo: TLevelInfo);
    { @groupEnd }

    { Level logic and state. }
    property Logic: TLevelLogic read FLogic;

    { Level information, independent from current level state. }
    property Info: TLevelInfo read FInfo;
  end;

  { Level logic. We use T3D descendant, since this is the comfortable
    way to add any behavior to the 3D world (it doesn't matter that
    "level logic" is not a usual 3D object --- it doesn't have to collide
    or be visible). }
  TLevelLogic = class(T3D)
  private
    FTime: TFloatTime;
    FWorld: T3DWorld;
  protected
    { Load 3D precalculated animation from (*.kanim) file, doing common tasks.
      @unorderedList(
        @item optionally creates triangle octree for the FirstScene and/or LastScene
        @item(call PrepareResources, with prRender, prBoundingBox, prShadowVolume
          (if shadow volumes possible at all in this OpenGL context))
        @item Free texture data, since they will not be needed anymore
        @item TimePlaying is by default @false, so the animation is not playing.
      )
      @groupBegin }
    function LoadLevelAnimation(const FileName: string;
      const CreateFirstOctreeCollisions, CreateLastOctreeCollisions: boolean;
      const AnimationClass: TCastlePrecalculatedAnimationClass): TCastlePrecalculatedAnimation;
    function LoadLevelAnimation(const FileName: string;
      const CreateFirstOctreeCollisions, CreateLastOctreeCollisions: boolean): TCastlePrecalculatedAnimation;
    { @groupEnd }

    { Load 3D scene from file, doing common tasks.
      @unorderedList(
        @item optionally create triangle octree
        @item(call PrepareResources, with prRender, prBoundingBox, prShadowVolume
          (if shadow volumes possible at all in this OpenGL context),)
        @item Free texture data, since they will not be needed anymore
      )
      @groupBegin }
    function LoadLevelScene(const FileName: string;
      const CreateOctreeCollisions: boolean;
      const SceneClass: TCastleSceneClass): TCastleScene;
    function LoadLevelScene(const FileName: string;
      const CreateOctreeCollisions: boolean): TCastleScene;
    { @groupEnd }

    { Handle a placeholder named in external modeler.
      Return @true if this is indeed a recognized placeholder name,
      and it was handled and relevant shape should be removed from level
      geometry (to not be rendered). }
    function Placeholder(const Shape: TShape; const PlaceholderName: string): boolean; virtual;

    { Called after all placeholders have been processed,
      that is after TGameSceneManager.LoadLevel placed initial creatures,
      items and other stuff on the level.
      Override it to do anything you want. }
    procedure PlaceholdersEnd; virtual;
  public
    { Create new level instance. Called before resources (creatures and items)
      are initialized (override PlaceholdersEnd if you need to do something
      after creatures and items are added).
      You can modify MainScene contents here.

      We provide AWorld instance at construction,
      and the created TLevelLogic instance will be added to this AWorld,
      and you cannot change it later. This is necessary, as TLevelLogic descendants
      at construction may actually modify your world, and depend on it later. }
    constructor Create(AOwner: TComponent; AWorld: T3DWorld;
      MainScene: TCastleScene; DOMElement: TDOMElement); reintroduce; virtual;
    function BoundingBox: TBox3D; override;
    function World: T3DWorld; override;

    { Called when new player starts new game on this level.
      This may be used to equip the player with some basic weapon / items.

      This is never called or used by the engine itself.
      This does nothing in the default TLevelLogic class implementation.

      Your particular game, where you can best decide when the player
      "starts a new game" and when the player merely "continues the previous
      game", may call it. And you may override this in your TLevelLogic descendants
      to equip the player. }
    procedure PrepareNewPlayer(NewPlayer: TPlayer); virtual;

    { Time of the level, in seconds. Time 0 when level is created.
      This is updated in our Idle. }
    property Time: TFloatTime read FTime;

    procedure Idle(const CompSpeed: Single; var RemoveMe: TRemoveType); override;
  end;

  TLevelLogicClasses = specialize TFPGMap<string, TLevelLogicClass>;

function LevelLogicClasses: TLevelLogicClasses;

{ All known levels. You can use this to show a list of available levels to user.
  You can also search it and use TGameSceneManager.LoadLevel to load
  a given TLevelInfo instance. }
function Levels: TLevelInfoList;

implementation

uses SysUtils, CastleGLUtils, CastleFilesUtils, CastleStringUtils, 
  GLImages, UIControls, XMLRead, CastleInputs, CastleXMLUtils,
  GLRenderer, RenderingCameraUnit, Math, CastleWarnings;

{ globals -------------------------------------------------------------------- }

var
  FLevelLogicClasses: TLevelLogicClasses;

function LevelLogicClasses: TLevelLogicClasses;
begin
  if FLevelLogicClasses = nil then
  begin
    FLevelLogicClasses := TLevelLogicClasses.Create;
    FLevelLogicClasses['Level'] := TLevelLogic;
  end;
  Result := FLevelLogicClasses;
end;

var
  { Created in initialization of this unit, destroyed in finalization
    (or when the last TGameSceneManager referring to TLevelInfo is destroyed).
    Owns it's Items. }
  FLevels: TLevelInfoList;

function Levels: TLevelInfoList;
begin
  Result := FLevels;
end;

{ TGameSceneManager ---------------------------------------------------------- }

const
  DirectionFromOrientation: array [TOrientationType] of TVector3Single =
  ( (0, 0, -1),
    (0, -1, 0),
    (1, 0, 0) );

function TGameSceneManager.Placeholder(Shape: TShape;
  PlaceholderName: string): boolean;
const
  { Prefix of all placeholders that we seek on 3D models. }
  PlaceholderPrefix = 'Cas';
  ResourcePrefix = PlaceholderPrefix + 'Res';
  MoveLimitName = PlaceholderPrefix + 'MoveLimit';
  WaterName = PlaceholderPrefix + 'Water';
  SectorPrefix = PlaceholderPrefix + 'Sector';
  WaypointPrefix = PlaceholderPrefix + 'Waypoint';

  procedure PlaceholderResource(Shape: TShape; PlaceholderName: string);
  var
    ResourceName: string;
    ResourceNumberPresent: boolean;
    Resource: T3DResource;
    Box: TBox3D;
    Position, Direction: TVector3Single;
    IgnoredBegin, NumberBegin: Integer;
    ResourceNumber: Int64;
  begin
    { PlaceholderName is now <resource_name>[<resource_number>][_<ignored>] }

    { cut off optional [_<ignored>] suffix }
    IgnoredBegin := Pos('_', PlaceholderName);
    if IgnoredBegin <> 0 then
      PlaceholderName := Copy(PlaceholderName, 1, IgnoredBegin - 1);

    { calculate ResourceName, ResourceNumber, ResourceNumberPresent }
    NumberBegin := CharsPos(['0'..'9'], PlaceholderName);
    ResourceNumberPresent := NumberBegin <> 0;
    if ResourceNumberPresent then
    begin
      ResourceName := Copy(PlaceholderName, 1, NumberBegin - 1);
      ResourceNumber := StrToInt(SEnding(PlaceholderName, NumberBegin));
    end else
    begin
      ResourceName := PlaceholderName;
      ResourceNumber := 0;
    end;

    Resource := Resources.FindName(ResourceName);
    if not Resource.Prepared then
      OnWarning(wtMajor, 'Resource', Format('Resource "%s" is initially present on the level, but was not prepared yet --- which probably means you did not add it to <resources> inside level level.xml file. This causes loading on-demand, which is less comfortable for player.',
        [Resource.Name]));

    Box := Shape.BoundingBox;
    Position := Box.Middle;
    Position[Items.GravityCoordinate] := Box.Data[0, Items.GravityCoordinate];

    if Info.PlaceholderDefaultDirectionSpecified then
      Direction := Info.PlaceholderDefaultDirection else
      Direction := DirectionFromOrientation[T3DOrient.DefaultOrientation];
    Direction := MatrixMultDirection(Shape.State.Transform, Direction);

    Resource.InstantiatePlaceholder(Items, Position, Direction,
      ResourceNumberPresent, ResourceNumber);
  end;

  { Shapes placed under the name CasWaypoint[_<ignored>]
    are removed from the Scene, and are added as new waypoint.
    Waypoint's Position is set to the middle point of shape's bounding box. }
  procedure PlaceholderWaypoint(Shape: TShape);
  var
    Waypoint: TWaypoint;
  begin
    Waypoint := TWaypoint.Create;
    Waypoint.Box := Shape.BoundingBox;
    Waypoint.Position := Waypoint.Box.Middle;
    Waypoints.Add(Waypoint);

    { Tests:
    Writeln('Waypoint ', Waypoints.Count - 1, ': at position ',
      VectorToNiceStr(Waypoint.Position));}
  end;

  { Shapes placed under the name CasSector<index>[_<ignored>]
    are removed from the Scene, and are added to sector <index> BoundingBoxes.

    Count of the Sectors list is enlarged, if necessary,
    to include all sectors indicated in the Scene. }
  procedure PlaceholderSector(Shape: TShape; const SectorNodeName: string);
  var
    IgnoredBegin, SectorIndex: Integer;
  begin
    { Calculate SectorIndex }
    IgnoredBegin := Pos('_', SectorNodeName);
    if IgnoredBegin = 0 then
      SectorIndex := StrToInt(SectorNodeName) else
      SectorIndex := StrToInt(Copy(SectorNodeName, 1, IgnoredBegin - 1));

    Sectors.Count := Max(Sectors.Count, SectorIndex + 1);
    if Sectors[SectorIndex] = nil then
      Sectors[SectorIndex] := TSector.Create;

    Sectors[SectorIndex].Boxes.Add(Shape.BoundingBox);

    { Tests:
    Writeln('Sector ', SectorIndex, ': added box ',
      SectorBoundingBox.ToNiceStr); }
  end;

begin
  Result := true;
  if IsPrefix(ResourcePrefix, PlaceholderName) then
    PlaceholderResource(Shape, SEnding(PlaceholderName, Length(ResourcePrefix) + 1)) else
  if PlaceholderName = MoveLimitName then
    MoveLimit := Shape.BoundingBox else
  if PlaceholderName = WaterName then
    Water := Shape.BoundingBox else
  if IsPrefix(SectorPrefix, PlaceholderName) then
    PlaceholderSector(Shape, SEnding(PlaceholderName, Length(SectorPrefix) + 1)) else
  if IsPrefix(WaypointPrefix, PlaceholderName) then
    PlaceholderWaypoint(Shape) else
    Result := Logic.Placeholder(Shape, PlaceholderName);
end;

procedure TGameSceneManager.LoadLevelCore(const AInfo: TLevelInfo);
var
  { Sometimes it's not comfortable
    to remove the items while traversing --- so we will instead
    put them on this list.

    Be careful: never add here two nodes such that one may be parent
    of another, otherwise freeing one could free the other one too
    early. }
  ItemsToRemove: TX3DNodeList;

  procedure TraverseForPlaceholders(Shape: TShape);
  var
    PlaceholderName: string;
  begin
    PlaceholderName := Info.PlaceholderName(Shape);
    if (PlaceholderName <> '') and Placeholder(Shape, PlaceholderName) then
    begin
      { Don't remove OriginalGeometry node now --- will be removed later.
        This avoids problems with removing nodes while traversing. }
      if ItemsToRemove.IndexOf(Shape.OriginalGeometry) = -1 then
        ItemsToRemove.Add(Shape.OriginalGeometry);
    end;
  end;

  procedure RemoveItemsToRemove;
  var
    I: Integer;
  begin
    MainScene.BeforeNodesFree;
    for I := 0 to ItemsToRemove.Count - 1 do
      ItemsToRemove.Items[I].FreeRemovingFromAllParents;
    MainScene.ChangedAll;
  end;

  { After placeholders are processed, finish some stuff. }
  procedure PlaceholdersEnd;
  var
    NewMoveLimit: TBox3D;
  begin
    if MoveLimit.IsEmpty then
    begin
      { Set MoveLimit to MainScene.BoundingBox, and make maximum up larger. }
      NewMoveLimit := MainScene.BoundingBox;
      NewMoveLimit.Data[1, Items.GravityCoordinate] +=
        4 * (NewMoveLimit.Data[1, Items.GravityCoordinate] -
             NewMoveLimit.Data[0, Items.GravityCoordinate]);
      MoveLimit := NewMoveLimit;
    end;

    Sectors.LinkToWaypoints(Waypoints);

    Logic.PlaceholdersEnd;
  end;

  { Assign Camera, knowing MainScene and Player.
    We need to assign Camera early, as initial Camera also is used
    when placing initial resources on the level (to determine their
    initial direciton, World.GravityUp etc.) }
  procedure InitializeCamera;
  var
    InitialPosition: TVector3Single;
    InitialDirection: TVector3Single;
    InitialUp: TVector3Single;
    GravityUp: TVector3Single;
    CameraRadius, PreferredHeight: Single;
    NavigationNode: TNavigationInfoNode;
    WalkCamera: TWalkCamera;
  begin
    MainScene.GetPerspectiveViewpoint(InitialPosition,
      InitialDirection, InitialUp, GravityUp);

    NavigationNode := MainScene.NavigationInfoStack.Top as TNavigationInfoNode;

    if (NavigationNode <> nil) and (NavigationNode.FdAvatarSize.Count >= 1) then
      CameraRadius := NavigationNode.FdAvatarSize.Items[0] else
      CameraRadius := MainScene.BoundingBox.AverageSize(false, 1) * 0.007;

    if (NavigationNode <> nil) and (NavigationNode.FdAvatarSize.Count >= 2) then
      PreferredHeight := NavigationNode.FdAvatarSize.Items[1] else
      PreferredHeight := CameraRadius * 5;
    CorrectPreferredHeight(PreferredHeight, CameraRadius,
      DefaultCrouchHeight, DefaultHeadBobbing);

    if Player <> nil then
      WalkCamera := Player.Camera else
      { If you don't initialize Player (like for castle1 background level
        or castle-view-level or lets_take_a_walk) then just create a camera. }
      WalkCamera := TWalkCamera.Create(Self);

    { initialize some navigation settings of player }
    if Player <> nil then
    begin
      Player.DefaultPreferredHeight := PreferredHeight;
      if NavigationNode <> nil then
        Player.DefaultMoveHorizontalSpeed := NavigationNode.FdSpeed.Value else
        Player.DefaultMoveHorizontalSpeed := 1.0;
      Player.DefaultMoveVerticalSpeed := 20;
    end else
    begin
      { if you use Player with TGameSceneManager, then Player will automatically
        update camera's speed properties. But if not, we have to set them
        here. }
      WalkCamera.PreferredHeight := PreferredHeight;
      if NavigationNode <> nil then
        WalkCamera.MoveHorizontalSpeed := NavigationNode.FdSpeed.Value else
        WalkCamera.MoveHorizontalSpeed := 1.0;
      WalkCamera.MoveVerticalSpeed := 20;
    end;

    Camera := WalkCamera;

    WalkCamera.Init(InitialPosition, InitialDirection,
      InitialUp, GravityUp, PreferredHeight, CameraRadius);
    WalkCamera.CancelFallingDown;
  end;

var
  Options: TPrepareResourcesOptions;
  SI: TShapeTreeIterator;
  PreviousResources: T3DResourceList;
  I: Integer;
begin
  { release stuff from previous level. Our items must be clean.
    This releases previous Level (logic), MainScene,
    and our creatures and items --- the ones added in TraverseForResources,
    but also the ones created dynamically (when creature is added to scene manager,
    e.g. because player/creature shoots a missile, or when player drops an item).
    The only thing that can (and should) remain is Player. }
  I := 0;
  while I < Items.Count do
    if Items[I] <> Player then
      Items[I].Free else
      Inc(I);
  FLogic := nil; { it's freed now }

  { save PreviousResources, before Info is overridden with new level.
    This allows us to keep PreviousResources while new resources are required,
    and this means that resources already loaded for previous level
    don't need to be reloaded for new. }
  PreviousResources := T3DResourceList.Create(false);
  if Info <> nil then
  begin
    PreviousResources.Assign(Info.LevelResources);
    Dec(Levels.References);
    FInfo := nil;
  end;

  FInfo := AInfo;
  Inc(Levels.References);
  Info.Played := true;

  Progress.Init(1, 'Loading level "' + Info.Title + '"');
  try
    { disconnect previous Camera from SceneManager.
      Otherwise, it would be updated by MainScene loading binding new
      NavigationInfo (with it's speed) and Viewpoint.
      We prefer to do it ourselves in InitializeCamera. }
    Camera := nil;

    MainScene := TCastleScene.Create(Self);
    MainScene.Load(Info.SceneFileName);

    { Scene must be the first one on Items, this way Items.MoveCollision will
      use Scene for wall-sliding (see T3DList.MoveCollision implementation). }
    Items.Insert(0, MainScene);

    InitializeCamera;

    Progress.Step;
  finally
    Progress.Fini;
  end;

  { load new resources (and release old unused). This must be done after
    InitializeCamera (because it uses GravityUp), which is turn must
    be after loading MainScene (because initial camera looks at MainScene
    contents).
    It will show it's own progress bar. }
  Info.LevelResources.Prepare(BaseLights, GravityUp);
  PreviousResources.Release;
  FreeAndNil(PreviousResources);

  Progress.Init(1, 'Loading level "' + Info.Title + '"');
  try
    { create new Logic }
    FLogic := Info.LogicClass.Create(Self, Items, MainScene, Info.Element);
    Items.Add(Logic);

    { We will calculate new Sectors and Waypoints and other stuff
      based on placeholders. Initialize them now to be empty. }
    FreeAndNil(FSectors);
    FreeAndNil(Waypoints);
    FSectors := TSectorList.Create(true);
    Waypoints := TWaypointList.Create(true);
    MoveLimit := EmptyBox3D;
    Water := EmptyBox3D;

    ItemsToRemove := TX3DNodeList.Create(false);
    try
      SI := TShapeTreeIterator.Create(MainScene.Shapes, { OnlyActive } true);
      try
        while SI.GetNext do TraverseForPlaceholders(SI.Current);
      finally SysUtils.FreeAndNil(SI) end;
      RemoveItemsToRemove;
    finally ItemsToRemove.Free end;

    PlaceholdersEnd;

    { calculate Options for PrepareResources }
    Options := [prRender, prBackground, prBoundingBox];
    if GLShadowVolumesPossible then
      Options := Options + prShadowVolume;

    MainScene.PrepareResources(Options, false, BaseLights);

    MainScene.FreeResources([frTextureDataInNodes]);

    Progress.Step;
  finally
    Progress.Fini;
  end;

  { Loading octree have their own Progress, so we load them outside our
    progress. }
  MainScene.TriangleOctreeProgressTitle := 'Loading level (triangle octree)';
  MainScene.ShapeOctreeProgressTitle := 'Loading level (Shape octree)';
  MainScene.Spatial := [ssRendering, ssDynamicCollisions];
  MainScene.PrepareResources([prSpatial], false, BaseLights);

  if (Player <> nil) then
    Player.LevelChanged;

  SoundEngine.MusicPlayer.Sound := Info.MusicSound;
  { Notifications.Show('Loaded level "' + Info.Title + '"');}

  MainScene.ProcessEvents := true;
end;

procedure TGameSceneManager.LoadLevel(const AInfo: TLevelInfo);
var
  SavedImage: TRGBImage;
  SavedImageBarYPosition: Single;
begin
  if AInfo.LoadingImage <> nil then
  begin
    SavedImage := Progress.UserInterface.Image;
    SavedImageBarYPosition := Progress.UserInterface.ImageBarYPosition;
    try
      Progress.UserInterface.Image := AInfo.LoadingImage;
      Progress.UserInterface.ImageBarYPosition := AInfo.LoadingImageBarYPosition;
      LoadLevelCore(AInfo);
    finally
      Progress.UserInterface.Image := SavedImage;
      Progress.UserInterface.ImageBarYPosition := SavedImageBarYPosition;
    end;
  end else
    LoadLevelCore(AInfo);
end;

procedure TGameSceneManager.LoadLevel(const LevelName: string);
begin
  LoadLevel(Levels.FindName(LevelName));
end;

destructor TGameSceneManager.Destroy;
begin
  if Info <> nil then
  begin
    if Info.LevelResources <> nil then
      Info.LevelResources.Release;

    Dec(FLevels.References);
    if FLevels.References = 0 then
      FreeAndNil(FLevels);
  end;

  inherited;
end;

{ TLevelLogic ---------------------------------------------------------------- }

constructor TLevelLogic.Create(AOwner: TComponent; AWorld: T3DWorld;
  MainScene: TCastleScene; DOMElement: TDOMElement);
begin
  inherited Create(AOwner);
  FWorld := AWorld;
  { Actually, the fact that our BoundingBox is empty also prevents collisions.
    But for some methods, knowing that Collides = false allows them to exit
    faster. }
  Collides := false;
end;

function TLevelLogic.World: T3DWorld;
begin
  Result := FWorld;

  Assert(Result <> nil,
    'TLevelLogic.World should never be nil, you have to provide World at TLevelLogic constructor');
  Assert( ((inherited World) = nil) or ((inherited World) = Result),
    'World specified at TLevelLogic constructor must be the same world where TLevelLogic instance is added');
end;

function TLevelLogic.BoundingBox: TBox3D;
begin
  { This object is invisible and non-colliding. }
  Result := EmptyBox3D;
end;

procedure TLevelLogic.PrepareNewPlayer(NewPlayer: TPlayer);
begin
  { Nothing to do in this class. }
end;

function TLevelLogic.LoadLevelScene(
  const FileName: string;
  const CreateOctreeCollisions: boolean;
  const SceneClass: TCastleSceneClass): TCastleScene;
var
  Options: TPrepareResourcesOptions;
begin
  Result := SceneClass.Create(Self);
  Result.Load(FileName);

  { calculate Options for PrepareResources }
  Options := [prRender, prBoundingBox { always needed }];
  if GLShadowVolumesPossible then
    Options := Options + prShadowVolume;

  Result.PrepareResources(Options, false, World.BaseLights);

  if CreateOctreeCollisions then
    Result.Spatial := [ssDynamicCollisions];

  Result.FreeResources([frTextureDataInNodes]);

  Result.ProcessEvents := true;
end;

function TLevelLogic.LoadLevelScene(
  const FileName: string;
  const CreateOctreeCollisions: boolean): TCastleScene;
begin
  Result := LoadLevelScene(FileName, CreateOctreeCollisions, TCastleScene);
end;

function TLevelLogic.LoadLevelAnimation(
  const FileName: string;
  const CreateFirstOctreeCollisions, CreateLastOctreeCollisions: boolean;
  const AnimationClass: TCastlePrecalculatedAnimationClass): TCastlePrecalculatedAnimation;
var
  Options: TPrepareResourcesOptions;
begin
  Result := AnimationClass.Create(Self);
  Result.LoadFromFile(FileName, false, true, 1);

  { calculate Options for PrepareResources }
  Options := [prRender, prBoundingBox { always needed }];
  if GLShadowVolumesPossible then
    Options := Options + prShadowVolume;

  Result.PrepareResources(Options, false, World.BaseLights);

  if CreateFirstOctreeCollisions then
    Result.FirstScene.Spatial := [ssDynamicCollisions];

  if CreateLastOctreeCollisions then
    Result.LastScene.Spatial := [ssDynamicCollisions];

  Result.FreeResources([frTextureDataInNodes]);

  Result.TimePlaying := false;
end;

function TLevelLogic.LoadLevelAnimation(
  const FileName: string;
  const CreateFirstOctreeCollisions, CreateLastOctreeCollisions: boolean): TCastlePrecalculatedAnimation;
begin
  Result := LoadLevelAnimation(FileName,
    CreateFirstOctreeCollisions, CreateLastOctreeCollisions,
    TCastlePrecalculatedAnimation);
end;

procedure TLevelLogic.Idle(const CompSpeed: Single; var RemoveMe: TRemoveType);
begin
  inherited;
  FTime += CompSpeed;
end;

function TLevelLogic.Placeholder(const Shape: TShape;
  const PlaceholderName: string): boolean;
begin
  Result := false;
end;

procedure TLevelLogic.PlaceholdersEnd;
begin
  { Nothing to do in this class. }
end;

{ TLevelInfo ------------------------------------------------------------ }

constructor TLevelInfo.Create;
begin
  inherited;
  LevelResources := T3DResourceList.Create(false);
end;

destructor TLevelInfo.Destroy;
begin
  FreeAndNil(Document);
  FreeAndNil(LevelResources);
  FreeAndNil(LoadingImage);
  inherited;
end;

procedure TLevelInfo.LoadFromDocument;

  procedure MissingRequiredAttribute(const AttrName: string);
  begin
    raise Exception.CreateFmt(
      'Missing required attribute "%s" of <level> element', [AttrName]);
  end;

  { Like DOMGetAttribute, but reads TLevelLogicClass value. }
  function DOMGetLevelLogicClassAttribute(const Element: TDOMElement;
    const AttrName: string; var Value: TLevelLogicClass): boolean;
  var
    ValueStr: string;
    LevelClassIndex: Integer;
  begin
    Result := DOMGetAttribute(Element, AttrName, ValueStr);
    LevelClassIndex := LevelLogicClasses.IndexOf(ValueStr);
    if LevelClassIndex <> -1 then
      Value := LevelLogicClasses.Data[LevelClassIndex] else
      raise Exception.CreateFmt('Unknown level type "%s"', [ValueStr]);
  end;

  { Add all resources with AlwaysPrepared = true to the LevelResources. }
  procedure AddAlwaysPreparedResources;
  var
    I: Integer;
  begin
    for I := 0 to Resources.Count - 1 do
      if Resources[I].AlwaysPrepared and
         (LevelResources.IndexOf(Resources[I]) = -1) then
      LevelResources.Add(Resources[I]);
  end;

var
  LoadingImageFileName: string;
  SoundName: string;
  PlaceholdersKey: string;
  PlaceholderDefaultDirectionString: string;
begin
  Element := Document.DocumentElement;

  if Element.TagName <> 'level' then
    raise Exception.CreateFmt('Root node of level.xml file must be <level>, but is "%s", in "%s"',
      [Element.TagName, DocumentBasePath]);

  { Required atttributes }

  if not DOMGetAttribute(Element, 'name', Name) then
    MissingRequiredAttribute('name');

  if not DOMGetAttribute(Element, 'scene', SceneFileName) then
    MissingRequiredAttribute('scene');
  SceneFileName := CombinePaths(DocumentBasePath, SceneFileName);

  if not DOMGetAttribute(Element, 'title', Title) then
    MissingRequiredAttribute('title');

  { Optional attributes }

  if not DOMGetIntegerAttribute(Element, 'number', Number) then
    Number := 0;

  if not DOMGetBooleanAttribute(Element, 'demo', Demo) then
    Demo := false;

  if not DOMGetAttribute(Element, 'title_hint', TitleHint) then
    TitleHint := '';

  if not DOMGetBooleanAttribute(Element, 'default_played',
    DefaultPlayed) then
    DefaultPlayed := false;

  if not DOMGetLevelLogicClassAttribute(Element, 'type', LogicClass) then
    LogicClass := TLevelLogic;

  PlaceholderName := PlaceholderNames['x3dshape'];
  if DOMGetAttribute(Element, 'placeholders', PlaceholdersKey) then
    PlaceholderName := PlaceholderNames[PlaceholdersKey];

  FreeAndNil(LoadingImage); { make sure LoadingImage is clear first }
  if DOMGetAttribute(Element, 'loading_image', LoadingImageFileName) then
  begin
    LoadingImageFileName := CombinePaths(DocumentBasePath, LoadingImageFileName);
    LoadingImage := LoadImage(LoadingImageFileName, [TRGBImage], []) as TRGBImage;
  end;

  if not DOMGetSingleAttribute(Element, 'loading_image_bar_y_position',
    LoadingImageBarYPosition) then
    LoadingImageBarYPosition := DefaultImageBarYPosition;

  PlaceholderDefaultDirectionSpecified := DOMGetAttribute(Element,
    'placeholder_default_direction', PlaceholderDefaultDirectionString);
  if PlaceholderDefaultDirectionSpecified then
    PlaceholderDefaultDirection := Vector3SingleFromStr(PlaceholderDefaultDirectionString);

  LevelResources.LoadResources(Element);
  AddAlwaysPreparedResources;

  if DOMGetAttribute(Element, 'music_sound', SoundName) then
    MusicSound := SoundEngine.SoundFromName(SoundName) else
    MusicSound := stNone;
end;

{ TLevelInfoList ------------------------------------------------------- }

function TLevelInfoList.FindName(const AName: string): TLevelInfo;
var
  I: Integer;
  S: string;
begin
  for I := 0 to Count - 1 do
    if Items[I].Name = AName then
      Exit(Items[I]);

  S := Format('Level name "%s" is not found on the Levels list', [AName]);
  if Count = 0 then
    S += '.' + NL + NL + 'Warning: there are no levels available on the list at all. This means that the game data was not correctly installed (as we did not find any level.xml files defining any levels). Or the developer forgot to call Levels.LoadFromFiles.';
  raise Exception.Create(S);
end;

function IsSmallerByNumber(const A, B: TLevelInfo): Integer;
begin
  Result := A.Number - B.Number;
end;

procedure TLevelInfoList.LoadFromConfig;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Items[I].Played := Config.GetValue(
      'levels_available/' + Items[I].Name + '/played',
      Items[I].DefaultPlayed);
end;

procedure TLevelInfoList.SaveToConfig(const Config: TCastleConfig);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Config.SetDeleteValue(
      'levels_available/' + Items[I].Name + '/played',
      Items[I].Played,
      Items[I].DefaultPlayed);
end;

procedure TLevelInfoList.LoadLevelXml(const FileName: string);
var
  NewLevelInfo: TLevelInfo;
begin
  NewLevelInfo := TLevelInfo.Create;
  Add(NewLevelInfo);
  NewLevelInfo.Played := false;

  ReadXMLFile(NewLevelInfo.Document, FileName);
  NewLevelInfo.DocumentBasePath := ExtractFilePath(FileName);
  NewLevelInfo.LoadFromDocument;
end;

procedure TLevelInfoList.LoadFromFiles(const LevelsPath: string);
begin
  ScanForFiles(LevelsPath, 'level.xml', @LoadLevelXml);
end;

procedure TLevelInfoList.LoadFromFiles;
begin
  LoadFromFiles(ProgramDataPath);
  Sort(@IsSmallerByNumber);
end;

{ initialization / finalization ---------------------------------------------- }

initialization
  FLevels := TLevelInfoList.Create(true);
  Inc(FLevels.References);

  Config.OnSave.Add(@FLevels.SaveToConfig);
finalization
  FreeAndNil(FLevelLogicClasses);

  if (FLevels <> nil) and (Config <> nil) then
    Config.OnSave.Remove(@FLevels.SaveToConfig);

  { there may still exist TGameSceneManager instances that refer to our
    TLevelInfo instances. So we don't always free Levels below. }
  if FLevels <> nil then
  begin
    Dec(FLevels.References);
    if FLevels.References = 0 then
      FreeAndNil(FLevels);
  end;
end.