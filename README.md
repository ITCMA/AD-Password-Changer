# AD-Password-Changer
Ein schlankes PowerShell-GUI-Tool, mit dem Benutzer ihr eigenes Active-Directory-Kennwort selbst ändern können (Self-Service) – läuft im Benutzerkontext, ohne Admin-Rechte.
A lightweight PowerShell GUI tool that lets users change their own Active Directory password (self-service) – runs in the user context, no admin rights required.

## Funktionen / Features

- 🔐 Ändert das eigene AD-Kennwort über `UserPrincipal.ChangePassword()` — erfordert zwingend das alte Kennwort (kein administratives Reset)
- 🕒 Zeigt Datum und Alter des aktuellen Kennworts an
- ✅ Client-seitige Vorabprüfung der Komplexität (Länge, Groß-/Kleinschreibung, Ziffer, Sonderzeichen)
- 🌍 Automatische Sprachumschaltung Deutsch/Englisch anhand des Windows-Standorts
- 👤 Läuft vollständig im Kontext des angemeldeten Benutzers
- 🖥️ Reine GUI (Windows Forms), kein Konsolenfenster bei Verwendung als EXE

- ## Voraussetzungen / Requirements

- Windows-Client, domänengebunden
- Benutzer ist mit Domänenkonto angemeldet
- PowerShell 5.1 (Windows-integriert) oder PowerShell 7+
- .NET-Assembly `System.DirectoryServices.AccountManagement` (auf Windows-Clients standardmäßig vorhanden)

## Verwendung / Usage

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD-Kennwort-Aendern.ps1
```

Oder als kompilierte EXE (siehe Abschnitt „EXE erstellen“ bzw. Kommentarblock im Skript).

## EXE erstellen / Build as EXE

Mit dem Open-Source-Modul [ps2exe](https://github.com/MScholtes/PS2EXE):

```powershell
Install-Module -Name ps2exe -Scope CurrentUser

Invoke-ps2exe -inputFile ".\AD-Password-Changer.ps1" `
              -outputFile ".\AD-Password-Changer.exe" `
              -noConsole `
              -title "AD Password Changer" `
              -product "AD Password Changer" `
              -version "1.0.0.0" `
              -requireAdmin:$false
```

> ⚠️ `-requireAdmin:$false` ist wichtig, damit die EXE weiterhin im normalen Benutzerkontext läuft. Frisch erzeugte ps2exe-EXEs werden von manchen Virenscannern zunächst als verdächtig eingestuft (generisches PowerShell-Wrapping) — ggf. signieren oder beim AV-Hersteller zur Freigabe einreichen.

## Verteilung / Deployment

Denkbare Wege, das Tool im Unternehmen bereitzustellen:

- Als Verknüpfung auf dem Desktop / im Startmenü (per GPO oder Softwareverteilung)
- Als Login-Skript-Aufruf oder verknüpft mit einer Tastenkombination (Strg+Alt+Entf-Ersatz für Self-Service)
- Signiert und über ein internes Software-Repository (SCCM, Intune Win32-App, etc.) verteilt

## Sicherheitshinweise / Security notes

- Das Tool ersetzt **nicht** die serverseitige AD-Kennwortrichtlinie. Die clientseitige Prüfung dient nur der Benutzerfreundlichkeit (frühzeitiges Feedback); die endgültige Durchsetzung (Länge, Historie, Mindestalter, Komplexität) erfolgt immer durch den Domänencontroller.
- Es werden keine Kennwörter geloggt, gecacht oder auf Datenträger geschrieben.
- Empfehlung: Skript/EXE vor der Verteilung code-signieren, um Integrität sicherzustellen und AV-Fehlalarme zu reduzieren.
