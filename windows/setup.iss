#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
[Setup]
AppName=ebm Central
AppVersion={#MyAppVersion}
AppPublisher=Atik Islam
AppPublisherURL=https://github.com/atikrights/ebm-central
AppSupportURL=https://github.com/atikrights/ebm-central/issues
AppUpdatesURL=https://github.com/atikrights/ebm-central/releases
DefaultDirName={autopf}\ebmCentral
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\build\windows\inno
OutputBaseFilename=ebm-central-windows
Compression=lzma
SolidCompression=yes
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\ebm_central.exe
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
WizardStyle=modern
SetupMutex=ebmCentralSetupMutex
AppMutex=ebmCentralMutex
CloseApplications=yes

[InstallDelete]
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\ebm Central"; Filename: "{app}\ebm_central.exe"
Name: "{autodesktop}\ebm Central"; Filename: "{app}\ebm_central.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ebm_central.exe"; Description: "{cm:LaunchProgram,ebm Central}"; Flags: nowait postinstall skipifsilent

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"
