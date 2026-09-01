<#
.SYNOPSIS
    GUI-Tool zum Aendern des eigenen Active-Directory-Kennworts (Self-Service).
    GUI tool for changing your own Active Directory password (self-service).
 
.BESCHREIBUNG (DE)
    - Laeuft im Kontext des angemeldeten Benutzers (keine erhoehten Rechte noetig)
    - Ermittelt und zeigt das Alter des aktuellen Kennworts an
    - Zeigt die Kennwortkomplexitaetsanforderungen an
    - Prueft die Eingabe clientseitig, bevor sie an AD gesendet wird
    - Aendert das Kennwort ueber UserPrincipal.ChangePassword(altesPW, neuesPW)
      -> Dies erfordert zwingend die Kenntnis des ALTEN Kennworts
         (kein administratives Zuruecksetzen, sondern echtes Self-Service-Aendern)
    - Oberflaeche automatisch auf Deutsch oder Englisch, siehe Abschnitt
      "SPRACHERKENNUNG" weiter unten
 
.DESCRIPTION (EN)
    - Runs in the context of the logged-on user (no elevated rights required)
    - Determines and displays the age of the current password
    - Displays the password complexity requirements
    - Validates input client-side before sending it to AD
    - Changes the password via UserPrincipal.ChangePassword(oldPwd, newPwd)
      -> This requires knowledge of the OLD password
         (a genuine self-service change, not an administrative reset)
    - UI language is automatically German or English, see "LANGUAGE DETECTION"
      section below
 
.HINWEISE / NOTES
    - Benoetigt .NET Framework (Assembly System.DirectoryServices.AccountManagement),
      das auf normalen, domaenengebundenen Windows-Clients bereits vorhanden ist.
    - Muss auf einem domaenengebundenen Rechner ausgefuehrt werden, waehrend der
      Benutzer mit seinem Domaenenkonto angemeldet ist.
    - Die tatsaechliche Kennwortrichtlinie (Laenge, Komplexitaet, Historie,
      Mindestalter) wird letztlich vom Domaenencontroller durchgesetzt. Die
      Pruefungen in diesem Skript dienen nur der Benutzerfreundlichkeit
      (fruehzeitige Fehlermeldung), sie ersetzen NICHT die serverseitige Richtlinie.
 
