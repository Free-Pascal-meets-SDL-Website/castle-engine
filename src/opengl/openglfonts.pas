{
  Copyright 2001-2005,2007 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

{ @abstract(Ten modul zapewnia podstawowe klasy dla klas fontow pod OpenGL'em.)

  Implementacja fontow musi
   - pokrywac procedury abstract,
   - dostarczyc wlasny konstruktor w ktorym zainicjuje pole fRowHeight,
  Implementacja moze
   - dodac nowe procedury, bardziej wyspecjalizowane dla implementacji.
   - pokrywac procedury virtual

  Kazda implementacja musi przestrzegac zasad (a zewnetrzny kod moze na nich polegac) :
   - wszystkie Print'y wymagaja do dzialania maksymalnie 1 wolnego miejsca na stosie
      attribow.
     Dodatkowo Printy w TGLOutlineFont moga wymagac jednego wolnego miejsca na stosie
      modelview matrix.
     (tzn. moga wymagac mniej - ale nie wiecej !).
   - KAZDE PrintXxx zanim zakonczy w pelni przywraca stan OpenGL'a przed swoim wywolaniem
     (jedyna zmiana stanu to ze pojawil sie napis; ale wszystko pozostale, w szczegolnosci
     modelview matrix i raster position, musi pozostac takie jak bylo).
     Wyjatek stanowi PrintAndMove ktore w przypadku bitmapped fonta powinno
      po zakonczeniu ustawic glRasterPos na koniec stringa a w przypadku
      outlined fonta powinno ustawic modelview-matrix tak zeby kilkakrotne
      wywolanie PrintAndMove pod rzad wypisalo jeden string za drugim.
      To musza byc jednak JEDYNE zmiany dokonane przez PrintAdMove.

  Implementacja moze zakladac ze (a zewnetrzny kod musi to zapewniac) :
   - kazde PrintXxx jest wywolywane tylko gdy aktualne matrix mode to MODELVIEW_MATRIX.
   - konstruktory i destruktory sa wywolywane tylko gdy gl context jest aktywny
     (np. w InitGL/ExitGL).
}

unit OpenGLFonts;

{$I openglmac.inc}

interface

uses Classes, GL, GLU, SysUtils, KambiGLUtils;

type
  TGLBitmapFont_Abstract = class
  protected
    fRowHeight: Integer;
  public
    { PrintAndMove wypisuje string s przesuwajac raster pos po wypisaniu
      kazdej literki. W rezultacie, po zakonczeniu mozesz np. wywolac
      PrintAndMove jeszcze raz i bedziesz pisal od miejsca na ekranie
      w ktorym skonczyles, inaczej mowiac PrintAndMove('whatever') is
      exactly equivalent to PrintAndMove('what'); PrintAndMove('ever');
      (except for some extremely small additional performance cost in the
      latter case). }
    procedure PrintAndMove(const s: string); virtual; abstract;
    procedure PrintAndMoveFmt(const s: string; const args: array of const);

    { Print saves current raster position, calls PrintAndMove and then
      restores raster position. So Print effectively prints the string
      without affecting current raster pos. And if you care about
      performance, you should note that if you simply don't care about
      position of raster after Printing a string than you should
      use PrintAndMove instead of Print. }
    procedure Print(const s: string);
    procedure PrintFmt(const s: string; const args: array of const);

    function TextWidth(const s: string): integer; virtual; abstract;
    function TextHeight(const s: string): integer; virtual; abstract;

    { co do RowHeight : to nie musi byc DOKLADNIE TextHeight('Wy') -
      bedzie bardzo dobrze jesli wlasnie w RowHeight bedzie dodany jakis maly
      odstep miedzy liniami, np. +2 dla bitmap fontow. }
    property RowHeight: integer read fRowHeight;

    { Descend : jak gleboko moze spasc charakter ponizej wysokosci 0 ?
      Domyslnie brane jest TextHeight('y')-TextHeight('a'), mozesz pokryc ta
      metode w swojej klasie aby dostarczyc jakiejs dokladniejszej / inaczej
      liczonej informacji. }
    function Descend: integer; virtual;

    { procedury BreakLines lamia string (w ktorym moga byc juz zlamane miejsca
      nl, zostana one poprawnie zauwazone) lub TStrings w taki sposob
      aby zadna linia nie miala TextWidth wiekszego niz maxLineWidth.
      Zawartosc unbroken nie jest w zaden sposob modyfikowana.
      Dotychczasowa zawartosc broken zostaje zachowana, nowe stringi zostana
      dopisane na koniec broken. firstToBreak mowi od ktorej linii zaczac
      lamanie.

      Stara sie polamac PRAWIE za wszelka cene. To znaczy np. stara sie lamac
      na bialych znakach, ale jezeli w stringu jest za dlugi wyraz bez bialych
      znakow to tez go zlamie. Jedyna sytuacja w ktorej wynikowy MaxLineWidth()
      dla tak polamanej listy nie bedzie spelniac ograniczenia to gdy
      jeden ze znakow uzytych w tekscie jest SAM wiekszy od narzuconego
      maxLineWidth. Wtedy po prostu nie da sie zlamac stringa zadowalajaco -
      ponizsze procedury zezwola wtedy na to aby ten jeden znak byl sam
      w linii i naruszal ograniczenie maxLineWidth. }
    procedure BreakLines(const unbroken: string; broken: TStrings; maxLineWidth: integer); overload;
    procedure BreakLines(unbroken, broken: TStrings; maxLineWidth: integer); overload;
    procedure BreakLines(broken: TStrings; maxLineWidth: integer; firstToBreak: integer); overload;
    { MaxTextWidth - najwieksze TextWidth(slist[i]) gdzie i przebiega 0..slist.count-1 }
    function MaxTextWidth(slist: TStringList): integer;

    { Print strings from 0 to strs.count-1 using this font.
      glRasterPosi(RasterX0, RasterY0) is the position of the last string,
      each previous string will be RowHeight + BonusVerticalSpace higher,
      and so on (BonusVerticalSpace CAN be <0, only
      (RowHeight + BonusVerticalSpace) must be > 0).

      Wersje 2-arg uznaja RasterX0 = RasterY0 = 0.

      glRasterPos value will be ignored and then modified by this method. }
    procedure PrintStrings(strs: TStrings; BonusVerticalSpace: TGLint); overload;
    procedure PrintStrings(const strs: array of string; BonusVerticalSpace: TGLint); overload;
    procedure PrintStrings(strs: TStrings;
      BonusVerticalSpace: TGLint; RasterX0, RasterY0: integer); overload;
    procedure PrintStrings(const strs: array of string;
      BonusVerticalSpace: TGLint; RasterX0, RasterY0: integer); overload;

    { Lamie string s (uzywajac BreakLines, wiec oryginalne #13 i #10 w stringu
      sa uwzglednione i string jest dzielony tak zeby zadna jego linia nie miala
      wiecej niz MaxLineWidth).

      Potem wypisuje string. Jezeli RasterPositionsFirst to RasterX0, RasterY0
      okresla pozycje pierwszego stringu na liscie, wpp. okresla pozycje
      ostatniego. Kolejne linie sa wypisywane kazda o
      RowHeight + BonusVerticalSpace nizej niz poprzednia (tak jak
      w PrintStrings, wymagane jest tylko zeby
      (RowHeight + BonusVerticalSpace) > 0).

      Funkcja zwraca liczbe linii jakie uzyskano po zlamaniu stringu s.
      W ten sposob mozesz np. obliczyc pozycje jaka miala na ekranie
      pierwsza / ostatnia ze zlamanych linii (to ktora z tych wartosci bylaby
      dla ciebie nieznana zalezy od tego ktora z tych wartosci podales,
      czyli od RasterPositionsFirst). }
    function PrintBrokenString(const s: string;
      MaxLineWidth, RasterX0, RasterY0: Integer;
      RasterPositionsFirst: boolean; BonusVerticalSpace: Integer): Integer;

    { rysuje strs kolorem StringCol i otacza je prostokatem ktory w srodku
        ma kolor InsideCol i stipple Stipple (lub nie ma stipple jesli
        Stipple = nil) a krawedz ma kolorem BorderCol.
        BoxPixelMargin to min odleglosc miedzy tekstem a krawedzia prostokata
        w pixelach. Robi to wszystko poprawnie
        zaczynajac od pozycji glRasterPos(0, 0), wzgledem aktualnej matrix
        (aktualne matrix to musi byc naturalnie MODELVIEW) i przy zalozeniu
        ze 1 jednostka OpenGL'a xowa to XPixelsRes piksli, a ykowa to
        YPixelsRes piksli.
      BonusVerticalSpace - jak w PrintStrings.
      RasterPos and curent color will be ignored and then modified by this proc,
        no other state is affected.
        Current matrix value is used and not modified.
      Requires one attrib stack and one matrix stack place. }
    procedure PrintStringsBorderedRect(const strs: array of string; BonusVerticalSpace: TGLint;
      const InsideCol, BorderCol, TextCol: TVector4f; Stipple: PPolygonStipple;
      BoxPixelMargin: integer; const XPixelsRes, YPixelsRes: TGLfloat); overload;
    procedure PrintStringsBorderedRect(strs: TStringList; BonusVerticalSpace: TGLint;
      const InsideCol, BorderCol, TextCol: TVector4f; Stipple: PPolygonStipple;
      BoxPixelMargin: integer; const XPixelsRes, YPixelsRes: TGLfloat); overload;

    { Draw strings in a box frame at the top of the window.

      WindowTop specifies the top pixel of the window.

      WindowTopMargin is the height between box and WindowTop, also in pixels. }
    procedure PrintStringsBorderedRectTop(
      strs: TStringList; BonusVerticalSpace: TGLint;
      const InsideCol, BorderCol, TextCol: TVector4f; Stipple: PPolygonStipple;
      BoxPixelMargin: integer; const XPixelsRes, YPixelsRes: TGLfloat;
      WindowTop, WindowTopMargin: TGLint);

    { Temporarily switch to 2d projection and print given string.
      This is a comfortable routine in demo programs that generally have 3d
      projection, and need to switch to 2d projection only to set raster
      position to print some text.

      This uses glProjectionPushPop2D, in 2d is sets modelview matrix
      to identity and raster pos to X, Y, and then prints text like
      PrintStrings(S). }
    procedure Projection2DPrintStrings(X, Y: Integer; S: TStrings); overload;
    procedure Projection2DPrintStrings(X, Y: Integer; S: string); overload;
  end;

  TGLBitmapFontClass = class of TGLBitmapFont_Abstract;

  TGLOutlineFont_Abstract = class
  protected
    fRowHeight: single;
  public
    procedure Print(const s: string); virtual; abstract;
    procedure PrintFmt(const s: string; const args: array of const);
    procedure PrintSrodek(const s: string);
    procedure PrintAndMove(const s: string); virtual; abstract;
    procedure PrintAndMoveFmt(const s: string; const args: array of const);

    function textWidth(const s: string): single; virtual; abstract;
    function textHeight(const s: string): single; virtual; abstract;
    property RowHeight: single read fRowHeight;
    function Descend: single; virtual;
  end;

const
  GLFontChFirst = Ord(' ');
  GLFontChCount = Ord(High(Char))-GLFontChFirst+1;
  { powyzsze stale powinny byc uzywane jezeli konstruktor jakiegos gl fontu
    wymaga podania przedzialu znakow dla ktorych beda generowane faktyczne litery
    fontu (np. display listy).
    Wtedy powyzsze stale okreslaja odpowiednio Ord() pierwszego znaku ktory
    powinien zostac wygenerowany a GLFontChCount - ilosc wszystkich znakow.
  }

implementation

uses KambiUtils, KambiClassUtils, KambiStringUtils;

{ TGLBitmapFont_Abstract ------------------------------------------------------}

procedure TGLBitmapFont_Abstract.Print(const s: string);
var rasterPos4f: TVector4f;
begin
 glGetFloatv(GL_CURRENT_RASTER_POSITION, @rasterPos4f);
 PrintAndMove(s);
 glRasterPos4fv(@rasterPos4f);
end;

procedure TGLBitmapFont_Abstract.PrintFmt(const s: string; const args: array of const);
begin
 Print(Format(s, args));
end;

procedure TGLBitmapFont_Abstract.PrintAndMoveFmt(const s: string; const args: array of const);
begin
 PrintAndMove(Format(s, args));
end;

function TGLBitmapFont_Abstract.Descend: integer;
begin
 result := TextHeight('y')-TextHeight('a');
end;

procedure TGLBitmapFont_Abstract.BreakLines(const unbroken: string;
  broken: TStrings; maxLineWidth: integer);
var unbrokenlist: TStringList;
begin
 unbrokenlist := TStringList.Create;
 try
  Strings_SetText(unbrokenlist, unbroken);
  BreakLines(unbrokenlist, broken, maxLineWidth);
 finally unbrokenlist.Free end;
end;

procedure TGLBitmapFont_Abstract.BreakLines(unbroken, broken: TStrings;
  maxLineWidth: integer);
var i, firstToBreak: integer;
begin
 firstToBreak := broken.count;
 for i := 0 to unbroken.count-1 do broken.Append(unbroken[i]);
 BreakLines(broken, maxLineWidth, firstToBreak);
end;

procedure TGLBitmapFont_Abstract.BreakLines(broken: TStrings;
  maxLineWidth: integer; firstToBreak: integer);
var i, j: integer;
    linew: integer;
    p: integer;
    break1, break2: string;
begin

 { ponizej lamiemy stringi unbroken.
   Lamanie to nie jest takie proste bo my nie mamy czegos takiego jak
   MaxCol - ilosc znakow w linii, bo kazdy znak moze miec inna szerokosc -
   font nie musi byc monospaced ! Gdyby byl - no coz, to robota bylaby prosta :
    broken.text := WrapText(broken.text, maxLineWidth div font.TextWidth('w'));
    (no, zakladajac ze firstToBreak = 0)
   i juz. A tak - musimy po kolei badac kazdy string szukajac w nim literki
   ktora sprawia ze nie miesci sie w maxLineWidth i wtedy obcinac.
 }

 i := firstToBreak;
 { instead of "for" use "while" because broken.count will be changing }
 while i < broken.count do
 begin
  { zobacz czy nie trzeba zlamac linii nr i.
    Linii '' z pewnoscia nie trzeba lamac. }
  if broken[i] <> '' then
  begin
   { ponizsze dwie linijki implikuja ze do zlamanej linii ZAWSZE trafia
     pierwszy znak z linii niezlamanej, NAWET jesli ten pierwszy znak
     jest szerszy niz maxLineWidth. No bo jezeli ten znak jest szerszy
     od maxLineWidth to przeciez nie moglby trafic do ZADNEJ linii,
     prawda ? Jedyna alternatywa byloby rzucenie w takim wypadku
     wyjatku z komunikatem ze "maxLineWidth" jest za male zeby w pelni
     poprawnie polamac string. }
   linew := TextWidth(broken[i][1]);
   j := 2;
   while (j <= Length(broken[i])) and
         (linew + TextWidth(broken[i][j]) <= maxLineWidth) do
   begin
    linew := linew + TextWidth(broken[i][j]);
    Inc(j);
   end;
   if j <= Length(broken[i]) then
   begin
    { oho ! ta linie trzeba zlamac przed znakiem j, bo linia jest za dluga kiedy
      ma j znakow. Efekt breaka bedzie tez taki ze broken.count sie zwiekszy wiec
      w nastepnym obrocie petli bedziemy lamali dalsza czesc tej linii - i o to
      chodzi. }
    p := BackCharsPos(WhiteSpaces, Copy(broken[i], 1,j));
    if p > 0 then
    begin
     break1 := Copy(broken[i], 1,p-1);
     break2 := SEnding(broken[i], p+1) { break at pos p, delete p-th char }
    end else
    begin
     break1 := Copy(broken[i], 1,j-1);
     break2 := SEnding(broken[i], j);  { break at pos j-1 }
    end;
    broken[i] := break1;
    broken.Insert(i+1, break2);
   end;
  end;

  Inc(i);
 end;
end;

function TGLBitmapFont_Abstract.MaxTextWidth(slist: TStringList): integer;
var i, linew: integer;
begin
 result := 0;
 for i := 0 to slist.Count-1 do
 begin
  linew := TextWidth(slist[i]);
  if linew > result then result := linew;
 end;
end;

procedure TGLBitmapFont_Abstract.PrintStrings(const strs: array of string;
  BonusVerticalSpace: TGLint; RasterX0, RasterY0: integer);
var
  I, H: integer;
begin
  H := High(strs);
  for i := 0 to High(strs) do
  begin
    glRasterPos2i(RasterX0, (H-i) * (RowHeight + BonusVerticalSpace) + RasterY0);
    PrintAndMove(strs[i]);
  end;
end;

procedure TGLBitmapFont_Abstract.PrintStrings(strs: TStrings;
  BonusVerticalSpace: TGLint; RasterX0, RasterY0: integer);
var
  I, H: integer;
begin
  H := strs.Count-1;
  for i := 0 to H do
  begin
    glRasterPos2i(RasterX0, (H-i) * (RowHeight + BonusVerticalSpace) + RasterY0);
    PrintAndMove(strs[i]);
  end;
end;

procedure TGLBitmapFont_Abstract.PrintStrings(const strs: array of string;
  BonusVerticalSpace: TGLint);
begin PrintStrings(strs, BonusVerticalSpace, 0, 0) end;

procedure TGLBitmapFont_Abstract.PrintStrings(strs: TStrings;
  BonusVerticalSpace: TGLint);
begin PrintStrings(strs, BonusVerticalSpace, 0, 0) end;

function TGLBitmapFont_Abstract.PrintBrokenString(const s: string;
  MaxLineWidth, RasterX0, RasterY0: integer;
  RasterPositionsFirst: boolean; BonusVerticalSpace: Integer): Integer;
var broken: TStringList;
begin
 broken := TStringList.Create;
 try
  BreakLines(s, broken, MaxLineWidth);
  if RasterPositionsFirst then
   RasterY0 -= (broken.Count-1)*(RowHeight + BonusVerticalSpace);
  PrintStrings(broken, BonusVerticalSpace, RasterX0, RasterY0);
  result := broken.Count;
 finally broken.Free end;
end;

procedure TGLBitmapFont_Abstract.PrintStringsBorderedRect(
  strs: TStringList; BonusVerticalSpace: TGLint;
  const InsideCol, BorderCol, TextCol: TVector4f; Stipple: PPolygonStipple;
  BoxPixelMargin: integer; const XPixelsRes, YPixelsRes: TGLfloat);
var
  Y2: Integer;
begin
  { You can't calculate full Y2 / YPixelsRes in one expression,
    FPC 2.2.0 under x86_64 will calculate something random then.
    Submittted as
    [http://www.freepascal.org/mantis/view.php?id=9893] }
  Y2 := (RowHeight + BonusVerticalSpace) * Strs.Count +
    2 * BoxPixelMargin + Descend;
  DrawGLBorderedRectangle(0, 0,
    (MaxTextWidth(Strs) + 2 * BoxPixelMargin) / XPixelsRes,
    Y2 / YPixelsRes,
    InsideCol, BorderCol, Stipple);
  glColorv(TextCol);
  PrintStrings(strs, BonusVerticalSpace, BoxPixelMargin, BoxPixelMargin + Descend);
end;

procedure TGLBitmapFont_Abstract.PrintStringsBorderedRectTop(
  strs: TStringList; BonusVerticalSpace: TGLint;
  const InsideCol, BorderCol, TextCol: TVector4f; Stipple: PPolygonStipple;
  BoxPixelMargin: integer; const XPixelsRes, YPixelsRes: TGLfloat;
  WindowTop, WindowTopMargin: TGLint);
var
  X2, Y2: Integer;
begin
  X2 := MaxTextWidth(Strs) + 2 * BoxPixelMargin;
  Y2 := (RowHeight + BonusVerticalSpace) * Strs.Count +
    2 * BoxPixelMargin + Descend;
  DrawGLBorderedRectangle(0,
    (WindowTop - WindowTopMargin * 2 - Y2) / YPixelsRes,
    X2 / XPixelsRes,
    (WindowTop - WindowTopMargin) / YPixelsRes,
    InsideCol, BorderCol, Stipple);
  glColorv(TextCol);
  glPushMatrix;
    glTranslatef(0, (WindowTop - WindowTopMargin - Y2)  / YPixelsRes, 0);
    PrintStrings(strs, BonusVerticalSpace, BoxPixelMargin,
      BoxPixelMargin + Descend);
  glPopMatrix;
end;

procedure TGLBitmapFont_Abstract.PrintStringsBorderedRect(
  const strs: array of string; BonusVerticalSpace: TGLint;
  const InsideCol, BorderCol, TextCol: TVector4f; Stipple: PPolygonStipple;
  BoxPixelMargin: integer; const XPixelsRes, YPixelsRes: TGLfloat);
var slist: TStringList;
begin
 slist := TStringList.Create;
 try
  AddStrArrayToStrings(strs, slist);
  PrintStringsBorderedRect(slist, BonusVerticalSpace,
    InsideCol, BorderCol, TextCol, Stipple,
    BoxPixelMargin, XPixelsRes, YPixelsRes);
 finally slist.Free end;
end;

type
  TProjection2DPrintData = record
    S: TStrings;
    X, Y: Integer;
    Font: TGLBitmapFont_Abstract;
  end;
  PProjection2DPrintData = ^TProjection2DPrintData;

procedure Draw2d(Data: Pointer);
var
  PData: PProjection2DPrintData;
begin
  PData := PProjection2DPrintData(Data);
  glLoadIdentity();
  PData^.Font.PrintStrings(PData^.S, 0, PData^.X, PData^.Y);
end;

procedure TGLBitmapFont_Abstract.Projection2DPrintStrings(
  X, Y: Integer; S: TStrings);
var
  Data: TProjection2DPrintData;
begin
  Data.S := S;
  Data.X := X;
  Data.Y := Y;
  Data.Font := Self;
  glProjectionPushPop2D(@Draw2d, @Data);
end;

procedure TGLBitmapFont_Abstract.Projection2DPrintStrings(
  X, Y: Integer; S: string);
var
  SList: TStrings;
begin
  SList := TStringList.Create;
  try
    SList.Text := S;
    Projection2DPrintStrings(X, Y, SList);
  finally SList.Free end;
end;

{ TGLOutlineFont_Abstract ------------------------------------------------------}

procedure TGLOutlineFont_Abstract.PrintFmt(const s: string; const args: array of const);
begin
 Print(Format(s, args));
end;

procedure TGLOutlineFont_Abstract.PrintAndMoveFmt(const s: string; const args: array of const);
begin
 PrintAndMove(Format(s, args));
end;

procedure TGLOutlineFont_Abstract.PrintSrodek(const s: string);
begin
 glTranslatef(-TextWidth(s)/2, 0.0, 0.0);
 Print(s);
end;

function TGLOutlineFont_Abstract.descend: single;
begin
 result := TextHeight('y')-TextHeight('a');
end;

end.

(*
-------------------------------------------------------------------

taka nieudana proba zrobienia czegos :

procedure PrintAndMovePos(const s: string; x, y,z: TGLfloat);

procedure TGLBitmapFont_Abstract.PrintAndMovePos(const s: string; x, y,z: TGLfloat);
var i: integer;
begin
 for i := 1 to Length(s) do
 begin
  glRasterPos3f(x, y,z);
  PrintAndMove(s[i]);
  { sami wykorzystujemy xmove i ymove aby zmienic x i y. W ten sposob
    mozemy wywolywac przed narysowaniem kazdej literki glRasterPos(x, y)
    w ten sposob sprawiajac ze jesli czesc napisu nie bedzie wypisana
    z powodu ze ich raster position bedzie invalid to pozostala czesc
    bedzie i tak w porzadku. }
  x := x+TextWidth(s[i]);
 end;
end;

*)
