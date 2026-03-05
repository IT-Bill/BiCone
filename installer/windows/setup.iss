[Setup]
AppName=BiCone
AppVersion={#MyAppVersion}
AppPublisher=IT-Bill
AppPublisherURL=https://github.com/IT-Bill/BiCone
DefaultDirName={autopf}\BiCone
DefaultGroupName=BiCone
OutputDir=.
OutputBaseFilename=BiCone-{#MyAppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\bicone.exe
WizardStyle=modern

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\BiCone"; Filename: "{app}\bicone.exe"
Name: "{autodesktop}\BiCone"; Filename: "{app}\bicone.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\bicone.exe"; Description: "Launch BiCone"; Flags: nowait postinstall skipifsilent
