program castle_editor;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  // packages:
  castle_components,
  castle_editor_automatic_package,
  Forms, FormChooseProject, ProjectUtils, FormNewProject,
  EditorUtils, FormProject, FrameDesign, FormAbout, FrameViewFile,
  FormPreferences, VisualizeTransform, FormSpriteSheetEditor, DataModuleIcons,
  FormImportAtlas, FormImportStarling, FormNewUnit;


{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TIcons, Icons);
  Application.CreateForm(TChooseProjectForm, ChooseProjectForm);
  Application.CreateForm(TNewProjectForm, NewProjectForm);
  Application.CreateForm(TAboutForm, AboutForm);
  Application.CreateForm(TPreferencesForm, PreferencesForm);
  Application.CreateForm(TImportAtlasForm, ImportAtlasForm);
  Application.CreateForm(TImportStarlingForm, ImportStarlingForm);
  Application.CreateForm(TNewUnitForm, NewUnitForm);
  Application.Run;
end.