.WIE ERSTELLE ICH EINE EXE-DATEI AUS DIESEM SKRIPT? / HOW DO I BUILD AN EXE?
    Das beliebteste und einfachste Werkzeug dafuer ist "ps2exe"
    (PowerShell-Modul, Open Source, https://github.com/MScholtes/PS2EXE).
 
    1. Modul installieren (einmalig, im normalen PowerShell-Fenster):
         Install-Module -Name ps2exe -Scope CurrentUser
 
    2. Skript in eine EXE umwandeln (Beispielaufruf):
         Invoke-ps2exe -inputFile ".\AD-Password-Changer.ps1" `
                        -outputFile ".\AD-Password-Changer.exe" `
                        -noConsole `
                        -title "AD Password Changer" `
                        -product "AD Password Changer" `
                        -version "1.0.0.0" `
                        -requireAdmin:$false
 
       Wichtige Parameter:
         -noConsole       -> unterdrueckt das schwarze Konsolenfenster (reine GUI)
         -requireAdmin:$false -> WICHTIG, da das Tool bewusst im normalen
                                  Benutzerkontext laufen soll, nicht als Admin
         -iconFile ".\icon.ico" -> optional, eigenes Icon fuer die EXE
 
    3. Die erzeugte AD-Kennwort-Aendern.exe kann anschliessend z. B. per
       Softwareverteilung, GPO oder als Verknuepfung auf dem Desktop verteilt
       werden. Es ist keine PowerShell-Ausfuehrungsrichtlinie (ExecutionPolicy)
       mehr noetig, da es sich um eine kompilierte EXE handelt.
 
    Hinweis: Manche Virenscanner/AV-Loesungen stufen frisch mit ps2exe erzeugte
    EXE-Dateien zunaechst als verdaechtig ein (generisches PowerShell-Wrapping).
    Ggf. Codesigning verwenden oder die Datei beim AV-Hersteller/der eigenen
    Sicherheitsabteilung zur Freigabe/Whitelisting einreichen.
#>
 
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
 
# ============================================================================
# SPRACHERKENNUNG / LANGUAGE DETECTION
# ============================================================================
# Regel: Wenn der Windows-Standort (Region) Deutschland ist, wird Deutsch
# verwendet. In allen anderen Faellen wird Englisch verwendet. Als Fallback
# wird zusaetzlich die UI-Kultur des Benutzers geprueft (z. B. falls die
# Region nicht ermittelt werden kann).
#
# Rule: If the Windows location (region) is Germany, German is used.
# In all other cases, English is used. As a fallback, the user's UI culture
# is also checked (e.g. if the region cannot be determined).
try {
    $regionCode = [System.Globalization.RegionInfo]::CurrentRegion.TwoLetterISORegionName
} catch {
    $regionCode = $null
}
$uiCultureName = [System.Globalization.CultureInfo]::CurrentUICulture.Name
 
if ($regionCode -eq "DE" -or ($null -eq $regionCode -and $uiCultureName -like "de-*")) {
    $Lang = "de"
} else {
    $Lang = "en"
}
 
# ============================================================================
# TEXTBAUSTEINE / STRING TABLES
# ============================================================================
$Strings = @{
    "de" = @{
        FormTitle       = "Active Directory Kennwort ändern"
        UserLabel       = "Angemeldeter Benutzer: {0}"
        AgeKnown        = "Aktuelles Kennwort gesetzt am {0} (Alter: {1} Tage)"
        AgeUnknown      = "Kennwortalter konnte nicht ermittelt werden."
        OldPwLabel      = "Altes Kennwort:"
        NewPwLabel      = "Neues Kennwort:"
        ConfirmPwLabel  = "Kennwort bestätigen:"
        ShowInputCheck  = "Eingaben anzeigen"
        PolicyText      = "Kennwortanforderungen:`n - Mindestens 10 Zeichen`n - Gross- und Kleinbuchstaben`n - Mindestens eine Ziffer`n - Mindestens ein Sonderzeichen`n - Darf keinem der letzten verwendeten`n   Kennwörter entsprechen (Kennworthistorie)"
        ChangeButton    = "Kennwort ändern"
        CloseButton     = "Schliessen"
        ErrFillAll      = "Bitte alle Felder ausfüllen."
        ErrMismatch     = "Die neuen Kennwörter stimmen nicht überein."
        ErrSameAsOld    = "Das neue Kennwort darf nicht dem alten entsprechen."
        ErrTooShort     = "Das Kennwort muss mindestens 10 Zeichen lang sein."
        ErrNoUpper      = "Das Kennwort muss mindestens einen Grossbuchstaben enthalten."
        ErrNoLower      = "Das Kennwort muss mindestens einen Kleinbuchstaben enthalten."
        ErrNoDigit      = "Das Kennwort muss mindestens eine Ziffer enthalten."
        ErrNoSpecial    = "Das Kennwort muss mindestens ein Sonderzeichen enthalten."
        SuccessStatus   = "Kennwort wurde erfolgreich geändert."
        SuccessTitle    = "Erfolg"
        SuccessBody     = "Ihr Active Directory Kennwort wurde erfolgreich geändert."
        ErrorPrefix     = "Fehler: {0}"
        AdConnFailTitle = "Fehler"
        AdConnFailBody  = "Fehler beim Verbinden mit Active Directory:`n{0}`n`nStellen Sie sicher, dass dieser Rechner domänengebunden ist und Sie mit einem Domänenkonto angemeldet sind."
    }
    "en" = @{
        FormTitle       = "Change Active Directory Password"
        UserLabel       = "Logged-on user: {0}"
        AgeKnown        = "Current password set on {0} (age: {1} days)"
        AgeUnknown      = "Password age could not be determined."
        OldPwLabel      = "Old password:"
        NewPwLabel      = "New password:"
        ConfirmPwLabel  = "Confirm password:"
        ShowInputCheck  = "Show input"
        PolicyText      = "Password requirements:`n - At least 10 characters`n - Upper- and lowercase letters`n - At least one digit`n - At least one special character`n - Must not match any of the recently`n   used passwords (password history)"
        ChangeButton    = "Change password"
        CloseButton     = "Close"
        ErrFillAll      = "Please fill in all fields."
        ErrMismatch     = "The new passwords do not match."
        ErrSameAsOld    = "The new password must not be the same as the old one."
        ErrTooShort     = "The password must be at least 10 characters long."
        ErrNoUpper      = "The password must contain at least one uppercase letter."
        ErrNoLower      = "The password must contain at least one lowercase letter."
        ErrNoDigit      = "The password must contain at least one digit."
        ErrNoSpecial    = "The password must contain at least one special character."
        SuccessStatus   = "Password changed successfully."
        SuccessTitle    = "Success"
        SuccessBody     = "Your Active Directory password has been changed successfully."
        ErrorPrefix     = "Error: {0}"
        AdConnFailTitle = "Error"
        AdConnFailBody  = "Error connecting to Active Directory:`n{0}`n`nMake sure this computer is domain-joined and you are logged on with a domain account."
    }
}
$T = $Strings[$Lang]
 
# --- Verbindung zu AD herstellen und aktuellen Benutzer ermitteln ---
try {
    $ctxType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($ctxType)
    $userPrincipal = [System.DirectoryServices.AccountManagement.UserPrincipal]::Current
    if (-not $userPrincipal) { throw "Current user could not be determined." }
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        ($T.AdConnFailBody -f $_.Exception.Message),
        $T.AdConnFailTitle, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}
 
$samAccountName = $userPrincipal.SamAccountName
$lastSet = $userPrincipal.LastPasswordSet
 
if ($lastSet) {
    $ageDays = [int](New-TimeSpan -Start $lastSet -End (Get-Date)).TotalDays
    $ageText = $T.AgeKnown -f $lastSet.ToString('dd.MM.yyyy'), $ageDays
} else {
    $ageText = $T.AgeUnknown
}
 
# --- GUI aufbauen / build GUI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = $T.FormTitle
$form.Size = New-Object System.Drawing.Size(430, 440)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
 
$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Text = $T.UserLabel -f $samAccountName
$lblUser.Location = New-Object System.Drawing.Point(15, 15)
$lblUser.Size = New-Object System.Drawing.Size(390, 20)
$form.Controls.Add($lblUser)
 
$lblAge = New-Object System.Windows.Forms.Label
$lblAge.Text = $ageText
$lblAge.Location = New-Object System.Drawing.Point(15, 38)
$lblAge.Size = New-Object System.Drawing.Size(390, 20)
$form.Controls.Add($lblAge)
 
$lblOld = New-Object System.Windows.Forms.Label
$lblOld.Text = $T.OldPwLabel
$lblOld.Location = New-Object System.Drawing.Point(15, 80)
$lblOld.Size = New-Object System.Drawing.Size(150, 20)
$form.Controls.Add($lblOld)
 
$txtOld = New-Object System.Windows.Forms.TextBox
$txtOld.Location = New-Object System.Drawing.Point(180, 78)
$txtOld.Size = New-Object System.Drawing.Size(220, 20)
$txtOld.UseSystemPasswordChar = $true
$form.Controls.Add($txtOld)
 
$lblNew = New-Object System.Windows.Forms.Label
$lblNew.Text = $T.NewPwLabel
$lblNew.Location = New-Object System.Drawing.Point(15, 112)
$lblNew.Size = New-Object System.Drawing.Size(150, 20)
$form.Controls.Add($lblNew)
 
$txtNew = New-Object System.Windows.Forms.TextBox
$txtNew.Location = New-Object System.Drawing.Point(180, 110)
$txtNew.Size = New-Object System.Drawing.Size(220, 20)
$txtNew.UseSystemPasswordChar = $true
$form.Controls.Add($txtNew)
 
$lblConfirm = New-Object System.Windows.Forms.Label
$lblConfirm.Text = $T.ConfirmPwLabel
$lblConfirm.Location = New-Object System.Drawing.Point(15, 144)
$lblConfirm.Size = New-Object System.Drawing.Size(150, 20)
$form.Controls.Add($lblConfirm)
 
$txtConfirm = New-Object System.Windows.Forms.TextBox
$txtConfirm.Location = New-Object System.Drawing.Point(180, 142)
$txtConfirm.Size = New-Object System.Drawing.Size(220, 20)
$txtConfirm.UseSystemPasswordChar = $true
$form.Controls.Add($txtConfirm)
 
$chkShow = New-Object System.Windows.Forms.CheckBox
$chkShow.Text = $T.ShowInputCheck
$chkShow.Location = New-Object System.Drawing.Point(180, 168)
$chkShow.Size = New-Object System.Drawing.Size(200, 20)
$chkShow.Add_CheckedChanged({
    $show = -not $chkShow.Checked
    $txtOld.UseSystemPasswordChar = $show
    $txtNew.UseSystemPasswordChar = $show
    $txtConfirm.UseSystemPasswordChar = $show
})
$form.Controls.Add($chkShow)
 
$lblPolicy = New-Object System.Windows.Forms.Label
$lblPolicy.Text = $T.PolicyText
$lblPolicy.Location = New-Object System.Drawing.Point(15, 195)
$lblPolicy.Size = New-Object System.Drawing.Size(390, 110)
$form.Controls.Add($lblPolicy)
 
$btnChange = New-Object System.Windows.Forms.Button
$btnChange.Text = $T.ChangeButton
$btnChange.Location = New-Object System.Drawing.Point(15, 315)
$btnChange.Size = New-Object System.Drawing.Size(180, 32)
$form.Controls.Add($btnChange)
 
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = $T.CloseButton
$btnClose.Location = New-Object System.Drawing.Point(220, 315)
$btnClose.Size = New-Object System.Drawing.Size(180, 32)
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)
 
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(15, 355)
$lblStatus.Size = New-Object System.Drawing.Size(390, 60)
$lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
$form.Controls.Add($lblStatus)
 
