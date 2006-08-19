{
  Copyright 2002-2006 Michalis Kamburelis.

  This file is part of "Kambi's 3dmodels Pascal units".

  "Kambi's 3dmodels Pascal units" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "Kambi's 3dmodels Pascal units" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "Kambi's 3dmodels Pascal units"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

(*
  @abstract(This unit defines VRML nodes. This is the most important
  unit for VRML processing, as nodes are the key idea in VRML.)

  In fact, the whole VRML file is just a VRML node, so "processing
  VRML nodes" means also "processing VRML files".
  And this unit allows you to read nodes from the stream
  (with the help of lexer in VRMLLexer unit and parser of VRML fields
  in VRMLFields unit). We also have here methods to save nodes back
  to stream.

  I przede wszystkim metody do przeszukiwania grafu VRML'a na rozne sposoby -
  patrz metody Traverse, EnumerateNodes i FindNode. Szczegolnie metoda Traverse
  jest wazna : pozwala ona zamienic graf VRMl'a na liste par
  (Node typu TGeneralShapeNode + State : TVRMLGraphTraverseState).
  Renderowanie takiej listy sprowadza sie teraz do wyrenderowania
  kazdej takiej pary, czyli kazdego shape'u z odpowiednimi ustawieniami
  State. To jest cala robota jaka musi wykonac renderer taki jak np.
  OpenGLRenderer w VRMLOpenGLRenderer (alternatywnie, renderer moze uzywac
  tez Triangulate).

  Oraz kazdy node ma zdefiniowane swoje pola i wiele node'ow
  maja zaimplementowane pewne ogolne metody do operowania
  na nich (ladowanie zawartosci w node'ach WWWInline i Texture2,
  funkcja MatrixTransformation w podklasach GeneralTransformation itp.)
  Node'y z grupy GeneralShape maja kilka istotnych metod jak
  [Local]BoudingBox, Vertices/TrianglesCount, Triangulate.

  Ten modul naturalnie nie zalezy od OpenGL'a. Tak miedzy nami to kiedys
  zalezal od OpenGL'a i w ogole bylo tu zaimplementowane mnostwo
  innych rzeczy, m.in. jadro renderera OpenGL'owego i bylo tu naprawde tloczno.
  Ale teraz juz jest czysto. I jestesmy kompletnie niezalezni od renderera,
  co jest wazne bo renderer przez OpenGL'a nie jest juz jedynym mozliwym
  rendererem - mamy juz VRMLRayTracer.

  As for VRML versions handling:
  @unorderedList(
    @item(
      We handle both VRML 1.0 and 2.0.
      Every correct VRML file should be parsed by this unit
      (TODO: although for VRML 2.0 some constructs like "PROTO" are not
      done yet, see TODO.vrml97).)

    @item(
      Also many Inventor 1.0 files should be correctly parsed.
      We handle Inventor 1.0 mostly like VRML 1.0, also some small
      things and nodes specific for Inventor 1.0 are implemented here, see
      [http://www.camelot.homedns.org/~michalis/kambi_vrml_extensions.php#ext_iv_in_vrml].

      TNodeUnknown pozwala omijac parserowi nawet kompletnie
      nieznane node'y pozbawione pol "fields" i "isA" (z VRML'a 1.0
      extensibility features). Dlatego jestesmy w stanie odczytac i
      wyswietlic satysfakcjonujaca czesc wiekszosci plikow Inventora
      jakie mialem w /usr/share/inventor/demos/. Super !)

    @item(
      Nawet dla VRMLa 1.0 w wielu miejscach uzywam specyfikacji VRMLa 97:
      @unorderedList(
        @item(zeby ustalic rzeczy zdefiniowane w niejasny sposob w specyfikacji
          VRML 1.0)
        @item(zeby pododawac do VRMLa 1.0 male drobiazgi z VRMLa 97, jak
          attenuation swiatel)
        @item(VRMLRayTracer uzywa modelu oswietlenia zdefiniowanego
          w specyfikacji VRMLa 97)
      ))

    @item(
      Note that structures in this unit are @italic(not) focused
      on either VRML 1.0 or VRML 2.0. On the contrary: we try to handle
      the @italic(sum of VRML 1.0 and 2.0). When reading VRML 1.0,
      many VRML 2.0 constructs (that not conflict with anything in VRML 1.0)
      are allowed, and the other way around too.

      Internally, we do not convert VRML 1.0-specific constructs
      to VRML 2.0 constructs (or the other way around).
      For example, we do not convert VRML 1.0 idea of direct children nodes
      to VRML 2.0 idea of children nodes embedded in MFNode fields.
      We just allow both constructs. In fact, you could define here
      a node that uses both VRML 1.0 children nodes and has some
      MFNode fields --- in other words, a node invalid in terms of VRML 1.0 spec
      and invalid in terms of VRML 2.0 spec, but valid if you take
      "sum of features" of both VRML versions.

      Sometimes this means more work for us, as some similar ideas
      have to be implemented in two different ways, and then some
      common access methods (like SmartChild* methods of TVRMLNode)
      must be done. But the advantage is that we have a clean
      implementation, that is suited and perfectly conforming
      to both VRML 1.0 and 2.0.)
  )

  Notka do mechanizmu DEF/USE : gdy uzywamy DEF nie mozemy odwolac
  sie do nazwy node'a ktory aktualnie parsujemy (osiagamy to
  po prostu dodajac nazwe node do NodeNameBinding dopiero PO
  sparsowaniu node'a). W ten sposob zapewniamy sobie ze graf VRML'a
  nie moze zawierac cykli i jestesmy szczesliwi.

  Notka do mechanizmu wczytywania grafu VRMLa : jak widac nie robimy
  dekonstrukcji w czasie odczytywania sceny - co znaczy tyle ze
  po odczytaniu calego strumienia jestesmy w stanie zapisac z
  powrotem do innego strumienia cala scene VRMLa, nie tracac zadnej
  informacji. O ile oczywiscie na renderowanie i w ogole wiekszosc operacji
  mozna patrzec jako na jakis rodzaj dekonstrukcji to my zawsze zostajemy
  w posiadaniu calej informacji o scenie.
  Sa dwa wyjatki :
  @orderedList(
    @item(
      Inline nodes (WWWInline, Inline, InlineLoadControl) ktore
      w BeforeTraverse laduje swoja scene jako swoje dziecko)
    @item(
      node'y moga (w niezdefiniowanym momencie) poprawiac wartosci
      swoich pol jesli te sa w oczywisty sposob nieprawidlowe i
      bezsensowne. Staram sie przy tym uznawac mozliwie duzo wartosci
      za sensowne (np. specyfikacja VRMLa nie dopuszcza Cylindra ktory
      nie ma zadnej czesci wlaczonej, ale ja to dopuszczam) wiec jezeli program
      i scena sa dobrze napisane to taka sytuacja nie powinna nigdy zajsc.)

    @item(
      w przypadku scen o wielu root node'ach (ktore sa de facto niepoprawne
      trzymajac sie sciscle specyfikacji VRMLa 1.0, chociaz sa poprawne w
      VRMLu 97 i ja je dopuszczam takze w VRMLu 1.0, patrz nizej) jezeli
      root node'ow w pliku byloby wiele to jako root node tworzymy sobie
      node Group i w nim umieszczamy wszystkie root nodes.

      (Jest to zaimplementowane w ParseVRMLFile. Jest to chyba najbardziej
      sensowny sposob w jaki mozna to zrobic - w programie bedziemy chcieli
      przeciez reprezentowac model VRMLa jako jeden obiekt; wiec nalezaloby
      uzyc TVRMLNodesList, ale wtedy musielibysmy powtorzyc implementacje
      wielu rzeczy w TVRMLNode takze dla takiej listy; wiec tutaj pomysl:
      przeciez klasa TNodeGroup jest wlasnie taka prosta lista node'ow.)

      We represent this special "additional" Group node as a TNodeGroupHidden,
      @italic(that is a descendant of TNodeGroup (not the other way around)).
      This way you can entirely forget about this issue and just process
      the VRML model as you like, and the only downside will be that you
      will actually work with a different model (with additional Group node)
      than what was encoded in the file. You can also test for
      (Node is TNodeGroupHidden) and recognize this special case.
      SaveToVRMLFile does this, and avoids writing this hidden Group node.)
  )

  Takie unikanie dekonstrukcji pozwoli nam
  @orderedList(
    @item(
      na unikniecie zbytniego przywiazania naszego kodu VRMLa do konkretnych
      zastosowan. Poniewaz mamy cala informacje o scenie mozemy zrobic
      wszystko co mozemy zrobic ze scena VRMLa - co nie byloby mozliwe gdybysmy
      w czasie dekonstrukcji (np. wykonujac juz w czasie odczytu wszystkie
      transformacje na macierzy i transformujac punkty) tracili jakas czesc
      informacji.)

    @item(
      no i mozemy w ten sposob latwo wykorzystac nasz kod VRMLa do pisania
      konwerterow innych formatow na VRMLa. Uzywajac modulu Object3dAsVRML
      i tutejszego SaveToVRMLFile mamy sliczny konwerter 3ds, obj, geo -> VRML.)
  )

  Specyfikacja VRMLa 1.0 z dodanymi "moimi rozszerzeniami VMRLa"
  [http://www.camelot.homedns.org/~michalis/kambi-vrml.php] stanowia
  uzasadnienie dla wielu rzeczy ktore robimy w tym module.

  Node'y o nazwach *General* to nie sa koncowe klasy node'ow,
  to tylko klasy posrednie jak GeneralShape, GeneralLight,
  GeneralCamera, GeneralTraformation itp. Te klasy pozwalaja
  nam zaimplementowac jakas funkcjonalnosc dla kilku podobnych
  klas jednoczesnie, te klasy buduja tez ladne drzewko
  zaleznosci obiektow dzieki czemu np. w EnumerateNodes mozemy
  jako parametr podac TNodeGeneralLight aby znalezc wszystkie
  swiatla na scenie.

  24 sierpnia 2003: znaczne osiagniecie : wyeliminowalem typ TVRMLNodeKind
    ktory wyliczal mi wszystkie istniajace klasy node'ow. Dzieki temu
    typowi moglem latwo robic powiazania w stylu "dana nazwa wezla VRMLa
    odpowiada jakiej podklasie TVRMLNode ?" : taki typ (razem z kilkoma
    stalymi) przechowywal mi informacje o wszystkich istniejacych
    koncowych podklasach TVRMLNode. Wada tego jednak byl fakt ze wszystkie
    wezly VRMLa musialy byc zdefiniowane w tym jednym module. Nie mozna
    bylo np. w malfunction zaimplementowac specjalnych node'ow w stylu
    "MalfunctionLevel { fog TRUE }" do uzytku tylko przez malfunction.
    To znaczy nie bylo praktycznie sensu definiowac potomkow typu
    TVRMLNode w innych modulach niz VRMLNodes bo nawet jesli mogles zdefiniowac
    podklasy TVRMLNode w innych modulach to i tak nie mogles ich uzyc
    (bo zeby one byly widziane przez mechanizm odwzorowywania
    "nazwa VRMLa -> podklasa TVRMLNode" musialy byc dodane do odpowiednich
    stalych w TYM module...). Usunalem ta niedogodnosc eliminujac zupelnie
    typ TVRMLNodeKind. Teraz nie ma zadnej stalej tablicy przechowujacej
    jakies informacje na temat "wszystkich dostepnych node'ow" - ekwiwalentem
    tego jest obiekt NodesManager w ktorym mozna w czasie wykonania programu
    rejestrowac dowolne stworzone podklasy TVRMLNode (prawdopodobnie najsensowniej
    jest robic to w sekcji initialization modulu; uzywaj tego podobnie jak
    Picture.RegisterPictureClass z Graphics z VCLa Borlanda.).
  Ciagle pozostaje niestety ograniczenie ze wszystkie wezly ktore maja byc
    uwzgledniane w tablicy TVRMLGraphTraverseState.LastNodes musza byc
    zadeklarowane w tym module. To powoduje ze ciagle nie mozemy przerzucic
    implementacji wszystkich specyficznych node'ow do jakiegos osobnego modulu.
    Ktoregos dnia, gdy ograniczenie to zacznie mi przeszkadzac, zapewne
    to zaimplementuje (tablica TraverseStateLastNodesClasses bedzie musiala
    byc wtedy zrobiona jako dynamiczna lista klas TVRMLNodeClass; problemem
    jest tutaj ze TTraverseStateLastNodes bedzie wtedy takze musialo
    byc struktura dynamiczna i proste zapytania LastNodes.Coordinate3 bedzie
    musialo byc zastapione na cos mniej wygodnego i badziej czasochlonnego
    podczas wykonywania : LastNodes.NodesFind[TNodeCoordinate3].)
  Aby wykazac ze to rzeczywiscie dziala (i to dziala calkiem fajnie) zapisalem
    w malfunction w LevelUnit cztery node'y specyficzne dla malfunction :
    MalfunctionLevelInfo, Malfunction(NotMoving|CircleMoving|Hunting)Enemy.
    Teraz definicje leveli malfunction nie potrzebuja ZADNYCH specjalnie
    parsowanych wezlow Info. Zalety: parser+lekser VRMLa od razu robia
    mi mnostwo checkow i podaja moim node'ow gotowy wynik. Kod parsowania
    zawartosci wezlow Info byl bardzo prosty, mimo to teraz nie musimy
    go juz w ogole pisac - wszystko zrzucamy na leksera+parsera VRMLa.
    Ponadto nasze node'y dzialaja od razu w ramach wezlow VRMLa, a wiec
    np. nie trzeba sobie wszedzie pisac co sie stanie jesli nie podasz tego
    pola. W VRMLu jesli nie podasz pola to zostanie uzyta jego wartosc domyslna,
    wystarczy powiedziec ile ona wynosi. Trzeba przyznac ze do tak prostych
    zadan jak levele malfunction definiowanie wlasnych wezlow VRMLa zapewnia
    duza elegancje w kodzie ale nie daje az tak wiele realnych zyskow.

  Examples of defining your own VRML node types (without modifying
  sources of this unit, or any other unit) are in these programs:
  - bezier_curves (VRMLBezierCurve)
  - malfunction (LevelUnit)

  Co do zapisywania VRMLa :
  - kazde pole zapisuje 1 lub wiecej calych linii
  - kazdy node zapisuje najpierw linie [DEF NodeName] NodeKindName {
    potem swoje pola
    potem swoje subnode'y
    potem linie }
    zmieniajac Indent o IndentIncrement zdefiniowane w VRMLFields
  - linie sa konczone przez nl
  - mechanizm DEF/USE pol jest zapisywany dobrze, tzn. jezeli
    jakies pole jest obecne wiecej niz raz w drzewie VRML'a to jest
    zapisywane do pliku tylko raz, kazdy nastepny zapis to tylko
    zapisanie 'USE <NodeName>'
  - w wiekszosci przypadkow pola o wartosciach domyslnych nie sa zapisywane.
    W zasadzie zapisywanie pol o wartosciach domyslnych nie byloby bledem,
    choc mogloby denerwowac userow. Ale my naprawde tego potrzebujemy ze
    wzgledu na male rozszerzenia VRMLa 1.0 jakie tu zaimplementowalem
    (patrz wyzej). Jesli chcemy zapisywac poprawne pliki VRMLa to nie mozemy
    dopuszczac zeby np. eksport pliku 3DS na VRMLa dodawal jakies pole
    "mirror" do kazdego Materialu. Wiec nie bedziemy zapisywac "mirror" kiedy
    "mirror" = [0.0] i w ten sposob rozwiazujemy problem. Jednoczesnie,
    jesli ktos rzeczywiscie stworzyl plik podajac wlasciwosc "mirror"
    rozna od domyslnej to uwzglednimy wszedzie to pole i zapiszemy je w
    razie potrzeby z powrotem do pliku VRMLa.
*)

unit VRMLNodes;

{
  Known problems:
  - MFString field with strings not enclosed in double quotes will
    not be parsed corectly. Moreover, parsing SFStrings not enclosed
    in double quotes is implemented rather as a "quick & dirty hack"
    than as a nice solution. Really, it's a weird "feature" of
    VRML 1.0 (eliminated in VRML 97) to allow strings not enclosed
    in double quotes.
    And I know about only ONE program that utilizes it (Blender)
    and this program uses it only in SFString field (Texture2.filename).
    So I doubt I will ever fix this -- I would consider it a waste of time,
    since not enclosing strings in double quotes is something totally
    useless.
}

{ This makes interfaces unparented by default.
  Without this I would have to care about overriding AddRef
  and similar useless crap for objects that want to implement
  INodeGeneralInline interface. Or derive TVRMLNode from
  TInterfacedObject (which is not really bad, but what's the
  reason ? I don't need whole AddRef/etc. stuff). }
{$interfaces corba}

interface

uses VectorMath, Classes, SysUtils, VRMLLexer, KambiUtils, KambiClassUtils,
  VRMLFields, Boxes3d, Images, TTFontsTypes, BackgroundBase, VRMLErrors;

{$define read_interface}

const
  { }
  CountTraverseStateLastNodes = 10;
  HighTraverseStateLastNodes = CountTraverseStateLastNodes - 1;

{ -----------------------------------------------------------------------------
  dluuuga deklaracja "type" w ktorej wiele rzeczy jest zdefiniowanych
  wzajemnie (rekurencyjnie). }

type
  {forward declarations}
  TVRMLNodesList = class;
  TNodeGeneralLightsList = class;
  TVRMLNode = class;
  TNodeCoordinate3 = class;
  TNodeShapeHints = class;
  TNodeFontStyle_1 = class;
  TNodeMaterial_1 = class;
  TNodeMaterialBinding = class;
  TNodeNormal = class;
  TNodeNormalBinding = class;
  TNodeTexture2 = class;
  TNodeTextureCoordinate2 = class;
  TNodeGeneralShape = class;
  TNodeGeneralLight = class;
  TNodeKambiTriangulation = class;
  TNodeShape = class;
  TNodeGeneralTexture = class;

  TVRMLNodeClass = class of TVRMLNode;

  TVRMLNodeProc = procedure (node: TVRMLNode) of object;

  { Stala TraverseStateLastNodesClasses okresla jakie node'y beda zapamietywane
    w TVRMLGraphTraverseState w LastNodes. TTraverseStateLastNodes to wlasnie
    typ dla LastNodes, ktory dzieki wariantom pozwala zarowno iterowac
    po swojej zawartosci (przez Nodes[]) jak i odwolywac sie do tej zawartosci
    przez odpowiednie nazwy ktore juz maja odpowiednie typy
    (np. zamiast "Rekord.TNodeCoordinate3(Nodes[0])" wystarczy
    "Rekord.Coordinate3")  }
  TTraverseStateLastNodes = record
    case Integer of
      0: ( Nodes: array[0..HighTraverseStateLastNodes]of TVRMLNode; );
      1: ( Coordinate3 :TNodeCoordinate3;
           ShapeHints :TNodeShapeHints;
           FontStyle :TNodeFontStyle_1;
           Material :TNodeMaterial_1;
           MaterialBinding :TNodeMaterialBinding;
           Normal :TNodeNormal;
           NormalBinding :TNodeNormalBinding;
           Texture2 :TNodeTexture2;
           TextureCoordinate2 :TNodeTextureCoordinate2;
           KambiTriangulation: TNodeKambiTriangulation;
           { additions here must be synchronized with additions to
             TraverseStateLastNodesClasses }
         );
  end;

  { rekord do zapamietywania w TVRMLGraphTraverseState swiatla.
    Kazde swiatlo to jeden node z grupy general light i jego tranformacja -
    rzeczy takie jak pozycja i kierunek, swiatla sa modyfikowane przez ta
    transformacje.

    TransfLocation to juz przeliczone Transformation*Location dla swiatel
    TNodeGenarlLightWLocation. TransfNormDirection to juz
    znormalizowane i transformowane Direction dla swiatel Directional i Spot
    (jest transformowane tak zeby przesuniecia nie mialy znaczenia,
    licza sie tylko obroty i skalowania).

    TODO: TransfLocation/Direction nie jest zbyt eleganckim rozwiazaniem

    NIGDY nie konstruuj tego rekordu recznie - on moze byc modyfikowany tylko
    w TDynActiveLightArray.AddLight  }
  TActiveLight = record
    LightNode: TNodeGeneralLight;
    Transform: TMatrix4Single;
    TransfLocation: TVector3Single;
    TransfNormDirection: TVector3Single;
  end;
  PActiveLight = ^TActiveLight;

  TDynArrayItem_1 = TActiveLight;
  PDynArrayItem_1 = PActiveLight;
  {$define DYNARRAY_1_IS_STRUCT}
  {$I DynArray_1.inc}
  TDynActiveLightArray = class(TDynArray_1)
  public
    { -1 jesli nie ma }
    function IndexOfLightNode(LightNode: TNodeGeneralLight): integer;
    procedure AddLight(ALightNode: TNodeGeneralLight; const ATransform: TMatrix4Single);
    function Equals(SecondValue: TDynActiveLightArray): boolean;
  end;
  TArray_ActiveLight = TInfiniteArray_1;
  PArray_ActiveLight = PInfiniteArray_1;

  { ponizsza klasa TVRMLGraphTraversalState definiuje "stan" w czasie
    przechodzenia sceny VRML'a.

    jedyne pole ktore pamieta aktualna transformacje to CurrMatrix,
    wiec wiadomo jak zaimplementowac np. TransformSeparator.

    Node'y ktore trafiaja na liste LastNodes (bo sa wsrod
    TraverseStateLastNodesClasses) nie moga wplywac w zaden inny sposob na stan
    tej klasy podczas wykonywania Traverse w Before/Middle/After Traverse.
    Innymi slowy, gwarantuje sie ze zmiana wartosci na jakims polu jkaiegos
    node'a z grupy LastNodesKinds nie wplynie w zaden sposob na sposob
    w jaki powinien byc renderowany shape ktorego State nie zawiera
    danego LastNode'a. Korzystam z tego w TFLatScene.ChangedFields.

    Podobnie swiatla trafiaja na ActiveLights i w zaden inny sposob nie moga
    zmieniac State trawersowania. }
  TVRMLGraphTraverseState = class
  private
    FLastNodes: TTraverseStateLastNodes;
    OwnsLastNodes: boolean;
    procedure CommonCreate;
  public
    { nie, ParentsCount elementow Last* NIE odzwierciedla faktu ze sa one
      podlegle TVRMLRenderState. W ogole ten obiekt nie zajmuje sie
      zarzadzaniem tymi polami - on tylko przechowuje sobie ich wartosci.
      W szczegolnosci wiec gwarantowane jest ze obiekty nigdy nie beda nil
      ale ta gwarancja musi byc takze zapewniona przez kod ktory tworzy
      ten obiekt przez Create. }
    property LastNodes: TTraverseStateLastNodes read FLastNodes;

    ActiveLights: TDynActiveLightArray;

    CurrMatrix: TMatrix4Single;
    CurrTextureMatrix: TMatrix4Single;

    ParentShape: TNodeShape;

    constructor CreateCopy(Source: TVRMLGraphTraverseState);
    constructor Create(const ADefaultLastNodes: TTraverseStateLastNodes); overload;

    { Standard create, with standard initial LastNodes state.

      This is equivalent to creating last nodes like
      @longCode(#  TraverseState_CreateNodes(StateDefaultNodes) #)
      then creating this object with
      @longCode(#  Create(StateDefaultNodes) #)
      When this object will be freed, such implicitly created StateDefaultNodes
      will be also freed (using TraverseState_FreeAndNilNodes).

      Note: while this constructor seems very comfortable, in some cases
      it's not useful, exactly because it frees at the end used StateDefaultNodes.
      Consider e.g. TVRMLFlatScene, that has to traverse all nodes and
      store the traversing result in a flat list: this means that it must
      save various TVRMLGraphTraverseState instances, that may have
      references to nodes from StateDefaultNodes. So it must have independent
      StateDefaultNodes field that "lives" for the whole lifetime
      of TVRMLFlatScene and is passed to each TVRMLGraphTraverseState.Create call.

      If you don't understand the note above then don't worry,
      you're probably fine with using this parameter-less constructor :) }
    constructor Create; overload;

    destructor Destroy; override;

    { Note that Equals doesn't compare OwnsLastNodes values,
      as they don't really define the "content" of the instance... }
    function Equals(SecondValue: TVRMLGraphTraverseState): boolean;

    { This is like Equals but it ignores some fields that are
      ignored when rendering using
      TVRMLOpenGLRenderer.RenderShapeStateNoTransform.
      For example, it ignores CurrMatrix. }
    function EqualsNoTransform(SecondValue: TVRMLGraphTraverseState): boolean;

    { Returns proper texture node that should be used
      for nodes within this State, regardless whether this in
      VRML 1.0 or 2.0.

      Details:
      If ParentShape <> nil, this returns texture node taken from
      ParentShape.Texture (note that it may be nil, if Apperance
      of Appearance.Texture node is NULL in VRML).
      Otherwise it returns texture from LastNodes.Texture2. }
    function Texture: TNodeGeneralTexture;
  end;

  TTraversingFunc = procedure (Node: TVRMLNode;
    State: TVRMLGraphTraverseState) of object;

  TEnumerateChildrenFunction =
    procedure (Node, Child: TVRMLNode) of object;

  TNewTriangleProc = procedure (const Tri: TTriangle3Single;
    State: TVRMLGraphTraverseState; ShapeNode: TNodeGeneralShape;
    MatNum: integer) of object;

  TSFNode = class;
  TMFNode = class;

  { VRML node.

    Each descendant must:
    - Define Fd* fields that allow fast, comfortable and type-secure way
      for program to retrieve and set their fields
    - override constructor (look at TVRMLNode.Create comments for things
      that MUST be defined in this derived constructor).
  }
  TVRMLNode = class
  private
    fNodeName: string;
    FWWWBasePath: string;
    FChildren, FParentNodes: TVRMLNodesList;
    function GetChildrenItem(i: integer): TVRMLNode;
    function GetParentNodesItem(i: integer): TVRMLNode;
    procedure SetChildrenItem(I: Integer; Value: TVRMLNode);
    FParentFields: TVRMLFieldsList;
    function GetParentFieldsItem(Index: Integer): TVRMLField;
    function GetParentFieldsNodeItem(Index: Integer): TVRMLNode;
    procedure RemoveParentField(Field: TVRMLField);
    procedure AddParentField(Field: TVRMLField);
    function GetSmartChildren(Index: Integer): TVRMLNode;
    procedure AndSuggestedVRMLVersion(
      var Result: boolean;
      var VerMajor, VerMinor, SuggestionPriority: Integer;
      const NewResult: boolean;
      const NewVerMajor, NewVerMinor, NewSuggestionPriority: Integer);
    procedure TryFindNode_Found(Node: TVRMLNode);
  protected
    fAllowedChildren: boolean;
    fParsingAllowedChildren: boolean;

    { This enumerates all active child nodes of given node.
      "Active nodes" means that only the visible (or affecting
      the visible) parts are enumerated --- e.g. from Switch
      node only one child will be enumerated.

      "Direct" means that this enumerates only direct
      descendants, i.e. this is not recursive.
      See methods like Traverse or EnumerateNodes if you
      want recursive behavior.

      This can enumerate both @link(Children) nodes in VRML 1.0
      style and nodes within TSFNode and TMFNode fields.

      Default implementation in this class returns all Children
      nodes of VRML 1.0. If you need to remove some children
      for VRML 1.0 (e.g. for Switch or LOD nodes)
      or add some children for VRML 2.0 you
      have to override this. You're not required to call
      inherited when overriding this. }
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); virtual;

    { This simply enumerates all direct descendant nodes of
      this node. I.e. all children in VRML 1.0 style and
      all nodes in SFNode and MFNode fields. }
    procedure DirectEnumerateAll(
      Func: TEnumerateChildrenFunction);

    { This enumerates direct descendant nodes of this node.
      This is equivalent to DirectEnumerateActive or
      DirectEnumerateAll, depending on value of OnlyActive param. }
    procedure DirectEnumerate(
      Func: TEnumerateChildrenFunction;
      OnlyActive: boolean);

    { w tej klasie te metody nie nie robia, w podklasach mozna za ich
      pomoca zmodyfikowac nieco zachowanie state'a podczas przechodzenia
      grafu. BeforeTraverse MOZE podmienic State na inny, tylko musi
      go pozniej przywrocic w AfterTraverse. (to jest uzywane w Separatorze).
      PAMIETAJ wywolywac inherited - w Before i Middle Traverse inherited
      powinno byc wywolywane na poczatku, w AfterTraverse - na koncu.  }
    procedure BeforeTraverse(var State: TVRMLGraphTraverseState); virtual;
    procedure MiddleTraverse(State: TVRMLGraphTraverseState); virtual;
    procedure AfterTraverse(var State: TVRMLGraphTraverseState); virtual;

    { method below can be used by a specific node kind to parse fields
      that are NOT on Fields list. Notka : oczywiscie, normalnie
      WSZYSTKIE pola powinny byc na liscie Fields i musza tam byc abysmy
      mogli je normalnie odczytywac ! Po co wiec to udziwnienie ?
      Chodzi o to ze probujemy obslugiwac kilka roznych odmian VRML'a :
      Inventora, VRML'a 1.0 i VRML'a 97. Czasem pewne pola
      danego node'a sa w innej odmianie wyrazone innym polem. Chcac zachowac
      rozsadna prostote wykonania nie mozemy w danym nodzie umieszcac
      dwoch pol ktore wyrazaja to samo ale w inny sposob. Wiec za pomoca
      ponizszej metody pozwalamy node'owi obsluzyc "inne pola" tak aby
      mogl je zinterpretowac i zapisac w swoich polach. Przyklad:
      TNodeShapeHints.

      W klasie TVRMLNode ta metoda nic nie robi, zwraca tylko false.
      Jezeli w jakiejs klasie je przedefiniujesz, powinienes albo
      odczytywac cale pole na ktorym stoi lexer i zwracac true albo
      nie zmieniac pozycji lexera i zwracac false.

      Jest gwarantowane ze w momencie wywolania tej proc. Lexer.Token = vtName. }
    function TryParseSpecialField(Lexer: TVRMLLexer;
      NodeNameBinding: TStringList): boolean; virtual;

    {methods to use in Fd* fields to allow comfortable access to node's specific fields}
    function GetField(i: integer): TVRMLField;
    function GetFieldAsSFBitMask(i: integer): TSFBitMask;
    function GetFieldAsSFBool(i: integer): TSFBool;
    function GetFieldAsSFColor(i: integer): TSFColor;
    function GetFieldAsSFEnum(i: integer): TSFEnum;
    function GetFieldAsSFFloat(i: integer): TSFFloat;
    function GetFieldAsSFTime(i: integer): TSFTime;
    function GetFieldAsSFImage(i: integer): TSFImage;
    function GetFieldAsSFLong(i: integer): TSFLong;
    function GetFieldAsSFInt32(i: integer): TSFInt32;
    function GetFieldAsSFMatrix(i: integer): TSFMatrix;
    function GetFieldAsSFRotation(i: integer): TSFRotation;
    function GetFieldAsSFString(i: integer): TSFString;
    function GetFieldAsSFVec2f(i: integer): TSFVec2f;
    function GetFieldAsSFVec3f(i: integer): TSFVec3f;
    function GetFieldAsSFNode(i: integer): TSFNode;
    function GetFieldAsMFColor(i: integer): TMFColor;
    function GetFieldAsMFLong(i: integer): TMFLong;
    function GetFieldAsMFInt32(i: integer): TMFInt32;
    function GetFieldAsMFVec2f(i: integer): TMFVec2f;
    function GetFieldAsMFVec3f(i: integer): TMFVec3f;
    function GetFieldAsMFRotation(i: integer): TMFRotation;
    function GetFieldAsMFFloat(i: integer): TMFFloat;
    function GetFieldAsMFTime(i: integer): TMFTime;
    function GetFieldAsMFString(i: integer): TMFString;
    function GetFieldAsMFNode(i: integer): TMFNode;
  public
    { kazdy typ node'a ma ustalone Fields razem z ich defaultowymi wartosciami
      w konstruktorze. Potem, czytajac obiekt ze strumienia lub operujac na
      nim kodem mozesz zmieniac tylko wartosci na poszczegolnych polach.
      Node sam zwalnia swoje pola w destruktorze.

      Uwaga - w przypadku klasy TNodeUnknown (i tylko tam) to pole jest
      inicjowane kazdorazowo po parsowaniu (a wiec moze ulegac zmianie
      w czasie zycia obiektu, juz po wywolaniu konstruktora).

      @noAutoLinkHere }
    Fields: TVRMLFieldsList;

    { Children property lists children VRML nodes, in the sense of VRML 1.0.
      In VRML 2.0, nodes never have any Children nodes expressed on this
      list (however, their children nodes may be expressed as items
      of TMFNode / TSFNode fields).

      Kazdy VRML nodes moze miec dowolnie wiele Children.
      Kiedy jakis node jest na liscie Children
      jednego node'a to ma swojego rodzica na swojej liscie ParentNodes.
      Wiec w ten sposob mozemy podrozowac po grafie w obie strony.
      (pamietaj ze graf VRML'a nie ma cykli gdy na niego patrzec jak na graf
      skierowany (a takim wlasnie jest) ale kazdy node moze miec wiele rodzicow
      wiec jezeli potraktujemy go jako graf nieskierowany to mozemy otrzymac
      cykle; wszystko przez to ze node moze miec wiele ParentNodes bo moze
      uzywac mechanizmu USE).

      Kiedy jakis node jest na liscie Children innego node'a to gdy ten inny
      node bedzie go kasowal ze swojej listy Children (a w destruktorze
      kazdy node kasuje wszystkich ze swojej listy Children) to wywola
      jego destruktora. Innymi slowy, gdy jakis node jest czyims dzieckiem
      to jest reference-counted i automatycznie zwalniany.
      Actually, nodes can be children of both nodes (VRML 1.0 style,
      then Children and ParentNodes is used) or fields (TMFNode or TSFNode,
      in VRML 2.0 style; then ParentFields is used). So the node is freed
      only when it's not referenced by any node and not referenced by any
      field.

      Wazna konwencja : jak widac, rodzic automatycznie martwi sie o swoje
      dzieci. Natomiast dziecko w swoim Free nie martwi sie o uaktualnienie
      swoich rodzicow.

      Zwracam tez uwage ze RemoveChild wymaga indeksu. Okreslanie dziecka
      jako children: TVRMLNode jest nie-1-znaczne bo przeciez jeden node
      moze miec kilka razy to samo dziecko (i w rezultacie, nawiasem mowiac,
      kazde dziecko moze miec wiele razy tego samego Parenta). A nie chcemy
      przeciez pomieszac sobie kolejnosci w Children (ona determinuje
      przeciez kolejnosc przegladania grafu, a wiec Renderowania itp.)
      (Natomiast mozemy sobie pozwolic i nieraz pozwalamy na ew. pomieszanie
      kolejnosci w ParentNodes; inaczej musielibysmy z kazdym ParentNodes pamietac
      swoj index na jego liscie). Tak wiec na listach Children i ParentNodes
      moga byc duplikaty i zdecydowanie nie powinnismy nigdzie niefrasobliwie
      "czyscic" tych list przez DeleteDuplicates;

      You can also replace one children with another by writing
      to this property, like @code(Children[I] := NewChildren;).
      This works like a shortcut for
      @code(RemoveChild(I); AddChild(I, NewChildren);).
      But 1. it's more efficient; 2. it's safer --- if
      Children[I] is already equal to NewChildren, then
      first @code(RemoveChild(I);) would free this children and following
      AddChild would be totally wrong.

      @noAutoLinkHere }
    property Children[i: integer]: TVRMLNode
      read GetChildrenItem write SetChildrenItem;

    function ChildrenCount: integer;

    { AddChild z Index (musi byc w zakresie 0..ChildrenCount)
      przesuwa elementy o numerach Index i wiekszych w prawo i
      wstawia child na wskazane Index.    }
    procedure AddChild(Index: Integer; child: TVRMLNode); overload;

    { AddChild bez Indexu - dodaje na koniec listy Children. }
    procedure AddChild(child: TVRMLNode); overload;

    procedure RemoveChild(i: integer);
    procedure RemoveAllChildren;

    property ParentNodes[i: integer]:TVRMLNode read GetParentNodesItem;
    function ParentNodesCount: integer;

    { This lists all SFNode and MFNode fields where this node is referenced.
      This is somewhat analogous for ParentNodes, but for VRML 2.0.

      ParentFieldsNode is just for your comfort, it returns always
      appropriate field's ParentNode property value
      (i.e. @code((ParentField[Index] as TSFNode).ParentNode)
      or @code((ParentField[Index] as TMFNode).ParentNode)). }
    property ParentFields[Index: Integer]: TVRMLField read GetParentFieldsItem;
    property ParentFieldsNode[Index: Integer]: TVRMLNode
      read GetParentFieldsNodeItem;
    function ParentFieldsCount: Integer;

    { bardzo speszial metoda Free: o ile tylko Self <> nil, usuwa nasz node
      ze WSZYSTKICH list ParentNodes[].Children i robi Destroy.
      Tym samym robi nam Free robiac to czego normalne Free nie robi :
      martwiac sie o ParentNodes. Jezeli chcesz usunac node ze srodka hierarchii
      VRMLa - to jest dobra metoda zeby to zrobic. }
    procedure FreeRemovingFromAllParentNodes;

    { AllowedChildren okresla jakie dzieci moga byc dziecmi tego node'a.
      Warunek ten bedzie sprawdzany w AddChild wiec nigdy nie uda ci sie dodac
      node'a ktory nie jest tutaj dozwolony.

      ParsingAllowedChildren okresla jakie dzieci moga byc odczytane
      ze strumienia jako dzieci tego node'a. Chwilowo ma to zastosowanie
      tylko dla wezlow *Inline ktore w strumieniu nie moze miec zapisanych
      zadnych dzieci ale laduja swoje inline jako swoje Child.
      Wiec musza miec ParsingAllowedChildren=[] i AllowedChildren = All.

      TODO: jak bedzie mi to potrzebne to zaimplementuje te pola jako
      tablice TDynVRMLNodeClassArray z dodatkowym polem Any. Taka tablica
      bedzie pasowala do wszystkiego gdy Any = true, wpp. tylko do wymienionych
      na niej elementow. Wartosc *AllowedChildren = true tutaj odpowiadac
      bedzie Any = true tam, *AllowedChildren = false oznacza Any = false i Items=[].
      Wartosc Any jest potrzebna zeby na zapas powiedziec : wszystkie node'y
      sa tu dozwolone, nawet takie o jakich jeszcze nie wie NodesManager -
      - a jest to przeciez czesta sytuacja.

      Naturalnie ParsingAllowedChildren musi sie zawierac w AllowedChildren
      bo inaczej parsowanie moze wygenerowac wyjatek (wywolujac
      AddChild z niedozwolonym argumentem). W tej chwili oznacza to tylko
      ze nie moze byc ParsingAllowedChildren = true i AllowedChildren = false.

      Uwaga - w przypadku klasy TNodeUnknown (i tylko tam) wartosci tych
      pol sa inicjowane po kazdorazowym parsowaniu (a wiec ulegaja zmianie
      juz po wykonaniu konstruktora obiektu). }
    property AllowedChildren: boolean read fAllowedChildren; { = false }
    property ParsingAllowedChildren: boolean read fParsingAllowedChildren; { = false }

    { Name of this node, as defined by VRML "DEF" construct.

      NodeName = '' oznacza ze obiekt nie mial zdefiniowanej nazwy.

      It's named NodeName, to not confuse this with TVRMLField.Name.
      (Even though TVRMLField and TVRMLNode classes have nothing in common.
      TSFNode descends from TVRMLField and @italic(contains) TVRMLNode
      instance in it's Value field. Once I wanted to just make
      TSFNode = TVRMLNode and TVRMLNode descendant of TVRMLField,
      but this wasn't a good idea: TSFNode may be NULL, but still
      it has a field name, so it should be nicely represented as
      TSFNode instance with Value = nil.) }
    property NodeName: string read fNodeName;

    { WWWBasePath is the base URL path for all URLs
      in node's fields. This is used by all nodes that get some
      url (like Texture2 and WWWInline in VRML 1.0, ImageTexture
      and Inline in VRML 2.0 etc.).

      This way URL's in node's fields may contain relative names.
      If WWWBasePath doesn't begin with <proto>:// it is understood
      to be a file:// base path.

      TODO: chwilowo, poniewaz tylko odwolania do lokalnych plikow
      sa zaimplementowane, cale to bajanie o URL'ach to tylko mowa
      "jak kiedys bedzie". Chwilowo WWWBasePath musi byc lokalna sciezka
      (i to absolutna, bezwzgledna sciezka).

      WWWBasePath jest ustalane w Create, ew. pozniej jest zmieniane w trakcie
      Parse() na podstawie Lexer.WWWBasePath.
      W ten sposob np. moglibysmy, gdybysmy tylko chcieli, rozwiazywac
      wezly jak WWWInline lub Texture2 zaraz po sparsowaniu ich. }
    property WWWBasePath: string read FWWWBasePath;

    { This returns absolute path, assuming that RelativePath is relative
      path from WWWBasePath or that RelativePath is already absolute. }
    function PathFromWWWBasePath(const RelativePath: string): string;

    { Parse jest zaimplementowane ogolnie dla wszystkich TVRMLNode'ow
      za wyjatkiem node'a TNodeUnknown ktory redefiniuje ta metode.
      Parse ustala wartosci Fields, liste Children, WWWBasePath.
      W przypadku TNodeUnknown ma dozwolone takze zeby inicjowal
      *AllowedChildren i ilosc i typy Fields.
      Czasami jakies inne node'y robia override tej metody zeby (po wywolaniu
      w niej inherited) zrobic jakies dodatkowe rzeczy ktore powinno sie
      zrobic po sparsowaniu.

      @noAutoLinkHere }
    procedure Parse(Lexer: TVRMLLexer; NodeNameBinding: TStringList); virtual;

    { Konstruktor. Inicjuje wszystko (jak to konstruktor), w szczegolnosci :
      @unorderedList(
        @item(inicjuje NodeName, WWWBasePath na podstawie podanych tu parametrow)
        @item(
          inicjuje tablice Fields ustawiajac polom ich defaultowe wartosci
          (dla implementatorow podklas TVRMLNode:
          w klasie TVRMLNode inicjujemy Fields na tablice o 0 elementach;
          w konstruktorze podklasy musisz wywolac Fields.Add(...)
          aby dodac sobie odpowiednie pola))
        @item(
          [Parsing]AllowedChildren
          (dla implementatorow podklas TVRMLNode:
          w klasie TVRMLNode inicjujemy je na zbiory puste (tzn. chwilowo po prostu
          na false) po prostu dlatego ze wydaje sie to byc najczestsza wartoscia.
          W konstruktorze podklas mozesz swobodnie zmienic wartosci tych pol.))
      )

      @noAutoLinkHere }
    constructor Create(const ANodeName: string; const AWWWBasePath: string); virtual;

    { CreateParse : wygodne polaczenie Create+Parse }
    constructor CreateParse(const ANodeName: string; Lexer: TVRMLLexer; NodeNameBinding: TStringList);

    { @noAutoLinkHere }
    destructor Destroy; override;

    { NodeTypeName zwraca nazwe klasy w VRML'u. Zawsze jest <>''.
      To ma byc normalna nazwa node'a, taka ktora odczytujemy
      i zapisujemy bezposrednio z/do pliku VRMLa (wobec tego jest ona tez
      case-sensitive, jak caly VRML).
      Nie zmienia sie przez caly czas zycia obiektu, tzn. raz zainicjowana w
      konstruktorze juz taka pozostaje (nawet dla obiektu TNodeUnknown;
      dla obiektu TNodeUnknown po prostu NodeTypeName nie jest 1-znacznie
      wyznaczone przez sama klase, tzn. obiekty klasy TNodeUnknown moga
      miec rozne NodeTypeName, w przeciwienstwie do "normalnych" klas ktore
      zawsze maja takie samo NodeTypeName; ale to nie czyni przypadku
      TNodeUnknown czyms wyjatkowym dla tej funkcji).

      W tej klasie NodeTypeName zwraca ClassNodeTypeName. Uwagi do
      implementacji podklas TVRMLNode dotyczace tej funkcji - patrz
      ClassNodeTypeName. }
    function NodeTypeName: string; virtual;

    { ClassNodeTypeName zwraca nazwe klasy VRMLa zwiazanej z tym node'm lub
      '' w przypadku klas ktore nie maja zwiazanej ze soba 1-znacznej nazwy
      typu wezla VRMLa ktory reprezentuja (a poniewaz kazda klasa wezla VRMLa
      musi miec NodeTypeName <> '' wiec oznacza to ze te wyjatkowe klasy ustalaja
      sobie NodeTypeName w jakis inny, specjalny sposob - jedyny dostepny
      w tej chwili przyklad tego to TNodeUnknown (chociaz nie wykluczam sobie
      w tym momencie czy nie pojawi sie kiedys jeszcze jakis inny tego typu node))

      Jezeli masz do dyspozycji instancje obiektu to nie powinienes uzywac
      tej funkcji. Jedyna jej zaleta ponad NodeTypeName jest ze jest funkcja
      klasy. Jezeli masz do dyspozycji tylko klase obiektu to uzywajac
      tej funkcji musisz sie zdecydowac co zrobic jesli dostaniesz w odpowiedzi
      '' (albo jakos sie zabezpieczyc zeby nigdy w danym kontekscie takich
      klas nie miec...)

      Uwagi do implementacji podklas TVRMLNode:
      W tej klasie ClassNodeTypeName zwraca ''. Wszystkie niesbtrakcyjne
      klasy wezlow VRMLa musza pokrywac albo ClassNodeTypeName (i w ten
      sposob staja sie normalnymi klasami ktore maja zawszetaka sama wartosc
      NodeTypeName dla swojej klasy) albo NodeClassTypeName (i w ten sposob
      staja sie klasami specjalnymi, jak TNodeUnknown, ktore nie maja
      stalej wartosci NodeTypeName). }
    class function ClassNodeTypeName: string; virtual;

    { Traverse enumerates all nodes of VRML graph that are active
      for our hierarchy. "Active nodes" means that only the visible (or affecting
      the visible) parts are enumerated --- e.g. from Switch node only one
      child will be enumerated. For all nodes of NodeClass TraversingFunc
      will be called. Traverse not only enumerates these
      nodes, it also collects all state (transformation, etc ---
      see TVRMLGraphTraverseState) that affects how given node should
      be presented.

      Schemat dzialania Traverse :

@preformatted(
  BeforeTraverse;
  if Self is NodeClass then TraversingFunc (Self, State)
  MiddleTraverse
  for all children returned by DirectEnumerateActive
    call their Traverse(State)
  AfterTraverse,
  dodaj Self do stanu State do LastNode (o ile Self wsrod
    TraverseStateLastNodesClasses)
)

      Jezeli zostalo wykonane BeforeTraverse, na pewno zostanie wykonane tez
      AfterTraverse (wywolanie AfterTraverse jest w finally..end).

      Kolejnosc w jakiej przechodzi graf jest naturalnie istotna.
      W czasie wykonywania Traverse mozesz modyfikowac tylko node'y dzieci
      (bezposrednie i niebezposrednie) node'a na ktorym wlasnie stoisz. }
    procedure Traverse(State: TVRMLGraphTraverseState;
      NodeClass: TVRMLNodeClass;
      TraversingFunc: TTraversingFunc); virtual;

    { This is like @link(Traverse), but it automatically handles
      creating and destroying of TVRMLGraphTraverseState and it's LastNodes.

      This is comfortable --- but see comments at
      TVRMLGraphTraverseState.Create: if you want to save for later
      State instances obtained during traversing,
      than you shouldn't use this. }
    procedure TraverseFromDefaultState(
      NodeClass: TVRMLNodeClass; TraversingFunc: TTraversingFunc);

    { Enumerate all our children of some class. Recursively.
      Zwroci do proc() takze sam obiekt na ktorym EnumerateNodes zostalo
      wywolane, jezeli tylko ten obiekt jest klasy nodeClass.

      This enumerates both VRML 1.0 @link(Children) as well as
      nodes in TSFNode and TMFNode fields.
      If OnlyActive then it will enumerate only active parts
      of the graph (as defined by @link(DirectEnumerateActive)),
      so it will work as a simpler version of Traverse
      (simpler, because it doesn't track any state).
      If not OnlyActive then it will simply enumerate all nodes.

      Wersja z argumentem SeekNodeName wymaga ponadto aby node mial NodeName=
      SeekNodeName (gdy SeekNodeName = '' to znajduje nienazwane node'y,
      wiec wartosc '' nie jest tu traktowana specjalnie).

      Zaczyna przegladac dzieci dopiero jak przegladnie Self. Jezeli np.
      w proc. zmodyfikowales (np. dodales) wlasne Children to EnumerateNodes
      will enumerate these new children. To ma znaczenie np. w
      TVRMLScene.LoadAllInlined gdzie w proc robimy LoadInlined. Poniewaz
      EnumerateNodes przeglada dzieci po wywolaniu proc., wiadomo ze
      przegladnie tez nowo zaladowane dziecko.

      BTW modyfikowanie dzieci node'a ktory wlasnie dostales do proc()
      to jedyna dozwolona modyfikacja na hierarchii VRMLa ktora mozesz
      wykonywac w czasie EnumerateNodes.

      @groupBegin }
    procedure EnumerateNodes(
      proc: TVRMLNodeProc; OnlyActive: boolean); overload;
    procedure EnumerateNodes(nodeClass: TVRMLNodeClass;
      proc: TVRMLNodeProc; OnlyActive: boolean); overload;
    procedure EnumerateNodes(nodeClass: TVRMLNodeClass;
      const SeekNodeName: string;
      proc: TVRMLNodeProc; OnlyActive: boolean); overload;
    { @groupEnd }

    { TryFindNodeByName and TryFindNode seek for a node with
      given class (and node name, in case of TryFindNodeByName).
      If OnlyActive then they seek among only active nodes
      (as defined by DirectEnumerateActive), otherwise all nodes.

      These functions are quite like EnumerateNodes, except
      they stop at the first occurence and return it.

      TryFindNodeByName and TryFindNode return @nil if such node
      is not found. FindNodeByName and FindNode raise exception
      in this case.

      @groupBegin }
    function TryFindNodeByName(FindClass: TVRMLNodeClass;
      const FindName: string;
      OnlyActive: boolean): TVRMLNode;
    function FindNodeByName(FindClass: TVRMLNodeClass;
      const FindName: string;
      OnlyActive: boolean): TVRMLNode;
    function TryFindNode(FindClass: TVRMLNodeClass;
      OnlyActive: boolean): TVRMLNode;
    function FindNode(FindClass: TVRMLNodeClass;
      OnlyActive: boolean): TVRMLNode;
    { @groupEnd }

    { Znajdz pierwszy Node (zadanej klasy NodeClass) razem ze State
      (lub tylko z Transform).
      Dziala jak Traverse ktore zatrzymuje sie po pierwszej udanej probie.
      Pamietaj ze State nie jest pamietane nigdzie indziej i musisz je zwolnic.
      W przypadku TryFindNodeTransform nie musisz o tym pamietac,
      no i TryFindNodeTransform dziala nieco szybciej.

      Zwraca false and sets Node, State and Transform to undefined
      (because they are "out" params) if not found.

      @groupBegin }
    function TryFindNodeState(InitialState: TVRMLGraphTraverseState;
      NodeClass: TVRMLNodeClass;
      out Node: TVRMLNode; out State: TVRMLGraphTraverseState): boolean;
    function TryFindNodeTransform(InitialState: TVRMLGraphTraverseState;
      NodeClass: TVRMLNodeClass;
      out Node: TVRMLNode; out Transform: TMatrix4Single): boolean;
    { @groupEnd }

    { This seeks Self and parent nodes (from ParentNodes and ParentFields,
      recursively), for given node name.

      In other words, this is similar to TryNodeByName or NodeByName,
      but it goes "upward" in graph hierarchy. Note that this
      never restricts itself only to "active" graph part
      (see DirectEnumerateActive and OnlyActive param of various
      methods) because you really can't detect what is the "active"
      part of the graph when going upward.

      @groupBegin }
    function TryFindParentByName(const FindName: string): TVRMLNode;
    function FindParentByName(const FindName: string): TVRMLNode;
    { @groupEnd }

    { Przeszukuje podobnie jak powyzsze FindParentByName. Zwraca true
      jesli znalazl tam gdzies node Node. }
    function HasParent(Node: TVRMLNode): boolean;

    { sprawdza czy istnieje w grafie VRML'a zaczepionym w danym punkcie
      node Node. Znaczenie OnlyActive jak zwykle. }
    function IsNodePresent(Node: TVRMLNode; OnlyActive: boolean): boolean;

    { policz ile jest node'ow danej klasy.
      Uzywajac np. TNodeGeneralLight mozesz
      sprawdzic czy na scenie zostalo zdefiniowane jakiekolwiek swiato.
      Parametr countOnlyActiveNodes ma znaczenie jak zwykle.

      This traverses both VRML 1.0 children nodes and VRML 2.0 nodes
      inside SFNode and MFNode fields. }
    function NodesCount(NodeClass: TVRMLNodeClass;
      CountOnlyActiveNodes: boolean): integer;

    { zapisz node do strumienia; ta metoda jest tu zaimplementowana zupelnie
      ogolnie i dziala dla kazdej podklasy TVRMLNode. Jak widac,
      zapisujac graf VRML'a takze trzymamy sobie aktualne NodeNameBinding.
      W ten sposob wiemy ze jezeli jakis node juz jest na tej liscie
      to wystarczy zrobic mu USE. Jednoczesnie NodeNameBinding to,
      podobnie jak przy parsowaniu, lista bez duplikatow, wiec jezeli nawet
      w scenie beda dwa node'y o tej samej nazwie to my zapiszemy scene
      poprawnie (uzyjemy USE tylko tam gdzie bedziemy mogli, jesli nie bedziemy
      mogli - zapiszemy node normalnie).

      Note that if ChildrenSaveToStream returns @false
      we don't write our Children. Currently this is used by various inline
      nodes (WWWInline, Inline, etc.) }
    procedure SaveToStream(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList);

    { szuka tej klasy node'a (rzeczywistej koncowej klasy, z ClassType) w
      TraverseStateLastNodesClasses. Zwraca indeks lub -1 jesli nie znalazl. }
    class function TraverseStateLastNodesIndex: Integer;

    { Some of the nodes are meant to be handled only for specific
      VRML versions. This functions says whether this node is supposed
      to be present in given VRML version. VerMajor and VerMinor
      arguments are expected in the same form as TVRMLLexer.VRMLVerMajor,
      TVRMLLexer.VRMLVerMinor.

      For example some nodes can only work in VRML < 2.0,
      some others only in VRML >= 2.0. There are even some pairs
      of nodes: for example TNodeCone_1 works with VRML < 2.0,
      TNodeCone_2 works with VRML >= 2.0.

      NodesManager will use this.

      Default implementation of this function returns always @true.
      Generally, I don't try to set this too aggresively ---
      in other words, for all cases when it's sensible, I allow
      nodes to be used in every VRML version, even when official
      specification doesn't. This means that when reading VRML 1.0
      files actually a large part of VRML 2.0 is allowed too,
      and also while reading VRML 2.0 many constructs from VRML 1.0
      (officially no longer present in VRML 2.0) are allowed too.
      I'm trying to support what I call a "sum of VRML 1.0 and 2.0".

      In practice I only use this function when both VRML 1.0 and 2.0
      specify the same node name but

      @unorderedList(
        @item(With different fields.

          For example Cone and Cylinder have slightly different fields,
          due to the fact that VRML 2.0 resigned from using TSFBitMask fields.)

        @item(With different behavior.

          For example definitions of Sphere for VRML 1.0
          and 2.0 are practically equal. However, the behavior from where
          to take texture and material info is different --- in VRML 1.0
          we take last Texture2, Material etc. nodes, while in VRML 2.0
          we look in parent Shape's "appearance" field. So once again
          two different Sphere classes are needed.)
      ) }
    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      virtual;

    { MFNode field of this node that should be treated as general
      "children" field of this node. This is used in some places,
      like SmartAddChild.

      Should return nil if this node doesn't have such
      field (that's the default implementation in this class).
      This should always return the same value for given class instance
      (in other words, don't implement this to sometimes return one field,
      sometimes the other, sometimes nil, etc.). }
    function ChildrenField: TMFNode; virtual;

    { These operate on children nodes, in either VRML 2.0 style
      (if ChildrenField is non-nil, then these get/set ChildrenField.Items)
      or in VRML 1.0 style (if ChildrenField is nil, then these get/set
      our Children).

      This is useful to operate on grouping nodes both in VRML 1.0 and VRML 2.0
      style using the same code. }
    procedure SmartAddChild(Node: TVRMLNode);
    property SmartChildren[Index: Integer]: TVRMLNode read GetSmartChildren;
    function SmartChildrenCount: integer;

    { SuggestedVRMLVersion determines what VRML header to use
      when saving the node to file. Returns @true and sets out arguments
      if some version is preferred, otherwise returns @false.

      SuggestionPriority should be used to indicate the "strongness"
      of this suggestion. The idea is that if there are two nodes
      that have different VRML version suggestions, then the one
      with greater SuggestionPriority "wins".

      Right now I use SuggestionPriority 1000 for nodes
      that are only in one VRML version, according to VRML 1.0 and 2.0
      specs (with my extensions), and SuggestionPriority 100 for
      VRML 2.0 nodes that are also allowed in VRML 1.0
      by my extensions
      [http://www.camelot.homedns.org/~michalis/kambi_vrml_extensions.php].
      This way e.g. if your VRML hierarchy consists only of
      a single TNodeBackground node, then the result will be saved as VRML 2.0
      (as this will give VRML 2.0-compliant file).
      But if your VRML hierarchy has for example TNodeBackground node inside
      TNodeGroup_1, then the result will be VRML 1.0 file
      (non-standard VRML 1.0 file using my "extension" that allows
      Background node in VRML 1.0).

      Default implementation in this class enumerates all
      SFNode and MFNoden fields and Children nodes
      and determines their suggested VRML version. }
    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; virtual;

    { Returns should SaveToStream save our Children.
      In this class default implementation returns @true,
      this is what you will want in 99% of cases.
      It's useful to set this to false if you use
      Children internally, e.g. *Inline nodes. }
    class function ChildrenSaveToStream: boolean; virtual;
  end;

  TObjectsListItem_3 = TVRMLNode;
  {$I objectslist_3.inc}
  TVRMLNodesList = class(TObjectsList_3);

  TVRMLNodeClassesList = class(TList)
  private
    function GetItems(Index: Integer): TVRMLNodeClass;
    procedure SetItems(Index: Integer; Value: TVRMLNodeClass);
  public
    property Items[Index: Integer]: TVRMLNodeClass
      read GetItems write SetItems;
    procedure AssignArray(
      const AItemsArray: array of TVRMLNodeClass);
    function IndexOf(NodeClass: TVRMLNodeClass): Integer; overload;
    { This is equivalent to IndexOf(NodeClass.ClassType),
      taking care of necessary typecasts. }
    function IndexOf(Node: TVRMLNode): Integer; overload;
    procedure Add(Value: TVRMLNodeClass);
  end;

  { SFNode VRML field.
    It's defined in this unit, not in VRMLFields, since it uses
    TVRMLNode definition. NULL value of the field is indicated by
    Value field = nil. This field has always the same default value: NULL.

    Note that we store AllowedChildren list, which is a list of
    classes allowed as a Value (also nil is always allowed).
    But this is used only to produce warnings for a user.
    You should never assert that Value actually is one the requested
    classes. We want to keep here even not allowed items,
    because we want operation "read from VRML file + write to VRML file"
    to be as non-destructible as possible. So if user wrote
    invalid class hierarchy, we will output this invalid class hierarchy. }
  TSFNode = class(TVRMLSimpleSingleField)
  private
    FValue: TVRMLNode;
    FParentNode: TVRMLNode;
    FAllowedChildren: TVRMLNodeClassesList;
    procedure SetValue(AValue: TVRMLNode);
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(AParentNode: TVRMLNode; const AName: string;
      const AnAllowedChildren: array of TVRMLNodeClass); overload;
    { Constructor that takes AnAllowedChildren as TVRMNodeClassesList.
      Note that we copy the contents of AnAllowedChildren, not the
      reference. }
    constructor Create(AParentNode: TVRMLNode; const AName: string;
      AnAllowedChildren: TVRMLNodeClassesList); overload;
    destructor Destroy; override;

    property Value: TVRMLNode read FValue write SetValue;
    procedure Parse(Lexer: TVRMLLexer; NodeNameBinding: TStringList); override;
    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure Assign(Source: TPersistent); override;
    property ParentNode: TVRMLNode read FParentNode;
  end;

  { MFNode VRML field.

    Just like SFNode, it's defined in this unit, as it uses TVRMLNode.
    Note that items of MFNode @italic(cannot) be nil (i.e. VRML doesn't
    allow to use NULL inside MFNode), contrary to SFNode.
    Default value of MFNode field is always "0 items".

    Note that TMFNode implementation doesn't use TVRMLSimpleMultField.
    Reasons ? 1. We don't want to use TDynArray descendant.
    We want to use TVRMLNodesList. 2. We don't want to do parsing
    using SFNode, because MFNode doesn't allow NULL items.

    Just like for TSFNode:
    Note that we store AllowedChildren list, which is a list of
    classes allowed as Items.
    But this is used only to produce warnings for a user.
    You should never assert that every item actually is one the requested
    classes.  }
  TMFNode = class(TVRMLMultField)
  private
    FItems: TVRMLNodesList;
    FParentNode: TVRMLNode;
    FAllowedChildren: TVRMLNodeClassesList;
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(AParentNode: TVRMLNode; const AName: string;
      const AnAllowedChildren: array of TVRMLNodeClass); overload;
    { Constructor that takes AnAllowedChildren as TVRMNodeClassesList.
      Note that we copy the contents of AnAllowedChildren, not the
      reference. }
    constructor Create(AParentNode: TVRMLNode; const AName: string;
      AnAllowedChildren: TVRMLNodeClassesList); overload;
    destructor Destroy; override;

    { Lists items of this fields.

      Do not modify this list explicitly. Use only methods in this class
      like AddItem (they take care of calling appropriate
      AddParentField / RemoveParentField, otherwise you
      could break reference-counting of nodes by ParentFields). }
    property Items: TVRMLNodesList read FItems;

    procedure AddItem(Node: TVRMLNode);
    procedure ClearItems;
    procedure AssignItems(SourceItems: TVRMLNodesList);

    { Just a shortcut for Items.Count }
    function Count: integer; override;

    procedure Parse(Lexer: TVRMLLexer; NodeNameBinding: TStringList); override;

    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure Assign(Source: TPersistent); override;

    property ParentNode: TVRMLNode read FParentNode;
  end;

  { Specific VRML nodes ---------------------------------------------------- }

  { Shape is the only node that produces some visible results
    during rendering. Basically, most if the VRML language is just
    a method of describing those shapes and many other nodes
    are defined only to set up additional state for shapes
    (materials, transformations, lighting).

    Some exceptions to this are camera nodes, sensors (WWWAnchor in VRML 1.0),
    Info, WorldInfo, Background, Fog. These nodes specify some things
    that can't be embedded in simple Render command for a node.
    These things describe
    @unorderedList(
      @item(user interaction with the world (cameras, sensors))
      @item(
        some information that has no meaning to us and all we can do about it
        (besides ignoring it) is to show it to the user (Info, WorldInfo))
      @item(
        some information about how to render the world that cannot be just
        expressed as "modifying the way all subsequent shapes are drawn"
        (Fog, Background))
    )

    This class may have some special functionality and it builds
    comfortable object inheritance hierarchy.
    For example, now we can use EnumerateNodes(TNodeGeneralShape).

    A few things that make Shape node special :
    @unorderedList(
      @item only shape nodes may have [Local]BoundingBox
      @item(
        only shape nodes define something visible "in usual way"
        during rendering (Some other nodes in VRML 2.0 are visible but in an
        unusual way, like Background and Fog. These nodes must be rendered in
        a special way --- they are not affected in any usual way by the current
        transformation matrix etc.))
      @item(
        only shape nodes can add triangles to the scene, so the Triangulate
        method can be defined only for shape nodes.)
      @item(
        shape nodes never have children (that's why I don't need to define
        in interface whether [Local]BoundingBox or Triangles/VerticesCount
        calculate child nodes too - because they will never have any child
        nodes; TODO: some VRML 2.0 shape nodes will break this ?))
      @item(
        shape nodes doesn't affect anything in graph traverse state.)
    ) }
  TNodeGeneralShape = class(TVRMLNode)
    { BoundingBox oblicza BoundingBox shape node'a VRMLa ktory podczas
      trawersowania grafu VRML'a ma stan State.

      LocalBoundingBox liczy BoundingBox jakby CurrMatrix = IdentityMatrix,
      czyli liczy bounding box wzgledem lokalnego ukladu node'a.

      W tej klasie LocalBoundingBox jest liczone jako BoundingBox ktore
      dostaje specjalnie spreparowane State z CurrMatrix = zawsze Identity.
      Jest to poprawna metoda realizacji LocalBoundingBox'a natomiast
      nieco nieoptymalna czasowo : bedzie wykonywanych wiele mnozen przez
      macierz o ktorej wiadomo ze jest Identity. Wiec w podklasach mozesz
      pokrywac ta metode aby liczyc LocalBoundingBox'a w szybszy sposob.

      Zwracam uwage ze odwrotny pomysl --- realizacja BoundingBox'a przez
      LocalBoundingBox'a (transformujac wyliczony LocalBoundingBox przez
      State.CurrMatrix) nie jest juz tak dobrym pomyslem --- mozemy w rezultacie
      otrzymac o wiele za duze BoundingBox'y.

      Tym niemniej miejscami zamierzam tak liczyc BoundingBox'a --- np. dla sfery.
      Wiec w tej klasie BoundingBox jest zaimplementowany wlasnie jako
      LocalBoundingBox transformowany o State.CurrMatrix.

      W kazdej podklasie Shape powinienes pokryc przynajmniej jedna z tych metod
      --- jak to napisalem powyzej, jezeli nie pokryjesz BoundingBox'a to byc
      moze otrzymany BoundingBox bedzie nieco za duze (co jest w sumie
      dopuszczalne, ale nie do przesady), jezeli nie pokryjesz LocalBoundingBox
      --- to LocalBoundingBox nie bedzie liczony tak szybko jak moglby byc.
      Najlepiej wiec byloby gdybys pokrywal obie te metody. }
    function BoundingBox(State: TVRMLGraphTraverseState): TBox3d; virtual;
    function LocalBoundingBox(State: TVRMLGraphTraverseState): TBox3d; virtual;

    { kazda podklasa GeneralShape musi pokrywac i implementowac te metody.

      Te metody zwracaja ilosc trojkatow jaka definiuje [Local]Triangulate
      (z takimi samymi parametrami State i OverTriangulate)
      dla tego node'a i ilosc roznych vertexow jakie sa uzywane w tych
      trojkatach (chociaz nie wykonuje w tym celu zadnych porownan miedzy
      zdefiniowanymi punktami w node'ach i definiujac nieporzadnie node'y
      (np. podajac dwa razy ten sam punkt w Coordinate3) mozesz latwo to
      oszukac). (acha, dla PointSet naturalnie nie ma zadnych trojkatow
      ale VerticesCount to ciagle liczba vertexow, mimo ze nie sa uzywane
      w zadnych trojkatach).

      State chwilowo nie jest nigdzie uzywany w TrianglesCount,
      ale jestem gotowy gdyby w przyszlosci jakis node tego potrzebowal
      (bo w sumie nie byloby w tym nic wyjatkowego, tzn. nie byloby to
      nic co w modelu VRMLu jaki tu zaimplementowalem musialbym gdziekolwiek
      traktowac jako jakis wyjatek)

      Uwaga --- gdy przychodzi do TrianglesCount moze sie okazac ze Triangulate
      zwrocilo inna ilosc trojkatow gdy niektore face byly non-convex (bo w tym
      przypadku TriangulateFace ma prawo pousuwac trojkaty zdegenerowane
      do punktu). Generalnie nie polegaj na TrianglesCount jako na dokladnej
      wartosci --- raczej jako na przyblizeniu ktore zazwyczaj bedzie bardzo
      bardzo dokladne. }
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; virtual; abstract;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; virtual; abstract;

    { triangulate node = call NewTriangleProc for each triangle this node
      defines. NewTriangleProc will be called with (Tri, State, Node) where
      Tri will be new triangle,  and State will always be State podany tutaj
      parametrem and Node will always be Self.

      LocalTriangulate robi to samo ale nie uwzglednia State.CurrMatrix.
      W podklasach trzeba zdefiniowac tylko LocalTriangulate.

      Jezeli OverTriangulate = false to [Local]Triangulate generuje tylko tyle
      trojkatow zeby doskonale odzwierciedlac ksztalt node'a. W przypadku
      gdy nie jest to mozliwe (np. przy kulach, stozkach itp.)
      [Local]Triangulate uzywa State.KambiTriangulation
      aby zdecydowac sie jak dobre chcemy miec przyblizenie oryginalu.

      Jezeli OverTriangulate = true to [Local]Triangulate moze wygenerowac
      wiecej trojkatow --- w przypadku duzych powierzchni moze zdecydowac sie
      zeby je rozbic na wiecej malych trojkatow niz jest to rzeczywiscie
      potrzebne aby wyrazic te powierzchnie jako zbior trojkatow.
      Np. node Cube (szescianik) mozna wyrazic doskonale dokladnie jako
      12 trojkatow i to wlasnie zrobimy gdy OverTriangulate = false.
      ALE gdy OverTriangulate = true my rozbijemy kazda sciane szescianu
      na WIECEJ trojkatow, zgodnie z parametrem State.
      KambiTriangulation .RectDivisions.
      Do czego to sie moze przydac ? Gdy uzywasz cieniowania Gourauda (albo
      jeszcze gorzej, cieniowania plaskiego) jedynym remedium zeby renderowac
      rozblyski na srodku duzych powierzchni jest wlasnie rozbijac te powierzchnie
      na duzo trojkatow. }
    procedure Triangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean;
      NewTriangleProc: TNewTriangleProc);
    procedure LocalTriangulate(State: TVRMLGraphTraverseState;
      OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); virtual; abstract;
  end;

  { This is descendant of TNodeGeneralShape that is allowed only in
    VRML <= 1.0.

    In VRML 1.0 shape nodes are allowed pretty everywhere,
    while VRML 2.0 has different idea of how shapes are handled
    (they must be inside Shape node), so no shape node
    is suitable at the same time for VRML 1.0 and VRML 2.0. }
  TNodeGeneralShape_1 = class(TNodeGeneralShape)
  public
    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  { Font justification that can be specified by FontStyle in
    justify/justification field. First three fields are equal
    (after casting by Ord) to JUSTIFICATION_* constants. }
  TVRMLFontJustify = (fjBegin, fjMiddle, fjEnd);

  TNodeAsciiText_1 = class(TNodeGeneralShape_1)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdString: TMFString index 0 read GetFieldAsMFString;
    property FdSpacing: TSFFloat index 1 read GetFieldAsSFFloat;
    { Use consts JUSTIFICATION_XXX (declared below in this unit) }
    property FdJustification: TSFEnum index 2 read GetFieldAsSFEnum;
    property FdWidth: TMFFloat index 3 read GetFieldAsMFFloat;

    function BoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;

    function Justify: TVRMLFontJustify;
  end;

  TNodeCone_1 = class(TNodeGeneralShape_1)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdParts: TSFBitMask index 0 read GetFieldAsSFBitMask;
    property FdBottomRadius: TSFFloat index 1 read GetFieldAsSFFloat;
    property FdHeight: TSFFloat index 2 read GetFieldAsSFFloat;

    function BoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeCube_1 = class(TNodeGeneralShape_1)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdWidth: TSFFloat index 0 read GetFieldAsSFFloat;
    property FdHeight: TSFFloat index 1 read GetFieldAsSFFloat;
    property FdDepth: TSFFloat index 2 read GetFieldAsSFFloat;

    function LocalBoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeCylinder_1 = class(TNodeGeneralShape_1)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdParts: TSFBitMask index 0 read GetFieldAsSFBitMask;
    property FdRadius: TSFFloat index 1 read GetFieldAsSFFloat;
    property FdHeight: TSFFloat index 2 read GetFieldAsSFFloat;

    function LocalBoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  {wspolny rodzic dla IndexedFaceSet, IndexedTriangleMesh, IndexedLineSet}
  TNodeGeneralIndexed_1 = class(TNodeGeneralShape_1)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    property FdCoordIndex: TMFLong index 0 read GetFieldAsMFLong;
    property FdMaterialIndex: TMFLong index 1 read GetFieldAsMFLong;
    property FdNormalIndex: TMFLong index 2 read GetFieldAsMFLong;
    property FdTextureCoordIndex: TMFLong index 3 read GetFieldAsMFLong;

    function BoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function LocalBoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
  end;

  { wspolny rodzic dla IndexedFaceSet i IndexedTriangleMesh }
  TNodeIndexed_Faces_Or_Triangles_1 = class(TNodeGeneralIndexed_1)
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
  end;

  TNodeIndexedFaceSet_1 = class(TNodeIndexed_Faces_Or_Triangles_1)
    class function ClassNodeTypeName: string; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  { IndexedTriangleMesh --- from Inventor 1.0. }
  TNodeIndexedTriangleMesh_1 = class(TNodeIndexed_Faces_Or_Triangles_1)
    class function ClassNodeTypeName: string; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeIndexedLineSet_1 = class(TNodeGeneralIndexed_1)
    class function ClassNodeTypeName: string; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodePointSet_1 = class(TNodeGeneralShape_1)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdStartIndex: TSFLong index 0 read GetFieldAsSFLong;
    property FdNumPoints: TSFLong index 1 read GetFieldAsSFLong;

    {oblicz startIndex i numPoints na podstawie odpowiednich pol.
     Zwrocone numPoints jest na pewno > 0, przedzial startIndex..numPoints-1
     na pewno zawiera sie w przedziale 0..LastCoordinate3.FdPoint.Count-1.
     Ta proc. NIE poprawia wartosci na polach Fd* - bo byc moze w skryptach
     bedzie wygodniej zakladac ze nawet nieprawidlowe wartosci sa trwale. }
    procedure CalculateRange(LastCoordinate3: TNodeCoordinate3;
      out startIndex, numPoints: integer);

    function BoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeSphere_1 = class(TNodeGeneralShape_1)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdRadius: TSFFloat index 0 read GetFieldAsSFFloat;

    function LocalBoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeCoordinate3 = class(TVRMLNode)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdPoint: TMFVec3f index 0 read GetFieldAsMFVec3f;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  { Font family that can be specified by FontStyle node in family
    field. First three fields are equal (after casting by Ord) to
    three values of FSFAMILY_* constants. }
  TVRMLFontFamily = (ffSerif, ffSans, ffTypeWriter);

  TNodeFontStyle_1 = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdSize: TSFFloat index 0 read GetFieldAsSFFloat;
    property FdFamily: TSFEnum index 1 read GetFieldAsSFEnum;
    property FdStyle: TSFBitMask index 2 read GetFieldAsSFBitMask;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function Family: TVRMLFontFamily;
    function Bold: boolean;
    function Italic: boolean;
    function TTF_Font: PTrueTypeFont;
  end;

  TNodeInfo = class(TVRMLNode)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdString: TSFString index 0 read GetFieldAsSFString;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeLOD_1 = class(TVRMLNode)
  protected
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;

    property FdRange: TMFFloat index 0 read GetFieldAsMFFloat;
    property FdCenter: TSFVec3f index 1 read GetFieldAsSFVec3f;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeMaterial_1 = class(TVRMLNode)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdAmbientColor: TMFColor index 0 read GetFieldAsMFColor;
    property FdDiffuseColor: TMFColor index 1 read GetFieldAsMFColor;
    property FdSpecularColor: TMFColor index 2 read GetFieldAsMFColor;
    property FdEmissiveColor: TMFColor index 3 read GetFieldAsMFColor;
    property FdShininess: TMFFloat index 4 read GetFieldAsMFFloat;
    property FdTransparency: TMFFloat index 5 read GetFieldAsMFFloat;

    { pola dodane przeze mnie na potrzeby raytracerow na RGK }
    property FdMirror: TMFFloat index 6 read GetFieldAsMFFloat;
    property FdReflSpecular: TMFColor index 7 read GetFieldAsMFColor;
    property FdReflDiffuse: TMFColor index 8 read GetFieldAsMFColor;
    property FdTransSpecular: TMFColor index 9 read GetFieldAsMFColor;
    property FdTransDiffuse: TMFColor index 10 read GetFieldAsMFColor;
    property FdReflSpecularExp: TMFFloat index 11 read GetFieldAsMFFloat;
    property FdTransSpecularExp: TMFFloat index 12 read GetFieldAsMFFloat;

    property FdFogImmune: TSFBool index 13 read GetFieldAsSFBool;

    { ponizej sa funkcje do latwego wyciagania materialu z node'a material.
      De facto powinienes ich uzywac zawsze gdy zalezy ci na wyciagnieciu
      wartosci materialu. Te funkcje uwzgledniaja fakt ze pola moga byc
      zapisane zle (niezgodnie ze specyfik. VRMLa albo zgodnie ale w jakis
      szczegolny przypadek wymagajacy opakowania) - np. ze moze nie byc
      podanej zadnej wartosci dla ambient a my chcemy kolor numer zero
      (w tym przypadku zwracany jest defaultowy kolor ambient materialu VRMLa)
      albo ze moze nie byc wystarczajacej ilosci kolorow (wtedy bierzemy
      ostatni kolor).

      W przypadku czterech wartosci Trans/ReflSpecular/Diffuse
      te funkcje realizuja "wyliczanie" na podstawie innych pol materialu,
      tak jak opisalem w
      [http://camelot.homedns.org/~michalis/kambi_vrml_extensions.php].

      Funkcje zwracajace TVector4Single zwracaja [TVector3Single, Opacity].

      Transparency i Opacity sa zwracane w zakresie 0..1, przy czym
      Opacity = 1 - Transparency.

      ShininessExp to @italic(nieznormalizowany) wykladnik odbicia zwierciadlanego
      (dla modelu osw. Phonga) (mimo ze w VRMLu powinnismy dostac
      znormalizowany, tzn. w zakresie 0..1 reprezentujacym 0..128;
      ale nie widze szczerze mowiac sensu takiej normalizacji, wartosc
      128 nie jest (chyba?) zadna szczegolna wartoscia, to tylko taka
      ustalona granica powyzej ktorej i tak wartosci juz w zasadzie nie maja
      sensu (cos^128 to juz jest BARDZO waska gorka).
      W sumie dla usera zakres 0..1 moze byc po prostu wygodniejszy do myslenia
      (chociaz moze byc tez mylacy, bo roznice miedzy 1 a 0.5 w takiej konwencji
      trudno jakos okreslic jako "dwa razy wieksza') ale dla wszystkiego co
      chcielibysmy robic programowo zdecydowanie bedziemy potrzebowali
      nieznormalizowanej wartosci. }
    function AmbientColor3Single(MatNum: integer): TVector3Single;
    function AmbientColor4Single(MatNum: integer): TVector4Single;
    function DiffuseColor3Single(MatNum: integer): TVector3Single;
    function DiffuseColor4Single(MatNum: integer): TVector4Single;
    function SpecularColor3Single(MatNum: integer): TVector3Single;
    function SpecularColor4Single(MatNum: integer): TVector4Single;
    function EmissiveColor3Single(MatNum: integer): TVector3Single;
    function EmissiveColor4Single(MatNum: integer): TVector4Single;
    function Transparency(MatNum: integer): Single;
    function Opacity(MatNum: integer): Single;
    function Shininess(MatNum: integer): Single;
    function ShininessExp(MatNum: integer): Single;

    function Mirror(MatNum: integer): Single;
    function ReflSpecular (MatNum: integer): TVector3Single;
    function ReflDiffuse  (MatNum: integer): TVector3Single;
    function TransSpecular(MatNum: integer): TVector3Single;
    function TransDiffuse (MatNum: integer): TVector3Single;
    function ReflSpecularExp (MatNum: integer): Single;
    function TransSpecularExp(MatNum: integer): Single;

    { true oznacza ze ten material to specjalny przypadek o ktorym mowa w
      specyfikacji VRMLa : pola ambient, diffuse i specular maja dlugosc = 0
      a wiec nalezy uznac kolor Emissive za JUZ WYLICZONY ostateczny kolor.
      Powinienes wowczas odczytac tylko wartosc EmissiveColor i
      Transparency/Opacity (ujete w jednej prostej wartosci EmissiveColor4Single)
      i nie patrzec na inne wlasciwosci materialu. }
    function OnlyEmissiveMaterial: boolean;

    { true jesli wszystkie elementy pola FdTransparency sa ostro wieksze
      od zera  (od SingleEqualityEpsilon, tak naprawde).
      Pamietaj ze pole FdTransparency o Length = 0 jest zawsze traktowane
      jakby podano wartosc domyslna, tzn. [0], a wiec wtedy ta funkcja zwraca
      false (jest to sprzeczne z matematyczna (i intuicyjna) definicja
      kwalifikatora "all" ktora mowi ze "kazde zdanie kwalifikowane
      'dla kazdego' jest prawdziwe dla zbioru pustego") }
    function IsAllMaterialsTransparent: boolean;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeMaterialBinding = class(TVRMLNode)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdValue: TSFEnum index 0 read GetFieldAsSFEnum;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeNormalBinding = class(TVRMLNode)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdValue: TSFEnum index 0 read GetFieldAsSFEnum;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGeneralTexture = class(TVRMLNode)
  private
    { This is always <> nil.
      We use only IsNull to indicate whether we have or have not a texture here. }
    FTextureImage: TImage;
    FIsTextureLoaded: boolean;
  protected
    { This should loads actual image. It must return newly created TImage
      instance if texture could be loaded, or nil if no texture could
      be loaded. You do not care in this method about things like
      IsImageLoaded --- this method should just always,
      unconditionally, make everything it can do to load texture.

      You can use VRMLNonFatalError inside, so we're prepared
      that this may even exit with exception (since VRMLNonFatalError
      can raise exception).

      You have to return TRGBImage or TAlphaImage here,
      see TextureImage docs. }
    function LoadTextureImage: TImage; virtual; abstract;
  public
    constructor Create(const ANodeName: string;
      const AWWWBasePath: string); override;
    destructor Destroy; override;

    { Pierwsze uzycie TextureImage spowoduje ze tekstura zostanie automatycznie
      zaladowana na podstawie pol obiektu.

      IsTextureLoaded mowi czy nastepne uzycie TextureImage spowoduje
      ReloadTexture, a wiec potencjalnie siegniecie do pliku
      (a takze blad VRMLNonFatalError jesli plik nie istnieje/nie mozna
      go odczytac itp.).

      IsTextureImage <=> not TextureImage.IsNull, a wiec samo
      uzycie IsTextureImage powoduje automatycznie zaladowanie tekstury
      (i ustawienie IsTextureLoaded na true).

      Dzieki temu mechanizmowi w standardowej sytuacji, tzn. gdy nigdy
      nie uzyjesz w programie ReloadTexture, blad w rodzaju
      "texture file foo.png does not exist" bedzie zgloszony do VRMLNonFatalError
      tylko raz --- za kazdym nastepnym razem IsTextureImage = false ale
      IsTextureLoaded = true wiec odwolania do TextureImage beda po prostu
      zwracac ImageNone.

      TextureImage class  always in (TRGBImage, TAlphaImage)
      po prostu dlatego ze takie sa formaty akceptowane w KambiGLUtils.
      TODO: to nie jest eleganckie, przeciez nie chcemy zeby OpenGL
      wplywal na ten modul nawet w taki subtelny sposob. }
    function TextureImage: TImage;
    function IsTextureImage: boolean; { = not TextureImage.IsNull }
    property IsTextureLoaded: boolean read FIsTextureLoaded;
    procedure ReloadTexture;

    { Krotki opis tego jak zdefiniowana jest tekstura. none jesli nie
      zdefiniowana, jakie jest filename, jakie jest inline. NIE okresla
      jak i jaka tekstura jest zaladowana. }
    function TextureDescription: string; virtual; abstract;

    function RepeatS: boolean; virtual; abstract;
    function RepeatT: boolean; virtual; abstract;
  end;

  TNodeTexture2 = class(TNodeGeneralTexture)
  protected
    { Texture in this class is loaded z pliku (pole filename)
      lub inlined (pole image). Pierwszenstwo ma tekstura z pliku,
      jesli filename = '' (lub wystapi jakis blad przy ladowaniu z filename
      ale VRMLNonFatalError to zignoruje) to zostanie uzyta tekstura inline.
      Jezeli nie ma tekstury inline i nie ma prawidlowego filename to tekstura
      zostanie zaladowana jako ImageNone. To ostatnie stwierdzenie ma
      znaczenie: mowi ono ze IsTextureImage znaczy co innego niz
      IsTextureLoaded.

      BTW, in VRML 1.0 taki node z IsTextureLoaded = true i
      IsTextureImage = false tez ma swoje znaczenie:
      oznacza "wylacz aktywna teksture". }
    function LoadTextureImage: TImage; override;
  public
    constructor Create(const ANodeName: string;
      const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;

    property FdFilename: TSFString index 0 read GetFieldAsSFString;
    property FdImage: TSFImage index 1 read GetFieldAsSFImage;
    property FdWrapS: TSFEnum index 2 read GetFieldAsSFEnum;
    property FdWrapT: TSFEnum index 3 read GetFieldAsSFEnum;

    { Ignored fields -- they are not part of VRML 1.0 spec
      and I was not able to find any spec for them on the net.
      But some models ([http://www-vrl.umich.edu/sel_prj/EECS498/])
      use them. }
    property FdModel: TSFEnum index 4 read GetFieldAsSFEnum;
    property FdBlendColor: TSFVec3f index 5 read GetFieldAsSFVec3f;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function TextureDescription: string; override;
    function RepeatS: boolean; override;
    function RepeatT: boolean; override;
  end;

  TNodeTexture2Transform = class(TVRMLNode)
  protected
    procedure MiddleTraverse(State: TVRMLGraphTraverseState); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdTranslation: TSFVec2f index 0 read GetFieldAsSFVec2f;
    property FdRotation: TSFFloat index 1 read GetFieldAsSFFloat;
    property FdScaleFactor: TSFVec2f index 2 read GetFieldAsSFVec2f;
    property FdCenter: TSFVec2f index 3 read GetFieldAsSFVec2f;
    function TextureMatrixTransformation: TMatrix4Single;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeTextureCoordinate2 = class(TVRMLNode)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdPoint: TMFVec2f index 0 read GetFieldAsMFVec2f;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeShapeHints = class(TVRMLNode)
  private
    function TryParseSpecialField(Lexer: TVRMLLexer;
      NodeNameBinding: TStringList): boolean; override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdVertexOrdering: TSFenum index 0 read GetFieldAsSFEnum;
    property FdShapeType: TSFEnum index 1 read GetFieldAsSFEnum;
    property FdFaceType: TSFEnum index 2 read GetFieldAsSFEnum;
    property FdCreaseAngle: TSFFloat index 3 read GetFieldAsSFFloat;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  { TNodeGeneralTransformation - wspolna klasa dla wszystkich node'ow ktorych
    jedynym celem jest zmodyfikowac aktualna macierz modelview.
    Wystarczy ze w kazdej z podklas napiszesz funkcje MatrixTransform: TMatrix4f
    no i oczywiscie zainicjujesz pola danego node'a. }
  TNodeGeneralTransformation = class(TVRMLNode)
  protected
    procedure MiddleTraverse(State: TVRMLGraphTraverseState); override;
  public
    function MatrixTransformation: TMatrix4Single; virtual; abstract;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeMatrixTransform = class(TNodeGeneralTransformation)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdMatrix: TSFMatrix index 0 read GetFieldAsSFMatrix;
    function MatrixTransformation: TMatrix4Single; override;
  end;

  TNodeRotation = class(TNodeGeneralTransformation)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdRotation: TSFRotation index 0 read GetFieldAsSFRotation;
    function MatrixTransformation: TMatrix4Single; override;
  end;

  { This node is actually from Inventor. It's not in VRML 1.0 spec.
    But some invalid VRML 1.0 models use it,
    e.g. [http://www-vrl.umich.edu/sel_prj/EECS498/]. }
  TNodeRotationXYZ = class(TNodeGeneralTransformation)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdAxis: TSFEnum index 0 read GetFieldAsSFEnum;
    property FdAngle: TSFFloat index 1 read GetFieldAsSFFloat;
    function MatrixTransformation: TMatrix4Single; override;
  end;

  TNodeScale = class(TNodeGeneralTransformation)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdScaleFactor: TSFVec3f index 0 read GetFieldAsSFVec3f;
    function MatrixTransformation: TMatrix4Single; override;
  end;

  TNodeTransform_1 = class(TNodeGeneralTransformation)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdTranslation: TSFVec3f index 0 read GetFieldAsSFVec3f;
    property FdRotation: TSFRotation index 1 read GetFieldAsSFRotation;
    property FdScaleFactor: TSFVec3f index 2 read GetFieldAsSFVec3f;
    property FdScaleOrientation: TSFRotation index 3 read GetFieldAsSFRotation;
    property FdCenter: TSFVec3f index 4 read GetFieldAsSFVec3f;
    function MatrixTransformation: TMatrix4Single; override;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;
  end;

  TNodeTranslation = class(TNodeGeneralTransformation)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdTranslation: TSFVec3f index 0 read GetFieldAsSFVec3f;
    function MatrixTransformation: TMatrix4Single; override;
  end;

  TVRMLCameraKind = (ckOrthographic, ckPerspective);

  { A common class for both VRML 1.0 camera nodes and VRML 2.0 Viewpoint
    node. }
  TNodeGeneralViewpoint = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    property FdPosition: TSFVec3f index 0 read GetFieldAsSFVec3f;
    property FdOrientation: TSFRotation index 1 read GetFieldAsSFRotation;
    property FdDirection: TMFVec3f index 2 read GetFieldAsMFVec3f;
    property FdUp: TMFVec3f index 3 read GetFieldAsMFVec3f;

    class function CameraKind: TVRMLCameraKind; virtual; abstract;

    { Oblicz CamPos, Dir, Up na podstawie aktualnych ustawien kamery - zgodnie
      ze specyfikacja VRMLa,

@preformatted(
  CamPos = FdPosition,
  CamDir = (0, 0, -1) rotated by FdOrientation,
  CamUp = (0, 1, 0) rotated by FdOrientation,
  and CamPos, Dir, Up are transformed by given CamTransform.
)
      (you should give here the actual VRML transformation at the point in file
      where camera is defined).

      Dodajemy do tego dodatki Kambiego :
      jesli FdDirection.Length > 0 to CamDirection nie jest liczone z
      FdOrientation ale jest brane wprost z FdDirection.Items[0].
      Podobnie dla FdUp.

      Zwraca zawsze znormalizowany CamDir i CamUp bo:
      @orderedList(
        @item(
          zeby zmusic cie do stosowania konsekwentnej zasady wyrazonej na
          poczatku VRMLNodes i nie pisania kodu ktory w jakis sposob bylby
          uzalezniony od podawanych tu CamDir. To dlatego ze
          pola FdOrientation / FdDirection / FdUp tego wezla NIE sluza do
          podawania czegokolwiek poza kierunkami, a wiec ich dlugosc jest
          niewazna. No i stosujac FdOrientation, a wiec uzywajac standardowego
          VRMLa 1.0, nie mozna nawet podac dlugosci FdDirection/FdUp innej
          niz 1.)
        @item(
          Normalizujemy tutaj bo w implementacji tej funkcji czesto wiemy
          ze nie trzeba normalizowac, np. gdy zwracamy standardowe dir/up
          kamery obrocone o orientation to nie potrzebujemy robic zadnej
          normalizacji bo wiemy ze wynik ma dlugosc 1. W ten sytuacji byloby
          nieoptymalne gdybys musial po wywolaniu tej procedury wywolac
          NormalizeTo1st(CamDir), bo przeciez czesto w ponizszej procedurze
          wiadomo ze nie trzea normalizowac (a wiec wywolanie NormalizeTo1st
          i wywolywany w jego srodku Sqrt sa zbedne).)
      )

      TODO: FocalDistance powinien tez byc tu zwracany (po przeliczeniu
      przez CamTransform) for TNodeGeneralVRML1Camera. }
    procedure GetCameraVectors(const CamTransform: TMatrix4Single;
      out CamPos, CamDir, CamUp: TVector3Single);
  end;

  TNodeGeneralViewpointClass = class of TNodeGeneralViewpoint;

  { GeneralCamera - wspolna klasa dla wszystkich kamer VRML'a. }
  TNodeGeneralVRML1Camera = class(TNodeGeneralViewpoint)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;

    property FdFocalDistance: TSFFloat index 4 read GetFieldAsSFFloat;
    property FdHeightAngle: TSFFloat index 5 read GetFieldAsSFFloat;

    { Ignored fields -- they are not part of VRML 1.0 spec
      and I was not able to find any spec for them on the net.
      But some models ([http://www-vrl.umich.edu/sel_prj/EECS498/])
      use them. }
    property FdNearDistance: TSFFloat index 6 read GetFieldAsSFFloat;
    property FdFarDistance: TSFFloat index 7 read GetFieldAsSFFloat;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeOrthographicCamera = class(TNodeGeneralVRML1Camera)
    class function ClassNodeTypeName: string; override;
    class function CameraKind: TVRMLCameraKind; override;
  end;

  TNodePerspectiveCamera = class(TNodeGeneralVRML1Camera)
    class function ClassNodeTypeName: string; override;
    class function CameraKind: TVRMLCameraKind; override;
  end;

  TNodeGeneralLight = class(TVRMLNode)
  protected
    procedure MiddleTraverse(State: TVRMLGraphTraverseState); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    property FdOn: TSFBool index 0 read GetFieldAsSFBool;
    property FdIntensity: TSFFloat index 1 read GetFieldAsSFFloat;
    property FdColor: TSFColor index 2 read GetFieldAsSFColor;
    property FdAmbientIntensity: TSFFloat index 3 read GetFieldAsSFFloat;
  end;

  TObjectsListItem_1 = TNodeGeneralLight;
  {$I objectslist_1.inc}
  TNodeGeneralLightsList = class(TObjectsList_1);

  TNodeGeneralDirectionalLight = class(TNodeGeneralLight)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdDirection: TSFVec3f index 4 read GetFieldAsSFVec3f;
  end;

  TNodeDirectionalLight_1 = class(TNodeGeneralDirectionalLight)
    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGeneralPositionalLight = class(TNodeGeneralLight)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    property FdLocation: TSFVec3f index 4 read GetFieldAsSFVec3f;
    property FdAttenuation: TSFVec3f index 5 read GetFieldAsSFVec3f;

    { Attenuation obliczaja attenuation (tzn. wzorek 1/max( attenuation[0] + ...)
      zgodnie ze specyfik. VRMLa 97. Poniewaz obliczenie parametru DistanceToLight
      moze czasem wiazac sie ze spora strata czasu mozesz sprawdzic najpierw
      wartosc DistanceNeededForAttenuation --- jezeli jest false, to wartosc
      parametru DistanceToLight dla Attenutaion() nie ma znaczenia (mozesz
      podac cokolwiek).

      PAMIETAJ --- DistanceToLight powinien byc w lights coordinate system.
      TODO: raytracer nie realizuje teraz tego "PAMIETAJ" powyzej
      TODO: nie wiem czy OpenGL realizuje to "PAMIETAJ" powyzej
      w swoich swiatlach, check w OpenGL spec }
    function DistanceNeededForAttenuation: boolean;
    function Attenuation(const DistanceToLight: Single): Single; overload;
    function Attenuation(const DistanceToLight: Double): Double; overload;
  end;

  TNodeGeneralPointLight = class(TNodeGeneralPositionalLight)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
  end;

  TNodePointLight_1 = class(TNodeGeneralPointLight)
    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeSpotLight_1 = class(TNodeGeneralPositionalLight)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdDirection: TSFVec3f index 6 read GetFieldAsSFVec3f;
    property FdDropOffRate: TSFFloat index 7 read GetFieldAsSFFloat;
    property FdCutOffAngle: TSFFloat index 8 read GetFieldAsSFFloat;

    { nieznormalizowany wykladnik dla spot'a (na podstawie dropOffRate) }
    function SpotExp: Single;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGroup_1 = class(TVRMLNode)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  { A Group node that is added when VRML file contains more than one root
    node. See comments at the beginning of this unit for more info. }
  TNodeGroupHidden_1 = class(TNodeGroup_1)
  end;

  { A general class that can ce used as a separator, something that
    pushes and pops all attribs and matrices.
    It is used in implementation of Separator and WWWAnchor.
    Also WWWInline does the same work, when it's "separate" field is true. }
  TNodeGeneralSeparator = class(TVRMLNode)
  private
    OriginalState: TVRMLGraphTraverseState;
  protected
    procedure BeforeTraverse(var State: TVRMLGraphTraverseState); override;
    procedure AfterTraverse(var State: TVRMLGraphTraverseState); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeSeparator = class(TNodeGeneralSeparator)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdRenderCulling: TSFEnum index 0 read GetFieldAsSFEnum;
  end;

  TNodeSwitch_1 = class(TVRMLNode)
  protected
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdWhichChild: TSFLong index 0 read GetFieldAsSFLong;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeTransformSeparator = class(TVRMLNode)
  private
    OriginalMatrix: TMatrix4Single;
  protected
    procedure BeforeTraverse(var State: TVRMLGraphTraverseState); override;
    procedure AfterTraverse(var State: TVRMLGraphTraverseState); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  { TODO: node anchor dziala jak Separator, wartosci jego pol nie maja
    nigdzie zadnego znaczenia. Trzebaby to zaimplementowac, co wymaga
    1) TURLDataStream, patrz komentarz przy TNodeWWWInline
    2) mechaznimu picking - to juz mamy w view3dscene }
  TNodeWWWAnchor = class(TNodeGeneralSeparator)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdName: TSFString index 0 read GetFieldAsSFString;
    property FdDescription: TSFString index 0 read GetFieldAsSFString;
    property FdMap: TSFEnum index 0 read GetFieldAsSFEnum;
  end;

  INodeGeneralInline = interface
    { Call LoadInlined to load Inlined NOW. If Inlined is already loaded,
      than : if CanReload = true Inlined will be freed and loaded again,
      else (if CanReload = false) nothing will happen.

      LoadInlined(false) will be called automatically in BeforeTraverse. }
    procedure LoadInlined(CanReload: boolean);
  end;

  { gdy chcemy operowac na scenie juz po jej zaladowaniu, bezposrednio
    lub poprzez metode w rodzaju TVRMLNode.EnumerateNodes, jest istotne
    gdzie w hierarchii sceny znajduja sie Inlined nodes. Odpowiadam :
    sa one SubNode'ami WWWInline. Mozesz testowac ChildrenCount <> 0
    aby sprawdzic czy Inlined zostaly juz zaladowane. Mozesz
    zazadac ich natychmiastowego zaladowania uzywajac LoadInlined.

    TODO : naturalnie tylko FdName jako nazwa pliku na lokalnym
    systemie plikow jest obslugiwana chwilowo. W ogole, generalnie
    to fajnie byloby gdyby TVRMLScene.Create przyjmowalo URL a nie
    filename albo jeszcze lepiej gdyby miec strumien TURLDataStream
    ktory moze podawac dane identyfikowane przez URL...
    Moze nie w najblizszym czasie, ale zamierzam cos takiego kiedys
    zaimplementowac - szkielet (dla http) juz zrobilem w iswb. }
  TNodeWWWInline = class(TVRMLNode, INodeGeneralInline)
  private
    OriginalState: TVRMLGraphTraverseState;
    BeforeTraversePushedState: boolean;
  protected
    procedure BeforeTraverse(var State: TVRMLGraphTraverseState); override;
    procedure AfterTraverse(var State: TVRMLGraphTraverseState); override;
  public
    procedure LoadInlined(CanReload: boolean);

    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdName: TSFString index 0 read GetFieldAsSFString;
    property FdBboxSize: TSFVec3f index 1 read GetFieldAsSFVec3f;
    property FdBboxCenter: TSFVec3f index 2 read GetFieldAsSFVec3f;
    property FdSeparate: TSFBool index 3 read GetFieldAsSFBool;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    class function ChildrenSaveToStream: boolean; override;
  end;

  TNodeKambiTriangulation = class(TVRMLNode)
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;

    property FdQuadricSlices: TSFLong index 0 read GetFieldAsSFLong;
    property FdQuadricStacks: TSFLong index 1 read GetFieldAsSFLong;
    property FdRectDivisions: TSFLong index 2 read GetFieldAsSFLong;

    { zwracaja wartosc z odpowiedniego pola FdXxx lub,
      jesli ta wartosc jest -1, zwracaja Detail_Xxx.

      (Jesli ta wartosc jest nieprawidlowa to wywoluja VRMLNonFatalError
      a potem "po cichu" zmieniaja ta wartosc na wartosc wzieta z Detail_Xxx.
      A wiec poprawiaja blednego VRMLa.) }
    function QuadricStacks: Cardinal;
    function QuadricSlices: Cardinal;
    function RectDivisions: Cardinal;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  { Alphabetically, all VRML 97 nodes }

  { }
  { This is a VRML 2.0 grouping node.
    This will push/pop full TVRMLGraphTraverseState
    in Before/AfterTraverse. }
  TNodeGeneralGrouping = class(TVRMLNode)
  private
    OriginalState: TVRMLGraphTraverseState;
  protected
    procedure BeforeTraverse(var State: TVRMLGraphTraverseState); override;
    procedure AfterTraverse(var State: TVRMLGraphTraverseState); override;
  end;

  TNodeAnchor = class(TNodeGeneralGrouping)
  protected
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      MFNode   addChildren } { }
    { eventIn      MFNode   removeChildren } { }
    property Fdchildren: TMFNode index 0 read GetFieldAsMFNode;
    property Fddescription: TSFString index 1 read GetFieldAsSFString;
    property Fdparameter: TMFString index 2 read GetFieldAsMFString;
    property Fdurl: TMFString index 3 read GetFieldAsMFString;
    property FdbboxCenter: TSFVec3f index 4 read GetFieldAsSFVec3f;
    property FdbboxSize: TSFVec3f index 5 read GetFieldAsSFVec3f;

    function ChildrenField: TMFNode; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeAppearance = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdmaterial: TSFNode index 0 read GetFieldAsSFNode;
    property Fdtexture: TSFNode index 1 read GetFieldAsSFNode;
    property FdtextureTransform: TSFNode index 2 read GetFieldAsSFNode;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeAudioClip = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fddescription: TSFString index 0 read GetFieldAsSFString;
    property Fdloop: TSFBool index 1 read GetFieldAsSFBool;
    property Fdpitch: TSFFloat index 2 read GetFieldAsSFFloat;
    property FdstartTime: TSFTime index 3 read GetFieldAsSFTime;
    property FdstopTime: TSFTime index 4 read GetFieldAsSFTime;
    property Fdurl: TMFString index 5 read GetFieldAsMFString;
    { eventOut       SFTime   duration_changed } { }
    { eventOut       SFBool   isActive } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeBackground = class(TVRMLNode)
  private
    FBgImagesLoaded: boolean; { = false }

    { if not FBgImagesLoaded it should be always equal to BackgroundImagesNone
      (this is not important for interface of this class but we will use
      this in our implementation) }
    FBgImages: TBackgroundImages;

    FAllowedBgImagesClasses: TDynArrayImageClasses;
    function GetBgImages: TBackgroundImages;
    procedure UnloadImages;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    destructor Destroy; override;
    class function ClassNodeTypeName: string; override;

    { eventIn      SFBool   set_bind } { }
    property FdGroundAngle: TMFFloat index 0 read GetFieldAsMFFloat;
    property FdGroundColor: TMFColor index 1 read GetFieldAsMFColor;
    property FdBackUrl: TMFString index 2 read GetFieldAsMFString;
    property FdBottomUrl: TMFString index 3 read GetFieldAsMFString;
    property FdFrontUrl: TMFString index 4 read GetFieldAsMFString;
    property FdLeftUrl: TMFString index 5 read GetFieldAsMFString;
    property FdRightUrl: TMFString index 6 read GetFieldAsMFString;
    property FdTopUrl: TMFString index 7 read GetFieldAsMFString;
    property FdSkyAngle: TMFFloat index 8 read GetFieldAsMFFloat; {  [0, Pi] }
    property FdSkyColor: TMFColor index 9 read GetFieldAsMFColor; {  [0, 1] }
    { eventOut     SFBool   isBound } { }

    procedure Parse(Lexer: TVRMLLexer; NodeNameBinding: TStringList); override;

    { Pierwsze uzycie BgImages (albo pierwsze uzycie BgImages po Parse)
      automatycznie zaladuje obrazki z URLi
      BackUrl/BottomUrl itd. Obrazki dla ktorych zaden osiagalny URL nie byl
      podany zostana ustawione na ImageNone.
      Obrazki beda mialy Kind wsrod AllowedBgImagesKinds.

      Obrazki beda zawsze odpowiadaly URLom w polach Fd*Url - dlatego po
      zrobieniu Parse na tym obiekcie nastepne wywolanie BgImages bedzie
      ladowalo je od nowa. }
    property BgImages: TBackgroundImages read GetBgImages;

    { Czy obrazki juz sa zaladowane ? W zasadzie ta funkcja nigdy nie powinna
      ci byc potrzebna skoro cale ladowanie / zwalnianie obrazkow jest
      robione automatycznie. Ale moze ci przydac : ona mowi czy najblizsze
      wywolanie BgImages wywola ReloadBgImages czy nie. }
    property BgImagesLoaded: boolean read FBgImagesLoaded;

    { Wymusza przeladowanie obrazkow BgImages, nawet jesli BgImages zostalo
      juz raz wywolane (a wiec obrazki juz raz zostaly zaladowane).
      Uzywaj np. jezeli podejrzewasz ze zawartosc obrazkow zmienila sie
      na dysku. }
    procedure ReloadBgImages;

    { Wszystkie obrazki na BgImages (ktore nie sa nil) maja zawsze
      klase wsrod AllowedBgImagesClasses.

      Aby zapewnic ze to stwierdzenie zawsze zachodzi jezeli BgImages zostalo
      juz chociaz raz wywolane to zmiana AllowedBgImagesClasses spowoduje
      uniewaznienie BgImages (tzn. nastepne wywolanie BgImages bedzie
      musialo przeladowac obrazki od nowa) }
    property AllowedBgImagesClasses: TDynArrayImageClasses
      read FAllowedBgImagesClasses; { = [], so all image classes are allowed }
    procedure SetAllowedBgImagesClasses(const Value: array of TImageClass);

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeBillboard = class(TNodeGeneralGrouping)
  protected
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      MFNode   addChildren } { }
    { eventIn      MFNode   removeChildren } { }
    property FdaxisOfRotation: TSFVec3f index 0 read GetFieldAsSFVec3f;
    property Fdchildren: TMFNode index 1 read GetFieldAsMFNode;
    property FdbboxCenter: TSFVec3f index 2 read GetFieldAsSFVec3f;
    property FdbboxSize: TSFVec3f index 3 read GetFieldAsSFVec3f;

    function ChildrenField: TMFNode; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeBox = class(TNodeGeneralShape)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdsize: TSFVec3f index 0 read GetFieldAsSFVec3f;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function LocalBoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeCollision = class(TNodeGeneralGrouping)
  protected
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      MFNode   addChildren } { }
    { eventIn      MFNode   removeChildren } { }
    property Fdchildren: TMFNode index 0 read GetFieldAsMFNode;
    property Fdcollide: TSFBool index 1 read GetFieldAsSFBool;
    property FdbboxCenter: TSFVec3f index 2 read GetFieldAsSFVec3f;
    property FdbboxSize: TSFVec3f index 3 read GetFieldAsSFVec3f;
    property Fdproxy: TSFNode index 4 read GetFieldAsSFNode;
    { eventOut     SFTime   collideTime } { }

    function ChildrenField: TMFNode; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeColor = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdcolor: TMFColor index 0 read GetFieldAsMFColor;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeColorInterpolator = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      SFFloat set_fraction } { }
    property Fdkey: TMFFloat index 0 read GetFieldAsMFFloat;
    property FdkeyValue: TMFColor index 1 read GetFieldAsMFColor;
    { eventOut     SFColor value_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeCone_2 = class(TNodeGeneralShape)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdbottomRadius: TSFFloat index 0 read GetFieldAsSFFloat;
    property Fdheight: TSFFloat index 1 read GetFieldAsSFFloat;
    property Fdside: TSFBool index 2 read GetFieldAsSFBool;
    property Fdbottom: TSFBool index 3 read GetFieldAsSFBool;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function BoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeContour2D = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      MFNode  addChildren } { }
    { eventIn      MFNode  removeChildren } { }
    property Fdchildren: TMFNode index 0 read GetFieldAsMFNode;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeCoordinate = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdpoint: TMFVec3f index 0 read GetFieldAsMFVec3f;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeCoordinateDeformer = class(TNodeGeneralGrouping)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      MFNode   addChildren } { }
    { eventIn      MFNode   removeChildren } { }
    property Fdchildren: TMFNode index 0 read GetFieldAsMFNode;
    property FdcontrolPoint: TMFVec3f index 1 read GetFieldAsMFVec3f;
    property FdinputCoord: TMFNode index 2 read GetFieldAsMFNode;
    property FdinputTransform: TMFNode index 3 read GetFieldAsMFNode;
    property FdoutputCoord: TMFNode index 4 read GetFieldAsMFNode;
    property Fdweight: TMFFloat index 5 read GetFieldAsMFFloat;
    property FdbboxCenter: TSFVec3f index 6 read GetFieldAsSFVec3f;
    property FdbboxSize: TSFVec3f index 7 read GetFieldAsSFVec3f;
    property FduDimension: TSFInt32 index 8 read GetFieldAsSFInt32;
    property FduKnot: TMFFloat index 9 read GetFieldAsMFFloat;
    property FduOrder: TSFInt32 index 10 read GetFieldAsSFInt32;
    property FdvDimension: TSFInt32 index 11 read GetFieldAsSFInt32;
    property FdvKnot: TMFFloat index 12 read GetFieldAsMFFloat;
    property FdvOrder: TSFInt32 index 13 read GetFieldAsSFInt32;
    property FdwDimension: TSFInt32 index 14 read GetFieldAsSFInt32;
    property FdwKnot: TMFFloat index 15 read GetFieldAsMFFloat;
    property FdwOrder: TSFInt32 index 16 read GetFieldAsSFInt32;

    function ChildrenField: TMFNode; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeCoordinateInterpolator = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      SFFloat set_fraction } { }
    property Fdkey: TMFFloat index 0 read GetFieldAsMFFloat;
    property FdkeyValue: TMFVec3f index 1 read GetFieldAsMFVec3f;
    { eventOut     MFVec3f value_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeCylinder_2 = class(TNodeGeneralShape)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdbottom: TSFBool index 0 read GetFieldAsSFBool;
    property Fdheight: TSFFloat index 1 read GetFieldAsSFFloat;
    property Fdradius: TSFFloat index 2 read GetFieldAsSFFloat;
    property Fdside: TSFBool index 3 read GetFieldAsSFBool;
    property Fdtop: TSFBool index 4 read GetFieldAsSFBool;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function LocalBoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeCylinderSensor = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdautoOffset: TSFBool index 0 read GetFieldAsSFBool;
    property FddiskAngle: TSFFloat index 1 read GetFieldAsSFFloat;
    property Fdenabled: TSFBool index 2 read GetFieldAsSFBool;
    property FdmaxAngle: TSFFloat index 3 read GetFieldAsSFFloat;
    property FdminAngle: TSFFloat index 4 read GetFieldAsSFFloat;
    property Fdoffset: TSFFloat index 5 read GetFieldAsSFFloat;
    { eventOut     SFBool     isActive } { }
    { eventOut     SFRotation rotation_changed } { }
    { eventOut     SFVec3f    trackPoint_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeDirectionalLight_2 = class(TNodeGeneralDirectionalLight)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeElevationGrid = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      MFFloat  set_height } { }
    property Fdcolor: TSFNode index 0 read GetFieldAsSFNode;
    property Fdnormal: TSFNode index 1 read GetFieldAsSFNode;
    property FdtexCoord: TSFNode index 2 read GetFieldAsSFNode;
    property Fdheight: TMFFloat index 3 read GetFieldAsMFFloat;
    property Fdccw: TSFBool index 4 read GetFieldAsSFBool;
    property FdcolorPerVertex: TSFBool index 5 read GetFieldAsSFBool;
    property FdcreaseAngle: TSFFloat index 6 read GetFieldAsSFFloat;
    property FdnormalPerVertex: TSFBool index 7 read GetFieldAsSFBool;
    property Fdsolid: TSFBool index 8 read GetFieldAsSFBool;
    property FdxDimension: TSFInt32 index 9 read GetFieldAsSFInt32;
    property FdxSpacing: TSFFloat index 10 read GetFieldAsSFFloat;
    property FdzDimension: TSFInt32 index 11 read GetFieldAsSFInt32;
    property FdzSpacing: TSFFloat index 12 read GetFieldAsSFFloat;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeExtrusion = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn MFVec2f    set_crossSection } { }
    { eventIn MFRotation set_orientation } { }
    { eventIn MFVec2f    set_scale } { }
    { eventIn MFVec3f    set_spine } { }
    property FdbeginCap: TSFBool index 0 read GetFieldAsSFBool;
    property Fdccw: TSFBool index 1 read GetFieldAsSFBool;
    property Fdconvex: TSFBool index 2 read GetFieldAsSFBool;
    property FdcreaseAngle: TSFFloat index 3 read GetFieldAsSFFloat;
    property FdcrossSection: TMFVec2f index 4 read GetFieldAsMFVec2f;
    property FdendCap: TSFBool index 5 read GetFieldAsSFBool;
    property Fdorientation: TMFRotation index 6 read GetFieldAsMFRotation;
    property Fdscale: TMFVec2f index 7 read GetFieldAsMFVec2f;
    property Fdsolid: TSFBool index 8 read GetFieldAsSFBool;
    property Fdspine: TMFVec3f index 9 read GetFieldAsMFVec3f;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeFog = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdcolor: TSFColor index 0 read GetFieldAsSFColor;
    property FdfogType: TSFString index 1 read GetFieldAsSFString;
    property FdvisibilityRange: TSFFloat index 2 read GetFieldAsSFFloat;
    property FdVolumetric: TSFBool index 3 read GetFieldAsSFBool;
    property FdVolumetricDirection: TSFVec3f index 4 read GetFieldAsSFVec3f;
    property FdVolumetricVisibilityStart: TSFFloat index 5 read GetFieldAsSFFloat;
    { eventIn      SFBool   set_bind } { }
    { eventOut     SFBool   isBound } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeFontStyle_2 = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdfamily: TMFString index 0 read GetFieldAsMFString;
    property Fdhorizontal: TSFBool index 1 read GetFieldAsSFBool;
    property Fdjustify: TMFString index 2 read GetFieldAsMFString;
    property Fdlanguage: TSFString index 3 read GetFieldAsSFString;
    property FdleftToRight: TSFBool index 4 read GetFieldAsSFBool;
    property Fdsize: TSFFloat index 5 read GetFieldAsSFFloat;
    property Fdspacing: TSFFloat index 6 read GetFieldAsSFFloat;
    property Fdstyle: TSFString index 7 read GetFieldAsSFString;
    property FdtopToBottom: TSFBool index 8 read GetFieldAsSFBool;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function Family: TVRMLFontFamily;
    function Bold: boolean;
    function Italic: boolean;
    function Justify: TVRMLFontJustify;
    function TTF_Font: PTrueTypeFont;

    class function DefaultSize: Single;
    class function DefaultSpacing: Single;
    class function DefaultFamily: TVRMLFontFamily;
    class function DefaultBold: boolean;
    class function DefaultItalic: boolean;
    class function DefaultJustify: TVRMLFontJustify;
    class function DefaultTTF_Font: PTrueTypeFont;
  end;

  TNodeGeoCoordinate = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdgeoOrigin: TSFNode index 0 read GetFieldAsSFNode;
    property FdgeoSystem: TMFString index 1 read GetFieldAsMFString;
    property Fdpoint: TMFString index 2 read GetFieldAsMFString;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGeoElevationGrid = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn        MFFloat    set_height } { }
    { eventIn        SFFloat    set_yScale } { }
    property Fdcolor: TSFNode index 0 read GetFieldAsSFNode;
    property Fdnormal: TSFNode index 1 read GetFieldAsSFNode;
    property FdtexCoord: TSFNode index 2 read GetFieldAsSFNode;
    property Fdccw: TSFBool index 3 read GetFieldAsSFBool;
    property FdcolorPerVertex: TSFBool index 4 read GetFieldAsSFBool;
    property FdcreaseAngle: TSFFloat index 5 read GetFieldAsSFFloat;
    property FdgeoOrigin: TSFNode index 6 read GetFieldAsSFNode;
    property FdgeoSystem: TMFString index 7 read GetFieldAsMFString;
    property FdgeoGridOrigin: TSFString index 8 read GetFieldAsSFString;
    property Fdheight: TMFFloat index 9 read GetFieldAsMFFloat;
    property FdnormalPerVertex: TSFBool index 10 read GetFieldAsSFBool;
    property Fdsolid: TSFBool index 11 read GetFieldAsSFBool;
    property FdxDimension: TSFInt32 index 12 read GetFieldAsSFInt32;
    property FdxSpacing: TSFString index 13 read GetFieldAsSFString;
    property FdyScale: TSFFloat index 14 read GetFieldAsSFFloat;
    property FdzDimension: TSFInt32 index 15 read GetFieldAsSFInt32;
    property FdzSpacing: TSFString index 16 read GetFieldAsSFString;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGeoLocation = class(TNodeGeneralGrouping)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdgeoCoords: TSFString index 0 read GetFieldAsSFString;
    property Fdchildren: TMFNode index 1 read GetFieldAsMFNode;
    property FdgeoOrigin: TSFNode index 2 read GetFieldAsSFNode;
    property FdgeoSystem: TMFString index 3 read GetFieldAsMFString;

    function ChildrenField: TMFNode; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGeoLOD = class(TNodeGeneralGrouping)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdcenter: TSFString index 0 read GetFieldAsSFString;
    property Fdchild1Url: TMFString index 1 read GetFieldAsMFString;
    property Fdchild2Url: TMFString index 2 read GetFieldAsMFString;
    property Fdchild3Url: TMFString index 3 read GetFieldAsMFString;
    property Fdchild4Url: TMFString index 4 read GetFieldAsMFString;
    property FdgeoOrigin: TSFNode index 5 read GetFieldAsSFNode;
    property FdgeoSystem: TMFString index 6 read GetFieldAsMFString;
    property Fdrange: TSFFloat index 7 read GetFieldAsSFFloat;
    property FdrootUrl: TMFString index 8 read GetFieldAsMFString;
    property FdrootNode: TMFNode index 9 read GetFieldAsMFNode;
    { eventOut   MFNode    children } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGeoMetadata = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fddata: TMFNode index 0 read GetFieldAsMFNode;
    property Fdsummary: TMFString index 1 read GetFieldAsMFString;
    property Fdurl: TMFString index 2 read GetFieldAsMFString;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGeoOrigin = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdgeoSystem: TMFString index 0 read GetFieldAsMFString;
    property FdgeoCoords: TSFString index 1 read GetFieldAsSFString;
    property FdrotateYUp: TSFBool index 2 read GetFieldAsSFBool;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGeoPositionInterpolator = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn   SFFloat   set_fraction } { }
    property FdgeoOrigin: TSFNode index 0 read GetFieldAsSFNode;
    property FdgeoSystem: TMFString index 1 read GetFieldAsMFString;
    property Fdkey: TMFFloat index 2 read GetFieldAsMFFloat;
    property FdkeyValue: TMFString index 3 read GetFieldAsMFString;
    { eventOut  SFString  geovalue_changed } { }
    { eventOut  SFVec3f   value_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGeoTouchSensor = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdenabled: TSFBool index 0 read GetFieldAsSFBool;
    property FdgeoOrigin: TSFNode index 1 read GetFieldAsSFNode;
    property FdgeoSystem: TMFString index 2 read GetFieldAsMFString;
    { eventOut      SFVec3f   hitNormal_changed } { }
    { eventOut      SFVec3f   hitPoint_changed } { }
    { eventOut      SFVec2f   hitTexCoord_changed } { }
    { eventOut      SFString  hitGeoCoord_changed } { }
    { eventOut      SFBool    isActive } { }
    { eventOut      SFBool    isOver } { }
    { eventOut      SFTime    touchTime } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGeoViewpoint = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn        SFBool       set_bind } { }
    { eventIn        SFString     set_orientation } { }
    { eventIn        SFString     set_position } { }
    property FdfieldOfView: TSFFloat index 0 read GetFieldAsSFFloat;
    property Fdheadlight: TSFBool index 1 read GetFieldAsSFBool;
    property Fdjump: TSFBool index 2 read GetFieldAsSFBool;
    property FdnavType: TMFString index 3 read GetFieldAsMFString;
    property Fddescription: TSFString index 4 read GetFieldAsSFString;
    property FdgeoOrigin: TSFNode index 5 read GetFieldAsSFNode;
    property FdgeoSystem: TMFString index 6 read GetFieldAsMFString;
    property Fdorientation: TSFRotation index 7 read GetFieldAsSFRotation;
    property Fdposition: TSFString index 8 read GetFieldAsSFString;
    property FdspeedFactor: TSFFloat index 9 read GetFieldAsSFFloat;
    { eventOut       SFTime       bindTime } { }
    { eventOut       SFBool       isBound } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGroup_2 = class(TNodeGeneralGrouping)
  protected
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      MFNode  addChildren } { }
    { eventIn      MFNode  removeChildren } { }
    property Fdchildren: TMFNode index 0 read GetFieldAsMFNode;
    property FdbboxCenter: TSFVec3f index 1 read GetFieldAsSFVec3f;
    property FdbboxSize: TSFVec3f index 2 read GetFieldAsSFVec3f;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function ChildrenField: TMFNode; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeGroupHidden_2 = class(TNodeGroup_2)
  end;

  TNodeImageTexture = class(TNodeGeneralTexture)
  private
    FUsedUrl: string;
  protected
    function LoadTextureImage: TImage; override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdurl: TMFString index 0 read GetFieldAsMFString;
    property FdrepeatS: TSFBool index 1 read GetFieldAsSFBool;
    property FdrepeatT: TSFBool index 2 read GetFieldAsSFBool;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function TextureDescription: string; override;
    function RepeatS: boolean; override;
    function RepeatT: boolean; override;

    { This contains one of URLs from the list of FdUrl.Items
      (already expanded to absolute URL by PathFromWWWBasePath)
      that was actually used to load current texture image.
      This is set when image is actually loaded. If image is not
      loaded it's ''. }
    property UsedUrl: string read FUsedUrl;
  end;

  TNodeIndexedFaceSet_2 = class(TNodeGeneralShape)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn       MFInt32 set_colorIndex } { }
    { eventIn       MFInt32 set_coordIndex } { }
    { eventIn       MFInt32 set_normalIndex } { }
    { eventIn       MFInt32 set_texCoordIndex } { }
    property Fdcolor: TSFNode index 0 read GetFieldAsSFNode;
    property Fdcoord: TSFNode index 1 read GetFieldAsSFNode;
    property Fdnormal: TSFNode index 2 read GetFieldAsSFNode;
    property FdtexCoord: TSFNode index 3 read GetFieldAsSFNode;
    property Fdccw: TSFBool index 4 read GetFieldAsSFBool;
    property FdcolorIndex: TMFInt32 index 5 read GetFieldAsMFInt32;
    property FdcolorPerVertex: TSFBool index 6 read GetFieldAsSFBool;
    property Fdconvex: TSFBool index 7 read GetFieldAsSFBool;
    property FdcoordIndex: TMFInt32 index 8 read GetFieldAsMFInt32;
    property FdcreaseAngle: TSFFloat index 9 read GetFieldAsSFFloat;
    property FdnormalIndex: TMFInt32 index 10 read GetFieldAsMFInt32;
    property FdnormalPerVertex: TSFBool index 11 read GetFieldAsSFBool;
    property Fdsolid: TSFBool index 12 read GetFieldAsSFBool;
    property FdtexCoordIndex: TMFInt32 index 13 read GetFieldAsMFInt32;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function BoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function LocalBoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeIndexedLineSet_2 = class(TNodeGeneralShape)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn       MFInt32 set_colorIndex } { }
    { eventIn       MFInt32 set_coordIndex } { }
    property Fdcolor: TSFNode index 0 read GetFieldAsSFNode;
    property Fdcoord: TSFNode index 1 read GetFieldAsSFNode;
    property FdcolorIndex: TMFInt32 index 2 read GetFieldAsMFInt32;
    property FdcolorPerVertex: TSFBool index 3 read GetFieldAsSFBool;
    property FdcoordIndex: TMFInt32 index 4 read GetFieldAsMFInt32;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function BoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function LocalBoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeInline = class(TNodeGeneralGrouping, INodeGeneralInline)
  protected
    procedure BeforeTraverse(var State: TVRMLGraphTraverseState); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdurl: TMFString index 0 read GetFieldAsMFString;
    property FdbboxCenter: TSFVec3f index 1 read GetFieldAsSFVec3f;
    property FdbboxSize: TSFVec3f index 2 read GetFieldAsSFVec3f;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    class function ChildrenSaveToStream: boolean; override;

    procedure LoadInlined(CanReload: boolean);
  end;

  TNodeInlineLoadControl = class(TNodeGeneralGrouping, INodeGeneralInline)
  protected
    procedure BeforeTraverse(var State: TVRMLGraphTraverseState); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdload: TSFBool index 0 read GetFieldAsSFBool;
    property Fdurl: TMFString index 1 read GetFieldAsMFString;
    property FdbboxCenter: TSFVec3f index 2 read GetFieldAsSFVec3f;
    property FdbboxSize: TSFVec3f index 3 read GetFieldAsSFVec3f;
    { eventOut     MFNode    children } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    class function ChildrenSaveToStream: boolean; override;

    procedure LoadInlined(CanReload: boolean);
  end;

  TNodeLOD_2 = class(TNodeGeneralGrouping)
  protected
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdlevel: TMFNode index 0 read GetFieldAsMFNode;
    property Fdcenter: TSFVec3f index 1 read GetFieldAsSFVec3f;
    property Fdrange: TMFFloat index 2 read GetFieldAsMFFloat;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function ChildrenField: TMFNode; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeMaterial_2 = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdambientIntensity: TSFFloat index 0 read GetFieldAsSFFloat;
    property FddiffuseColor: TSFColor index 1 read GetFieldAsSFColor;
    property FdemissiveColor: TSFColor index 2 read GetFieldAsSFColor;
    property Fdshininess: TSFFloat index 3 read GetFieldAsSFFloat;
    property FdspecularColor: TSFColor index 4 read GetFieldAsSFColor;
    property Fdtransparency: TSFFloat index 5 read GetFieldAsSFFloat;
    property FdFogImmune: TSFBool index 6 read GetFieldAsSFBool;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    { Opacity is just a 1 - FdTransparency.Value.
      Defined for your comfort --- for
      OpenGL you will usually want to pass Opacity, not Transparency. }
    function Opacity: Single;

    { ShininessExp is just 128 * FdShininess.Value, this is the "real"
      exponent indicated by shininess field value.
      Defined for your comfort --- for any graphic library you will usually
      want to pass the "real" exponent given by this function, not just
      value of shininess field. }
    function ShininessExp: Single;
  end;

  TNodeMovieTexture = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdloop: TSFBool index 0 read GetFieldAsSFBool;
    property Fdspeed: TSFFloat index 1 read GetFieldAsSFFloat;
    property FdstartTime: TSFTime index 2 read GetFieldAsSFTime;
    property FdstopTime: TSFTime index 3 read GetFieldAsSFTime;
    property Fdurl: TMFString index 4 read GetFieldAsMFString;
    property FdrepeatS: TSFBool index 5 read GetFieldAsSFBool;
    property FdrepeatT: TSFBool index 6 read GetFieldAsSFBool;
    { eventOut     SFTime   duration_changed } { }
    { eventOut     SFBool   isActive } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeNavigationInfo = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      SFBool   set_bind } { }
    property FdavatarSize: TMFFloat index 0 read GetFieldAsMFFloat;
    property Fdheadlight: TSFBool index 1 read GetFieldAsSFBool;
    property Fdspeed: TSFFloat index 2 read GetFieldAsSFFloat;
    property Fdtype: TMFString index 3 read GetFieldAsMFString;
    property FdvisibilityLimit: TSFFloat index 4 read GetFieldAsSFFloat;
    { eventOut     SFBool   isBound } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeNormal = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdvector: TMFVec3f index 0 read GetFieldAsMFVec3f;
  end;

  TNodeNormalInterpolator = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      SFFloat set_fraction } { }
    property Fdkey: TMFFloat index 0 read GetFieldAsMFFloat;
    property FdkeyValue: TMFVec3f index 1 read GetFieldAsMFVec3f;
    { eventOut     MFVec3f value_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeNurbsCurve = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdcontrolPoint: TMFVec3f index 0 read GetFieldAsMFVec3f;
    property Fdweight: TMFFloat index 1 read GetFieldAsMFFloat;
    property Fdtessellation: TSFInt32 index 2 read GetFieldAsSFInt32;
    property Fdknot: TMFFloat index 3 read GetFieldAsMFFloat;
    property Fdorder: TSFInt32 index 4 read GetFieldAsSFInt32;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeNurbsCurve2D = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdcontrolPoint: TMFVec2f index 0 read GetFieldAsMFVec2f;
    property Fdtessellation: TSFInt32 index 1 read GetFieldAsSFInt32;
    property Fdweight: TMFFloat index 2 read GetFieldAsMFFloat;
    property Fdknot: TMFFloat index 3 read GetFieldAsMFFloat;
    property Fdorder: TSFInt32 index 4 read GetFieldAsSFInt32;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeNurbsGroup = class(TNodeGeneralGrouping)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn       MFNode   addChildren } { }
    { eventIn       MFNode   removeChildren } { }
    property Fdchildren: TMFNode index 0 read GetFieldAsMFNode;
    property FdtessellationScale: TSFFloat index 1 read GetFieldAsSFFloat;
    property FdbboxCenter: TSFVec3f index 2 read GetFieldAsSFVec3f;
    property FdbboxSize: TSFVec3f index 3 read GetFieldAsSFVec3f;

    function ChildrenField: TMFNode; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeNurbsPositionInterpolator = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      SFFloat  set_fraction } { }
    property Fddimension: TSFInt32 index 0 read GetFieldAsSFInt32;
    property FdkeyValue: TMFVec3f index 1 read GetFieldAsMFVec3f;
    property FdkeyWeight: TMFFloat index 2 read GetFieldAsMFFloat;
    property Fdknot: TMFFloat index 3 read GetFieldAsMFFloat;
    property Fdorder: TSFInt32 index 4 read GetFieldAsSFInt32;
    { eventOut     SFVec3f  value_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeNurbsSurface = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdcontrolPoint: TMFVec3f index 0 read GetFieldAsMFVec3f;
    property FdtexCoord: TSFNode index 1 read GetFieldAsSFNode;
    property FduTessellation: TSFInt32 index 2 read GetFieldAsSFInt32;
    property FdvTessellation: TSFInt32 index 3 read GetFieldAsSFInt32;
    property Fdweight: TMFFloat index 4 read GetFieldAsMFFloat;
    property Fdccw: TSFBool index 5 read GetFieldAsSFBool;
    property Fdsolid: TSFBool index 6 read GetFieldAsSFBool;
    property FduDimension: TSFInt32 index 7 read GetFieldAsSFInt32;
    property FduKnot: TMFFloat index 8 read GetFieldAsMFFloat;
    property FduOrder: TSFInt32 index 9 read GetFieldAsSFInt32;
    property FdvDimension: TSFInt32 index 10 read GetFieldAsSFInt32;
    property FdvKnot: TMFFloat index 11 read GetFieldAsMFFloat;
    property FdvOrder: TSFInt32 index 12 read GetFieldAsSFInt32;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeNurbsTextureSurface = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdcontrolPoint: TMFVec2f index 0 read GetFieldAsMFVec2f;
    property Fdweight: TMFFloat index 1 read GetFieldAsMFFloat;
    property FduDimension: TSFInt32 index 2 read GetFieldAsSFInt32;
    property FduKnot: TMFFloat index 3 read GetFieldAsMFFloat;
    property FduOrder: TSFInt32 index 4 read GetFieldAsSFInt32;
    property FdvDimension: TSFInt32 index 5 read GetFieldAsSFInt32;
    property FdvKnot: TMFFloat index 6 read GetFieldAsMFFloat;
    property FdvOrder: TSFInt32 index 7 read GetFieldAsSFInt32;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeOrientationInterpolator = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      SFFloat    set_fraction } { }
    property Fdkey: TMFFloat index 0 read GetFieldAsMFFloat;
    property FdkeyValue: TMFRotation index 1 read GetFieldAsMFRotation;
    { eventOut     SFRotation value_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodePixelTexture = class(TNodeGeneralTexture)
  protected
    function LoadTextureImage: TImage; override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdimage: TSFImage index 0 read GetFieldAsSFImage;
    property FdrepeatS: TSFBool index 1 read GetFieldAsSFBool;
    property FdrepeatT: TSFBool index 2 read GetFieldAsSFBool;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function TextureDescription: string; override;
    function RepeatS: boolean; override;
    function RepeatT: boolean; override;
  end;

  TNodePlaneSensor = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdautoOffset: TSFBool index 0 read GetFieldAsSFBool;
    property Fdenabled: TSFBool index 1 read GetFieldAsSFBool;
    property FdmaxPosition: TSFVec2f index 2 read GetFieldAsSFVec2f;
    property FdminPosition: TSFVec2f index 3 read GetFieldAsSFVec2f;
    property Fdoffset: TSFVec3f index 4 read GetFieldAsSFVec3f;
    { eventOut     SFBool  isActive } { }
    { eventOut     SFVec3f trackPoint_changed } { }
    { eventOut     SFVec3f translation_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodePointLight_2 = class(TNodeGeneralPointLight)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    property Fdradius: TSFFloat index 6 read GetFieldAsSFFloat;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodePointSet_2 = class(TNodeGeneralShape)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdcolor: TSFNode index 0 read GetFieldAsSFNode;
    property Fdcoord: TSFNode index 1 read GetFieldAsSFNode;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function BoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodePolyline2D = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdpoint: TMFVec2f index 0 read GetFieldAsMFVec2f;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodePositionInterpolator = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      SFFloat set_fraction } { }
    property Fdkey: TMFFloat index 0 read GetFieldAsMFFloat;
    property FdkeyValue: TMFVec3f index 1 read GetFieldAsMFVec3f;
    { eventOut     SFVec3f value_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeProximitySensor = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdcenter: TSFVec3f index 0 read GetFieldAsSFVec3f;
    property Fdsize: TSFVec3f index 1 read GetFieldAsSFVec3f;
    property Fdenabled: TSFBool index 2 read GetFieldAsSFBool;
    { eventOut     SFBool     isActive } { }
    { eventOut     SFVec3f    position_changed } { }
    { eventOut     SFRotation orientation_changed } { }
    { eventOut     SFTime     enterTime } { }
    { eventOut     SFTime     exitTime } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeScalarInterpolator = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      SFFloat set_fraction } { }
    property Fdkey: TMFFloat index 0 read GetFieldAsMFFloat;
    property FdkeyValue: TMFFloat index 1 read GetFieldAsMFFloat;
    { eventOut     SFFloat value_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeScript = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdurl: TMFString index 0 read GetFieldAsMFString;
    property FddirectOutput: TSFBool index 1 read GetFieldAsSFBool;
    property FdmustEvaluate: TSFBool index 2 read GetFieldAsSFBool;
    { # And any number of: } { }
    { eventIn      eventType eventName } { }
    { field        fieldType fieldName initialValue } { }
    { eventOut     eventType eventName } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeTextureTransform = class;

  TNodeShape = class(TVRMLNode)
  protected
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdappearance: TSFNode index 0 read GetFieldAsSFNode;
    property Fdgeometry: TSFNode index 1 read GetFieldAsSFNode;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    procedure BeforeTraverse(var State: TVRMLGraphTraverseState); override;
    procedure AfterTraverse(var State: TVRMLGraphTraverseState); override;

    { This is a shortcut for FdAppearance.Value.FdTexture.Value.
      If anything makes this impossible (Apperance field is NULL,
      or Appearance.Texture field is NULL, or wrong node class is
      passed as Appearance or Texture node), then returns nil.
      @noAutoLinkHere }
    function Texture: TNodeGeneralTexture;

    { This is like @link(Texture), but it returns TextureTransform
      of Apperance. }
    function TextureTransform: TNodeTextureTransform;

    { This is like @link(Texture), but it returns Material
      of Apperance. }
    function Material: TNodeMaterial_2;
  end;

  TNodeSound = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fddirection: TSFVec3f index 0 read GetFieldAsSFVec3f;
    property Fdintensity: TSFFloat index 1 read GetFieldAsSFFloat;
    property Fdlocation: TSFVec3f index 2 read GetFieldAsSFVec3f;
    property FdmaxBack: TSFFloat index 3 read GetFieldAsSFFloat;
    property FdmaxFront: TSFFloat index 4 read GetFieldAsSFFloat;
    property FdminBack: TSFFloat index 5 read GetFieldAsSFFloat;
    property FdminFront: TSFFloat index 6 read GetFieldAsSFFloat;
    property Fdpriority: TSFFloat index 7 read GetFieldAsSFFloat;
    property Fdsource: TSFNode index 8 read GetFieldAsSFNode;
    property Fdspatialize: TSFBool index 9 read GetFieldAsSFBool;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeSphere_2 = class(TNodeGeneralShape)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdradius: TSFFloat index 0 read GetFieldAsSFFloat;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function LocalBoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;
  end;

  TNodeSphereSensor = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdautoOffset: TSFBool index 0 read GetFieldAsSFBool;
    property Fdenabled: TSFBool index 1 read GetFieldAsSFBool;
    property Fdoffset: TSFRotation index 2 read GetFieldAsSFRotation;
    { eventOut     SFBool     isActive } { }
    { eventOut     SFRotation rotation_changed } { }
    { eventOut     SFVec3f    trackPoint_changed } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeSpotLight_2 = class(TNodeGeneralLight)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdattenuation: TSFVec3f index 4 read GetFieldAsSFVec3f;
    property FdbeamWidth: TSFFloat index 5 read GetFieldAsSFFloat;
    property FdcutOffAngle: TSFFloat index 6 read GetFieldAsSFFloat;
    property Fddirection: TSFVec3f index 7 read GetFieldAsSFVec3f;
    property Fdlocation: TSFVec3f index 8 read GetFieldAsSFVec3f;
    property Fdradius: TSFFloat index 9 read GetFieldAsSFFloat;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeSwitch_2 = class(TNodeGeneralGrouping)
  protected
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdchoice: TMFNode index 0 read GetFieldAsMFNode;
    property FdwhichChoice: TSFInt32 index 1 read GetFieldAsSFInt32;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function ChildrenField: TMFNode; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeText = class(TNodeGeneralShape)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdstring: TMFString index 0 read GetFieldAsMFString;
    property FdfontStyle: TSFNode index 1 read GetFieldAsSFNode;
    property Fdlength: TMFFloat index 2 read GetFieldAsMFFloat;
    property FdmaxExtent: TSFFloat index 3 read GetFieldAsSFFloat;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function BoundingBox(State: TVRMLGraphTraverseState): TBox3d; override;
    function VerticesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    function TrianglesCount(State: TVRMLGraphTraverseState; OverTriangulate: boolean): Cardinal; override;
    procedure LocalTriangulate(State: TVRMLGraphTraverseState; OverTriangulate: boolean; NewTriangleProc: TNewTriangleProc); override;

    { This returns FdFontStyle.Value. Returns nil if FdFontStyle.Value
      is nil or if it's not TNodeFontStyle_2. }
    function FontStyle: TNodeFontStyle_2;
  end;

  TNodeTextureCoordinate = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdpoint: TMFVec2f index 0 read GetFieldAsMFVec2f;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeTextureTransform = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdcenter: TSFVec2f index 0 read GetFieldAsSFVec2f;
    property Fdrotation: TSFFloat index 1 read GetFieldAsSFFloat;
    property Fdscale: TSFVec2f index 2 read GetFieldAsSFVec2f;
    property Fdtranslation: TSFVec2f index 3 read GetFieldAsSFVec2f;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    function Matrix: TMatrix4Single;
  end;

  TNodeTimeSensor = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property FdcycleInterval: TSFTime index 0 read GetFieldAsSFTime;
    property Fdenabled: TSFBool index 1 read GetFieldAsSFBool;
    property Fdloop: TSFBool index 2 read GetFieldAsSFBool;
    property FdstartTime: TSFTime index 3 read GetFieldAsSFTime;
    property FdstopTime: TSFTime index 4 read GetFieldAsSFTime;
    { eventOut     SFTime   cycleTime } { }
    { eventOut     SFFloat  fraction_changed
    { eventOut     SFBool   isActive } { }
    { eventOut     SFTime   time } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeTouchSensor = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdenabled: TSFBool index 0 read GetFieldAsSFBool;
    { eventOut     SFVec3f hitNormal_changed } { }
    { eventOut     SFVec3f hitPoint_changed } { }
    { eventOut     SFVec2f hitTexCoord_changed } { }
    { eventOut     SFBool  isActive } { }
    { eventOut     SFBool  isOver } { }
    { eventOut     SFTime  touchTime } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeTransform_2 = class(TNodeGeneralGrouping)
  protected
    procedure DirectEnumerateActive(
      Func: TEnumerateChildrenFunction); override;
    procedure BeforeTraverse(var State: TVRMLGraphTraverseState); override;
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      MFNode      addChildren } { }
    { eventIn      MFNode      removeChildren } { }
    property Fdcenter: TSFVec3f index 0 read GetFieldAsSFVec3f;
    property Fdchildren: TMFNode index 1 read GetFieldAsMFNode;
    property Fdrotation: TSFRotation index 2 read GetFieldAsSFRotation;
    property Fdscale: TSFVec3f index 3 read GetFieldAsSFVec3f;
    property FdscaleOrientation: TSFRotation index 4 read GetFieldAsSFRotation;
    property Fdtranslation: TSFVec3f index 5 read GetFieldAsSFVec3f;
    property FdbboxCenter: TSFVec3f index 6 read GetFieldAsSFVec3f;
    property FdbboxSize: TSFVec3f index 7 read GetFieldAsSFVec3f;

    class function ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
      override;

    function ChildrenField: TMFNode; override;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeTrimmedSurface = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn       MFNode   addTrimmingContour } { }
    { eventIn       MFNode   removeTrimmingContour } { }
    property FdtrimmingContour: TMFNode index 0 read GetFieldAsMFNode;
    property Fdsurface: TSFNode index 1 read GetFieldAsSFNode;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeViewpoint = class(TNodeGeneralViewpoint)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    { eventIn      SFBool     set_bind } { }
    property FdfieldOfView: TSFFloat index 4 read GetFieldAsSFFloat;
    property Fdjump: TSFBool index 5 read GetFieldAsSFBool;
    property Fddescription: TSFString index 6 read GetFieldAsSFString;
    { eventOut     SFTime     bindTime } { }
    { eventOut     SFBool     isBound } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;

    class function CameraKind: TVRMLCameraKind; override;

    { This calculates proper angle of view for typical rectangular
      display, based on given fieldOfView field value.
      Result is in radians (just like fieldOfView VRML field).

      If you want to calculate horizontal angle of view then
      pass as ThisToOtherSizeRatio your window's width / height.
      If you want to calculate vertical angle of view then
      pass as ThisToOtherSizeRatio your window's height / width.
      For this method it doesn't really matter which is horizontal
      and which is vertical, both are treated the same.

      This works following VRML spec. So the angle of view for
      smaller window size is set to fieldOfViee. The other angle
      can always be calculated by AdjustViewAngleRadToAspectRatio
      (this implements the same equation that is mentioned in VRML spec).
      The larger angle cannot be larger than Pi, and may force the
      smaller angle to be smaller than fieldOfView. }
    function AngleOfView(const ThisToOtherSizeRatio: Single): Single;

    { This is like AngleOfView, but it allows you to specify
      FieldOfView as a parameter. }
    class function ViewpointAngleOfView(
      FieldOfView: Single;
      const ThisToOtherSizeRatio: Single): Single;
  end;

  TNodeVisibilitySensor = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdcenter: TSFVec3f index 0 read GetFieldAsSFVec3f;
    property Fdenabled: TSFBool index 1 read GetFieldAsSFBool;
    property Fdsize: TSFVec3f index 2 read GetFieldAsSFVec3f;
    { eventOut     SFTime  enterTime } { }
    { eventOut     SFTime  exitTime } { }
    { eventOut     SFBool  isActive } { }

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

  TNodeWorldInfo = class(TVRMLNode)
  public
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;
    class function ClassNodeTypeName: string; override;
    property Fdinfo: TMFString index 0 read GetFieldAsMFString;
    property Fdtitle: TSFString index 1 read GetFieldAsSFString;

    function SuggestedVRMLVersion(
      out VerMajor, VerMinor, SuggestionPriority: Integer): boolean; override;
  end;

{ very very special node --------------------------------------------------- }

  (* @abstract(TNodeUnknown represents a node with an unrecognized type.)

    If we approach some node with not recognized name we create TNodeUnknown.
    TNodeUnknown has very special Parse method.
    We want to use "fields" and "isA" VRML 1.0 extensibility features here.
    (TODO - these extensibility features are not implemented yet;
     for now all unrecognized nodes are of kind 1))
    We have three cases :

    @orderedList(
      @item(
        Unknown node that doesn't have the "fields" field. It CAN be parsed
        by simply looking for matching "}". Such node will use default
        Render, Init/CloseGL and BoundingBox method implementations -
        wiec w praktyce taki node nie bedzie robil zadnego renderingu i mial
        BoundingBox = EmptyBox3d.
        Uwaga - *AllowedChildren bedzie = false.)

      @item(
        node ktory ma pole "fields" ale nie ma pola "isA" albo nie jest
        tam podany zaden znany typ node'a. Taki node bedzie mial
        wypelnione podczas parsowania pola Fields i bedzie parsowany
        normalnie ale ciagle nie bedzie mial zadnego wplywu na renderowanie
        sceny VRML'a, podobnie jak w przypadku 1. (chociaz jego dzieci BEDA
        mialy - taki node bedzie zasadniczo dzialal jak node Group)
        Uwaga - *AllowedChildren bedzie = true.)

      @item(
        wreszcie node ktory ma pola "fields" i "isA" i znalezlismy
        wsrod isA jakis znany nam typ node'a. Czyli wiemy ze mamy
        jakies rozszerzenie znanego nam node'a. Taki node bedzie mial
        dynamicznie utworzone pola Fields i bedzie normalnie parsowany
        (tak jak typ 2) a ponadto taki node bedzie mial taki wplyw
        na model VRML'a jakby byl typem node'a ktory jest pierwszym
        znanym nam typem na liscie "isA".
        Uwaga - *AllowedChildren bedzie = *AllowedChildren znanego typu node'a.)
    )

    Ten node nigdy nie powinien byc tworzony tak jak normalny node
    --- wrecz normalne wirtualne Create(const AName: string) spowoduje
    wyjatek ! Tworz obiekty tego typu tylko uzywajac CreateUnknownParse,
    ew. mozesz uzyc CreateUnknown (jezeli tylko znajdziesz jakis sens
    dla uzycia CreateUnknown bez Parse...).

    Spostrzezenie : ten mechanizm jest calkiem dobry - node'y kazdego
    typu, nawet 1, moga byc nazywane i mozna sie pozniej do nich
    odwolywac przez USE. Jezeli node jest typu 2 i 3 to nawet
    ich SubNode'y beda wlaczone w ten standardowy mechanizm !
    Po Parse node'u unknown typu 1) robimy VRMLNonFatalError
    (bo dokladnie to zaszlo --- to jest nieprawidlowy node, ale umiemy sobie
    poradzic).
  *)
  TNodeUnknown = class(TVRMLNode)
  private
    fNodeTypeName: string;
  public
    function NodeTypeName: string; override;
    procedure Parse(Lexer: TVRMLLexer; NodeNameBinding: TStringList); override;

    { base Create will throw exception. Always use CreateUnknown*

      @noAutoLinkHere }
    constructor Create(const ANodeName: string; const AWWWBasePath: string); override;

    constructor CreateUnknown(const ANodeName, AWWWBasePath, ANodeTypeName :string);
    constructor CreateUnknownParse(const ANodeName, ANodeTypeName :string;
      Lexer: TVRMLLexer; NodeNameBinding: TStringList);
  end;

{ TraverseStateLastNodesClasses ---------------------------------------------- }

const
  { opis patrz TTraverseStateLastNodes }
  TraverseStateLastNodesClasses :
    array[0..HighTraverseStateLastNodes] of TVRMLNodeClass =
    ( TNodeCoordinate3, TNodeShapeHints, TNodeFontStyle_1,
      TNodeMaterial_1, TNodeMaterialBinding, TNodeNormal, TNodeNormalBinding,
      TNodeTexture2, TNodeTextureCoordinate2,
      TNodeKambiTriangulation
      { additions here must be synchronized with additions to
        TTraverseStateLastNodes }
    );

{ TNodesManager ------------------------------------------------------------ }

type
  ENodesManagerError = class(EVRMLError);
  ENodeClassRegisterError = class(ENodesManagerError);
  TNodesManager = class
  private
    { Strings[] to ClassNodeTypeName. Objects[] to odpowiednie klasy. }
    Registered: TStringList;
  public
    constructor Create;
    destructor Destroy; override;

    { Mozesz rejestrowac tylko klasy o ClassNodeTypeName <> '' (w tej procedurze
      to sprawdzimy i ew. rzucimy wyjatek ENodeClassRegisterError).

      Nie mozesz zarejestrowac dwa razy tej samej klasy,
      spowoduje to ENodeClassRegisterError.

      Natomiast mozesz zarejestrowac wiele razy rozne klasy o tym samym
      ClassNodeTypeName. For example TNodeCone_1 and TNodeCone_2.
      They will be chosen in NodeTypeNameToClass using their ForVRMLVersion. }
    procedure RegisterNodeClass(NodeClass: TVRMLNodeClass);
    procedure RegisterNodeClasses(const NodeClasses: array of TVRMLNodeClass);

    { This unregisters class NodeClass, i.e. it removes it from
      our map table.

      @raises(ENodesManagerError if NodeClass.ClassNodeTypeName = ''
        (so it cannot be even registered), or if
        ((NodeClass was not registered) and ErrorIfNotRegistered)) }
    procedure UnRegisterNodeClass(NodeClass: TVRMLNodeClass;
      ErrorIfNotRegistered: boolean = true);

    { NodesManager zostal stworzony wlasnie po to aby zaimplementowac
      funkcje TypeNameToClass: odwzorowuje ona nazwe typu VRMLa
      na klase VRMLa ktora ma takie samo ClassNodeTypeName.

      Aby takie cos
      przeprowadzic potrzebny byl gdzies ekwiwalent globalnej tablicy
      przechowujacej wszystkie stworzone klasy wezlow VRMLa --- takim
      odpowiednikiem jest wlasnie ta klasa do ktorej trzeba rejestrowac wezly.
      Bedzie szukac wsrod zarejestrowanych klas klasy o zadanym
      ClassNodeTypeName, wybierajac tylko klase ktorej
      @code(ForVRMLVersion(VerMajor, VerMinor)) will return @true.

      Jesli nie znajdzie zwroci nil. }
    function NodeTypeNameToClass(const ANodeTypeName: string;
      const VerMajor, VerMinor: Integer): TVRMLNodeClass;
  end;

var
  { tworzony i niszczony w init/fini tego modulu }
  NodesManager: TNodesManager;

{ global procedures ---------------------------------------------------------- }

(*
  parse node : [ DEF <nodename> ] <nodetype> { node-content } or USE <nodename>

  NodeNameBinding jest lista bez duplikatow okreslajaca wszystkie dotychczasowe
  nazwy node'ow razem z ich instancjami. Jezeli kilka instancji mialo takie
  samo NodeName to na liscie znajduje sie ostatni z nich (ostatni w sensie
  pozycji w pliku, czy raczej w strumieniu tokenow Lexera). Tym samym
  jest chyba jasne do czego uzywamy NodeNameBinding : do realizacji
  konstrukcji "USE <nodename>". Procedura ParseNode nie moze modyfikowac
  tej listy, to zadania ma wykonywac TVRMLNode.Parse.
*)
function ParseNode(Lexer: TVRMLLexer; NodeNameBinding: TStringList;
  const AllowedNodes: boolean): TVRMLNode;

{ parse VRML file : parse whole VRML file, returning it's root node.

  Note that you must pass here TPeekCharStream class, not just any
  generic TStream class. But it's not a problem, really, because
  you can wrap any class inside TPeekCharStream descendant. E.g. do
  @longcode(#
    ParseVRMLFile(TBufferedReadStream.Create(MyStream, false), WWWBasePath)
  #)

  Note that this function can't handle compressed data (VRML files are
  sometimes compressed with gzip). You should already pass here a stream
  with uncompressed text data. }
function ParseVRMLFile(Stream: TPeekCharStream;
  const WWWBasePath: string): TVRMLNode; overload;

function ParseVRMLFileFromString(const VRMLContents: string;
  const WWWBasePath: string): TVRMLNode; overload;

{ FileName to nazwa istniejacego pliku (wzgledna lub bezwzgledna).
  Jezeli AllowStdIn to jesli filename = '-' to odczytamy model z StdInStream,
  w tym przypadku WWWBasePath bedzie ustawione na GetCurrentDir.

  This function can handle files compressed with gzip
  (it just internally filters file contents with TGZFileStream,
  uncompressing it on the fly). }
function ParseVRMLFile(const FileName: string;
  AllowStdIn: boolean): TVRMLNode; overload;

{ SaveToVRMLFile writes whole VRML file with given root Node.
  This includes writing VRML header '#VRML ...'.
  Also if PrecedingComment <> '' then we will write a comment
  '# '+ PrecedingComment at the beginning. }
procedure SaveToVRMLFile(Node: TVRMLNode;
  Stream: TStream; const PrecedingComment: string); overload;
procedure SaveToVRMLFile(Node: TVRMLNode;
  const Filename, PrecedingComment: string); overload;

{ Create and assign all State.Nodes. }
procedure TraverseState_CreateNodes(var StateNodes: TTraverseStateLastNodes);

{ Free and nil all State.Nodes. }
procedure TraverseState_FreeAndNilNodes(var StateNodes: TTraverseStateLastNodes);

const
  VRMLCameraKindToStr: array[TVRMLCameraKind]of string =
  ('Orthographic', 'Perspective');

const
  { consts for TNodeAsciiText.FdJustification.Value }
  JUSTIFICATION_LEFT = 0;
  JUSTIFICATION_CENTER = 1;
  JUSTIFICATION_RIGHT = 2;

  { consts for TNode(Material|Normal)Binding.FdValue.Value }
  BIND_DEFAULT = 0;
  BIND_OVERALL = 1;
  BIND_PER_PART = 2;
  BIND_PER_PART_INDEXED = 3;
  BIND_PER_FACE = 4;
  BIND_PER_FACE_INDEXED = 5;
  BIND_PER_VERTEX = 6;
  BIND_PER_VERTEX_INDEXED = 7;

  { consts for TNodeShapeHints.FdVertexOrdering.Value }
  VERTORDER_UNKNOWN = 0;
  VERTORDER_CLOCKWISE = 1;
  VERTORDER_COUNTERCLOCKWISE = 2;

  { consts for TNodeShapeHints.FdShapeType.Value }
  SHTYPE_UNKNOWN = 0;
  SHTYPE_SOLID = 1;

  { consts for TNodeShapeHints.FdFaceType.Value }
  FACETYPE_UNKNOWN = 0;
  FACETYPE_CONVEX = 1;

  { consts for TNodeFontStyle.FdFamily.Value }
  FSFAMILY_SERIF = 0;
  FSFAMILY_SANS = 1;
  FSFAMILY_TYPEWRITER = 2;

  { consts for TNodeFontStyle.FdStyleFlags[] }
  FSSTYLE_BOLD = 0;
  FSSTYLE_ITALIC = 1;

  { consts for TNodeCone.FdParts.Flags[] }
  CONE_PARTS_SIDES = 0;
  CONE_PARTS_BOTTOM = 1;

  { consts for TNodeCylinder.FdParts.Flags[] }
  CYLINDER_PARTS_SIDES = 0;
  CYLINDER_PARTS_TOP = 1;
  CYLINDER_PARTS_BOTTOM = 2;

  { consts for TNodeTexture2.FdWrapS/WrapT.Value }
  TEXWRAP_REPEAT = 0;
  TEXWRAP_CLAMP = 1;

{ TODO: these Detail parameters below should depend on object's distance
  from viewer. But there is a problem : we need those parameters defined
  when implementing Vertices/TrianglesCount and Triangulate. }
var
  { cylinder, cone, sphere and disk slices/stacks (slices for all objects
    must be equal to perfectly "match" when objects are connected
    (e.g. sphere connected with cylinder). Stacks and RectDivisions
    nie sa do tego zmuszone ale i tak nie ma zadnego sensownego powodu
    zeby z gory mowic ze dana bryla potrzebuje mniej stacks a inna wiecej).

    For the meaning of Detail_Quadric* consts look at definition of glu
    quadric functions (it is not guaranteed that our code will use this
    functions but we will always honour this Detail parameters in the same way).

    For the meaning of Detail_RectDivisions (used only in Cube for now) look
    at KambiGLUtils.DrawGLPlane.

    For now, you can change these variables only @italic(before using anything)
    from this module.

    These variables @italic(must) always honour Min values listed below. }
  Detail_QuadricSlices: Cardinal = 30;
  Detail_QuadricStacks: Cardinal = 20;
  Detail_RectDivisions: Cardinal = 2;

const
  { uzywaj w programie zawsze tych stalych zamiast zakladac ze maja one
    konkretne wartosci, ale mozesz oczywiscie przyjac zalozenie ze na pewno
    sa one Cardinalami (sa >=0) }
  MinQuadricSlices: Cardinal = 3; { mimo ze OpenGL akceptuje minimum 2, ale dla 2 wynik jest bez sensu }
  MinQuadricStacks: Cardinal = 2; { mimo ze OpenGL akceptuje minimum 1, ale dla 1 wynik jest bez sensu }
  MinRectDivisions: Cardinal = 0;

var
  AllowedChildrenNodes: TVRMLNodeClassesList;
  AllowedGeometryNodes: TVRMLNodeClassesList;

{$undef read_interface}

implementation

uses
  { fonts for AsciiText }
  { Bitstream Vera Sans }
  TTF_BitstreamVeraSans_Unit,
  TTF_BitstreamVeraSans_Bold_Unit,
  TTF_BitstreamVeraSans_Italic_Unit,
  TTF_BitstreamVeraSans_Bold_Italic_Unit,
  { Bitstream Vera Sans Mono }
  TTF_BitstreamVeraSansMono_Unit,
  TTF_BitstreamVeraSansMono_Bold_Unit,
  TTF_BitstreamVeraSansMono_Italic_Unit,
  TTF_BitstreamVeraSansMono_Bold_Italic_Unit,
  { Bitstream Vera Serif }
  TTF_BitstreamVeraSerif_Unit,
  TTF_BitstreamVeraSerif_Bold_Unit,
  TTF_BitstreamVeraSerif_Italic_Unit,
  TTF_BitstreamVeraSerif_Bold_Italic_Unit,

  Math, Triangulator, Object3dAsVRML, KambiZStream, VRMLCameraUtils,
  KambiStringUtils, KambiFilesUtils, RaysWindow;

{$define read_implementation}
{$I objectslist_1.inc}
{$I objectslist_3.inc}
{$I dynarray_1.inc}

{ TDynActiveLightArray --------------------------------------------------------- }

function TDynActiveLightArray.IndexOfLightNode(LightNode: TNodeGeneralLight): integer;
begin
 for result := 0 to High do
  if Items[result].LightNode = LightNode then exit;
 result := -1;
end;

procedure TDynActiveLightArray.AddLight(ALightNode: TNodeGeneralLight;
  const ATransform: TMatrix4Single);
begin
 IncLength;
 with Items[High] do
 begin
  LightNode := ALightNode;
  Transform := ATransform;
  if LightNode is TNodeGeneralPositionalLight then
   TransfLocation := MultMatrixPoint(Transform,
     TNodeGeneralPositionalLight(LightNode).FdLocation.Value);

  if LightNode is TNodeSpotLight_1 then
   TransfNormDirection := Normalized( MultMatrixPointNoTranslation(Transform,
     TNodeSpotLight_1(LightNode).FdDirection.Value) ) else
  if LightNode is TNodeSpotLight_2 then
   TransfNormDirection := Normalized( MultMatrixPointNoTranslation(Transform,
     TNodeSpotLight_2(LightNode).FdDirection.Value) ) else
  if LightNode is TNodeGeneralDirectionalLight then
   TransfNormDirection := Normalized( MultMatrixPointNoTranslation(Transform,
     TNodeGeneralDirectionalLight(LightNode).FdDirection.Value) );
 end;
end;

function TDynActiveLightArray.Equals(SecondValue: TDynActiveLightArray): boolean;

  function ActiveLightEquals(const L1, L2: TActiveLight): boolean;
  begin
    Result := (L1.LightNode = L2.LightNode) and
      MatricesPerfectlyEqual(L1.Transform, L2.Transform);
    { No need to compare TransfLocation or TransfNormDirection,
      as they are just precalculated based on LightNode and Transform. }
  end;

var
  I: Integer;
begin
  Result := SecondValue.Count = Count;
  if Result then
    for I := 0 to High do
      if not ActiveLightEquals(Items[I], SecondValue.Items[I]) then
        Exit(false);
end;

{ TVRMLGraphTraverseState ---------------------------------------------------- }

procedure TVRMLGraphTraverseState.CommonCreate;
begin
  inherited Create;
  ActiveLights := TDynActiveLightArray.Create;
end;

constructor TVRMLGraphTraverseState.CreateCopy(Source: TVRMLGraphTraverseState);
begin
  CommonCreate;

  CurrMatrix := Source.CurrMatrix;
  CurrTextureMatrix := Source.CurrTextureMatrix;
  FLastNodes := Source.FLastNodes;
  OwnsLastNodes := false;
  ParentShape := Source.ParentShape;

  ActiveLights.AppendDynArray(Source.ActiveLights);
end;

constructor TVRMLGraphTraverseState.Create(const ADefaultLastNodes: TTraverseStateLastNodes);
begin
  CommonCreate;

  CurrMatrix := IdentityMatrix4Single;
  CurrTextureMatrix := IdentityMatrix4Single;
  FLastNodes := ADefaultLastNodes;
  OwnsLastNodes := false;
end;

constructor TVRMLGraphTraverseState.Create;
begin
  CommonCreate;

  CurrMatrix := IdentityMatrix4Single;
  CurrTextureMatrix := IdentityMatrix4Single;
  TraverseState_CreateNodes(FLastNodes);
  OwnsLastNodes := true;
end;

destructor TVRMLGraphTraverseState.Destroy;
begin
  if OwnsLastNodes then
    TraverseState_FreeAndNilNodes(FLastNodes);

  ActiveLights.Free;
  inherited;
end;

function TVRMLGraphTraverseState.Equals(SecondValue: TVRMLGraphTraverseState):
  boolean;
var
  I: Integer;
begin
  Result := ActiveLights.Equals(SecondValue.ActiveLights) and
    MatricesPerfectlyEqual(CurrMatrix, SecondValue.CurrMatrix) and
    MatricesPerfectlyEqual(CurrTextureMatrix, SecondValue.CurrTextureMatrix) and
    (ParentShape = SecondValue.ParentShape);

  if Result then
  begin
    for I := 0 to HighTraverseStateLastNodes do
      if SecondValue.LastNodes.Nodes[I] <> LastNodes.Nodes[I] then
        Exit(false);
  end;
end;

function TVRMLGraphTraverseState.EqualsNoTransform(
  SecondValue: TVRMLGraphTraverseState): boolean;
var
  I: Integer;
begin
  { ActiveLights, CurrMatrix, CurrTextureMatrix
    are ignored by TVRMLOpenGLRenderer.RenderShapeStateNoTransform }

  Result := ParentShape = SecondValue.ParentShape;

  for I := 0 to HighTraverseStateLastNodes do
    if SecondValue.LastNodes.Nodes[I] <> LastNodes.Nodes[I] then
      Exit(false);

  Result := true;
end;

function TVRMLGraphTraverseState.Texture: TNodeGeneralTexture;
begin
  if ParentShape = nil then
    Result := LastNodes.Texture2 else
    Result := ParentShape.Texture;
end;

{ TVRMLNode ------------------------------------------------------------------- }

constructor TVRMLNode.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited Create;
 FAllowedChildren := false;
 FParsingAllowedChildren := false;

 FNodeName := ANodeName;
 FWWWBasePath := AWWWBasePath;

 FChildren := TVRMLNodesList.Create;
 FParentNodes := TVRMLNodesList.Create;
 FParentFields := TVRMLFieldsList.Create;
 Fields := TVRMLFieldsList.Create;
end;

destructor TVRMLNode.Destroy;
begin
 if FChildren <> nil then RemoveAllChildren;

 FreeWithContentsAndNil(Fields);
 FreeAndNil(FChildren);
 FreeAndNil(FParentNodes);
 FreeAndNil(FParentFields);
 inherited;
end;

procedure TVRMLNode.AddChild(Index: Integer; child: TVRMLNode);
begin
 Check( {is child allowed in AllowedChildren ?} AllowedChildren,
   'Node '+NodeTypeName+' is not allowed to have child node of type '+
   Child.NodeTypeName);
 child.FParentNodes.Add(Self);
 FChildren.Insert(Index, child);
end;

procedure TVRMLNode.AddChild(child: TVRMLNode);
begin
 AddChild(FChildren.Count, child);
end;

procedure TVRMLNode.RemoveChild(i: integer);
var
  OldChild: TVRMLNode;
begin
  OldChild := FChildren[i];
  FChildren.Delete(i);
  OldChild.FParentNodes.Delete(Self);
  if (OldChild.FParentNodes.Count = 0) and
     (OldChild.FParentFields.Count = 0) then
    OldChild.Free;
end;

procedure TVRMLNode.SetChildrenItem(I: Integer; Value: TVRMLNode);
var
  OldChild: TVRMLNode;
begin
  { Inefficient implementation: RemoveChild(I); AddChild(I, Value); }

  if Value <> FChildren[I] then
  begin
    Check( {is child allowed in AllowedChildren ?} AllowedChildren,
      'Node '+NodeTypeName+' is not allowed to have child node of type '+
      Value.NodeTypeName);

    OldChild := FChildren[i];
    FChildren[I] := Value;

    OldChild.FParentNodes.Delete(Self);
    if (OldChild.FParentNodes.Count = 0) and
       (OldChild.FParentFields.Count = 0) then
      OldChild.Free;

    Value.FParentNodes.Add(Self);
  end;
end;

procedure TVRMLNode.RemoveAllChildren;
begin
 while FChildren.Count > 0 do RemoveChild(0);
end;

function TVRMLNode.GetChildrenItem(i: integer): TVRMLNode; begin result := FChildren[i] end;
function TVRMLNode.GetParentNodesItem(i: integer): TVRMLNode; begin result := FParentNodes[i] end;

function TVRMLNode.ChildrenCount: integer; begin result := FChildren.Count end;
function TVRMLNode.ParentNodesCount: integer; begin result := FParentNodes.Count end;

procedure TVRMLNode.FreeRemovingFromAllParentNodes;
var i, j: integer;
begin
 if Self = nil then exit;

 for i := 0 to FParentNodes.Count-1 do
 begin
  j := FParentNodes[i].FChildren.IndexOf(Self);
  FParentNodes[i].FChildren.Delete(j);
  {nie musimy sie tu martwic usuwaniem naszego Parenta z listy FParentNodes ktora
   wlasnie przegladamy bo przeciez i tak zaraz zrobimy sobie Destroy; }
 end;
 Self.Destroy;
end;

function TVRMLNode.GetParentFieldsItem(Index: Integer): TVRMLField;
begin
  Result := FParentFields[Index];
end;

function TVRMLNode.GetParentFieldsNodeItem(Index: Integer): TVRMLNode;
var
  F: TVRMLField;
begin
  F := ParentFields[Index];
  if F is TSFNode then
    Result := TSFNode(F).ParentNode else
    Result := (F as TMFNode).ParentNode;
end;

function TVRMLNode.ParentFieldsCount: Integer;
begin
  Result := FParentFields.Count;
end;

procedure TVRMLNode.DirectEnumerateActive(Func: TEnumerateChildrenFunction);
var
  I: Integer;
begin
  for I := 0 to ChildrenCount - 1 do
    Func(Self, Children[I]);
end;

procedure TVRMLNode.DirectEnumerateAll(
  Func: TEnumerateChildrenFunction);
var
  I, J: Integer;
  SF: TSFNode;
  MF: TMFNode;
begin
  for I := 0 to ChildrenCount - 1 do
    Func(Self, Children[I]);

  for I := 0 to Fields.Count - 1 do
  begin
    if Fields[I] is TSFNode then
    begin
      SF := TSFNode(Fields[I]);
      if SF.Value <> nil then
        Func(Self, SF.Value);
    end else
    if Fields[I] is TMFNode then
    begin
      MF := TMFNode(Fields[I]);
      for J := 0 to MF.Items.Count - 1 do
        Func(Self, MF.Items[J]);
    end;
  end;
end;

procedure TVRMLNode.DirectEnumerate(
  Func: TEnumerateChildrenFunction;
  OnlyActive: boolean);
begin
  if OnlyActive then
    DirectEnumerateActive(Func) else
    DirectEnumerateAll(Func);
end;

procedure TVRMLNode.BeforeTraverse(var State: TVRMLGraphTraverseState); begin end;
procedure TVRMLNode.MiddleTraverse(State: TVRMLGraphTraverseState); begin end;
procedure TVRMLNode.AfterTraverse(var State: TVRMLGraphTraverseState); begin end;

type
  TTraverseEnumerator = class
    State: TVRMLGraphTraverseState;
    NodeClass: TVRMLNodeClass;
    TraversingFunc: TTraversingFunc;
    procedure EnumerateChildrenFunction(Node, Child: TVRMLNode);
  end;

  procedure TTraverseEnumerator.EnumerateChildrenFunction(
    Node, Child: TVRMLNode);
  begin
    Child.Traverse(State, NodeClass, TraversingFunc);
  end;

procedure TVRMLNode.Traverse(State: TVRMLGraphTraverseState;
  NodeClass: TVRMLNodeClass; TraversingFunc: TTraversingFunc);
var
  LastNodesIndex: Integer;
  Enumerator: TTraverseEnumerator;
begin
  BeforeTraverse(State);
  try
    if Self is NodeClass then TraversingFunc(Self, State);
    MiddleTraverse(State);

    Enumerator := TTraverseEnumerator.Create;
    try
      Enumerator.State := State;
      Enumerator.NodeClass := NodeClass;
      Enumerator.TraversingFunc := TraversingFunc;
      DirectEnumerateActive(Enumerator.EnumerateChildrenFunction);
    finally FreeAndNil(Enumerator) end;
  finally AfterTraverse(State) end;

  LastNodesIndex := TraverseStateLastNodesIndex;
  if LastNodesIndex <> -1 then State.FLastNodes.Nodes[LastNodesIndex] := Self;
end;

procedure TVRMLNode.TraverseFromDefaultState(
  NodeClass: TVRMLNodeClass; TraversingFunc: TTraversingFunc);
var
  InitialState: TVRMLGraphTraverseState;
begin
  InitialState := TVRMLGraphTraverseState.Create;
  try
    Traverse(InitialState, NodeClass, TraversingFunc);
  finally InitialState.Free end;
end;

function TVRMLNode.NodeTypeName: string;
begin
 result := ClassNodeTypeName;
end;

class function TVRMLNode.ClassNodeTypeName: string;
begin
 result := '';
end;

function TVRMLNode.GetField(i: integer): TVRMLField; begin result := Fields[i] end;
function TVRMLNode.GetFieldAsSFBitMask(i: integer): TSFBitMask; begin result := TSFBitMask(Fields[i]) end;
function TVRMLNode.GetFieldAsSFBool(i: integer): TSFBool; begin result := TSFBool(Fields[i]) end;
function TVRMLNode.GetFieldAsSFColor(i: integer): TSFColor; begin result := TSFColor(Fields[i]) end;
function TVRMLNode.GetFieldAsSFEnum(i: integer): TSFEnum; begin result := TSFEnum(Fields[i]) end;
function TVRMLNode.GetFieldAsSFFloat(i: integer): TSFFloat; begin result := TSFFloat(Fields[i]) end;
function TVRMLNode.GetFieldAsSFTime(i: integer): TSFTime; begin result := TSFTime(Fields[i]) end;
function TVRMLNode.GetFieldAsSFImage(i: integer): TSFImage; begin result := TSFImage(Fields[i]) end;
function TVRMLNode.GetFieldAsSFLong(i: integer): TSFLong; begin result := TSFLong(Fields[i]) end;
function TVRMLNode.GetFieldAsSFInt32(i: integer): TSFInt32; begin result := TSFInt32(Fields[i]) end;
function TVRMLNode.GetFieldAsSFMatrix(i: integer): TSFMatrix; begin result := TSFMatrix(Fields[i]) end;
function TVRMLNode.GetFieldAsSFRotation(i: integer): TSFRotation; begin result := TSFRotation(Fields[i]) end;
function TVRMLNode.GetFieldAsSFString(i: integer): TSFString; begin result := TSFString(Fields[i]) end;
function TVRMLNode.GetFieldAsSFVec2f(i: integer): TSFVec2f; begin result := TSFVec2f(Fields[i]) end;
function TVRMLNode.GetFieldAsSFVec3f(i: integer): TSFVec3f; begin result := TSFVec3f(Fields[i]) end;
function TVRMLNode.GetFieldAsSFNode(i: integer): TSFNode; begin result := TSFNode(Fields[i]) end;
function TVRMLNode.GetFieldAsMFColor(i: integer): TMFColor; begin result := TMFColor(Fields[i]) end;
function TVRMLNode.GetFieldAsMFLong(i: integer): TMFLong; begin result := TMFLong(Fields[i]) end;
function TVRMLNode.GetFieldAsMFInt32(i: integer): TMFInt32; begin result := TMFInt32(Fields[i]) end;
function TVRMLNode.GetFieldAsMFVec2f(i: integer): TMFVec2f; begin result := TMFVec2f(Fields[i]) end;
function TVRMLNode.GetFieldAsMFVec3f(i: integer): TMFVec3f; begin result := TMFVec3f(Fields[i]) end;
function TVRMLNode.GetFieldAsMFRotation(i: integer): TMFRotation; begin result := TMFRotation(Fields[i]) end;
function TVRMLNode.GetFieldAsMFFloat(i: integer): TMFFloat; begin result := TMFFloat(Fields[i]) end;
function TVRMLNode.GetFieldAsMFTime(i: integer): TMFTime; begin result := TMFTime(Fields[i]) end;
function TVRMLNode.GetFieldAsMFString(i: integer): TMFString; begin result := TMFString(Fields[i]) end;
function TVRMLNode.GetFieldAsMFNode(i: integer): TMFNode; begin result := TMFNode(Fields[i]) end;

constructor TVRMLNode.CreateParse(const ANodeName: string; Lexer: TVRMLLexer; NodeNameBinding: TStringList);
begin
 Create(ANodeName, '');
 Parse(Lexer, NodeNameBinding);
end;

function TVRMLNode.PathFromWWWBasePath(const RelativePath: string): string;
begin
  { This is a workaround for Blender errorneous VRML 1.0 export.
    Blender exports relative paths by prefixing them by "//"
    (that's a general convention used internally by Blender, AFAIK).
    Here I simply remove this "//". }
  if IsPrefix('//', RelativePath) then
    Result := CombinePaths(WWWBasePath, SEnding(RelativePath, 3)) else
    Result := CombinePaths(WWWBasePath, RelativePath);
end;

procedure TVRMLNode.Parse(Lexer: TVRMLLexer; NodeNameBinding: TStringList);
var ni: integer;
    ThisIsField: boolean;
begin
 RemoveAllChildren;

 {parse node}
 Lexer.CheckTokenIs(vtOpenCurlyBracket);
 Lexer.NextToken;
 while Lexer.Token <> vtCloseCurlyBracket do
 begin
  ThisIsField := false;

  {gdybym wiedzial ze wszystkie node'y sa standardowe (zgodne ze specyfikacja
   VRML'a) to moglbym tu sprawdzac czy Lexer.TokenName[0] in 'a'..'z'.
   Jezeli nie - wiedzialbym juz ze to na pewno nie jest nazwa pola bo
   wszystkie nazwy pol zaczynaja sie z malej litery. Ale nie mozemy tak
   zrobic poniewaz zarowno w VRML'u 1.0 jak 2.0 (97) mozna definiowac
   wlasne niestandardowe node'y i one moga miec pola ktore zaczynaja sie
   od duzych liter. }
  if Lexer.Token = vtName then
  begin
   ni := Fields.NameIndex(Lexer.TokenName);
   if ni >= 0 then
   begin
    ThisIsField := true;

    { Below: usually, it should be just "Lexer.NextToken;"
      But I have to add here some dirty hack to allow SFString fields
      to contain strings not enclosed in double quotes.
      So I have to call here NextTokenForceVTString before SFString field. }
    if Fields[ni] is TSFString then
     Lexer.NextTokenForceVTString else
     Lexer.NextToken;

    Fields[ni].Parse(Lexer, NodeNameBinding);
   end else
   if TryParseSpecialField(Lexer, NodeNameBinding) then
    ThisIsField := true;
  end;

  if not ThisIsField then
   AddChild(ParseNode(Lexer, NodeNameBinding, ParsingAllowedChildren));
 end;
 Lexer.NextToken;

 FWWWBasePath := Lexer.WWWBasePath;
end;

function TVRMLNode.TryParseSpecialField(Lexer: TVRMLLexer;
  NodeNameBinding: TStringList): boolean;
begin
  Result := false;
end;

type
  TEnumerateNodes0Enumerator = class
    Proc: TVRMLNodeProc;
    OnlyActive: boolean;
    procedure EnumerateChildrenFunction(Node, Child: TVRMLNode);
  end;

  procedure TEnumerateNodes0Enumerator.EnumerateChildrenFunction(
    Node, Child: TVRMLNode);
  begin
    Child.EnumerateNodes(Proc, OnlyActive);
  end;

procedure TVRMLNode.EnumerateNodes(
  Proc: TVRMLNodeProc; OnlyActive: boolean);
var
  Enumerator: TEnumerateNodes0Enumerator;
begin
  Proc(Self);

  Enumerator := TEnumerateNodes0Enumerator.Create;
  try
    Enumerator.Proc := Proc;
    Enumerator.OnlyActive := OnlyActive;
    DirectEnumerate(Enumerator.EnumerateChildrenFunction, OnlyActive);
  finally FreeAndNil(Enumerator) end;
end;

type
  TEnumerateNodes1Enumerator = class
    NodeClass: TVRMLNodeClass;
    Proc: TVRMLNodeProc;
    OnlyActive: boolean;
    procedure EnumerateChildrenFunction(Node, Child: TVRMLNode);
  end;

  procedure TEnumerateNodes1Enumerator.EnumerateChildrenFunction(
    Node, Child: TVRMLNode);
  begin
    Child.EnumerateNodes(NodeClass, Proc, OnlyActive);
  end;

procedure TVRMLNode.EnumerateNodes(nodeClass: TVRMLNodeClass;
  Proc: TVRMLNodeProc; OnlyActive: boolean);
var
  Enumerator: TEnumerateNodes1Enumerator;
begin
  if Self is NodeClass then Proc(Self);

  Enumerator := TEnumerateNodes1Enumerator.Create;
  try
    Enumerator.NodeClass := NodeClass;
    Enumerator.Proc := Proc;
    Enumerator.OnlyActive := OnlyActive;
    DirectEnumerate(Enumerator.EnumerateChildrenFunction, OnlyActive);
  finally FreeAndNil(Enumerator) end;
end;

type
  TEnumerateNodes2Enumerator = class
    NodeClass: TVRMLNodeClass;
    SeekNodeName: string;
    Proc: TVRMLNodeProc;
    OnlyActive: boolean;
    procedure EnumerateChildrenFunction(Node, Child: TVRMLNode);
  end;

  procedure TEnumerateNodes2Enumerator.EnumerateChildrenFunction(
    Node, Child: TVRMLNode);
  begin
    Child.EnumerateNodes(NodeClass, SeekNodeName, Proc, OnlyActive);
  end;

procedure TVRMLNode.EnumerateNodes(NodeClass: TVRMLNodeClass;
  const SeekNodeName: string;
  Proc: TVRMLNodeProc; OnlyActive: boolean);
var
  Enumerator: TEnumerateNodes2Enumerator;
begin
  if (Self is nodeClass) and (NodeName = SeekNodeName) then proc(Self);

  Enumerator := TEnumerateNodes2Enumerator.Create;
  try
    Enumerator.NodeClass := NodeClass;
    Enumerator.SeekNodeName := SeekNodeName;
    Enumerator.Proc := Proc;
    Enumerator.OnlyActive := OnlyActive;
    DirectEnumerate(Enumerator.EnumerateChildrenFunction, OnlyActive);
  finally FreeAndNil(Enumerator) end;
end;

type
  BreakTryFindNode = class(TCodeBreaker)
  public
    FoundNode: TVRMLNode;
    constructor Create(AFoundNode: TVRMLNode);
  end;

  constructor BreakTryFindNode.Create(AFoundNode: TVRMLNode);
  begin
    inherited Create;
    FoundNode := AFoundNode;
  end;

procedure TVRMLNode.TryFindNode_Found(Node: TVRMLNode);
begin
  raise BreakTryFindNode.Create(Node);
end;

function TVRMLNode.TryFindNode(FindClass: TVRMLNodeClass;
  OnlyActive: boolean): TVRMLNode;
begin
  try
    EnumerateNodes(FindClass, TryFindNode_Found, OnlyActive);
    Result := nil;
  except
    on B: BreakTryFindNode do Result := B.FoundNode;
  end;
end;

function TVRMLNode.FindNode(FindClass: TVRMLNodeClass; OnlyActive: boolean): TVRMLNode;
begin
  result := TryFindNode(FindClass, OnlyActive);
  Check(result <> nil,
    'Node class '+FindClass.ClassName+' not found (by TVRMLNode.FindNode)');
end;

function TVRMLNode.TryFindNodeByName(
  FindClass: TVRMLNodeClass; const FindName: string;
  OnlyActive: boolean): TVRMLNode;
begin
  try
    EnumerateNodes(FindClass, FindName, TryFindNode_Found, OnlyActive);
    Result := nil;
  except
    on B: BreakTryFindNode do Result := B.FoundNode;
  end;
end;

function TVRMLNode.FindNodeByName(
  FindClass: TVRMLNodeClass; const FindName: string;
  OnlyActive: boolean): TVRMLNode;
begin
  result := TryFindNodeByName(FindClass, FindName, OnlyActive);
  Check(result <> nil,
    'Node name '+FindName+' not found (by TVRMLNode.FindNodeByName)');
end;

{ TVRMLNode.TryFindNodeState/Transform ----------------------------------------- }

  type
    PVRMLNode = ^TVRMLNode;
    PVRMLGraphTraverseState = ^TVRMLGraphTraverseState;
    BreakTryFindNodeState = class(TCodeBreaker);
    TTryFindNodeStateObj = class
      PNode: PVRMLNode;
      PState: PVRMLGraphTraverseState;
      procedure TraverseFunc(ANode: TVRMLNode; AState: TVRMLGraphTraverseState);
    end;

    procedure TTryFindNodeStateObj.TraverseFunc(ANode: TVRMLNode; AState: TVRMLGraphTraverseState);
    begin
     PNode^ := ANode;
     PState^ := TVRMLGraphTraverseState.CreateCopy(AState);
     raise BreakTryFindNodeState.Create;
    end;

function TVRMLNode.TryFindNodeState(InitialState: TVRMLGraphTraverseState;
  NodeClass: TVRMLNodeClass;
  out Node: TVRMLNode; out State: TVRMLGraphTraverseState): boolean;
var Obj: TTryFindNodeStateObj;
begin
 Obj := TTryFindNodeStateObj.Create;
 try
  try
   Obj.PNode := @Node;
   Obj.PState := @State;
   Traverse(InitialState, NodeClass,
     {$ifdef FPC_OBJFPC} @ {$endif} Obj.TraverseFunc);
   result := false;
  except
   on BreakTryFindNodeState do result := true;
  end;
 finally Obj.Free end;
end;

  type
    TTryFindNodeTransformObj = class
      PNode: PVRMLNode;
      PTransform: PMatrix4Single;
      procedure TraverseFunc(ANode: TVRMLNode; AState: TVRMLGraphTraverseState);
    end;

    procedure TTryFindNodeTransformObj.TraverseFunc(ANode: TVRMLNode; AState: TVRMLGraphTraverseState);
    begin
     PNode^ := ANode;
     { to dlatego TryFindNodeTransform jest szybsze od TryFindNodeState :
       w TryFindNodeState trzeba tutaj kopiowac cale state,
       w TryFindNodeTransform wystarczy skopiowac transformacje. }
     PTransform^ := AState.CurrMatrix;
     raise BreakTryFindNodeState.Create;
    end;

function TVRMLNode.TryFindNodeTransform(InitialState: TVRMLGraphTraverseState;
  NodeClass: TVRMLNodeClass;
  out Node: TVRMLNode; out Transform: TMatrix4Single): boolean;
var Obj: TTryFindNodeTransformObj;
begin
 Obj := TTryFindNodeTransformObj.Create;
 try
  try
   Obj.PNode := @Node;
   Obj.PTransform := @Transform;
   Traverse(InitialState, NodeClass,
     {$ifdef FPC_OBJFPC} @ {$endif} Obj.TraverseFunc);
   result := false;
  except
   on BreakTryFindNodeState do result := true;
  end;
 finally Obj.Free end;
end;

function TVRMLNode.TryFindParentByName(const FindName: string): TVRMLNode;
var
  I: integer;
begin
  if NodeName = FindName then
    result := Self else
  begin
    result := nil;

    for I := 0 to ParentNodesCount - 1 do
    begin
      result := ParentNodes[I].TryFindParentByName(FindName);
      if result <> nil then exit;
    end;

    for I := 0 to ParentFieldsCount - 1 do
    begin
      result := ParentFieldsNode[I].TryFindParentByName(FindName);
      if result <> nil then exit;
    end;
  end;
end;

function TVRMLNode.FindParentByName(const FindName: string): TVRMLNode;
begin
  result := TryFindParentByName(FindName);
  Check(result <> nil, 'Node name '+FindName+' not found in parents');
end;

function TVRMLNode.HasParent(Node: TVRMLNode): boolean;
var
  I: integer;
begin
  if Self = Node then
    result := true else
  begin
    for i := 0 to ParentNodesCount - 1 do
      if ParentNodes[i].HasParent(Node) then Exit(true);

    for i := 0 to ParentFieldsCount - 1 do
      if ParentFieldsNode[i].HasParent(Node) then Exit(true);

    result := False;
  end;
end;

type
  TIsNodePresentSeeker = class
    SeekNode: TVRMLNode;
    procedure Seek(Node: TVRMLNode);
  end;

  BreakIsNodePresent = class(TCodeBreaker);

  procedure TIsNodePresentSeeker.Seek(Node: TVRMLNode);
  begin
    if Node = SeekNode then
      raise BreakIsNodePresent.Create;
  end;

function TVRMLNode.IsNodePresent(Node: TVRMLNode;
  OnlyActive: boolean): boolean;
var
  Seeker: TIsNodePresentSeeker;
begin
  Seeker := TIsNodePresentSeeker.Create;
  try
    Seeker.SeekNode := Node;
    try
      EnumerateNodes(Seeker.Seek, OnlyActive);
      Result := false;
    except
      on BreakIsNodePresent do Result := true;
    end;
  finally FreeAndNil(Seeker) end;
end;

type
  TNodeCounter = class
    procedure CountNode(node: TVRMLNode);
    Counter: integer;
  end;

  procedure TNodeCounter.CountNode(node: TVRMLNode);
  begin Inc(Counter) end;

function TVRMLNode.NodesCount(NodeClass: TVRMLNodeClass;
  CountOnlyActiveNodes: boolean): integer;
var
  C: TNodeCounter;
begin
  C := TNodeCounter.Create;
  try
    EnumerateNodes(NodeClass,
      {$ifdef FPC_OBJFPC} @ {$endif} C.CountNode, CountOnlyActiveNodes);
    result := C.Counter;
  finally C.Free end;
end;

procedure TVRMLNode.SaveToStream(Stream: TStream; const Indent: string; NodeNameBinding: TStringList);
var i: integer;
    NewIndent: string;
begin
 if NodeNameBinding.IndexOfObject(Self) >= 0 then
  WriteStr(Stream, Indent +'USE ' +NodeName +nl) else
 begin
  {zapisz nas do strumienia}
  WriteStr(Stream, Indent);
  if NodeName <> '' then WriteStr(Stream, 'DEF ' +NodeName +' ');
  WriteStr(Stream, NodeTypeName +' {' +nl);

  NewIndent := Indent +IndentIncrement;

  for i := 0 to Fields.Count-1 do
   Fields[i].SaveToStream(Stream, NewIndent, NodeNameBinding);
  if ChildrenSaveToStream then
   for i := 0 to ChildrenCount-1 do
    Children[i].SaveToStream(Stream, NewIndent, NodeNameBinding);

  WriteStr(Stream, Indent +'}' +nl);

  {teraz uaktualnij NodeNameBinding}
  if NodeName <> '' then
  begin
   i := NodeNameBinding.IndexOf(NodeName);
   if i >= 0 then
    NodeNameBinding.Objects[i] := Self else
    NodeNameBinding.Addobject(NodeName, Self);
  end;
 end;
end;

class function TVRMLNode.TraverseStateLastNodesIndex: Integer;
{ zwraca indeks do tablicy TraverseStateLastNodesClasses taki ze element
  na tej pozycji = NodeClass. Zwraca -1 jesli nie znalazl. }
begin
 { jestesmy w metodzie klasy, wiec Self to klasa (dlatego ponizej mozemy
   porownywac TraverseStateLastNodesClasses[result] z Self) }
 for result := 0 to HighTraverseStateLastNodes do
  if TraverseStateLastNodesClasses[result] = Self then Exit;
 result := -1;
end;

class function TVRMLNode.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := true;
end;

procedure TVRMLNode.RemoveParentField(Field: TVRMLField);
begin
  Check(FParentFields.Delete(Field), 'RemoveParentField: parent not found');

  if (FParentFields.Count = 0) and
     (FParentNodes.Count = 0) then
  begin
    { This is written as "Self.Destroy" to actually do the desctruction,
      freeing memory etc. If I would just call it "Destroy", it would
      perform what destructor does but leaving object instance unfreed. }
    Self.Destroy;
  end;
end;

procedure TVRMLNode.AddParentField(Field: TVRMLField);
begin
  FParentFields.Add(Field);
end;

function TVRMLNode.ChildrenField: TMFNode;
begin
  Result := nil;
end;

procedure TVRMLNode.SmartAddChild(Node: TVRMLNode);
begin
  if ChildrenField = nil then
    AddChild(Node) else
    ChildrenField.AddItem(Node);
end;

function TVRMLNode.GetSmartChildren(Index: Integer): TVRMLNode;
begin
  if ChildrenField = nil then
    Result := Children[Index] else
    Result := ChildrenField.Items[Index];
end;

function TVRMLNode.SmartChildrenCount: integer;
begin
  if ChildrenField = nil then
    Result := ChildrenCount else
    Result := ChildrenField.Items.Count;
end;

function TVRMLNode.SuggestedVRMLVersion(
  out VerMajor, VerMinor, SuggestionPriority: Integer): boolean;
var
  I, J: Integer;
  SF: TSFNode;
  MF: TMFNode;
  NewResult: boolean;
  NewVerMajor, NewVerMinor, NewSuggestionPriority: Integer;
  ChildIndex: Integer;
begin
  Result := false;

  for I := 0 to Fields.Count - 1 do
  begin
    if Fields[I] is TSFNode then
    begin
      SF := TSFNode(Fields[I]);
      if SF.Value <> nil then
      begin
        NewResult := SF.Value.SuggestedVRMLVersion(
          NewVerMajor, NewVerMinor, NewSuggestionPriority);
        AndSuggestedVRMLVersion(
          Result, VerMajor, VerMinor, SuggestionPriority,
          NewResult, NewVerMajor, NewVerMinor, NewSuggestionPriority);
      end;
    end else
    if Fields[I] is TMFNode then
    begin
      MF := TMFNode(Fields[I]);
      for J := 0 to MF.Items.Count - 1 do
      begin
        NewResult := MF.Items[J].SuggestedVRMLVersion(
          NewVerMajor, NewVerMinor, NewSuggestionPriority);
        AndSuggestedVRMLVersion(
          Result, VerMajor, VerMinor, SuggestionPriority,
          NewResult, NewVerMajor, NewVerMinor, NewSuggestionPriority);
      end;
    end;
  end;

  for ChildIndex := 0 to ChildrenCount - 1 do
  begin
    NewResult :=  Children[ChildIndex].SuggestedVRMLVersion(
      NewVerMajor, NewVerMinor, NewSuggestionPriority);
    AndSuggestedVRMLVersion(
      Result, VerMajor, VerMinor, SuggestionPriority,
      NewResult, NewVerMajor, NewVerMinor, NewSuggestionPriority);
  end;
end;

procedure TVRMLNode.AndSuggestedVRMLVersion(
  var Result: boolean;
  var VerMajor, VerMinor, SuggestionPriority: Integer;
  const NewResult: boolean;
  const NewVerMajor, NewVerMinor, NewSuggestionPriority: Integer);
begin
  if NewResult then
  begin
    if (not Result) or (NewSuggestionPriority >= SuggestionPriority) then
    begin
      VerMajor := NewVerMajor;
      VerMinor := NewVerMinor;
      SuggestionPriority := NewSuggestionPriority;
      Result := true;
    end;
  end;
end;

class function TVRMLNode.ChildrenSaveToStream: boolean;
begin
  Result := true;
end;

{ TVRMLNodeClassesList ------------------------------------------------------- }

function TVRMLNodeClassesList.GetItems(Index: Integer): TVRMLNodeClass;
begin
  Result := TVRMLNodeClass(inherited Items[Index]);
end;

procedure TVRMLNodeClassesList.SetItems(Index: Integer; Value: TVRMLNodeClass);
begin
  inherited Items[Index] := Pointer(Value);
end;

procedure TVRMLNodeClassesList.AssignArray(
  const AItemsArray: array of TVRMLNodeClass);
var
  I: Integer;
begin
  Count := High(AItemsArray) + 1;
  for I := 0 to High(AItemsArray) do
    Items[I] := AItemsArray[I];
end;

function TVRMLNodeClassesList.IndexOf(NodeClass: TVRMLNodeClass): Integer;
begin
  for Result := 0 to Count - 1 do
    if Items[Result] = NodeClass then
      Exit;
  Result := -1;
end;

function TVRMLNodeClassesList.IndexOf(Node: TVRMLNode): Integer;
begin
  Result := IndexOf(TVRMLNodeClass(Node.ClassType));
end;

procedure TVRMLNodeClassesList.Add(Value: TVRMLNodeClass);
begin
  inherited Add(Pointer(Value));
end;

{ TSFNode --------------------------------------------------------------------- }

constructor TSFNode.Create(AParentNode: TVRMLNode; const AName: string;
  const AnAllowedChildren: array of TVRMLNodeClass);
begin
  CreateUndefined(AName);
  FParentNode := AParentNode;
  FAllowedChildren := TVRMLNodeClassesList.Create;
  FAllowedChildren.AssignArray(AnAllowedChildren);
  Value := nil;
end;

constructor TSFNode.Create(AParentNode: TVRMLNode; const AName: string;
  AnAllowedChildren: TVRMLNodeClassesList);
begin
  Create(AParentNode, AName, []);
  FAllowedChildren.Assign(AnAllowedChildren);
end;

destructor TSFNode.Destroy;
begin
  { To delete Self from Value.FParentFields, and eventually free Value. }
  Value := nil;
  FreeAndNil(FAllowedChildren);
  inherited;
end;

procedure TSFNode.Parse(Lexer: TVRMLLexer; NodeNameBinding: TStringList);

  procedure ChildNotAllowed;
  var
    S: string;
  begin
    S := Format('Node "%s" is not allowed in the field "%s"',
      [Value.NodeTypeName, Name]);
    if ParentNode <> nil then
      S += Format(' of the node "%s"', [ParentNode.NodeTypeName]);
    VRMLNonFatalError(S);
  end;

begin
  if (Lexer.Token = vtKeyword) and (Lexer.TokenKeyword = vkNULL) then
  begin
    Value := nil;
    Lexer.NextToken;
  end else
  begin
    Value := ParseNode(Lexer, NodeNameBinding, true);
    if FAllowedChildren.IndexOf(Value) = -1 then
      ChildNotAllowed;
  end;
end;

procedure TSFNode.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
  if Value = nil then
    WriteStr(Stream, 'NULL') else
  begin
    WriteStr(Stream, NL);
    Value.SaveToStream(Stream, Indent + IndentIncrement, NodeNameBinding);
  end;
end;

function TSFNode.EqualsDefaultValue: boolean;
begin
  Result := Value = nil;
end;

function TSFNode.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFNode) and
   (TSFNode(SecondValue).Value = Value);
end;

procedure TSFNode.Assign(Source: TPersistent);
begin
  if Source is TSFNode then
  begin
    FName  := TSFNode(Source).Name;
    { Assign using Value property, so that FParentFields will get
      correctly updated. }
    Value  := TSFNode(Source).Value;
  end else
    inherited;
end;

procedure TSFNode.SetValue(AValue: TVRMLNode);
begin
  if FValue <> AValue then
  begin
    if FValue <> nil then
      FValue.RemoveParentField(Self);

    FValue := AValue;

    if AValue <> nil then
      FValue.AddParentField(Self);
  end;
end;

{ TMFNode -------------------------------------------------------------------- }

constructor TMFNode.Create(AParentNode: TVRMLNode; const AName: string;
  const AnAllowedChildren: array of TVRMLNodeClass);
begin
  inherited Create(AName);
  FParentNode := AParentNode;
  FAllowedChildren := TVRMLNodeClassesList.Create;
  FAllowedChildren.AssignArray(AnAllowedChildren);
  FItems := TVRMLNodesList.Create;
end;

constructor TMFNode.Create(AParentNode: TVRMLNode; const AName: string;
  AnAllowedChildren: TVRMLNodeClassesList);
begin
  Create(AParentNode, AName, []);
  FAllowedChildren.Assign(AnAllowedChildren);
end;

destructor TMFNode.Destroy;
begin
  ClearItems;
  FreeAndNil(FItems);
  FreeAndNil(FAllowedChildren);
  inherited;
end;

procedure TMFNode.SaveToStreamValue(Stream: TStream; const Indent: string;
  NodeNameBinding: TStringList);
var
  I: Integer;
begin
  { We code Count = 0 and Count = 1 cases separately just to get a more
    compact look in these common situations. }
  if Count = 0 then
    WriteStr(Stream, '[]') else
  if Count = 1 then
  begin
    WriteStr(Stream, NL);
    Items[0].SaveToStream(Stream, Indent + IndentIncrement, NodeNameBinding);
  end else
  begin
    WriteStr(Stream, '[' + NL);
    for I := 0 to Count - 1 do
      Items[I].SaveToStream(Stream, Indent + IndentIncrement, NodeNameBinding);
    WriteStr(Stream, Indent + ']');
  end;
end;

function TMFNode.Count: integer;
begin
  Result := Items.Count;
end;

procedure TMFNode.AddItem(Node: TVRMLNode);
begin
  Items.Add(Node);
  Node.AddParentField(Self);
end;

procedure TMFNode.ClearItems;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    FItems[I].RemoveParentField(Self);
  FItems.Count := 0;
end;

procedure TMFNode.AssignItems(SourceItems: TVRMLNodesList);
var
  I: Integer;
begin
  ClearItems;

  Items.Assign(SourceItems);

  for I := 0 to Count - 1 do
    Items[I].AddParentField(Self);
end;

procedure TMFNode.Parse(Lexer: TVRMLLexer; NodeNameBinding: TStringList);

  procedure ChildNotAllowed(Value: TVRMLNode);
  var
    S: string;
  begin
    S := Format('Node "%s" is not allowed in the field "%s"',
      [Value.NodeTypeName, Name]);
    if ParentNode <> nil then
      S += Format(' of the node "%s"', [ParentNode.NodeTypeName]);
    VRMLNonFatalError(S);
  end;

var
  Node: TVRMLNode;
begin
  ClearItems;

  { Note that we ignore commas here, because MFNode is in VRML 2.0 only. }
  if Lexer.Token = vtOpenSqBracket then
  begin
    Lexer.NextToken;

    while Lexer.Token <> vtCloseSqBracket do
    begin
      Node := ParseNode(Lexer, NodeNameBinding, true);
      AddItem(Node);
      if FAllowedChildren.IndexOf(Node) = -1 then
        ChildNotAllowed(Node);
    end;

    Lexer.NextToken;
  end else
    { one single item - not enclosed in [] brackets }
    AddItem(ParseNode(Lexer, NodeNameBinding, true));
end;

function TMFNode.EqualsDefaultValue: boolean;
begin
  Result := Count = 0;
end;

function TMFNode.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
  Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
    (SecondValue is TMFNode) and
    (TMFNode(SecondValue).Items.Equals(Items));
end;

procedure TMFNode.Assign(Source: TPersistent);
begin
  if Source is TMFNode then
  begin
    FName := TMFNode(Source).Name;
    AssignItems(TMFNode(Source).Items);
  end else
    inherited;
end;

{ TNodeGeneralShape_1 -------------------------------------------------------- }

class function TNodeGeneralShape_1.ForVRMLVersion(
  const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor <= 1;
end;

{ specific VRML nodes --------------------------------------------------------- }

{$I vrmlnodes_boundingboxes.inc}
{$I vrmlnodes_verticesandtrianglescounting.inc}
{$I vrmlnodes_triangulating.inc}
{$I vrmlnodes_suggested_vrml_version.inc}

constructor TNodeAsciiText_1.Create(const ANodeName: string; const AWWWBasePath: string);
const A1: array[0..0]of string = ('');
      A2: array[0..2]of string = ('LEFT', 'CENTER', 'RIGHT');
      A3: array[0..0]of Single = (0);
begin
 inherited;
 Fields.Add(TMFString.Create('string', A1));
 Fields.Add(TSFFloat.Create('spacing', 1));
 Fields.Add(TSFEnum.Create('justification', A2, JUSTIFICATION_LEFT));
 Fields.Add(TMFFloat.Create('width', A3));
end;

class function TNodeAsciiText_1.ClassNodeTypeName: string;
begin
 result := 'AsciiText';
end;

function TNodeAsciiText_1.Justify: TVRMLFontJustify;
begin
  Result := TVRMLFontJustify(FdJustification.Value);
end;

constructor TNodeCone_1.Create(const ANodeName: string; const AWWWBasePath: string);
const A1: array[0..1]of string = ('SIDES', 'BOTTOM');
begin
 inherited;
 Fields.Add(TSFBitMask.Create('parts', A1, 'NONE', 'ALL', [true, true]));
 Fields.Add(TSFFloat.Create('bottomRadius', 1, true));
 Fields.Add(TSFFloat.Create('height', 2, true));
end;

class function TNodeCone_1.ClassNodeTypeName: string;
begin
 result := 'Cone';
end;

constructor TNodeCube_1.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFFloat.Create('width', 2, true));
 Fields.Add(TSFFloat.Create('height', 2, true));
 Fields.Add(TSFFloat.Create('depth', 2, true));
end;

class function TNodeCube_1.ClassNodeTypeName: string;
begin
 result := 'Cube';
end;

constructor TNodeCylinder_1.Create(const ANodeName: string; const AWWWBasePath: string);
const A1: array[0..2]of string = ('SIDES', 'TOP', 'BOTTOM');
begin
 inherited;
 Fields.Add(TSFBitMask.Create('parts', A1, 'NONE', 'ALL', [true, true, true]));
 Fields.Add(TSFFloat.Create('radius', 1, true));
 Fields.Add(TSFFloat.Create('height', 2, true));
end;

class function TNodeCylinder_1.ClassNodeTypeName: string;
begin
 result := 'Cylinder';
end;

constructor TNodeGeneralIndexed_1.Create(const ANodeName: string; const AWWWBasePath: string);
const A1: array[0..0]of Longint = (0);
      A2: array[0..0]of Longint = (-1);
begin
 inherited;
 Fields.Add(TMFLong.CreateMFLong('coordIndex', A1, true));
 Fields.Add(TMFLong.Create('materialIndex', A2));
 Fields.Add(TMFLong.Create('normalIndex', A2));
 Fields.Add(TMFLong.CreateMFLong('textureCoordIndex', A2, true));
end;

class function TNodeIndexedFaceSet_1.ClassNodeTypeName: string;
begin
 result := 'IndexedFaceSet';
end;

class function TNodeIndexedTriangleMesh_1.ClassNodeTypeName: string;
begin
 result := 'IndexedTriangleMesh';
end;

class function TNodeIndexedLineSet_1.ClassNodeTypeName: string;
begin
 result := 'IndexedLineSet';
end;

constructor TNodePointSet_1.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFLong.Create('startIndex', 0));
 Fields.Add(TSFLong.Create('numPoints', -1));
end;

class function TNodePointSet_1.ClassNodeTypeName: string;
begin
 result := 'PointSet';
end;

procedure TNodePointSet_1.CalculateRange(LastCoordinate3: TNodeCoordinate3;
  out startIndex, numPoints: integer);
begin
 startIndex := FdStartIndex.Value;
 numPoints := FdNumPoints.Value;
 if startIndex >= LastCoordinate3.FdPoint.Count then
 begin
  startIndex := 0;
  numPoints := 0;
 end else
 begin
  if startIndex < 0 then
  begin
   if numPoints >= 0 then numPoints := numPoints+startIndex;
   startIndex := 0;
  end;

  {startIndex juz jest na pewno dobry, teraz ew. popraw numPoints}
  if numPoints >= 0 then
  begin
   if startIndex+numPoints > LastCoordinate3.FdPoint.Count then
    numPoints := LastCoordinate3.FdPoint.Count-startIndex;
  end else
   numPoints := LastCoordinate3.FdPoint.Count-startIndex;
 end;
end;

constructor TNodeSphere_1.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFFloat.Create('radius', 1, true));
end;

class function TNodeSphere_1.ClassNodeTypeName: string;
begin
 result := 'Sphere';
end;

constructor TNodeCoordinate3.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TMFVec3f.Create('point', [Vector3Single(0, 0, 0)]));
end;

class function TNodeCoordinate3.ClassNodeTypeName: string;
begin
 result := 'Coordinate3';
end;

constructor TNodeFontStyle_1.Create(const ANodeName: string; const AWWWBasePath: string);
const A1: array[0..2]of string = ('SERIF', 'SANS', 'TYPEWRITER');
      A2: array[0..1]of string = ('BOLD', 'ITALIC');
begin
 inherited;
 Fields.Add(TSFFloat.Create('size', 10, true));
 Fields.Add(TSFEnum.Create('family', A1, FSFAMILY_SERIF));
 Fields.Add(TSFBitMask.Create('style', A2, 'NONE', '', [false, false]));
end;

class function TNodeFontStyle_1.ClassNodeTypeName: string;
begin
 result := 'FontStyle';
end;

const
  TTF_Font_Results: array[TVRMLFontFamily, boolean, boolean]of PTrueTypeFont =
  (              {   [],                          [italic],                            [bold],                      [italic, bold] }
    {serif}      ( ((@TTF_BitstreamVeraSerif),   (@TTF_BitstreamVeraSerif_Italic)),    ((@TTF_BitstreamVeraSerif_Bold),    (@TTF_BitstreamVeraSerif_Bold_Italic)) ),
    {sans}       ( ((@TTF_BitstreamVeraSans),    (@TTF_BitstreamVeraSans_Italic)),     ((@TTF_BitstreamVeraSans_Bold),     (@TTF_BitstreamVeraSans_Bold_Italic)) ),
    {typewriter} ( ((@TTF_BitstreamVeraSansMono),(@TTF_BitstreamVeraSansMono_Italic)), ((@TTF_BitstreamVeraSansMono_Bold), (@TTF_BitstreamVeraSansMono_Bold_Italic)) )
  );

function TNodeFontStyle_1.TTF_Font: PTrueTypeFont;
begin
  Result := TTF_Font_Results[Family, Bold, Italic];
end;

function TNodeFontStyle_1.Family: TVRMLFontFamily;
begin
  Result := TVRMLFontFamily(FdFamily.Value);
end;

function TNodeFontStyle_1.Bold: boolean;
begin
  Result := FdStyle.Flags[FSSTYLE_BOLD];
end;

function TNodeFontStyle_1.Italic: boolean;
begin
  Result := FdStyle.Flags[FSSTYLE_ITALIC];
end;

class function TNodeFontStyle_1.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor <= 1;
end;

constructor TNodeInfo.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFString.Create('string', '<Undefined info>'));
end;

class function TNodeInfo.ClassNodeTypeName: string;
begin
 result := 'Info';
end;

constructor TNodeLOD_1.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TMFFloat.Create('range',[]));
 Fields.Add(TSFVec3f.Create('center', Vector3Single(0, 0, 0)));
 fParsingAllowedChildren := true;
 fAllowedChildren := true;
end;

class function TNodeLOD_1.ClassNodeTypeName: string;
begin
 result := 'LOD';
end;

procedure TNodeLOD_1.DirectEnumerateActive(Func: TEnumerateChildrenFunction);
begin
  { TODO: powinnismy tu uzywac odleglosci od viewera ? Problem.
    dla renderowania jest problem z wrzucaniem tego na display liste.
    dla boundingBoxa
      Wybrac ostatnie SubNode bo bedzie je nalatwiej obliczac ?
      Pierwsze, bo jest dokladne ? To ktore renderujemy ?
      W ostatnim przypadku, ladujemy z tym samym klopotem co RenderNKSpecific :
      zapamietywanie takiego BoundingBoxa nie jest poprawne.
  }
  if ChildrenCount = 0 then
    raise EVRMLError.Create('LOD node must have at least one child');

  Func(Self, Children[0]);
end;

class function TNodeLOD_1.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor <= 1;
end;

const
  DEF_MAT_AMBIENT : TVector3Single = (0.2, 0.2, 0.2);
  DEF_MAT_DIFFUSE : TVector3Single = (0.8, 0.8, 0.8);
  DEF_MAT_SPECULAR : TVector3Single = (0, 0, 0);
  DEF_MAT_EMISSIVE : TVector3Single = (0, 0, 0);
  DEF_MAT_SHININESS : Single = 0.2;
  DEF_MAT_TRANSPARENCY : Single = 0;
  DEF_MAT_MIRROR : Single = 0;
  DEF_MAT_REFL_SPECULAR_EXP  : Single = 1000000;
  DEF_MAT_TRANS_SPECULAR_EXP : Single = 1000000;

constructor TNodeMaterial_1.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TMFColor.Create('ambientColor', [DEF_MAT_AMBIENT]));
 Fields.Add(TMFColor.Create('diffuseColor', [DEF_MAT_DIFFUSE]));
 Fields.Add(TMFColor.Create('specularColor', [DEF_MAT_SPECULAR]));
 Fields.Add(TMFColor.Create('emissiveColor', [DEF_MAT_EMISSIVE]));
 Fields.Add(TMFFloat.Create('shininess', [DEF_MAT_SHININESS]));
 Fields.Add(TMFFloat.Create('transparency', [DEF_MAT_TRANSPARENCY]));

 Fields.Add(TMFFloat.Create('mirror', [DEF_MAT_MIRROR]));
 Fields.Add(TMFColor.Create('reflSpecular', []));
 Fields.Add(TMFColor.Create('reflDiffuse', []));
 Fields.Add(TMFColor.Create('transSpecular', []));
 Fields.Add(TMFColor.Create('transDiffuse', []));
 Fields.Add(TMFFloat.Create('reflSpecularExp', [DEF_MAT_REFL_SPECULAR_EXP]));
 Fields.Add(TMFFloat.Create('transSpecularExp', [DEF_MAT_TRANS_SPECULAR_EXP]));

 Fields.Add(TSFBool.Create('fogImmune', false));
end;

class function TNodeMaterial_1.ClassNodeTypeName: string;
begin
 result := 'Material';
end;

{functions below return MatNum Material property. If there doesn't exist
   enouch properties defined, thay return the last defined. This is useful :
   for example you can give one ambient, specular, emissive color and
   define multiple diffuseColors and then you can use multiple materials
   without defining multiple values for each field.
 VRML specification doesn't state clearly what to do when thare are not enouch
   material properties - there were some idea of "cycling" mechanism but was
   later deprecated. So I use the mechanism below - returning to the last defined
   property number. }

{$define MATERIAL_FUNCTION_3_SINGLE:=
function TNodeMaterial_1.MATERIAL_FUNCTION_NAME_3(MatNum: integer): TVector3Single;
begin
 if MATERIAL_FUNCTION_FIELD.Count = 0 then
  result := MATERIAL_FUNCTION_DEFAULT else
  result := MATERIAL_FUNCTION_FIELD.Items.Items[
    min(MatNum, MATERIAL_FUNCTION_FIELD.Count-1)];
end;

function TNodeMaterial_1.MATERIAL_FUNCTION_NAME_4(MatNum: integer): TVector4Single;
var result3: TVector3Single absolute result;
begin
 result3 := MATERIAL_FUNCTION_NAME_3(MatNum);
 result[3] := Opacity(MatNum);
end;
}

  {$define MATERIAL_FUNCTION_FIELD := FdAmbientColor}
  {$define MATERIAL_FUNCTION_DEFAULT := DEF_MAT_AMBIENT}
  {$define MATERIAL_FUNCTION_NAME_3 := AmbientColor3Single}
  {$define MATERIAL_FUNCTION_NAME_4 := AmbientColor4Single}
  MATERIAL_FUNCTION_3_SINGLE

  {$define MATERIAL_FUNCTION_FIELD := FdDiffuseColor}
  {$define MATERIAL_FUNCTION_DEFAULT := DEF_MAT_DIFFUSE}
  {$define MATERIAL_FUNCTION_NAME_3 := DiffuseColor3Single}
  {$define MATERIAL_FUNCTION_NAME_4 := DiffuseColor4Single}
  MATERIAL_FUNCTION_3_SINGLE

  {$define MATERIAL_FUNCTION_FIELD := FdSpecularColor}
  {$define MATERIAL_FUNCTION_DEFAULT := DEF_MAT_SPECULAR}
  {$define MATERIAL_FUNCTION_NAME_3 := SpecularColor3Single}
  {$define MATERIAL_FUNCTION_NAME_4 := SpecularColor4Single}
  MATERIAL_FUNCTION_3_SINGLE

  {$define MATERIAL_FUNCTION_FIELD := FdEmissiveColor}
  {$define MATERIAL_FUNCTION_DEFAULT := DEF_MAT_EMISSIVE}
  {$define MATERIAL_FUNCTION_NAME_3 := EmissiveColor3Single}
  {$define MATERIAL_FUNCTION_NAME_4 := EmissiveColor4Single}
  MATERIAL_FUNCTION_3_SINGLE

{$undef MATERIAL_FUNCTION_3_SINGLE}
{$undef MATERIAL_FUNCTION_FIELD}
{$undef MATERIAL_FUNCTION_DEFAULT}
{$undef MATERIAL_FUNCTION_NAME_3}
{$undef MATERIAL_FUNCTION_NAME_4}

{$define MATERIAL_FUNCTION_SINGLE:=
function TNodeMaterial_1.MATERIAL_FUNCTION_NAME(MatNum: integer): Single;
begin
 if MATERIAL_FUNCTION_FIELD.Count = 0 then
  result := MATERIAL_FUNCTION_DEFAULT else
  result := MATERIAL_FUNCTION_FIELD.Items.Items[
    min(MatNum, MATERIAL_FUNCTION_FIELD.Count-1)];
end;}

  {$define MATERIAL_FUNCTION_NAME := Transparency}
  {$define MATERIAL_FUNCTION_FIELD := FdTransparency}
  {$define MATERIAL_FUNCTION_DEFAULT := DEF_MAT_TRANSPARENCY}
  MATERIAL_FUNCTION_SINGLE

  {$define MATERIAL_FUNCTION_NAME := Mirror}
  {$define MATERIAL_FUNCTION_FIELD := FdMirror}
  {$define MATERIAL_FUNCTION_DEFAULT := DEF_MAT_MIRROR}
  MATERIAL_FUNCTION_SINGLE

  {$define MATERIAL_FUNCTION_NAME := ReflSpecularExp}
  {$define MATERIAL_FUNCTION_FIELD := FdReflSpecularExp}
  {$define MATERIAL_FUNCTION_DEFAULT := DEF_MAT_REFL_SPECULAR_EXP}
  MATERIAL_FUNCTION_SINGLE

  {$define MATERIAL_FUNCTION_NAME := TransSpecularExp}
  {$define MATERIAL_FUNCTION_FIELD := FdTransSpecularExp}
  {$define MATERIAL_FUNCTION_DEFAULT := DEF_MAT_TRANS_SPECULAR_EXP}
  MATERIAL_FUNCTION_SINGLE

{$undef MATERIAL_FUNCTION_NAME}
{$undef MATERIAL_FUNCTION_FIELD}
{$undef MATERIAL_FUNCTION_DEFAULT}
{$undef MATERIAL_FUNCTION_SINGLE}

function TNodeMaterial_1.Opacity(MatNum: integer): Single;
begin
 result := 1-Transparency(MatNum);
end;

function TNodeMaterial_1.Shininess(MatNum: integer): Single;
begin
  if FdShininess.Count = 0 then
    result := DEF_MAT_SHININESS else
    result := FdShininess.Items.Items[min(MatNum, FdShininess.Count-1)];
end;

function TNodeMaterial_1.ShininessExp(MatNum: integer): Single;
begin
  Result := Shininess(MatNum);

 {zgodnie ze specyfikacja VRML'a zakres 0..1 shininess VRML'a mapuje sie
  jednostajnie na caly zakres 0..128 OpenGL'a. Super. Robimy clamp
  na wszelki zas, na wypadek gdybysmy na skutek jakichs bledow nieco wyszli
  za zakres albo gdyby ktos zapisale zla wartosc w pliku (np. ujemna).

  A jezeli odczytana wartosc jest > 2 to zakladamy ze jakis
  kretyn zapisal nieznormalizowane wartosci Shininess w pliku
  (tacy sie zdarzaja, patrz helix.wrl).
  Pisze kretyn a mysle duzo gorzej bo jestem naprawde wkurzony - coraz
  wiecej musze w kodzie wprowadzac poprawek zeby odczytywac niepoprawnie
  zapisane VRMLe. A to rotacja wokol wektora (0, 0, 0) (program "Pioneer")
  a to nieznormalizowany Shininess... }
 if result > 2 then
  result := Clamped(result,         0.0, 128.0) else
  result := Clamped(result * 128.0, 0.0, 128.0);
end;

function TNodeMaterial_1.OnlyEmissiveMaterial: boolean;
begin
 result:=(FdAmbientColor.Count = 0) and
         (FdDiffuseColor.Count = 0) and
         (FdSpecularColor.Count = 0);
end;

{ cztery funkcje ktore w razie braku wartosci zapisanych w polu (FdXxx.Count = 0)
  wyliczaja sobie kolor z innych wlasciwosci materialu. }
{$define MATERIAL_FUNCTION_CALC:=
function TNodeMaterial_1.MATERIAL_FUNCTION_NAME(MatNum: integer): TVector3Single;
begin
 if MATERIAL_FUNCTION_FIELD.Count = 0 then
  result := MATERIAL_FUNCTION_CALCULATE else
  result := MATERIAL_FUNCTION_FIELD.Items.Items[min(MatNum,
    MATERIAL_FUNCTION_FIELD.Count-1)]
end;}

  {$define MATERIAL_FUNCTION_NAME := ReflSpecular}
  {$define MATERIAL_FUNCTION_FIELD := FdReflSpecular}
  {$define MATERIAL_FUNCTION_CALCULATE:=
    Vector3Single(Mirror(MatNum), Mirror(MatNum), Mirror(MatNum))}
  MATERIAL_FUNCTION_CALC

  {$define MATERIAL_FUNCTION_NAME := ReflDiffuse}
  {$define MATERIAL_FUNCTION_FIELD := FdReflDiffuse}
  {$define MATERIAL_FUNCTION_CALCULATE:=
    DiffuseColor3Single(MatNum)}
  MATERIAL_FUNCTION_CALC

  {$define MATERIAL_FUNCTION_NAME := TransSpecular}
  {$define MATERIAL_FUNCTION_FIELD := FdTransSpecular}
  {$define MATERIAL_FUNCTION_CALCULATE:=
    Vector3Single(Transparency(MatNum), Transparency(MatNum), Transparency(MatNum))}
  MATERIAL_FUNCTION_CALC

  {$define MATERIAL_FUNCTION_NAME := TransDiffuse}
  {$define MATERIAL_FUNCTION_FIELD := FdTransDiffuse}
  {$define MATERIAL_FUNCTION_CALCULATE:=
    VectorScale(DiffuseColor3Single(MatNum), Transparency(MatNum) )}
  MATERIAL_FUNCTION_CALC

{$undef MATERIAL_FUNCTION_CALC}
{$undef MATERIAL_FUNCTION_NAME}
{$undef MATERIAL_FUNCTION_FIELD}
{$undef MATERIAL_FUNCTION_CALCULATE}

function TNodeMaterial_1.IsAllMaterialsTransparent: boolean;
var i: Integer;
begin
 if FdTransparency.Items.Length = 0 then
  result := DEF_MAT_TRANSPARENCY > SingleEqualityEpsilon else
 begin
  for i := 0 to FdTransparency.Items.Length-1 do
   if FdTransparency.Items.Items[i] <= SingleEqualityEpsilon then Exit(false);
  result := true;
 end;
end;

class function TNodeMaterial_1.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor <= 1;
end;

constructor TNodeMaterialBinding.Create(const ANodeName: string; const AWWWBasePath: string);
const A1: array[0..7]of string = ('DEFAULT', 'OVERALL',
  'PER_PART', 'PER_PART_INDEXED',
  'PER_FACE', 'PER_FACE_INDEXED',
  'PER_VERTEX', 'PER_VERTEX_INDEXED');
begin
 inherited;
 Fields.Add(TSFEnum.Create('value', A1, 1));
end;

class function TNodeMaterialBinding.ClassNodeTypeName: string;
begin
 result := 'MaterialBinding';
end;

constructor TNodeNormalBinding.Create(const ANodeName: string; const AWWWBasePath: string);
const A1: array[0..7]of string = ('DEFAULT', 'OVERALL',
  'PER_PART', 'PER_PART_INDEXED',
  'PER_FACE', 'PER_FACE_INDEXED',
  'PER_VERTEX', 'PER_VERTEX_INDEXED');
begin
 inherited;
 Fields.Add(TSFEnum.Create('value', A1, 0));
end;

class function TNodeNormalBinding.ClassNodeTypeName: string;
begin
 result := 'NormalBinding';
end;

constructor TNodeGeneralTexture.Create(const ANodeName: string;
  const AWWWBasePath: string);
begin
  inherited;
  FTextureImage := TRGBImage.Create;
  FIsTextureLoaded := false;
end;

destructor TNodeGeneralTexture.Destroy;
begin
  FreeAndNil(FTextureImage);
  inherited;
end;

function TNodeGeneralTexture.TextureImage: TImage;
begin
  if not IsTextureLoaded then ReloadTexture;
  Assert(IsTextureLoaded);
  result := FTextureImage;
end;

function TNodeGeneralTexture.IsTextureImage: boolean;
begin
  result := not TextureImage.IsNull;
end;

procedure TNodeGeneralTexture.ReloadTexture;

  procedure ReplaceTextureImage(NewFTextureImage: TImage);
  begin
    FreeAndNil(FTextureImage);
    FTextureImage := NewFTextureImage;
  end;

var
  LoadedImage: TImage;
begin
  { Just like in implementation of TSFImage.Parse:

    Note that we should never let FTextureImage to be nil too long,
    because even if this method exits with exception, FTextureImage should
    always remain non-nil.
    That's why I'm doing below FTextureImage.Null instead of
    FreeAndNil(FTextureImage) and I'm using ReplaceTextureImage to set
    new FTextureImage.
    This way if e.g. TRGBImage.Create inside LoadTextureImage
    will raise out of mem exception,
    FTextureImage will still remain non-nil.

    This is all because I just changed Images unit interface to class-like
    and I want to do minimal changes to VRMLNodes unit to not break
    anything. TODO -- this will be solved better in the future, by simply
    allowing TextureImage to be nil at any time.
  }

  FTextureImage.Null;

  LoadedImage := LoadTextureImage;
  if LoadedImage <> nil then
    ReplaceTextureImage(LoadedImage);

  FIsTextureLoaded := true;
end;

constructor TNodeTexture2.Create(const ANodeName: string; const AWWWBasePath: string);
const A1: array[0..1]of string = ('REPEAT', 'CLAMP');
begin
 inherited;
 Fields.Add(TSFString.Create('filename', ''));
 Fields.Add(TSFImage.Create('image', nil));
 Fields.Add(TSFEnum.Create('wrapS', A1, TEXWRAP_REPEAT));
 Fields.Add(TSFEnum.Create('wrapT', A1, TEXWRAP_REPEAT));
 Fields.Add(TSFEnum.Create('model', ['DECAL'], 0));
 Fields.Add(TSFVec3f.Create('blendColor', Vector3Single(0, 0, 0)));
end;

class function TNodeTexture2.ClassNodeTypeName: string;
begin
 result := 'Texture2';
end;

function TNodeTexture2.LoadTextureImage: TImage;
var
  FullUrl: string;
begin
  Result := nil;

  FullUrl := PathFromWWWBasePath(FdFilename.Value);

  { sprobuj zaladowac teksture z pliku FdFilename }
  if FdFilename.Value <> '' then
  try
    Result := LoadImage(FullUrl, [TRGBImage, TAlphaImage], []);
  except
    on E: Exception do
      { pamietajmy ze VRMLNonFatalError moze spowodowac rzucenie wyjatku
        (chociaz nie musi) }
      VRMLNonFatalError('Exception ' + E.ClassName +
        ' occured when trying to load '+
        'texture from filename "' + FullUrl + '" : ' + E.Message);
  end;

  { Result = nil oznacza ze nie bylo filename albo tekstury z
    filename nie dalo sie zaladowac. Wiec jezeli jest to uzywamy inlined
    tekstury (w polu FdImage) }
  if (Result = nil) and (not FdImage.Value.IsNull) then
    Result := FdImage.Value.MakeCopy;
end;

function TNodeTexture2.TextureDescription: string;

  function InlinedDescr: string;
  begin
    result := Format('inlined (width = %d; height = %d; with alpha = %s)',
      [ FdImage.Value.Width, FdImage.Value.Height,
        BoolToStr[FdImage.Value is TAlphaImage] ]);
  end;

begin
  if FdFilename.Value <> '' then
  begin
    result := 'file "' +PathFromWWWBasePath(FdFilename.Value) +'"';
    if not FdImage.Value.IsNull then result += ' (and '+InlinedDescr+')';
  end else
  if not FdImage.Value.IsNull then
    result := InlinedDescr else
    result := 'none';
end;

function TNodeTexture2.RepeatS: boolean;
begin
  Result := FdWrapS.Value = TEXWRAP_REPEAT;
end;

function TNodeTexture2.RepeatT: boolean;
begin
  Result := FdWrapT.Value = TEXWRAP_REPEAT;
end;

constructor TNodeTexture2Transform.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFVec2f.Create('translation', Vector2Single(0, 0)));
 Fields.Add(TSFFloat.Create('rotation', 0));
 Fields.Add(TSFVec2f.Create('scaleFactor', Vector2Single(1, 1)));
 Fields.Add(TSFVec2f.Create('center', Vector2Single(0, 0)));
end;

class function TNodeTexture2Transform.ClassNodeTypeName: string;
begin
 result := 'Texture2Transform';
end;

function TNodeTexture2Transform.TextureMatrixTransformation: TMatrix4Single;
begin
 result := TranslationMatrix( Vector3Single(
   VectorAdd(FdTranslation.Value, FdCenter.Value) ));
 result := MultMatrices(result, RotationMatrixRad(FdRotation.Value, Vector3Single(0, 0, 1)));
 result := MultMatrices(result, ScalingMatrix(
   Vector3Single( FdScaleFactor.Value[0], FdScaleFactor.Value[1], 1 )));
 result := MultMatrices(result, TranslationMatrix(
   Vector3Single( -FdCenter.Value[0], -FdCenter.Value[1], 0 )));
end;

procedure TNodeTexture2Transform.MiddleTraverse(State: TVRMLGraphTraverseState);
begin
 inherited;
 State.CurrTextureMatrix := MultMatrices(State.CurrTextureMatrix,
   TextureMatrixTransformation);
end;

constructor TNodeTextureCoordinate2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TMFVec2f.Create('point', [Vector2Single(0, 0)]));
end;

class function TNodeTextureCoordinate2.ClassNodeTypeName: string;
begin
 result := 'TextureCoordinate2';
end;

constructor TNodeShapeHints.Create(const ANodeName: string;
  const AWWWBasePath: string);
const
  A1: array[0..2]of string = ('UNKNOWN_ORDERING', 'CLOCKWISE', 'COUNTERCLOCKWISE');
  A2: array[0..1]of string = ('UNKNOWN_SHAPE_TYPE', 'SOLID');
  A3: array[0..1]of string = ('UNKNOWN_FACE_TYPE', 'CONVEX');
begin
 inherited;
 Fields.Add(TSFEnum.Create('vertexOrdering', A1, VERTORDER_UNKNOWN));
 Fields.Add(TSFEnum.Create('shapeType', A2, SHTYPE_UNKNOWN));
 Fields.Add(TSFEnum.Create('faceType', A3, FACETYPE_CONVEX));
 Fields.Add(TSFFloat.Create('creaseAngle', 0.5));
end;

class function TNodeShapeHints.ClassNodeTypeName: string;
begin
 result := 'ShapeHints';
end;

function TNodeShapeHints.TryParseSpecialField(Lexer: TVRMLLexer;
  NodeNameBinding: TStringList): boolean;
const A1: array[0..2]of string=('SOLID', 'ORDERED', 'CONVEX');
var Hints: TSFBitMask;
begin
 if (Lexer.VRMLVerMajor = 0) and (Lexer.TokenName = 'hints') then
 begin
  Hints := TSFBitMask.Create('hints', A1, 'NONE', '',  [false, true, true]);
  try
   Lexer.NextToken;
   Hints.Parse(Lexer, NodeNameBinding);
   if Hints.Flags[0] then
    FdShapeType.Value := SHTYPE_SOLID else
    FdShapeType.Value := SHTYPE_UNKNOWN;
   if Hints.Flags[1] then
    FdVertexOrdering.Value := VERTORDER_COUNTERCLOCKWISE else
    FdVertexOrdering.Value := VERTORDER_UNKNOWN;
   if Hints.Flags[2] then
    FdFaceType.Value := FACETYPE_CONVEX else
    FdFaceType.Value := FACETYPE_UNKNOWN;
  finally Hints.Free end;
  result := true;
 end else
  result := false;
end;

procedure TNodeGeneralTransformation.MiddleTraverse(State: TVRMLGraphTraverseState);
begin
 inherited;
 State.CurrMatrix := MultMatrices(State.CurrMatrix, MatrixTransformation);
end;

constructor TNodeMatrixTransform.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFMatrix.Create('matrix', IdentityMatrix4Single));
end;

class function TNodeMatrixTransform.ClassNodeTypeName: string;
begin
 result := 'MatrixTransform';
end;

function TNodeMatrixTransform.MatrixTransformation: TMatrix4Single;
begin
 result := FdMatrix.Matrix;
end;

constructor TNodeRotation.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFRotation.Create('rotation', Vector3Single(0, 0, 1), 0));
end;

class function TNodeRotation.ClassNodeTypeName: string;
begin
 result := 'Rotation';
end;

function TNodeRotation.MatrixTransformation: TMatrix4Single;
begin
 {glRotate OpenGL'a ma obroty skierowane w ta sama strone co
    w/g specyfikacji VRML'a, wiec wszystko OK.
  Musimy sie tu zabezpieczyc przed glupim wektorem FdRotation -
    program o nazwie "Pioneer" potrafi takie cos zapisywac do
    pliku VRMla. }
 if IsZeroVector(FdRotation.Axis) then
  result := IdentityMatrix4Single else
  result := RotationMatrixRad(FdRotation.RotationRad, FdRotation.Axis);
end;

constructor TNodeRotationXYZ.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFEnum.Create('axis' , ['X', 'Y', 'Z'], 0));
 Fields.Add(TSFFloat.Create('angle', 0));
end;

class function TNodeRotationXYZ.ClassNodeTypeName: string;
begin
 Result := 'RotationXYZ';
end;

function TNodeRotationXYZ.MatrixTransformation: TMatrix4Single;
const
  AxisVectors: array[0..2]of TVector3Single =
  ( (1, 0, 0), (0, 1, 0), (0, 0, 1) );
begin
 Result := RotationMatrixRad(FdAngle.Value, AxisVectors[FdAxis.Value]);
end;

constructor TNodeScale.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFVec3f.Create('scaleFactor', Vector3Single(1, 1, 1)));
end;

class function TNodeScale.ClassNodeTypeName: string;
begin
 result := 'Scale';
end;

function TNodeScale.MatrixTransformation: TMatrix4Single;
begin
 result := ScalingMatrix(FdScaleFactor.Value);
end;

constructor TNodeTransform_1.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFVec3f.Create('translation', Vector3Single(0, 0, 0)));
 Fields.Add(TSFRotation.Create('rotation', Vector3Single(0, 0, 1), 0));
 Fields.Add(TSFVec3f.Create('scaleFactor', Vector3Single(1, 1, 1)));
 Fields.Add(TSFRotation.Create('scaleOrientation', Vector3Single(0, 0, 1), 0));
 Fields.Add(TSFVec3f.Create('center', Vector3Single(0, 0, 0)));
end;

class function TNodeTransform_1.ClassNodeTypeName: string;
begin
 result := 'Transform';
end;

function TNodeTransform_1.MatrixTransformation: TMatrix4Single;
begin
 result := TranslationMatrix(FdTranslation.Value);
 result := MultMatrices(result, TranslationMatrix(FdCenter.Value));
 if not IsZeroVector(FdRotation.Axis) then
  result := MultMatrices(result,
    RotationMatrixRad(FdRotation.RotationRad, FdRotation.Axis));
 result := MultMatrices(result,
   RotationMatrixRad(FdScaleOrientation.RotationRad, FdScaleOrientation.Axis));
 result := MultMatrices(result, ScalingMatrix(FdScaleFactor.Value));
 result := MultMatrices(result,
   RotationMatrixRad(-FdScaleOrientation.RotationRad, FdScaleOrientation.Axis));
 result := MultMatrices(result, TranslationMatrix(VectorNegate(FdCenter.Value)));
end;

class function TNodeTransform_1.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor <= 1;
end;

constructor TNodeTranslation.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFVec3f.Create('translation', Vector3Single(0, 0, 0)));
end;

class function TNodeTranslation.ClassNodeTypeName: string;
begin
 result := 'Translation';
end;

function TNodeTranslation.MatrixTransformation: TMatrix4Single;
begin
 result := TranslationMatrix(FdTranslation.Value);
end;

constructor TNodeGeneralViewpoint.Create(
  const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFVec3f.Create('position', Vector3Single(0, 0, 1)));
  Fields.Add(TSFRotation.Create('orientation', Vector3Single(0, 0, 1), 0));
  Fields.Add(TMFVec3f.Create('direction', []));
  Fields.Add(TMFVec3f.Create('up', []));
end;

procedure TNodeGeneralViewpoint.GetCameraVectors(
  const CamTransform: TMatrix4Single;
  out CamPos, CamDir, CamUp: TVector3Single);
begin
  CamPos := FdPosition.Value;
  if FdDirection.Items.Length > 0 then
    CamDir := FdDirection.Items.Items[0] else
    CamDir := FdOrientation.RotatedPoint( StdVRMLCamDir );
  if FdUp.Items.Length > 0 then
    CamUp := FdUp.Items.Items[0] else
    CamUp := FdOrientation.RotatedPoint( StdVRMLCamUp );

  { niestety, macierz ponizej moze cos skalowac wiec nawet jesli powyzej
    uzylismy FdOrientation.RotatedPoint( StdVRMLCamDir/Up ) i wiemy ze CamDir/Up
    jest znormalizowane - to i tak musimy je tutaj znormalizowac.
    TODO: byloby dobrze uzyc tutaj czegos jak MultMatrixPointNoTranslationNoScale }
  CamPos := MultMatrixPoint(CamTransform, CamPos);
  CamDir := Normalized( MultMatrixPointNoTranslation(CamTransform, CamDir) );
  CamUp := Normalized( MultMatrixPointNoTranslation(CamTransform, CamUp) );

  Assert(FloatsEqual(VectorLenSqr(CamDir), 1.0, 0.0001));
  Assert(FloatsEqual(VectorLenSqr(CamUp), 1.0, 0.0001));
end;

constructor TNodeGeneralVRML1Camera.Create(
  const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFFloat.Create('focalDistance', 5, true));
  Fields.Add(TSFFloat.Create('heightAngle', 0.785398, true));
  Fields.Add(TSFFloat.Create('nearDistance', 0));
  Fields.Add(TSFFloat.Create('farDistance', 0));
end;

class function TNodeOrthographicCamera.ClassNodeTypeName: string;
begin
 result := 'OrthographicCamera';
end;

class function TNodeOrthographicCamera.CameraKind: TVRMLCameraKind;
begin
 result := ckOrthographic;
end;

class function TNodePerspectiveCamera.ClassNodeTypeName: string;
begin
 result := 'PerspectiveCamera';
end;

class function TNodePerspectiveCamera.CameraKind: TVRMLCameraKind;
begin
 result := ckPerspective;
end;

constructor TNodeGeneralLight.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFBool.Create('on', true)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('intensity', 1)); Fields.Last.Exposed := true;
  Fields.Add(TSFColor.Create('color', Vector3Single(1, 1, 1))); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('ambientIntensity', -1)); Fields.Last.Exposed := true;
end;

procedure TNodeGeneralLight.MiddleTraverse(State: TVRMLGraphTraverseState);
begin
  inherited;
  State.ActiveLights.AddLight(Self, State.CurrMatrix);
end;

constructor TNodeGeneralPositionalLight.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFVec3f.Create('location', Vector3Single(0, 0, 1))); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('attenuation', Vector3Single(1, 0, 0))); Fields.Last.Exposed := true;
end;

function TNodeGeneralPositionalLight.DistanceNeededForAttenuation: boolean;
begin
  Result := (FdAttenuation.Value[1] > 0) or (FdAttenuation.Value[2] > 0);
end;

{$define ATTENUATION_IMPLEMENTATION:=
begin
 (* moglibysmy tu nie badac czy DistanceNeededForAttenuation i zawsze
    robic wersje pelna (bo przeciez
      FdAttenuation.Value[1] * DistanceToLight +
      FdAttenuation.Value[2] * Sqr(DistanceToLight)
    i tak bedzie = 0 gdy FdAttenuation.Value[1] = FdAttenuation.Value[2] = 0.
    Ale wydaje mi sie ze tak jest szybciej - testowanie kosztuje nas
    troszke czasu ale mozemy sobie w ten sposob ocalic 2 x mnozenie i dodawanie. *)

 (* we check whether attenuation = (0, 0, 0). VRML 97 spec says that specifying
    (0, 0, 0) should be equal to specifying (1, 0, 0). (well, we avoid
    division by zero possibility this way so it's quite sensible, even
    if it wastes some time) *)
 if (FdAttenuation.Value[0] = 0) and
    (FdAttenuation.Value[1] = 0) and
    (FdAttenuation.Value[2] = 0) then result := 1;

 if DistanceNeededForAttenuation then
  result := 1/ KambiUtils.max(FdAttenuation.Value[0] +
                   FdAttenuation.Value[1] * DistanceToLight +
                   FdAttenuation.Value[2] * Sqr(DistanceToLight), Single(1.0)) else
  result := 1/ KambiUtils.max(FdAttenuation.Value[0], Single(1.0));
end;}

function TNodeGeneralPositionalLight.Attenuation(const DistanceToLight: Single): Single;
ATTENUATION_IMPLEMENTATION

function TNodeGeneralPositionalLight.Attenuation(const DistanceToLight: Double): Double;
ATTENUATION_IMPLEMENTATION

constructor TNodeGeneralDirectionalLight.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFVec3f.Create('direction', Vector3Single(0, 0, -1))); Fields.Last.Exposed := true;
end;

class function TNodeGeneralDirectionalLight.ClassNodeTypeName: string;
begin
 result := 'DirectionalLight';
end;

class function TNodeDirectionalLight_1.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor <= 1;
end;

constructor TNodeGeneralPointLight.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { no new fields - this is just TNodeGeneralPositionalLight }
end;

class function TNodeGeneralPointLight.ClassNodeTypeName: string;
begin
  Result := 'PointLight';
end;

class function TNodePointLight_1.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor <= 1;
end;

constructor TNodeSpotLight_1.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFVec3f.Create('direction', Vector3Single(0, 0, -1)));
 Fields.Add(TSFFloat.Create('dropOffRate', 0));
 Fields.Add(TSFFloat.Create('cutOffAngle', 0.785398));
end;

class function TNodeSpotLight_1.ClassNodeTypeName: string;
begin
 result := 'SpotLight';
end;

function TNodeSpotLight_1.SpotExp: Single;
begin
 result := FdDropOffRate.Value*128.0;
end;

class function TNodeSpotLight_1.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor <= 1;
end;

constructor TNodeGroup_1.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 fParsingAllowedChildren := true;
 fAllowedChildren := true;
end;

class function TNodeGroup_1.ClassNodeTypeName: string;
begin
 result := 'Group';
end;

class function TNodeGroup_1.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor <= 1;
end;

constructor TNodeGeneralSeparator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 fParsingAllowedChildren := true;
 fAllowedChildren := true;
end;

procedure TNodeGeneralSeparator.BeforeTraverse(var State: TVRMLGraphTraverseState);
begin
 inherited;
 OriginalState := State;
 State := TVRMLGraphTraverseState.CreateCopy(OriginalState);
end;

procedure TNodeGeneralSeparator.AfterTraverse(var State: TVRMLGraphTraverseState);
begin
 State.Free;
 State := OriginalState;
 inherited;
end;

constructor TNodeSeparator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFEnum.Create('renderCulling', ['ON', 'OFF', 'AUTO'], 2));
end;

class function TNodeSeparator.ClassNodeTypeName: string;
begin
 result := 'Separator';
end;

constructor TNodeSwitch_1.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFLong.Create('whichChild', -1));
 fParsingAllowedChildren := true;
 fAllowedChildren := true;
end;

class function TNodeSwitch_1.ClassNodeTypeName: string;
begin
 result := 'Switch';
end;

procedure TNodeSwitch_1.DirectEnumerateActive(Func: TEnumerateChildrenFunction);
begin
  if FdWhichChild.Value = -3 then
  begin
    { Enumerate all.
      Note : value -3 is already deprecated in VRML 1.0;
      but I support it, at least for now. }
    inherited;
  end else
  begin
    { Jezeli whichChild jest nieprawidlowe to w rezultacie nie wejdziemy w
      zadne Child. Wpp. wejdziemy w jedno wyznaczone child. I o to chodzi.
      (note : value -1 is no special value; any value that doesn't specify
      valid child number and is not -3 instructs Switch to not enter
      into any child. This is conformant with VRML 97 specification) }
    if Between(FdWhichChild.Value, 0, ChildrenCount - 1) then
      Func(Self, Children[FdWhichChild.Value]);
  end;
end;

class function TNodeSwitch_1.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor <= 1;
end;

constructor TNodeTransformSeparator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 fParsingAllowedChildren := true;
 fAllowedChildren := true;
end;

class function TNodeTransformSeparator.ClassNodeTypeName: string;
begin
 result := 'TransformSeparator';
end;

procedure TNodeTransformSeparator.BeforeTraverse(var State: TVRMLGraphTraverseState);
begin
 inherited;
 {nie robimy kopii calego State'a bo w TVRMLRenderState moga byc
  jeszcze inne informacje ktore powinny "przeciec" na zewnatrz
  TransformSeparator'a.}
 OriginalMatrix := State.CurrMatrix;
end;

procedure TNodeTransformSeparator.AfterTraverse(var State: TVRMLGraphTraverseState);
begin
 State.CurrMatrix := OriginalMatrix;
 inherited;
end;

constructor TNodeWWWAnchor.Create(const ANodeName: string; const AWWWBasePath: string);
const A1: array[0..1]of string = ('NONE','POINT');
begin
 inherited;
 Fields.Add(TSFString.Create('name', ''));
 Fields.Add(TSFString.Create('description', ''));
 Fields.Add(TSFEnum.Create('map', A1, 0));
end;

class function TNodeWWWAnchor.ClassNodeTypeName: string;
begin
 result := 'WWWAnchor';
end;

constructor TNodeWWWInline.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFString.Create('name', ''));
 Fields.Add(TSFVec3f.Create('bboxSize', Vector3Single(0, 0, 0)));
 Fields.Add(TSFVec3f.Create('bboxCenter', Vector3Single(0, 0, 0)));
 Fields.Add(TSFBool.Create('separate', true));

 fParsingAllowedChildren := false;
 fAllowedChildren := true;
end;

class function TNodeWWWInline.ClassNodeTypeName: string;
begin
 result := 'WWWInline';
end;

procedure TNodeWWWInline.LoadInlined(CanReload: boolean);
begin
 if ChildrenCount > 0 then
 begin
  if CanReload then RemoveAllChildren else exit;
 end;
 AddChild(LoadAsVRML(PathFromWWWBasePath(FdName.Value), false));
end;

procedure TNodeWWWInline.BeforeTraverse(var State: TVRMLGraphTraverseState);
begin
 inherited;

 { We save here BeforeTraversePushedState, to be safe in case
   someone will change FdSeparate.Value between BeforeTraverse
   and AfterTraverse. }
 BeforeTraversePushedState := FdSeparate.Value;
 if BeforeTraversePushedState then
 begin
   OriginalState := State;
   State := TVRMLGraphTraverseState.CreateCopy(OriginalState);
 end;

 LoadInlined(false);
end;

procedure TNodeWWWInline.AfterTraverse(var State: TVRMLGraphTraverseState);
begin
 if BeforeTraversePushedState then
 begin
   FreeAndNil(State);
   State := OriginalState;
 end;

 inherited;
end;

class function TNodeWWWInline.ChildrenSaveToStream: boolean;
begin
  Result := false;
end;

const
  TriangulationUseDef = -1;

constructor TNodeKambiTriangulation.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 inherited;
 Fields.Add(TSFLong.Create('quadricSlices', TriangulationUseDef));
 Fields.Add(TSFLong.Create('quadricStacks', TriangulationUseDef));
 Fields.Add(TSFLong.Create('rectDivisions', TriangulationUseDef));
end;

class function TNodeKambiTriangulation.ClassNodeTypeName: string;
begin
 result := 'KambiTriangulation';
end;

{$define TRIANGULATION_DETAIL_FUNC:=
function TNodeKambiTriangulation.TRIANGULATION_DETAIL_FUNC_NAME: Cardinal;
begin
 if TRIANGULATION_DETAIL_FIELD.Value = TriangulationUseDef then
  result := TRIANGULATION_DETAIL_GLOBAL_VALUE else
 begin
  if Int64(TRIANGULATION_DETAIL_FIELD.Value) < Int64(TRIANGULATION_DETAIL_MIN) then
  begin
   VRMLNonFatalError(Format('Node "KambiTriangulation" '+
     'field "%s" value is %d but must be >= %d (or = -1)',
     [TRIANGULATION_DETAIL_FIELD_STRING,
      TRIANGULATION_DETAIL_FIELD.Value,
      TRIANGULATION_DETAIL_MIN]));
   TRIANGULATION_DETAIL_FIELD.Value := TRIANGULATION_DETAIL_GLOBAL_VALUE;
  end;

  result := TRIANGULATION_DETAIL_FIELD.Value;
 end;
end;}

  {$define TRIANGULATION_DETAIL_FUNC_NAME := QuadricSlices}
  {$define TRIANGULATION_DETAIL_FIELD := FdQuadricSlices}
  {$define TRIANGULATION_DETAIL_GLOBAL_VALUE := Detail_QuadricSlices}
  {$define TRIANGULATION_DETAIL_MIN := MinQuadricSlices}
  {$define TRIANGULATION_DETAIL_FIELD_STRING := 'quadricSlices'}
  TRIANGULATION_DETAIL_FUNC

  {$define TRIANGULATION_DETAIL_FUNC_NAME := QuadricStacks}
  {$define TRIANGULATION_DETAIL_FIELD := FdQuadricStacks}
  {$define TRIANGULATION_DETAIL_GLOBAL_VALUE := Detail_QuadricStacks}
  {$define TRIANGULATION_DETAIL_MIN := MinQuadricStacks}
  {$define TRIANGULATION_DETAIL_FIELD_STRING := 'quadricStacks'}
  TRIANGULATION_DETAIL_FUNC

  {$define TRIANGULATION_DETAIL_FUNC_NAME := RectDivisions}
  {$define TRIANGULATION_DETAIL_FIELD := FdRectDivisions}
  {$define TRIANGULATION_DETAIL_GLOBAL_VALUE := Detail_RectDivisions}
  {$define TRIANGULATION_DETAIL_MIN := MinRectDivisions}
  {$define TRIANGULATION_DETAIL_FIELD_STRING := 'rectDivisions'}
  TRIANGULATION_DETAIL_FUNC

{$undef TRIANGULATION_DETAIL_FUNC_NAME}
{$undef TRIANGULATION_DETAIL_FIELD}
{$undef TRIANGULATION_DETAIL_GLOBAL_VALUE}
{$undef TRIANGULATION_DETAIL_MIN}
{$undef TRIANGULATION_DETAIL_FIELD_STRING}
{$undef TRIANGULATION_DETAIL_FUNC}

{ Alphabetically, all VRML 97 nodes ------------------------------------------ }

procedure TNodeGeneralGrouping.BeforeTraverse(
  var State: TVRMLGraphTraverseState);
begin
  inherited;
  OriginalState := State;
  State := TVRMLGraphTraverseState.CreateCopy(OriginalState);
end;

procedure TNodeGeneralGrouping.AfterTraverse(
  var State: TVRMLGraphTraverseState);
begin
  FreeAndNil(State);
  State := OriginalState;
  inherited;
end;

class function TNodeAnchor.ClassNodeTypeName: string;
begin
  Result := 'Anchor';
end;

constructor TNodeAnchor.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      MFNode   addChildren }
  { eventIn      MFNode   removeChildren }
  Fields.Add(TMFNode.Create(Self, 'children', AllowedChildrenNodes)); Fields.Last.Exposed := true;
  Fields.Add(TSFString.Create('description', '')); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('parameter', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('url', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('bboxCenter', ZeroVector3Single));
  Fields.Add(TSFVec3f.Create('bboxSize', Vector3Single(-1, -1, -1)));
end;

function TNodeAnchor.ChildrenField: TMFNode;
begin
  Result := FdChildren;
end;

procedure TNodeAnchor.DirectEnumerateActive(Func: TEnumerateChildrenFunction);
var
  I: Integer;
begin
  for I := 0 to FdChildren.Count - 1 do
    Func(Self, FdChildren.Items[I]);
end;

class function TNodeAppearance.ClassNodeTypeName: string;
begin
  Result := 'Appearance';
end;

constructor TNodeAppearance.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFNode.Create(Self, 'material',
    [TNodeMaterial_2]));
  Fields.Last.Exposed := true;

  Fields.Add(TSFNode.Create(Self, 'texture',
    [TNodeImageTexture, TNodeMovieTexture, TNodePixelTexture]));
  Fields.Last.Exposed := true;

  Fields.Add(TSFNode.Create(Self, 'textureTransform',
    [TNodeTextureTransform]));
  Fields.Last.Exposed := true;
end;

class function TNodeAudioClip.ClassNodeTypeName: string;
begin
  Result := 'AudioClip';
end;

constructor TNodeAudioClip.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFString.Create('description', '')); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('loop', FALSE)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('pitch', 1.0)); Fields.Last.Exposed := true;
  Fields.Add(TSFTime.Create('startTime', 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFTime.Create('stopTime', 0)); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('url', [])); Fields.Last.Exposed := true;
  { eventOut       SFTime   duration_changed }
  { eventOut       SFBool   isActive }
end;

constructor TNodeBackground.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      SFBool   set_bind }
  Fields.Add(TMFFloat.Create('groundAngle', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFColor.Create('groundColor', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('backUrl', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('bottomUrl', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('frontUrl', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('leftUrl', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('rightUrl', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('topUrl', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('skyAngle', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFColor.Create('skyColor', [ZeroVector3Single])); Fields.Last.Exposed := true;
  { eventOut     SFBool   isBound }

  ImageClassesAssign(FAllowedBgImagesClasses, []);
  FBgImagesLoaded := false;
  FBgImages := BackgroundImagesNone;
end;

class function TNodeBackground.ClassNodeTypeName: string;
begin
 result := 'Background';
end;

procedure TNodeBackground.UnloadImages;
begin
 FBgImagesLoaded := false;
 BackgroundImagesFreeAll(FbgImages);
end;

procedure TNodeBackground.Parse(Lexer: TVRMLLexer; NodeNameBinding: TStringList);
begin
 inherited;
 UnloadImages;
end;

function TNodeBackground.GetBgImages: TBackgroundImages;
begin
 if not FBgImagesLoaded then ReloadBgImages;
 result := FBgImages;
end;

procedure TNodeBackground.ReloadBgImages;

  procedure LoadImg(bs: TBackgroundSide; Urls: TMFString);
  var
    I: Integer;
    URL: string;
  begin
    FBgImages[bs] := nil;
    for i := 0 to Urls.Count-1 do
    begin
      try
        URL := PathFromWWWBasePath(Urls.Items.Items[i]);
        FBgImages[bs] := LoadImage(URL, AllowedBgImagesClasses, [], 0, 0);
        Break;
      except
        on E: Exception do
        begin
          VRMLNonFatalError('Exception ' + E.ClassName +
            ' occured when trying to load ' +
            'background image from URL "' + URL + '" : '+E.Message);
          { and silence exception }
        end;
      end;
    end;
  end;

begin
 if FBgImagesLoaded then UnloadImages;

 LoadImg(bsBack, FdBackUrl);
 LoadImg(bsBottom, FdBottomUrl);
 LoadImg(bsFront, FdFrontUrl);
 LoadImg(bsLeft, FdLeftUrl);
 LoadImg(bsRight, FdRightUrl);
 LoadImg(bsTop, FdTopUrl);

 FBgImagesLoaded := true;
end;

procedure TNodeBackground.SetAllowedBgImagesClasses(const Value: array of TImageClass);
begin
 if not ImageClassesEqual(Value, AllowedBgImagesClasses) then
 begin
  ImageClassesAssign(FAllowedBgImagesClasses, Value);
  UnloadImages;
 end;
end;

destructor TNodeBackground.Destroy;
begin
 UnloadImages;
 inherited;
end;

class function TNodeBillboard.ClassNodeTypeName: string;
begin
  Result := 'Billboard';
end;

constructor TNodeBillboard.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      MFNode   addChildren }
  { eventIn      MFNode   removeChildren }
  Fields.Add(TSFVec3f.Create('axisOfRotation', Vector3Single(0, 1, 0))); Fields.Last.Exposed := true;
  Fields.Add(TMFNode.Create(Self, 'children', AllowedChildrenNodes)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('bboxCenter', ZeroVector3Single));
  Fields.Add(TSFVec3f.Create('bboxSize', Vector3Single(-1, -1, -1)));
end;

function TNodeBillboard.ChildrenField: TMFNode;
begin
  Result := FdChildren;
end;

procedure TNodeBillboard.DirectEnumerateActive(Func: TEnumerateChildrenFunction);
var
  I: Integer;
begin
  for I := 0 to FdChildren.Count - 1 do
    Func(Self, FdChildren.Items[I]);
end;

class function TNodeBox.ClassNodeTypeName: string;
begin
  Result := 'Box';
end;

constructor TNodeBox.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFVec3f.Create('size', Vector3Single(2, 2, 2)));
end;

class function TNodeCollision.ClassNodeTypeName: string;
begin
  Result := 'Collision';
end;

constructor TNodeCollision.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      MFNode   addChildren }
  { eventIn      MFNode   removeChildren }
  Fields.Add(TMFNode.Create(Self, 'children', AllowedChildrenNodes)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('collide', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('bboxCenter', ZeroVector3Single));
  Fields.Add(TSFVec3f.Create('bboxSize', Vector3Single(-1, -1, -1)));
  Fields.Add(TSFNode.Create(Self, 'proxy', AllowedChildrenNodes));
  { eventOut     SFTime   collideTime }
end;

function TNodeCollision.ChildrenField: TMFNode;
begin
  Result := FdChildren;
end;

procedure TNodeCollision.DirectEnumerateActive(Func: TEnumerateChildrenFunction);
var
  I: Integer;
begin
  for I := 0 to FdChildren.Count - 1 do
    Func(Self, FdChildren.Items[I]);
end;

class function TNodeColor.ClassNodeTypeName: string;
begin
  Result := 'Color';
end;

constructor TNodeColor.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFColor.Create('color', [])); Fields.Last.Exposed := true;
end;

class function TNodeColorInterpolator.ClassNodeTypeName: string;
begin
  Result := 'ColorInterpolator';
end;

constructor TNodeColorInterpolator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      SFFloat set_fraction }
  Fields.Add(TMFFloat.Create('key', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFColor.Create('keyValue', [])); Fields.Last.Exposed := true;
  { eventOut     SFColor value_changed }
end;

class function TNodeCone_2.ClassNodeTypeName: string;
begin
  Result := 'Cone';
end;

constructor TNodeCone_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFFloat.Create('bottomRadius', 1));
  Fields.Add(TSFFloat.Create('height', 2));
  Fields.Add(TSFBool.Create('side', TRUE));
  Fields.Add(TSFBool.Create('bottom', TRUE));
end;

class function TNodeCone_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

class function TNodeContour2D.ClassNodeTypeName: string;
begin
  Result := 'Contour2D';
end;

constructor TNodeContour2D.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      MFNode  addChildren }
  { eventIn      MFNode  removeChildren }
  Fields.Add(TMFNode.Create(Self, 'children',
    [TNodeNurbsCurve2D, TNodePolyline2D, TNodeContour2D]));
  Fields.Last.Exposed := true;
end;

class function TNodeCoordinate.ClassNodeTypeName: string;
begin
  Result := 'Coordinate';
end;

constructor TNodeCoordinate.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFVec3f.Create('point', [])); Fields.Last.Exposed := true;
end;

class function TNodeCoordinateDeformer.ClassNodeTypeName: string;
begin
  Result := 'CoordinateDeformer';
end;

constructor TNodeCoordinateDeformer.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      MFNode   addChildren }
  { eventIn      MFNode   removeChildren }
  Fields.Add(TMFNode.Create(Self, 'children', AllowedChildrenNodes)); Fields.Last.Exposed := true;
  Fields.Add(TMFVec3f.Create('controlPoint', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFNode.Create(Self, 'inputCoord', [TNodeCoordinate])); Fields.Last.Exposed := true;
  Fields.Add(TMFNode.Create(Self, 'inputTransform', [TNodeTransform_2])); Fields.Last.Exposed := true;
  Fields.Add(TMFNode.Create(Self, 'outputCoord', [TNodeCoordinate])); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('weight', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('bboxCenter', ZeroVector3Single));
  Fields.Add(TSFVec3f.Create('bboxSize', Vector3Single(-1, -1, -1)));
  Fields.Add(TSFInt32.Create('uDimension', 0));
  Fields.Add(TMFFloat.Create('uKnot', []));
  Fields.Add(TSFInt32.Create('uOrder', 2));
  Fields.Add(TSFInt32.Create('vDimension', 0));
  Fields.Add(TMFFloat.Create('vKnot', []));
  Fields.Add(TSFInt32.Create('vOrder', 2));
  Fields.Add(TSFInt32.Create('wDimension', 0));
  Fields.Add(TMFFloat.Create('wKnot', []));
  Fields.Add(TSFInt32.Create('wOrder', 2));
end;

function TNodeCoordinateDeformer.ChildrenField: TMFNode;
begin
  Result := FdChildren;
end;

class function TNodeCoordinateInterpolator.ClassNodeTypeName: string;
begin
  Result := 'CoordinateInterpolator';
end;

constructor TNodeCoordinateInterpolator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      SFFloat set_fraction }
  Fields.Add(TMFFloat.Create('key', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFVec3f.Create('keyValue', [])); Fields.Last.Exposed := true;
  { eventOut     MFVec3f value_changed }
end;

class function TNodeCylinder_2.ClassNodeTypeName: string;
begin
  Result := 'Cylinder';
end;

constructor TNodeCylinder_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFBool.Create('bottom', TRUE));
  Fields.Add(TSFFloat.Create('height', 2));
  Fields.Add(TSFFloat.Create('radius', 1));
  Fields.Add(TSFBool.Create('side', TRUE));
  Fields.Add(TSFBool.Create('top', TRUE));
end;

class function TNodeCylinder_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

class function TNodeCylinderSensor.ClassNodeTypeName: string;
begin
  Result := 'CylinderSensor';
end;

constructor TNodeCylinderSensor.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFBool.Create('autoOffset', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('diskAngle', 0.262)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('enabled', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('maxAngle', -1)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('minAngle', 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('offset', 0)); Fields.Last.Exposed := true;
  { eventOut     SFBool     isActive }
  { eventOut     SFRotation rotation_changed }
  { eventOut     SFVec3f    trackPoint_changed }
end;

constructor TNodeDirectionalLight_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { Default value of ambientIntensity for VRML 1.0 and 2.0 is different,
    see comments at ambientIntensity in implementation of TPointLight_2. }
  FdAmbientIntensity.Value := 0;
  FdAmbientIntensity.DefaultValue := 0;
end;

class function TNodeDirectionalLight_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

class function TNodeElevationGrid.ClassNodeTypeName: string;
begin
  Result := 'ElevationGrid';
end;

constructor TNodeElevationGrid.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      MFFloat  set_height }
  Fields.Add(TSFNode.Create(Self, 'color', [TNodeColor])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'normal', [TNodeNormal])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'texCoord', [TNodeTextureCoordinate])); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('height', []));
  Fields.Add(TSFBool.Create('ccw', TRUE));
  Fields.Add(TSFBool.Create('colorPerVertex', TRUE));
  Fields.Add(TSFFloat.Create('creaseAngle', 0));
  Fields.Add(TSFBool.Create('normalPerVertex', TRUE));
  Fields.Add(TSFBool.Create('solid', TRUE));
  Fields.Add(TSFInt32.Create('xDimension', 0));
  Fields.Add(TSFFloat.Create('xSpacing', 1.0));
  Fields.Add(TSFInt32.Create('zDimension', 0));
  Fields.Add(TSFFloat.Create('zSpacing', 1.0));
end;

class function TNodeExtrusion.ClassNodeTypeName: string;
begin
  Result := 'Extrusion';
end;

constructor TNodeExtrusion.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn MFVec2f    set_crossSection }
  { eventIn MFRotation set_orientation }
  { eventIn MFVec2f    set_scale }
  { eventIn MFVec3f    set_spine }
  Fields.Add(TSFBool.Create('beginCap', TRUE));
  Fields.Add(TSFBool.Create('ccw', TRUE));
  Fields.Add(TSFBool.Create('convex', TRUE));
  Fields.Add(TSFFloat.Create('creaseAngle', 0));
  Fields.Add(TMFVec2f.Create('crossSection', [ Vector2Single(1, 1), Vector2Single(1, -1), Vector2Single(-1, -1),  Vector2Single(-1, 1),  Vector2Single(1, 1) ]));
  Fields.Add(TSFBool.Create('endCap', TRUE));
  Fields.Add(TMFRotation.Create('orientation', [ Vector4Single(0, 0, 1, 0) ] ));
  Fields.Add(TMFVec2f.Create('scale', Vector2Single(1, 1)));
  Fields.Add(TSFBool.Create('solid', TRUE));
  Fields.Add(TMFVec3f.Create('spine', [ Vector3Single(0, 0, 0), Vector3Single(0, 1, 0) ]));
end;

class function TNodeFog.ClassNodeTypeName: string;
begin
  Result := 'Fog';
end;

constructor TNodeFog.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFColor.Create('color', Vector3Single(1, 1, 1))); Fields.Last.Exposed := true;
  Fields.Add(TSFString.Create('fogType', 'LINEAR')); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('visibilityRange', 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('volumetric', false));
  Fields.Add(TSFVec3f.Create('volumetricDirection', Vector3Single(0, -1, 0)));
  Fields.Add(TSFFloat.Create('volumetricVisibilityStart', 0));
  { eventIn      SFBool   set_bind }
  { eventOut     SFBool   isBound }
end;

class function TNodeFontStyle_2.ClassNodeTypeName: string;
begin
  Result := 'FontStyle';
end;

constructor TNodeFontStyle_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFString.Create('family', ['SERIF']));
  Fields.Add(TSFBool.Create('horizontal', TRUE));
  Fields.Add(TMFString.Create('justify', ['BEGIN']));
  Fields.Add(TSFString.Create('language', ''));
  Fields.Add(TSFBool.Create('leftToRight', TRUE));
  Fields.Add(TSFFloat.Create('size', DefaultSize));
  Fields.Add(TSFFloat.Create('spacing', DefaultSpacing));
  Fields.Add(TSFString.Create('style', 'PLAIN'));
  Fields.Add(TSFBool.Create('topToBottom', TRUE));
end;

class function TNodeFontStyle_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

function TNodeFontStyle_2.TTF_Font: PTrueTypeFont;
begin
  Result := TTF_Font_Results[Family, Bold, Italic];
end;

function TNodeFontStyle_2.Family: TVRMLFontFamily;
var
  I: Integer;
begin
  for I := 0 to FdFamily.Items.Count - 1 do
    if FdFamily.Items[I] = 'SERIF' then
      Exit(ffSerif) else
    if FdFamily.Items[I] = 'SANS' then
      Exit(ffSans) else
    if FdFamily.Items[I] = 'TYPEWRITER' then
      Exit(ffTypeWriter) else
      VRMLNonFatalError('Font family "' + FdFamily.Items[I] + '" not supported');

  { If no supported values on FdFamily.Items then fall back to serif }
  Result := ffSerif;
end;

const
  StyleBold = 'BOLD';
  StyleBoldItalic = 'BOLDITALIC';
  StyleItalic = 'ITALIC';
  StylePlain = 'PLAIN';

function TNodeFontStyle_2.Bold: boolean;
begin
  Result :=
    (FdStyle.Value = StyleBold) or
    (FdStyle.Value = StyleBoldItalic);

  { This is the end of calculating Result.
    But we would like to make a warning in case of invalid FdStyle
    value, so we do check below. }

  if not Result then
  begin
    if not (
      (FdStyle.Value = StyleItalic) or
      (FdStyle.Value = StylePlain) or
      (FdStyle.Value = '')) then
      VRMLNonFatalError('Font style "' + FdStyle.Value + '" not supported');
  end;
end;

function TNodeFontStyle_2.Italic: boolean;
begin
  Result :=
    (FdStyle.Value = StyleItalic) or
    (FdStyle.Value = StyleBoldItalic);

  { This is the end of calculating Result.
    But we would like to make a warning in case of invalid FdStyle
    value, so we do check below. }

  if not Result then
  begin
    if not (
      (FdStyle.Value = StyleBold) or
      (FdStyle.Value = StylePlain) or
      (FdStyle.Value = '')) then
      VRMLNonFatalError('Font style "' + FdStyle.Value + '" not supported');
  end;
end;

function TNodeFontStyle_2.Justify: TVRMLFontJustify;
begin
  if FdJustify.Items.Count = 0 then
    Result := fjBegin else
  begin
    if (FdJustify.Items[0] = 'BEGIN') or
       (FdJustify.Items[0] = 'FIRST') then
      Result := fjBegin else
    if FdJustify.Items[0] = 'MIDDLE' then
      Result := fjMiddle else
    if FdJustify.Items[0] = 'END' then
      Result := fjEnd else
    begin
      Result := fjBegin;
      VRMLNonFatalError('Font justify "' + FdJustify.Items[0] +
        '" not supported');
    end;
  end;
end;

class function TNodeFontStyle_2.DefaultSize: Single;
begin
  Result := 1;
end;

class function TNodeFontStyle_2.DefaultSpacing: Single;
begin
  Result := 1;
end;

class function TNodeFontStyle_2.DefaultFamily: TVRMLFontFamily;
begin
  Result := ffSerif;
end;

class function TNodeFontStyle_2.DefaultBold: boolean;
begin
  Result := false;
end;

class function TNodeFontStyle_2.DefaultItalic: boolean;
begin
  Result := false;
end;

class function TNodeFontStyle_2.DefaultJustify: TVRMLFontJustify;
begin
  Result := fjBegin;
end;

class function TNodeFontStyle_2.DefaultTTF_Font: PTrueTypeFont;
begin
  Result := TTF_Font_Results[DefaultFamily, DefaultBold, DefaultItalic];
end;

class function TNodeGeoCoordinate.ClassNodeTypeName: string;
begin
  Result := 'GeoCoordinate';
end;

constructor TNodeGeoCoordinate.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFNode.Create(Self, 'geoOrigin', [TNodeGeoOrigin]));
  Fields.Add(TMFString.Create('geoSystem', ['GD','WE']));
  Fields.Add(TMFString.Create('point', []));
end;

class function TNodeGeoElevationGrid.ClassNodeTypeName: string;
begin
  Result := 'GeoElevationGrid';
end;

constructor TNodeGeoElevationGrid.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn        MFFloat    set_height }
  { eventIn        SFFloat    set_yScale }
  Fields.Add(TSFNode.Create(Self, 'color', [TNodeColor])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'normal', [TNodeNormal])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'texCoord', [TNodeTextureCoordinate])); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('ccw', TRUE));
  Fields.Add(TSFBool.Create('colorPerVertex', TRUE));
  Fields.Add(TSFFloat.Create('creaseAngle', 0));
  Fields.Add(TSFNode.Create(Self, 'geoOrigin', [TNodeGeoOrigin]));
  Fields.Add(TMFString.Create('geoSystem', ['GD','WE']));
  Fields.Add(TSFString.Create('geoGridOrigin', '0 0 0'));
  Fields.Add(TMFFloat.Create('height', []));
  Fields.Add(TSFBool.Create('normalPerVertex', TRUE));
  Fields.Add(TSFBool.Create('solid', TRUE));
  Fields.Add(TSFInt32.Create('xDimension', 0));
  Fields.Add(TSFString.Create('xSpacing', '1.0'));
  Fields.Add(TSFFloat.Create('yScale', 1.0));
  Fields.Add(TSFInt32.Create('zDimension', 0));
  Fields.Add(TSFString.Create('zSpacing', '1.0'));
end;

class function TNodeGeoLocation.ClassNodeTypeName: string;
begin
  Result := 'GeoLocation';
end;

constructor TNodeGeoLocation.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFString.Create('geoCoords', '')); Fields.Last.Exposed := true;
  Fields.Add(TMFNode.Create(Self, 'children', AllowedChildrenNodes));
  Fields.Add(TSFNode.Create(Self, 'geoOrigin', [TNodeGeoOrigin]));
  Fields.Add(TMFString.Create('geoSystem', ['GD','WE']));
end;

function TNodeGeoLocation.ChildrenField: TMFNode;
begin
  Result := FdChildren;
end;

class function TNodeGeoLOD.ClassNodeTypeName: string;
begin
  Result := 'GeoLOD';
end;

constructor TNodeGeoLOD.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFString.Create('center', ''));
  Fields.Add(TMFString.Create('child1Url', []));
  Fields.Add(TMFString.Create('child2Url', []));
  Fields.Add(TMFString.Create('child3Url', []));
  Fields.Add(TMFString.Create('child4Url', []));
  Fields.Add(TSFNode.Create(Self, 'geoOrigin', [TNodeGeoOrigin]));
  Fields.Add(TMFString.Create('geoSystem', ['GD','WE']));
  Fields.Add(TSFFloat.Create('range', 10));
  Fields.Add(TMFString.Create('rootUrl', []));
  Fields.Add(TMFNode.Create(Self, 'rootNode', AllowedChildrenNodes));
  { eventOut   MFNode    children }
end;

class function TNodeGeoMetadata.ClassNodeTypeName: string;
begin
  Result := 'GeoMetadata';
end;

constructor TNodeGeoMetadata.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFNode.Create(Self, 'data', AllowedChildrenNodes)); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('summary', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('url', [])); Fields.Last.Exposed := true;
end;

class function TNodeGeoOrigin.ClassNodeTypeName: string;
begin
  Result := 'GeoOrigin';
end;

constructor TNodeGeoOrigin.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFString.Create('geoSystem', ['GD','WE'])); Fields.Last.Exposed := true;
  Fields.Add(TSFString.Create('geoCoords', '')); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('rotateYUp', FALSE));
end;

class function TNodeGeoPositionInterpolator.ClassNodeTypeName: string;
begin
  Result := 'GeoPositionInterpolator';
end;

constructor TNodeGeoPositionInterpolator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn   SFFloat   set_fraction }
  Fields.Add(TSFNode.Create(Self, 'geoOrigin', [TNodeGeoOrigin]));
  Fields.Add(TMFString.Create('geoSystem', ['GD','WE']));
  Fields.Add(TMFFloat.Create('key', []));
  Fields.Add(TMFString.Create('keyValue', []));
  { eventOut  SFString  geovalue_changed }
  { eventOut  SFVec3f   value_changed }
end;

class function TNodeGeoTouchSensor.ClassNodeTypeName: string;
begin
  Result := 'GeoTouchSensor';
end;

constructor TNodeGeoTouchSensor.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFBool.Create('enabled', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'geoOrigin', [TNodeGeoOrigin]));
  Fields.Add(TMFString.Create('geoSystem', ['GD','WE']));
  { eventOut      SFVec3f   hitNormal_changed }
  { eventOut      SFVec3f   hitPoint_changed }
  { eventOut      SFVec2f   hitTexCoord_changed }
  { eventOut      SFString  hitGeoCoord_changed }
  { eventOut      SFBool    isActive }
  { eventOut      SFBool    isOver }
  { eventOut      SFTime    touchTime }
end;

class function TNodeGeoViewpoint.ClassNodeTypeName: string;
begin
  Result := 'GeoViewpoint';
end;

constructor TNodeGeoViewpoint.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn        SFBool       set_bind }
  { eventIn        SFString     set_orientation }
  { eventIn        SFString     set_position }
  Fields.Add(TSFFloat.Create('fieldOfView', 0.785398)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('headlight', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('jump', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('navType', ['EXAMINE','ANY'])); Fields.Last.Exposed := true;
  Fields.Add(TSFString.Create('description', ''));
  Fields.Add(TSFNode.Create(Self, 'geoOrigin', [TNodeGeoOrigin]));
  Fields.Add(TMFString.Create('geoSystem', ['GD','WE']));
  Fields.Add(TSFRotation.Create('orientation', Vector3Single(0, 0, 1), 0));
  Fields.Add(TSFString.Create('position', '0 0 100000'));
  Fields.Add(TSFFloat.Create('speedFactor', 1.0));
  { eventOut       SFTime       bindTime }
  { eventOut       SFBool       isBound }
end;

class function TNodeGroup_2.ClassNodeTypeName: string;
begin
  Result := 'Group';
end;

constructor TNodeGroup_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      MFNode  addChildren }
  { eventIn      MFNode  removeChildren }
  Fields.Add(TMFNode.Create(Self, 'children', AllowedChildrenNodes)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('bboxCenter', ZeroVector3Single));
  Fields.Add(TSFVec3f.Create('bboxSize', Vector3Single(-1, -1, -1)));
end;

class function TNodeGroup_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

function TNodeGroup_2.ChildrenField: TMFNode;
begin
  Result := FdChildren;
end;

procedure TNodeGroup_2.DirectEnumerateActive(Func: TEnumerateChildrenFunction);
var
  I: Integer;
begin
  for I := 0 to FdChildren.Count - 1 do
    Func(Self, FdChildren.Items[I]);
end;

class function TNodeImageTexture.ClassNodeTypeName: string;
begin
  Result := 'ImageTexture';
end;

constructor TNodeImageTexture.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFString.Create('url', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('repeatS', TRUE));
  Fields.Add(TSFBool.Create('repeatT', TRUE));
end;

function TNodeImageTexture.LoadTextureImage: TImage;
var
  I: Integer;
  FullUrl: string;
begin
  Result := nil;

  FUsedUrl := '';
  for I := 0 to FdUrl.Count - 1 do
  begin
    FullUrl := PathFromWWWBasePath(FdUrl.Items[I]);
    try
      Result := LoadImage(FullUrl, [TRGBImage, TAlphaImage], []);
      FUsedUrl := FullUrl;
      Break;
    except
      on E: Exception do
        { pamietajmy ze VRMLNonFatalError moze spowodowac rzucenie wyjatku
          (chociaz nie musi) }
        VRMLNonFatalError('Exception ' + E.ClassName +
          ' occured when trying to load ' +
          'texture from filename "' + FullUrl + '" : ' + E.Message);
    end;
  end;
end;

function TNodeImageTexture.TextureDescription: string;
begin
  if UsedUrl <> '' then
    Result := 'file "' +PathFromWWWBasePath(UsedUrl) +'"' else
    Result := 'none';
end;

function TNodeImageTexture.RepeatS: boolean;
begin
  Result := FdRepeatS.Value;
end;

function TNodeImageTexture.RepeatT: boolean;
begin
  Result := FdRepeatT.Value;
end;

class function TNodeIndexedFaceSet_2.ClassNodeTypeName: string;
begin
  Result := 'IndexedFaceSet';
end;

constructor TNodeIndexedFaceSet_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn       MFInt32 set_colorIndex }
  { eventIn       MFInt32 set_coordIndex }
  { eventIn       MFInt32 set_normalIndex }
  { eventIn       MFInt32 set_texCoordIndex }
  Fields.Add(TSFNode.Create(Self, 'color', [TNodeColor])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'coord', [TNodeCoordinate, TNodeGeoCoordinate])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'normal', [TNodeNormal])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'texCoord', [TNodeTextureCoordinate])); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('ccw', TRUE));
  Fields.Add(TMFInt32.Create('colorIndex', []));
  Fields.Add(TSFBool.Create('colorPerVertex', TRUE));
  Fields.Add(TSFBool.Create('convex', TRUE));
  Fields.Add(TMFInt32.CreateMFLong('coordIndex', [], true));
  Fields.Add(TSFFloat.Create('creaseAngle', 0));
  Fields.Add(TMFInt32.Create('normalIndex', []));
  Fields.Add(TSFBool.Create('normalPerVertex', TRUE));
  Fields.Add(TSFBool.Create('solid', TRUE));
  Fields.Add(TMFInt32.CreateMFLong('texCoordIndex', [], true));
end;

class function TNodeIndexedFaceSet_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

class function TNodeIndexedLineSet_2.ClassNodeTypeName: string;
begin
  Result := 'IndexedLineSet';
end;

constructor TNodeIndexedLineSet_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn       MFInt32 set_colorIndex }
  { eventIn       MFInt32 set_coordIndex }
  Fields.Add(TSFNode.Create(Self, 'color', [TNodeColor])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'coord', [TNodeCoordinate, TNodeGeoCoordinate])); Fields.Last.Exposed := true;
  Fields.Add(TMFInt32.Create('colorIndex', []));
  Fields.Add(TSFBool.Create('colorPerVertex', TRUE));
  Fields.Add(TMFInt32.CreateMFLong('coordIndex', [], true));
end;

class function TNodeIndexedLineSet_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

class function TNodeInline.ClassNodeTypeName: string;
begin
  Result := 'Inline';
end;

constructor TNodeInline.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFString.Create('url', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('bboxCenter', ZeroVector3Single));
  Fields.Add(TSFVec3f.Create('bboxSize', Vector3Single(-1, -1, -1)));

  FParsingAllowedChildren := false;
  FAllowedChildren := true;
end;

procedure TNodeInline.LoadInlined(CanReload: boolean);
var
  I: Integer;
  FullUrl: string;
  NewNode: TVRMLNode;
begin
  if ChildrenCount > 0 then
  begin
    if CanReload then RemoveAllChildren else Exit;
  end;

  NewNode := nil;

  for I := 0 to FdUrl.Items.Count - 1 do
  begin
    FullUrl := PathFromWWWBasePath(FdUrl.Items[I]);
    try
      NewNode := LoadAsVRML(PathFromWWWBasePath(FullUrl), false);
      Break;
    except
      on E: Exception do
        { pamietajmy ze VRMLNonFatalError moze spowodowac rzucenie wyjatku
          (chociaz nie musi) }
        VRMLNonFatalError('Exception ' + E.ClassName +
          ' occured when trying to load '+
          'inline file from URL "' + FullUrl + ' : ' + E.Message);
    end;
  end;

  if NewNode <> nil then
    AddChild(NewNode);
end;

procedure TNodeInline.BeforeTraverse(var State: TVRMLGraphTraverseState);
begin
  inherited;
  LoadInlined(false);
end;

class function TNodeInline.ChildrenSaveToStream: boolean;
begin
  Result := false;
end;

class function TNodeInlineLoadControl.ClassNodeTypeName: string;
begin
  Result := 'InlineLoadControl';
end;

constructor TNodeInlineLoadControl.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFBool.Create('load', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('url', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('bboxCenter', ZeroVector3Single));
  Fields.Add(TSFVec3f.Create('bboxSize', Vector3Single(-1, -1, -1)));
  { eventOut     MFNode    children }

  FParsingAllowedChildren := false;
  FAllowedChildren := true;
end;

procedure TNodeInlineLoadControl.LoadInlined(CanReload: boolean);
var
  I: Integer;
  FullUrl: string;
  NewNode: TVRMLNode;
begin
  { TODO: InlineLoadControl should load it's contents to
    children MFNode, and we should make a way (analogous
    to TNodeInlineLoadControl.ChildrenSaveToStream)
    to say that "we don't want to save to stream "children" field".
    For now it's not really important (user doesn't see
    where it's loaded), but it will be later for scripts. }

  if ChildrenCount > 0 then
  begin
    if CanReload then RemoveAllChildren else Exit;
  end;

  if not FdLoad.Value then Exit;

  NewNode := nil;

  for I := 0 to FdUrl.Items.Count - 1 do
  begin
    FullUrl := PathFromWWWBasePath(FdUrl.Items[I]);
    try
      NewNode := LoadAsVRML(PathFromWWWBasePath(FullUrl), false);
      Break;
    except
      on E: Exception do
        { pamietajmy ze VRMLNonFatalError moze spowodowac rzucenie wyjatku
          (chociaz nie musi) }
        VRMLNonFatalError('Exception ' + E.ClassName +
          ' occured when trying to load '+
          'inline file from URL "' + FullUrl + ' : ' + E.Message);
    end;
  end;

  if NewNode <> nil then
    AddChild(NewNode);
end;

procedure TNodeInlineLoadControl.BeforeTraverse(var State: TVRMLGraphTraverseState);
begin
  inherited;
  LoadInlined(false);
end;

class function TNodeInlineLoadControl.ChildrenSaveToStream: boolean;
begin
  Result := false;
end;

class function TNodeLOD_2.ClassNodeTypeName: string;
begin
  Result := 'LOD';
end;

constructor TNodeLOD_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFNode.Create(Self, 'level', AllowedChildrenNodes)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('center', ZeroVector3Single));
  Fields.Add(TMFFloat.Create('range', []));
end;

class function TNodeLOD_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

function TNodeLOD_2.ChildrenField: TMFNode;
begin
  Result := FdLevel;
end;

procedure TNodeLOD_2.DirectEnumerateActive(Func: TEnumerateChildrenFunction);
begin
  { For now we simply always use the best LOD version,
    avoiding whole issue of choosing proper LOD child. }
  if FdLevel.Items.Count >= 1 then
    Func(Self, FdLevel.Items[0]);
end;

class function TNodeMaterial_2.ClassNodeTypeName: string;
begin
  Result := 'Material';
end;

constructor TNodeMaterial_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFFloat.Create('ambientIntensity', 0.2)); Fields.Last.Exposed := true;
  Fields.Add(TSFColor.Create('diffuseColor', Vector3Single(0.8, 0.8, 0.8))); Fields.Last.Exposed := true;
  Fields.Add(TSFColor.Create('emissiveColor', ZeroVector3Single)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('shininess', 0.2)); Fields.Last.Exposed := true;
  Fields.Add(TSFColor.Create('specularColor', ZeroVector3Single)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('transparency', 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('fogImmune', false)); Fields.Last.Exposed := true;
end;

class function TNodeMaterial_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

function TNodeMaterial_2.Opacity: Single;
begin
  Result := 1- FdTransparency.Value;
end;

function TNodeMaterial_2.ShininessExp: Single;
begin
  Result := Clamped(FdShininess.Value * 128.0, 0.0, 128.0);
end;

class function TNodeMovieTexture.ClassNodeTypeName: string;
begin
  Result := 'MovieTexture';
end;

constructor TNodeMovieTexture.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFBool.Create('loop', FALSE)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('speed', 1.0)); Fields.Last.Exposed := true;
  Fields.Add(TSFTime.Create('startTime', 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFTime.Create('stopTime', 0)); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('url', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('repeatS', TRUE));
  Fields.Add(TSFBool.Create('repeatT', TRUE));
  { eventOut     SFTime   duration_changed }
  { eventOut     SFBool   isActive }
end;

class function TNodeNavigationInfo.ClassNodeTypeName: string;
begin
  Result := 'NavigationInfo';
end;

constructor TNodeNavigationInfo.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      SFBool   set_bind }
  Fields.Add(TMFFloat.Create('avatarSize', [0.25, 1.6, 0.75])); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('headlight', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('speed', 1.0)); Fields.Last.Exposed := true;
  Fields.Add(TMFString.Create('type', ['WALK', 'ANY'])); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('visibilityLimit', 0.0)); Fields.Last.Exposed := true;
  { eventOut     SFBool   isBound }
end;

class function TNodeNormal.ClassNodeTypeName: string;
begin
  Result := 'Normal';
end;

constructor TNodeNormal.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFVec3f.Create('vector', [])); Fields.Last.Exposed := true;
end;

class function TNodeNormalInterpolator.ClassNodeTypeName: string;
begin
  Result := 'NormalInterpolator';
end;

constructor TNodeNormalInterpolator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      SFFloat set_fraction }
  Fields.Add(TMFFloat.Create('key', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFVec3f.Create('keyValue', [])); Fields.Last.Exposed := true;
  { eventOut     MFVec3f value_changed }
end;

class function TNodeNurbsCurve.ClassNodeTypeName: string;
begin
  Result := 'NurbsCurve';
end;

constructor TNodeNurbsCurve.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFVec3f.Create('controlPoint', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('weight', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFInt32.Create('tessellation', 0)); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('knot', []));
  Fields.Add(TSFInt32.Create('order', 3));
end;

class function TNodeNurbsCurve2D.ClassNodeTypeName: string;
begin
  Result := 'NurbsCurve2D';
end;

constructor TNodeNurbsCurve2D.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFVec2f.Create('controlPoint', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFInt32.Create('tessellation', 0)); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('weight', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('knot', []));
  Fields.Add(TSFInt32.Create('order', 3));
end;

class function TNodeNurbsGroup.ClassNodeTypeName: string;
begin
  Result := 'NurbsGroup';
end;

constructor TNodeNurbsGroup.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn       MFNode   addChildren }
  { eventIn       MFNode   removeChildren }
  Fields.Add(TMFNode.Create(Self, 'children', AllowedChildrenNodes)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('tessellationScale', 1.0)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('bboxCenter', ZeroVector3Single));
  Fields.Add(TSFVec3f.Create('bboxSize', Vector3Single(-1, -1, -1)));
end;

function TNodeNurbsGroup.ChildrenField: TMFNode;
begin
  Result := FdChildren;
end;

class function TNodeNurbsPositionInterpolator.ClassNodeTypeName: string;
begin
  Result := 'NurbsPositionInterpolator';
end;

constructor TNodeNurbsPositionInterpolator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      SFFloat  set_fraction }
  Fields.Add(TSFInt32.Create('dimension', 0)); Fields.Last.Exposed := true;
  Fields.Add(TMFVec3f.Create('keyValue', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('keyWeight', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('knot', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFInt32.Create('order', 4)); Fields.Last.Exposed := true;
  { eventOut     SFVec3f  value_changed }
end;

class function TNodeNurbsSurface.ClassNodeTypeName: string;
begin
  Result := 'NurbsSurface';
end;

constructor TNodeNurbsSurface.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFVec3f.Create('controlPoint', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'texCoord', [TNodeTextureCoordinate, TNodeNurbsTextureSurface])); Fields.Last.Exposed := true;
  Fields.Add(TSFInt32.Create('uTessellation', 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFInt32.Create('vTessellation', 0)); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('weight', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('ccw', TRUE));
  Fields.Add(TSFBool.Create('solid', TRUE));
  Fields.Add(TSFInt32.Create('uDimension', 0));
  Fields.Add(TMFFloat.Create('uKnot', []));
  Fields.Add(TSFInt32.Create('uOrder', 3));
  Fields.Add(TSFInt32.Create('vDimension', 0));
  Fields.Add(TMFFloat.Create('vKnot', []));
  Fields.Add(TSFInt32.Create('vOrder', 3));
end;

class function TNodeNurbsTextureSurface.ClassNodeTypeName: string;
begin
  Result := 'NurbsTextureSurface';
end;

constructor TNodeNurbsTextureSurface.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFVec2f.Create('controlPoint', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('weight', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFInt32.Create('uDimension', 0));
  Fields.Add(TMFFloat.Create('uKnot', []));
  Fields.Add(TSFInt32.Create('uOrder', 3));
  Fields.Add(TSFInt32.Create('vDimension', 0));
  Fields.Add(TMFFloat.Create('vKnot', []));
  Fields.Add(TSFInt32.Create('vOrder', 3));
end;

class function TNodeOrientationInterpolator.ClassNodeTypeName: string;
begin
  Result := 'OrientationInterpolator';
end;

constructor TNodeOrientationInterpolator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      SFFloat    set_fraction }
  Fields.Add(TMFFloat.Create('key', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFRotation.Create('keyValue', [])); Fields.Last.Exposed := true;
  { eventOut     SFRotation value_changed }
end;

class function TNodePixelTexture.ClassNodeTypeName: string;
begin
  Result := 'PixelTexture';
end;

constructor TNodePixelTexture.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFImage.Create('image', nil)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('repeatS', TRUE));
  Fields.Add(TSFBool.Create('repeatT', TRUE));
end;

function TNodePixelTexture.LoadTextureImage: TImage;
begin
  Result := nil;
  if not FdImage.Value.IsNull then
    Result := FdImage.Value.MakeCopy;
end;

function TNodePixelTexture.TextureDescription: string;
begin
  if not FdImage.Value.IsNull then
    result := Format('inlined (width = %d; height = %d; with alpha = %s)',
      [ FdImage.Value.Width, FdImage.Value.Height,
        BoolToStr[FdImage.Value is TAlphaImage] ]) else
    result := 'none';
end;

function TNodePixelTexture.RepeatS: boolean;
begin
  Result := FdRepeatS.Value;
end;

function TNodePixelTexture.RepeatT: boolean;
begin
  Result := FdRepeatT.Value;
end;

class function TNodePlaneSensor.ClassNodeTypeName: string;
begin
  Result := 'PlaneSensor';
end;

constructor TNodePlaneSensor.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFBool.Create('autoOffset', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('enabled', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec2f.Create('maxPosition', Vector2Single(-1, -1))); Fields.Last.Exposed := true;
  Fields.Add(TSFVec2f.Create('minPosition', Vector2Single(0, 0))); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('offset', ZeroVector3Single)); Fields.Last.Exposed := true;
  { eventOut     SFBool  isActive }
  { eventOut     SFVec3f trackPoint_changed }
  { eventOut     SFVec3f translation_changed }
end;

constructor TNodePointLight_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { Previous fields initialized in TNodeGeneralPointLight and above.
    However the default values of "ambientIntensity" and "location" fields
    are different.
    - ambientIntensity in VRML 1.0 is my extension,
      and the default value differs from VRML 2.0 spec on purpose,
      to allow VRML 1.0-compat behavior when ambientIntensity is not specified.
    - location has just different default value between VRML 1.0 and 2.0
      specifications... Though VRML 2.0 indeed has more sensible default
      value, so that's another improvement in VRML 2.0. }
  FdAmbientIntensity.Value := 0;
  FdAmbientIntensity.DefaultValue := 0;
  FdLocation.Value := ZeroVector3Single;
  FdLocation.DefaultValue := ZeroVector3Single;

  Fields.Add(TSFFloat.Create('radius', 100)); Fields.Last.Exposed := true;
end;

class function TNodePointLight_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

class function TNodePointSet_2.ClassNodeTypeName: string;
begin
  Result := 'PointSet';
end;

constructor TNodePointSet_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFNode.Create(Self, 'color', [TNodeColor])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'coord', [TNodeCoordinate, TNodeGeoCoordinate])); Fields.Last.Exposed := true;
end;

class function TNodePointSet_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

class function TNodePolyline2D.ClassNodeTypeName: string;
begin
  Result := 'Polyline2D';
end;

constructor TNodePolyline2D.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFVec2f.Create('point', [])); Fields.Last.Exposed := true;
end;

class function TNodePositionInterpolator.ClassNodeTypeName: string;
begin
  Result := 'PositionInterpolator';
end;

constructor TNodePositionInterpolator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      SFFloat set_fraction }
  Fields.Add(TMFFloat.Create('key', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFVec3f.Create('keyValue', [])); Fields.Last.Exposed := true;
  { eventOut     SFVec3f value_changed }
end;

class function TNodeProximitySensor.ClassNodeTypeName: string;
begin
  Result := 'ProximitySensor';
end;

constructor TNodeProximitySensor.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFVec3f.Create('center', ZeroVector3Single)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('size', ZeroVector3Single)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('enabled', TRUE)); Fields.Last.Exposed := true;
  { eventOut     SFBool     isActive }
  { eventOut     SFVec3f    position_changed }
  { eventOut     SFRotation orientation_changed }
  { eventOut     SFTime     enterTime }
  { eventOut     SFTime     exitTime }
end;

class function TNodeScalarInterpolator.ClassNodeTypeName: string;
begin
  Result := 'ScalarInterpolator';
end;

constructor TNodeScalarInterpolator.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      SFFloat set_fraction
  Fields.Add(TMFFloat.Create('key', [])); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('keyValue', [])); Fields.Last.Exposed := true;
  { eventOut     SFFloat value_changed }
end;

class function TNodeScript.ClassNodeTypeName: string;
begin
  Result := 'Script';
end;

constructor TNodeScript.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFString.Create('url', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('directOutput', FALSE));
  Fields.Add(TSFBool.Create('mustEvaluate', FALSE));
  { # And any number of: }
  { eventIn      eventType eventName }
  { field        fieldType fieldName initialValue }
  { eventOut     eventType eventName }
end;

class function TNodeShape.ClassNodeTypeName: string;
begin
  Result := 'Shape';
end;

constructor TNodeShape.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFNode.Create(Self, 'appearance', [TNodeAppearance])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'geometry', AllowedGeometryNodes)); Fields.Last.Exposed := true;
end;

procedure TNodeShape.DirectEnumerateActive(
  Func: TEnumerateChildrenFunction);
begin
  if FdGeometry.Value <> nil then
  begin
    { According to VRML spec, when geometry is NULL then object is not
      drawn so appearance doesn't matter. }
    if FdAppearance.Value <> nil then
      Func(Self, FdAppearance.Value);
    Func(Self, FdGeometry.Value);
  end;
end;

procedure TNodeShape.BeforeTraverse(var State: TVRMLGraphTraverseState);
begin
  inherited;
  State.ParentShape := Self;
end;

procedure TNodeShape.AfterTraverse(var State: TVRMLGraphTraverseState);
begin
  State.ParentShape := nil;
  inherited;
end;

function TNodeShape.Texture: TNodeGeneralTexture;
var
  Appearance: TNodeAppearance;
begin
  Result := nil;
  if (FdAppearance.Value <> nil) and
     (FdAppearance.Value is TNodeAppearance) then
  begin
    Appearance := TNodeAppearance(FdAppearance.Value);
    if (Appearance.FdTexture.Value <> nil) and
       (Appearance.FdTexture.Value is TNodeGeneralTexture) then
      Result := TNodeGeneralTexture(Appearance.FdTexture.Value);
  end;
end;

function TNodeShape.TextureTransform: TNodeTextureTransform;
var
  Appearance: TNodeAppearance;
begin
  Result := nil;
  if (FdAppearance.Value <> nil) and
     (FdAppearance.Value is TNodeAppearance) then
  begin
    Appearance := TNodeAppearance(FdAppearance.Value);
    if (Appearance.FdTextureTransform.Value <> nil) and
       (Appearance.FdTextureTransform.Value is TNodeTextureTransform) then
      Result := TNodeTextureTransform(Appearance.FdTextureTransform.Value);
  end;
end;

function TNodeShape.Material: TNodeMaterial_2;
var
  Appearance: TNodeAppearance;
begin
  Result := nil;
  if (FdAppearance.Value <> nil) and
     (FdAppearance.Value is TNodeAppearance) then
  begin
    Appearance := TNodeAppearance(FdAppearance.Value);
    if (Appearance.FdMaterial.Value <> nil) and
       (Appearance.FdMaterial.Value is TNodeMaterial_2) then
      Result := TNodeMaterial_2(Appearance.FdMaterial.Value);
  end;
end;

class function TNodeSound.ClassNodeTypeName: string;
begin
  Result := 'Sound';
end;

constructor TNodeSound.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFVec3f.Create('direction', Vector3Single(0, 0, 1))); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('intensity', 1)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('location', ZeroVector3Single)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('maxBack', 10)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('maxFront', 10)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('minBack', 1)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('minFront', 1)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('priority', 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'source', [TNodeAudioClip, TNodeMovieTexture])); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('spatialize', TRUE));
end;

class function TNodeSphere_2.ClassNodeTypeName: string;
begin
  Result := 'Sphere';
end;

constructor TNodeSphere_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFFloat.Create('radius', 1));
end;

class function TNodeSphere_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

class function TNodeSphereSensor.ClassNodeTypeName: string;
begin
  Result := 'SphereSensor';
end;

constructor TNodeSphereSensor.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFBool.Create('autoOffset', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('enabled', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFRotation.Create('offset', Vector3Single(0, 1, 0), 0)); Fields.Last.Exposed := true;
  { eventOut     SFBool     isActive }
  { eventOut     SFRotation rotation_changed }
  { eventOut     SFVec3f    trackPoint_changed }
end;

class function TNodeSpotLight_2.ClassNodeTypeName: string;
begin
  Result := 'SpotLight';
end;

constructor TNodeSpotLight_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFVec3f.Create('attenuation', Vector3Single(1, 0, 0))); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('beamWidth', 1.570796)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('cutOffAngle', 0.785398)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('direction', Vector3Single(0, 0, -1))); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('location', ZeroVector3Single)); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('radius', 100)); Fields.Last.Exposed := true;

  { Default value of ambientIntensity for VRML 1.0 and 2.0 is different,
    see comments at ambientIntensity in implementation of TPointLight_2. }
  FdAmbientIntensity.Value := 0;
  FdAmbientIntensity.DefaultValue := 0;
end;

class function TNodeSpotLight_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

class function TNodeSwitch_2.ClassNodeTypeName: string;
begin
  Result := 'Switch';
end;

constructor TNodeSwitch_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFNode.Create(Self, 'choice', AllowedChildrenNodes)); Fields.Last.Exposed := true;
  Fields.Add(TSFInt32.Create('whichChoice', -1)); Fields.Last.Exposed := true;
end;

class function TNodeSwitch_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

function TNodeSwitch_2.ChildrenField: TMFNode;
begin
  Result := FdChoice;
end;

procedure TNodeSwitch_2.DirectEnumerateActive(Func: TEnumerateChildrenFunction);
begin
  if Between(FdWhichChoice.Value, 0, FdChoice.Count - 1) then
    Func(Self, FdChoice.Items[FdWhichChoice.Value]);
end;

class function TNodeText.ClassNodeTypeName: string;
begin
  Result := 'Text';
end;

constructor TNodeText.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFString.Create('string', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'fontStyle', [TNodeFontStyle_2])); Fields.Last.Exposed := true;
  Fields.Add(TMFFloat.Create('length', [])); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('maxExtent', 0.0)); Fields.Last.Exposed := true;
end;

function TNodeText.FontStyle: TNodeFontStyle_2;
begin
  if (FdFontStyle.Value <> nil) and
     (FdFontStyle.Value is TNodeFontStyle_2) then
    Result := TNodeFontStyle_2(FdFontStyle.Value) else
    Result := nil;
end;

class function TNodeTextureCoordinate.ClassNodeTypeName: string;
begin
  Result := 'TextureCoordinate';
end;

constructor TNodeTextureCoordinate.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFVec2f.Create('point', [])); Fields.Last.Exposed := true;
end;

class function TNodeTextureTransform.ClassNodeTypeName: string;
begin
  Result := 'TextureTransform';
end;

constructor TNodeTextureTransform.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFVec2f.Create('center', Vector2Single(0, 0))); Fields.Last.Exposed := true;
  Fields.Add(TSFFloat.Create('rotation', 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec2f.Create('scale', Vector2Single(1, 1))); Fields.Last.Exposed := true;
  Fields.Add(TSFVec2f.Create('translation', Vector2Single(0, 0))); Fields.Last.Exposed := true;
end;

function TNodeTextureTransform.Matrix: TMatrix4Single;
begin
  { Note: don't be fooled by a little confusing VRML 2.0 spec
    wording for TextureTransform, that suggests that VRML 2.0
    TextureTransform should multiply matrices in reversed
    order than VRML 1.0. I'm talking about the paragraph

       In matrix transformation notation, where Tc is the
       untransformed texture coordinate, Tc' is the transformed
       texture coordinate, C (center), T (translation),
       R (rotation), and S (scale) are the intermediate
       transformation matrices,

         Tc' = -C � S � R � C � T � Tc

    VRML TextureTransform node transforms texture *coordinates*.
    OpenGL texture matrix transforms texture *coordinates*.
    And above paragraph says about texture *coordinates*.
    So I'm either ultra-dumb or ultra-smart, but for me
    the above paragraph is wrong: it says precisely that I should load
    the *reversed* matrix of what I'm actually loading.
    If I would follow this, I would actually *not* be
    conforming to the rest of TextureTransform description in VRML spec.

    Am I the only one fooled by this ? No:
    [http://bugs.sun.com/bugdatabase/view_bug.do?bug_id=4320634]

    So what's the truth (i.e. the correct order, consistent
    with the whole rest of TextureTransform specification and with
    other implementations) ?
    Actually the order is the same for
    both VRML 1.0 and 2.0, confirmed by experience (reversed
    order just will not work correctly, e.g. TextureTransform
    with rotation and center 0.5 0.5 fields specified will
    not behave correctly) and other implementations
    (see [http://search.cpan.org/src/LUKKA/FreeWRL-0.14/VRMLFunc.xs]
    function TextureTransform_Rend). }

  Result :=
    TranslationMatrix( Vector3Single(
      FdTranslation.Value[0] + FdCenter.Value[0],
      FdTranslation.Value[1] + FdCenter.Value[1], 0));
  Result := MultMatrices(Result,
    RotationMatrixRad(FdRotation.Value, Vector3Single(0, 0, 1)));
  Result := MultMatrices(Result,
    ScalingMatrix(
      Vector3Single( FdScale.Value[0], FdScale.Value[1], 1 )));
  Result := MultMatrices(Result,
    TranslationMatrix(
      Vector3Single( -FdCenter.Value[0], -FdCenter.Value[1], 0 )));
end;

class function TNodeTimeSensor.ClassNodeTypeName: string;
begin
  Result := 'TimeSensor';
end;

constructor TNodeTimeSensor.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFTime.Create('cycleInterval', 1)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('enabled', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('loop', FALSE)); Fields.Last.Exposed := true;
  Fields.Add(TSFTime.Create('startTime', 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFTime.Create('stopTime', 0)); Fields.Last.Exposed := true;
  { eventOut     SFTime   cycleTime }
  { eventOut     SFFloat  fraction_changed
  { eventOut     SFBool   isActive }
  { eventOut     SFTime   time }
end;

class function TNodeTouchSensor.ClassNodeTypeName: string;
begin
  Result := 'TouchSensor';
end;

constructor TNodeTouchSensor.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFBool.Create('enabled', TRUE)); Fields.Last.Exposed := true;
  { eventOut     SFVec3f hitNormal_changed }
  { eventOut     SFVec3f hitPoint_changed }
  { eventOut     SFVec2f hitTexCoord_changed }
  { eventOut     SFBool  isActive }
  { eventOut     SFBool  isOver }
  { eventOut     SFTime  touchTime }
end;

class function TNodeTransform_2.ClassNodeTypeName: string;
begin
  Result := 'Transform';
end;

constructor TNodeTransform_2.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      MFNode      addChildren }
  { eventIn      MFNode      removeChildren }
  Fields.Add(TSFVec3f.Create('center', ZeroVector3Single)); Fields.Last.Exposed := true;
  Fields.Add(TMFNode.Create(Self, 'children', AllowedChildrenNodes)); Fields.Last.Exposed := true;
  Fields.Add(TSFRotation.Create('rotation', Vector3Single(0, 0, 1), 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('scale', Vector3Single(1, 1, 1))); Fields.Last.Exposed := true;
  Fields.Add(TSFRotation.Create('scaleOrientation', Vector3Single(0, 0, 1), 0)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('translation', ZeroVector3Single)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('bboxCenter', ZeroVector3Single));
  Fields.Add(TSFVec3f.Create('bboxSize', Vector3Single(-1, -1, -1)));
end;

class function TNodeTransform_2.ForVRMLVersion(const VerMajor, VerMinor: Integer): boolean;
begin
  Result := VerMajor >= 2;
end;

function TNodeTransform_2.ChildrenField: TMFNode;
begin
  Result := FdChildren;
end;

procedure TNodeTransform_2.DirectEnumerateActive(Func: TEnumerateChildrenFunction);
var
  I: Integer;
begin
  for I := 0 to FdChildren.Count - 1 do
    Func(Self, FdChildren.Items[I]);
end;

procedure TNodeTransform_2.BeforeTraverse(var State: TVRMLGraphTraverseState);
begin
  inherited;

  { inherited TNodeGeneralGrouping already saved State.CurrMatrix }

  State.CurrMatrix := MultMatrices(State.CurrMatrix,
    TranslationMatrix(FdTranslation.Value));
  State.CurrMatrix := MultMatrices(State.CurrMatrix,
    TranslationMatrix(FdCenter.Value));
  if not IsZeroVector(FdRotation.Axis) then
    State.CurrMatrix := MultMatrices(State.CurrMatrix,
      RotationMatrixRad(FdRotation.RotationRad, FdRotation.Axis));
  State.CurrMatrix := MultMatrices(State.CurrMatrix,
    RotationMatrixRad(FdScaleOrientation.RotationRad, FdScaleOrientation.Axis));
  State.CurrMatrix := MultMatrices(State.CurrMatrix,
    ScalingMatrix(FdScale.Value));
  State.CurrMatrix := MultMatrices(State.CurrMatrix,
    RotationMatrixRad(-FdScaleOrientation.RotationRad, FdScaleOrientation.Axis));
  State.CurrMatrix := MultMatrices(State.CurrMatrix,
    TranslationMatrix(VectorNegate(FdCenter.Value)));
end;

class function TNodeTrimmedSurface.ClassNodeTypeName: string;
begin
  Result := 'TrimmedSurface';
end;

constructor TNodeTrimmedSurface.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn       MFNode   addTrimmingContour }
  { eventIn       MFNode   removeTrimmingContour }
  Fields.Add(TMFNode.Create(Self, 'trimmingContour', [TNodeContour2D])); Fields.Last.Exposed := true;
  Fields.Add(TSFNode.Create(Self, 'surface', [TNodeNurbsSurface])); Fields.Last.Exposed := true;
end;

class function TNodeViewpoint.ClassNodeTypeName: string;
begin
  Result := 'Viewpoint';
end;

constructor TNodeViewpoint.Create(
  const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  { eventIn      SFBool     set_bind }
  Fields.Add(TSFFloat.Create('fieldOfView', 0.785398)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('jump', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFString.Create('description', ''));
  { eventOut     SFTime     bindTime }
  { eventOut     SFBool     isBound }

  { Default value of position is different for Viewpoint than for VRML 1.0
    cameras (as set by TNodeGeneralViewpoint). }
  FdPosition.DefaultValue := Vector3Single(0, 0, 10);
  FdPosition.Value := FdPosition.DefaultValue;
end;

class function TNodeViewpoint.CameraKind: TVRMLCameraKind;
begin
  Result := ckPerspective;
end;

function TNodeViewpoint.AngleOfView(
  const ThisToOtherSizeRatio: Single): Single;
begin
  Result := ViewpointAngleOfView(FdFieldOfView.Value, ThisToOtherSizeRatio);
end;

class function TNodeViewpoint.ViewpointAngleOfView(
  FieldOfView: Single;
  const ThisToOtherSizeRatio: Single): Single;
var
  OtherAngle: Single;
begin
  Clamp(FieldOfView, 0.01, Pi - 0.01);

  if ThisToOtherSizeRatio < 1 then
  begin
    { So the resulting angle is the smaller one. }
    Result := FieldOfView;
    OtherAngle :=
      AdjustViewAngleRadToAspectRatio(Result, 1 / ThisToOtherSizeRatio);
    if OtherAngle > Pi then
      Result := AdjustViewAngleRadToAspectRatio(Pi, ThisToOtherSizeRatio);
  end else
  begin
    { So the resulting angle is the larger one. }
    OtherAngle := FieldOfView;
    Result :=
      AdjustViewAngleRadToAspectRatio(OtherAngle, ThisToOtherSizeRatio);
    if Result > Pi then
      Result := Pi;
  end;
end;

class function TNodeVisibilitySensor.ClassNodeTypeName: string;
begin
  Result := 'VisibilitySensor';
end;

constructor TNodeVisibilitySensor.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TSFVec3f.Create('center', ZeroVector3Single)); Fields.Last.Exposed := true;
  Fields.Add(TSFBool.Create('enabled', TRUE)); Fields.Last.Exposed := true;
  Fields.Add(TSFVec3f.Create('size', ZeroVector3Single)); Fields.Last.Exposed := true;
  { eventOut     SFTime  enterTime }
  { eventOut     SFTime  exitTime }
  { eventOut     SFBool  isActive }
end;

class function TNodeWorldInfo.ClassNodeTypeName: string;
begin
  Result := 'WorldInfo';
end;

constructor TNodeWorldInfo.Create(const ANodeName: string; const AWWWBasePath: string);
begin
  inherited;
  Fields.Add(TMFString.Create('info', []));
  Fields.Add(TSFString.Create('title', ''));
end;

{ TNodeUnknown ---------------------------------------------------------------- }

function TNodeUnknown.NodeTypeName: string;
begin
 result := fNodeTypeName;
end;

procedure TNodeUnknown.Parse(Lexer: TVRMLLexer; NodeNameBinding: TStringList);
{ TODO: tutaj zrobic parsowanie node'ow unknown typu 2) i 3),
  VRMlNonFatalError tez nie trzeba zawsze rzucac. }
var level: integer;
begin
 { w przypadku TNodeUnknown musimy fAllowedChildren i fParseAllowedChildren
   inicjowac na podstawie parsowania. }
 fAllowedChildren := false;
 fParsingAllowedChildren := false;

 Lexer.CheckTokenIs(vtOpenCurlyBracket);
 level := 1;
 while (level > 0) and (Lexer.Token <> vtEnd) do
 begin
  Lexer.NextToken;
  if Lexer.Token = vtOpenCurlyBracket then Inc(level) else
   if Lexer.Token = vtCloseCurlyBracket then Dec(level);
 end;
 {sprawdz czy nie wyladowalismy na EndOfFile}
 Lexer.CheckTokenIs(vtCloseCurlyBracket);
 Lexer.NextToken;

 FWWWBasePath := Lexer.WWWBasePath;

 VRMLNonFatalError('Unknown VRML node of type '''+NodeTypeName+
   ''' (named '''+NodeName+''')');
end;

constructor TNodeUnknown.Create(const ANodeName: string; const AWWWBasePath: string);
begin
 { ponizej : "bezpiecznik" zeby nigdy nie tworzyc tego node'a normalnie,
   zeby zawsze fNodeTypeName bylo ustalone. }
 raise Exception.Create('You cannot create Unknown node using default constructor');
end;

constructor TNodeUnknown.CreateUnknown(const ANodeName, AWWWBasePath, ANodeTypeName :string);
begin
 inherited Create(ANodeName, AWWWBasePath);
 fNodeTypeName := ANodeTypeName;
end;

constructor TNodeUnknown.CreateUnknownParse(const ANodeName, ANodeTypeName :string;
  Lexer: TVRMLLexer; NodeNameBinding: TStringList);
begin
 CreateUnknown(ANodeName, '', ANodeTypeName);
 Parse(Lexer, NodeNameBinding);
end;

{ TNodesManager ------------------------------------------------------------ }

constructor TNodesManager.Create;
begin
 inherited;
 Registered := TStringListCaseSens.Create;
end;

destructor TNodesManager.Destroy;
begin
 Registered.Free;
 inherited;
end;

procedure TNodesManager.RegisterNodeClass(NodeClass: TVRMLNodeClass);
begin
 if NodeClass.ClassNodeTypeName = '' then
  raise ENodesManagerError.Create('Class '+NodeClass.ClassName+' has '+
   'empty ClassNodeTypeName so it cannot be registered in TNodesManager');

 if Registered.IndexOfObject(TObject(Pointer(NodeClass))) <> -1 then
  raise ENodesManagerError.Create('Class '+NodeClass.ClassName+
    ' was already registered in TNodesManager');

 Registered.AddObject(NodeClass.ClassNodeTypeName, TObject(Pointer(NodeClass)));
end;

procedure TNodesManager.RegisterNodeClasses(
  const NodeClasses: array of TVRMLNodeClass);
var i: Integer;
begin
 for i := 0 to High(NodeClasses) do RegisterNodeClass(NodeClasses[i]);
end;

procedure TNodesManager.UnRegisterNodeClass(NodeClass: TVRMLNodeClass;
  ErrorIfNotRegistered: boolean);
var i: Integer;
begin
 if NodeClass.ClassNodeTypeName = '' then
  raise ENodesManagerError.Create('Class '+NodeClass.ClassName+' has '+
   'empty ClassNodeTypeName so it cannot be unregistered (or even registered) '+
   'in TNodesManager');

 i := Registered.IndexOfObject(TObject(Pointer(NodeClass)));
 if i <> - 1 then
  Registered.Delete(i) else
 if ErrorIfNotRegistered then
  ENodesManagerError.Create('Node class "' + NodeClass.ClassName +
    '" was not registered, so you cannot unregister it');
end;

function TNodesManager.NodeTypeNameToClass(const ANodeTypeName: string;
  const VerMajor, VerMinor: Integer): TVRMLNodeClass;
var
  I: Integer;
begin
  for I := 0 to Registered.Count - 1 do
  begin
    Result := TVRMLNodeClass(Registered.Objects[I]);
    if (Registered[I] = ANodeTypeName) and
       Result.ForVRMLVersion(VerMajor, VerMinor) then
      Exit;
  end;
  Result := nil;
end;

{ global procedures ---------------------------------------------------------- }

function ParseNode(Lexer: TVRMLLexer; NodeNameBinding: TStringList;
  const AllowedNodes: boolean): TVRMLNode;

  procedure ParseNamedNode(const nodename: string);

    function LexerTokenToNode: TVRMLNodeClass;
    {uwaga - moze zwrocic TNodeUnknown (ktory trzeba tworzyc specjalnym
     konstruktorem)}
    begin
     Lexer.CheckTokenIs(vtName, 'node type');
     result := NodesManager.NodeTypeNameToClass(Lexer.TokenName,
       Lexer.VRMLVerMajor, Lexer.VRMLVerMinor);
     if result <> nil then
     begin
      if not ({result is allowed in AllowedNodes ?} AllowedNodes) then
       raise EVRMLParserError.Create(Lexer,
         'Node type '+result.ClassNodeTypeName+' not allowed here');
     end else
     begin
      if not ({TNodeUnknown is allowed in AllowedNodes ?} AllowedNodes) then
       raise EVRMLParserError.Create(Lexer,
         'Unknown node type ('+Lexer.TokenName+') not allowed here');
      result := TNodeUnknown;
     end;
    end;

  var nodeclass: TVRMLNodeClass;
      NodeTypeName: string;
      i: integer;
  begin
   nodeClass := LexerTokenToNode;
   NodeTypeName := Lexer.TokenName;
   Lexer.NextToken;

   if nodeClass <> TNodeUnknown then
    result := nodeclass.CreateParse(nodename, Lexer, NodeNameBinding) else
    result := TNodeUnknown.CreateUnknownParse(nodename, NodeTypeName, Lexer, NodeNameBinding);

   {add NodeName to NodeNameBinding. Note : adding result to
    NodeNameBinding AFTER parsing result we make infinite recursion loops
    impossible.}
   i := NodeNameBinding.IndexOf(NodeName);
   if i >= 0 then
    NodeNameBinding.Objects[i] := result else
    NodeNameBinding.AddObject(NodeName, result);
  end;

var nodename: string;
    i: integer;
begin
 (* node means :
    DEF <name> <nodetype> { node-content } or
    USE <name> or
    <nodetype> { node-content }
 *)

 case Lexer.Token of
  vtKeyword:
    case Lexer.TokenKeyword of
     vkDEF:
       begin
        Lexer.NextTokenForceVTName;
        nodename := Lexer.TokenName;
        Lexer.NextToken;
        ParseNamedNode(nodename);
       end;
     vkUSE:
       begin
        Lexer.NextTokenForceVTName;
        nodename := Lexer.TokenName;

        {get appropriate node}
        i := NodeNameBinding.IndexOf(nodename);
        if i = -1 then
         raise EVRMLParserError.Create(Lexer, 'Incorrect USE clause : node name '+nodename+' undefined');
        result := TVRMLNode(NodeNameBinding.Objects[i]);

        Lexer.NextToken;
       end;
     else raise EVRMLParserError.Create(Lexer,
            'Expected node type or DEF or USE, got '+Lexer.DescribeToken);
    end;
  vtName: ParseNamedNode('');
  else raise EVRMLParserError.Create(Lexer,
         'Expected node type or DEF or USE, got '+Lexer.DescribeToken);
 end;
end;

function ParseVRMLFile(Stream: TPeekCharStream;
  const WWWBasePath: string): TVRMLNode;
var Lexer: TVRMLLexer;
    NodeNameBinding: TStringList;
    childNode: TVRMLNode;
begin
 Lexer := nil;
 NodeNameBinding := nil;
 try
  Lexer := TVRMLLexer.Create(Stream, WWWBasePath);
  NodeNameBinding := TStringListCaseSens.Create;

  result := ParseNode(Lexer, NodeNameBinding, true);
  try

   { ponizej : tak wyglada implementacja tej procedury ktora wymagalaby zeby
     caly plik byl jednym nodem VRMLa (tak jak tego wymaga specyfikacja
     VRMLa 1.0).

       Lexer.CheckTokenIs(vtEnd, 'end of file (remember : VRML 1.0 files can contain only one "root" node)');

     Nie uzywam jej, zamiast tego pozwalam plikow zawsze miec wiele node'ow
     i jezeli maja ich wiecej niz 1 to wrzucam je do stworzonego sztucznie
     jednego node'a Group (wiec odczytany i zapisany z powrotem w ten sposob
     plik zawsze ma jeden node w pliku). Zaimplementowalem to bo jest wiele
     tacich niepoprawnych plikow VRMLa 1.0 w internecie ktore maja wiecej
     niz jeden node zdefiniowany. Poza tym jest to krok w strone VRMLa 97
     (ktorego specyfikacja jawnie na to pozwala). Poza tym jest to proste i
     do zaimplementowania i jest calkiem logicznym rozszerzeniem VRMLa 1.0.
   }

   if Lexer.Token <> vtEnd then
   begin
     childNode := Result;

     if TNodeGroupHidden_1.ForVRMLVersion(
          Lexer.VRMLVerMajor, Lexer.VRMLVerMinor) then
       Result := TNodeGroupHidden_1.Create('', WWWBasePath) else
       Result := TNodeGroupHidden_2.Create('', WWWBasePath);

     Result.SmartAddChild(childNode);

     repeat
       Result.SmartAddChild(ParseNode(Lexer, NodeNameBinding, true));
     until Lexer.Token = vtEnd;
   end;

  except FreeAndNil(result); raise end;
 finally
  Lexer.Free;
  NodeNameBinding.Free
 end;
end;

function ParseVRMLFile(const FileName: string; AllowStdIn: boolean): TVRMLNode;
{
  First version.
  This will be nice if I will modify one day TDecompressionStream
  to make it able to handle gzip compressed streams
  (not zlib-compressed streams, as it does for now).

  function DoIt(BaseStream: TStream; FreeBaseStream: boolean;
    const WWWBasePath: string): TVRMLNode;
  var
    Stream: TPeekCharStream;
  begin
   try
    Stream := TBufferedReadStream.Create(
      TDecompressionStream.Create(BaseStream, 15+16), true);
    try
     Result := ParseVRMLFile(Stream, WWWBasePath);
    finally Stream.Free end;
   finally
    if FreeBaseStream then BaseStream.Free;
   end;
  end;

begin
 if AllowStdIn and (FileName = '-') then
  Result := DoIt(StdInStream, false, GetCurrentDir) else
  Result := DoIt(TFileStream.Create(FileName, fmOpenRead), true,
    ExtractFilePath(ExpandFilename(filename))); }

  function DoIt(BaseStream: TStream; FreeBaseStream: boolean;
    const WWWBasePath: string): TVRMLNode;
  var
    Stream: TPeekCharStream;
  begin
   Stream := TBufferedReadStream.Create(BaseStream, FreeBaseStream);
   try
    Result := ParseVRMLFile(Stream, WWWBasePath);
   finally Stream.Free end;
  end;

begin
 if AllowStdIn and (FileName = '-') then
  Result := DoIt(StdInStream, false, GetCurrentDir) else
 begin
  if SameText(ExtractFileExt(FileName), '.gz') then
   Result := DoIt(TGZFileStream.Create(FileName, gzOpenRead), true,
     ExtractFilePath(ExpandFilename(FileName))) else
   Result := DoIt(TFileStream.Create(FileName, fmOpenRead), true,
     ExtractFilePath(ExpandFilename(FileName)));
 end;
end;

function ParseVRMLFileFromString(const VRMLContents: string;
  const WWWBasePath: string): TVRMLNode; overload;
var
  Stream: TPeekCharStream;
begin
  Stream := TSimplePeekCharStream.Create(
    TStringStream.Create(VRMLContents), true);
  try
    Result := ParseVRMLFile(Stream, WWWBasePath);
  finally FreeAndNil(Stream) end;
end;

procedure SaveToVRMLFile(Node: TVRMLNode; Stream: TStream;
  const PrecedingComment: string);
const
  VRML10Header = '#VRML V1.0 ascii';
  VRML20Header = '#VRML V2.0 utf8';
var
  NodeNameBinding: TStringList;
  I: Integer;
  VerMajor, VerMinor, SuggestionPriority: Integer;
  VRMLHeader: string;
begin
  NodeNameBinding := TStringListCaseSens.Create;
  try
    if Node.SuggestedVRMLVersion(VerMajor, VerMinor, SuggestionPriority) then
    begin
      if (VerMajor = 1) and (VerMinor = 0) then
        VRMLHeader := VRML10Header else
      if (VerMajor = 2) and (VerMinor = 0) then
        VRMLHeader := VRML20Header else
        VRMLHeader := VRML10Header; { fallback is VRML10Header }
    end else
      VRMLHeader := VRML10Header; { fallback is VRML10Header }

    WriteStr(Stream, VRMLHeader +nl +nl);
    if PrecedingComment <> '' then
      WriteStr(Stream, '# '+PrecedingComment +nl +nl);

    if (Node is TNodeGroupHidden_1) or
       (Node is TNodeGroupHidden_2) then
    begin
      for I := 0 to Node.SmartChildrenCount - 1 do
        Node.SmartChildren[I].SaveToStream(Stream, '', NodeNameBinding);
    end else
      Node.SaveToStream(Stream, '', NodeNameBinding);
  finally NodeNameBinding.Free end;
end;

procedure SaveToVRMLFile(Node: TVRMLNode;
  const Filename, PrecedingComment: string);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(Filename, fmCreate);
  try
    SaveToVRMLFile(Node, Stream, PrecedingComment);
  finally Stream.Free end;
end;

procedure TraverseState_CreateNodes(var StateNodes: TTraverseStateLastNodes);
var
  I: Integer;
begin
  for I := 0 to HighTraverseStateLastNodes do
    StateNodes.Nodes[I] := TraverseStateLastNodesClasses[i].Create('', '');
end;

procedure TraverseState_FreeAndNilNodes(var StateNodes: TTraverseStateLastNodes);
var
  I: Integer;
begin
  for I := 0 to HighTraverseStateLastNodes do
    FreeAndNil(StateNodes.Nodes[i]);
end;

{ unit init/fini ------------------------------------------------------------ }

initialization
  NodesManager := TNodesManager.Create;
  NodesManager.RegisterNodeClasses([
    { Inventor spec nodes }
    TNodeIndexedTriangleMesh_1, TNodeRotationXYZ,

    { VRML 1.0 spec nodes }
    TNodeAsciiText_1, TNodeCone_1, TNodeCube_1, TNodeCylinder_1,
    TNodeIndexedFaceSet_1, TNodeIndexedLineSet_1,
    TNodePointSet_1, TNodeSphere_1,
    TNodeCoordinate3, TNodeFontStyle_1, TNodeInfo, TNodeLOD_1, TNodeMaterial_1,
    TNodeMaterialBinding, TNodeNormal, TNodeNormalBinding, TNodeTexture2,
    TNodeTexture2Transform,
    TNodeTextureCoordinate2, TNodeShapeHints,
    TNodeMatrixTransform, TNodeRotation,
    TNodeScale, TNodeTransform_1,
    TNodeTranslation,
    TNodeOrthographicCamera, TNodePerspectiveCamera,
    TNodeDirectionalLight_1, TNodePointLight_1, TNodeSpotLight_1,
    TNodeGroup_1, TNodeSeparator, TNodeSwitch_1, TNodeTransformSeparator,
    TNodeWWWAnchor,
    TNodeWWWInline,

    { Kambi non-standard nodes }
    TNodeKambiTriangulation,

    { VRML 2.0 spec nodes }
    TNodeAnchor,
    TNodeAppearance,
    TNodeAudioClip,
    TNodeBackground,
    TNodeBillboard,
    TNodeBox,
    TNodeCollision,
    TNodeColor,
    TNodeColorInterpolator,
    TNodeCone_2,
    TNodeContour2D,
    TNodeCoordinate,
    TNodeCoordinateDeformer,
    TNodeCoordinateInterpolator,
    TNodeCylinder_2,
    TNodeCylinderSensor,
    TNodeDirectionalLight_2,
    TNodeElevationGrid,
    TNodeExtrusion,
    TNodeFog,
    TNodeFontStyle_2,
    TNodeGeoCoordinate,
    TNodeGeoElevationGrid,
    TNodeGeoLocation,
    TNodeGeoLOD,
    TNodeGeoMetadata,
    TNodeGeoOrigin,
    TNodeGeoPositionInterpolator,
    TNodeGeoTouchSensor,
    TNodeGeoViewpoint,
    TNodeGroup_2,
    TNodeImageTexture,
    TNodeIndexedFaceSet_2,
    TNodeIndexedLineSet_2,
    TNodeInline,
    TNodeInlineLoadControl,
    TNodeLOD_2,
    TNodeMaterial_2,
    TNodeMovieTexture,
    TNodeNavigationInfo,
    { TNodeNormal, - registered already as VRML 1.0 node }
    TNodeNormalInterpolator,
    TNodeNurbsCurve,
    TNodeNurbsCurve2D,
    TNodeNurbsGroup,
    TNodeNurbsPositionInterpolator,
    TNodeNurbsSurface,
    TNodeNurbsTextureSurface,
    TNodeOrientationInterpolator,
    TNodePixelTexture,
    TNodePlaneSensor,
    TNodePointLight_2,
    TNodePointSet_2,
    TNodePolyline2D,
    TNodePositionInterpolator,
    TNodeProximitySensor,
    TNodeScalarInterpolator,
    TNodeScript,
    TNodeShape,
    TNodeSound,
    TNodeSphere_2,
    TNodeSphereSensor,
    TNodeSpotLight_2,
    TNodeSwitch_2,
    TNodeText,
    TNodeTextureCoordinate,
    TNodeTextureTransform,
    TNodeTimeSensor,
    TNodeTouchSensor,
    TNodeTransform_2,
    TNodeTrimmedSurface,
    TNodeViewpoint,
    TNodeVisibilitySensor,
    TNodeWorldInfo
    ]);

  AllowedChildrenNodes := TVRMLNodeClassesList.Create;
  AllowedChildrenNodes.AssignArray([
    { We add all nodes for VRML < 2.0, because we allow
      to mix VRML 1.0 inside VRML 2.0. }

    { Inventor spec nodes }
    TNodeIndexedTriangleMesh_1, TNodeRotationXYZ,

    { VRML 1.0 spec nodes }
    TNodeAsciiText_1, TNodeCone_1, TNodeCube_1, TNodeCylinder_1,
    TNodeIndexedFaceSet_1, TNodeIndexedLineSet_1,
    TNodePointSet_1, TNodeSphere_1,
    TNodeCoordinate3, TNodeFontStyle_1, TNodeInfo, TNodeLOD_1, TNodeMaterial_1,
    TNodeMaterialBinding, TNodeNormal, TNodeNormalBinding, TNodeTexture2,
    TNodeTexture2Transform,
    TNodeTextureCoordinate2, TNodeShapeHints,
    TNodeMatrixTransform, TNodeRotation,
    TNodeScale, TNodeTransform_1,
    TNodeTranslation,
    TNodeOrthographicCamera, TNodePerspectiveCamera,
    TNodeDirectionalLight_1, TNodePointLight_1, TNodeSpotLight_1,
    TNodeGroup_1, TNodeSeparator, TNodeSwitch_1, TNodeTransformSeparator,
    TNodeWWWAnchor,
    TNodeWWWInline,

    { Kambi non-standard nodes }
    TNodeKambiTriangulation,

    { VRML 2.0 spec nodes }
    TNodeAnchor,
    //TNodeAppearance,
    //TNodeAudioClip,
    TNodeBackground,
    TNodeBillboard,
    //TNodeBox,
    TNodeCollision,
    //TNodeColor,
    TNodeColorInterpolator,
    //TNodeCone_2,
    //TNodeContour2D,
    //TNodeCoordinate,
    { VRML 2.0 spec section "4.6.5 Grouping and children nodes"
      doesn't say is CoordinateDeformer allowed or not as children node.
      To be fixed when I'll implement CoordinateDeformer handling. }
    TNodeCoordinateDeformer,
    TNodeCoordinateInterpolator,
    //TNodeCylinder_2,
    TNodeCylinderSensor,
    TNodeDirectionalLight_2,
    //TNodeElevationGrid,
    //TNodeExtrusion,
    TNodeFog,
    { VRML 2.0 spec section "4.6.5 Grouping and children nodes"
      doesn't say is TNodeFontStyle allowed as children node,
      but FontStyle docs say that it's only for Text.fontStyle. }
    //TNodeFontStyle_2,
    //TNodeGeoCoordinate,
    //TNodeGeoElevationGrid,
    TNodeGeoLocation,
    TNodeGeoLOD,
    TNodeGeoMetadata,
    //TNodeGeoOrigin,
    TNodeGeoPositionInterpolator,
    TNodeGeoTouchSensor,
    TNodeGeoViewpoint,
    TNodeGroup_2,
    //TNodeImageTexture,
    //TNodeIndexedFaceSet_2,
    //TNodeIndexedLineSet_2,
    TNodeInline,
    { VRML 2.0 spec doesn't say InlineLoadControl is valid children
      node, it also doesn't say it's not valid. Common sense says
      it's valid. }
    TNodeInlineLoadControl,
    TNodeLOD_2,
    //TNodeMaterial_2,
    //TNodeMovieTexture,
    TNodeNavigationInfo,
    { Normal node is not a valid children node for VRML 2.0.
      But we don't have separate TNodeNormal_1 and TNodeNormal_2 classes,
      so node normal was already added here as all other VRML 1.0 nodes.
      So it's allowed children node for us --- in the spirit thst
      we allow to mix VRML 1.0 and 2.0. }
    //{ TNodeNormal, - registered already as VRML 1.0 node }
    TNodeNormalInterpolator,
    //TNodeNurbsCurve,
    //TNodeNurbsCurve2D,
    { VRML 2.0 spec section "4.6.5 Grouping and children nodes"
      doesn't say is NurbsGroup allowed or not as children node.
      To be fixed when I'll implement NurbsGroup handling. }
    TNodeNurbsGroup,
    TNodeNurbsPositionInterpolator,
    //TNodeNurbsSurface,
    //TNodeNurbsTextureSurface,
    TNodeOrientationInterpolator,
    { VRML 2.0 spec section "4.6.5 Grouping and children nodes"
      doesn't say is PixelTexture allowed or not as children node.
      But common sense says it's only for Appearance.texture field. }
    //TNodePixelTexture,
    TNodePlaneSensor,
    TNodePointLight_2,
    //TNodePointSet_2,
    //TNodePolyline2D,
    TNodePositionInterpolator,
    TNodeProximitySensor,
    TNodeScalarInterpolator,
    TNodeScript,
    TNodeShape,
    TNodeSound,
    //TNodeSphere_2,
    TNodeSphereSensor,
    TNodeSpotLight_2,
    TNodeSwitch_2,
    //TNodeText,
    //TNodeTextureCoordinate,
    //TNodeTextureTransform,
    TNodeTimeSensor,
    TNodeTouchSensor,
    TNodeTransform_2,
    //TNodeTrimmedSurface,
    TNodeViewpoint,
    TNodeVisibilitySensor,
    TNodeWorldInfo
  ]);

  AllowedGeometryNodes := TVRMLNodeClassesList.Create;
  AllowedGeometryNodes.AssignArray([
    TNodeBox,
    TNodeCone_2,
    TNodeContour2D,
    TNodeCylinder_2,
    TNodeElevationGrid,
    TNodeExtrusion,
    TNodeGeoElevationGrid,
    TNodeIndexedFaceSet_2,
    TNodeIndexedLineSet_2,
    TNodeNurbsCurve,
    TNodeNurbsSurface,
    TNodePointSet_2,
    TNodeSphere_2,
    TNodeText,
    TNodeTrimmedSurface
  ]);
finalization
  FreeAndNil(AllowedGeometryNodes);
  FreeAndNil(AllowedChildrenNodes);
  FreeAndNil(NodesManager);
end.
