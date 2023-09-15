# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file containing user logon names of employees leaving
$csvPath = "S:\Fileshare\HR\LeavingHires.csv"

# Define the target OU where you want to move the former employees
$ouPath = "OU=Former Employees,DC=CDB,DC=lan"

# Check if the CSV file exists
if (Test-Path $csvPath) {
    # Read the CSV file
    $leavingUserList = Import-Csv $csvPath

    # Loop through each user in the CSV
    foreach ($user in $leavingUserList) {
        $logonName = $user.LogonName

        # Check if the user exists
        $existingUser = Get-ADUser -Filter { (SamAccountName -eq $logonName) } -ErrorAction SilentlyContinue

        if ($existingUser -ne $null) {
            # Disable the user account
            Disable-ADAccount -Identity $logonName

            # Move the user to the "OU=Former Employees" OU
            Move-ADObject -Identity $existingUser -TargetPath $ouPath
        }
    }
}