# --- Lokale Vorabpruefung der Komplexitaet (nur UX, keine Ersetzung der AD-Richtlinie) ---
function Test-PasswordComplexity {
    param([string]$Password)
 
    if ($Password.Length -lt 10)             { return $T.ErrTooShort }
    if ($Password -cnotmatch '[A-Z]')        { return $T.ErrNoUpper }
    if ($Password -cnotmatch '[a-z]')        { return $T.ErrNoLower }
    if ($Password -notmatch '[0-9]')         { return $T.ErrNoDigit }
    if ($Password -notmatch '[^a-zA-Z0-9]')  { return $T.ErrNoSpecial }
    return $null
}
 
$btnChange.Add_Click({
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
    $old = $txtOld.Text
    $new = $txtNew.Text
    $confirm = $txtConfirm.Text
 
    if ([string]::IsNullOrEmpty($old) -or [string]::IsNullOrEmpty($new) -or [string]::IsNullOrEmpty($confirm)) {
        $lblStatus.Text = $T.ErrFillAll
        return
    }
    if ($new -ne $confirm) {
        $lblStatus.Text = $T.ErrMismatch
        return
    }
    if ($new -eq $old) {
        $lblStatus.Text = $T.ErrSameAsOld
        return
    }
    $complexityError = Test-PasswordComplexity -Password $new
    if ($complexityError) {
        $lblStatus.Text = $complexityError
        return
    }
 
    $btnChange.Enabled = $false
    try {
        $userPrincipal.ChangePassword($old, $new)
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
        $lblStatus.Text = $T.SuccessStatus
        $txtOld.Text = ""
        $txtNew.Text = ""
        $txtConfirm.Text = ""
        [System.Windows.Forms.MessageBox]::Show(
            $T.SuccessBody, $T.SuccessTitle,
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        $inner = $_.Exception.InnerException
        $msg = if ($inner) { $inner.Message } else { $_.Exception.Message }
        $lblStatus.Text = $T.ErrorPrefix -f $msg
    } finally {
        $btnChange.Enabled = $true
    }
})
 
[void]$form.ShowDialog()
