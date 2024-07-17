Import-Module ActiveDirecotry

$users = Import-Csv -Path "C:\path\to\the\file"

foreach ($user in $users) {
    $firstName = $user.firstName
    $lastName = $user.lastName
    $userName = $user.userName
    $password = $user.password
    $email = $user.email
    $ou = $user.ou
    $description = $user.description
    $displayName = "$firstName $latName"

    $existingUser = Get-ADUser -Filter {SamAccountName -eq $userName} -ErrorAction SilentlyContinue

    if ($existingUser) {
        Write-Host "L'utente $userName esiste gia"
        #Set-ADUser potrei modificare le proprietà dell'utente
    } else {
        New_ADUser `
            -GiveName $firstName `
            -Surname $lastName `
            -SamAccountName $userName `
            -UserPrincipalName $email `
            -Path $ou `
            -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) `
            -Enabled $true `
            -DisplayName $displayName `
            -Description $description `
            -EmailAddress $email `
            -PasswordNeverExpire $false `
            -ChangePasswordAtLogon $true
     }
     Write-Host "Operazione completata per l'utente $userName."         
}


