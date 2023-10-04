# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file containing user information
$csvPath = "S:\Fileshare\HR\LeavingHires.csv"

# Define the target OU where you want to move former employees
$ouPath = "OU=Former Employees,DC=CDB,DC=lan"

# Check if the CSV file exists
if (Test-Path $csvPath) {
    # Read the CSV file
    $userList = Import-Csv $csvPath

    # Loop through each user in the CSV
    foreach ($user in $userList) {
        $logonname = $user.logonname  # Logonname from the CSV

        # Check if the user exists
        $existingUser = Get-ADUser -Filter { (SamAccountName -eq $logonname) } -ErrorAction SilentlyContinue

        if ($existingUser -ne $null) {
            try {
                # Disable the user account
                Disable-ADAccount -Identity $logonname

                # Move the user to the former employees OU
                Move-ADObject -Identity $existingUser -TargetPath $ouPath -ErrorAction Stop
            } catch {
                Write-Host "Error offboarding user '$logonname': $_"
            }
        } 
    }
} else {
    Write-Host "CSV file not found at $csvPath."
}