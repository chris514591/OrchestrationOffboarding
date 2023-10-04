# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file containing user information
$csvPath = "S:\Fileshare\HR\LeavingHires.csv"

# Define the target OU where you want to move former employees
$ouPath = "OU=Former Employees,DC=CDB,DC=lan"

# Kasm Workspaces API credentials
$apiKey = "7fUH9ZV9HvWv"
$apiSecret = "Zb7iiChJVyFWNSuQwYdcAGHypV2oCU7g"
$apiEndpoint = "https://172.16.1.21/api/public/update_user"  # Updated API endpoint URL for updating users

# Bypass SSL/TLS certificate checks (for debugging/testing purposes)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

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
                # Disable the user account in Active Directory
                Disable-ADAccount -Identity $logonname

                # Move the user to the former employees OU
                Move-ADObject -Identity $existingUser -TargetPath $ouPath -ErrorAction Stop

                # Disable the user in Kasm Workspaces
                $kasmDisableUserParams = @{
                    "api_key" = $apiKey
                    "api_key_secret" = $apiSecret
                    "target_user" = @{
                        "username" = $logonname
                        "disabled" = $true
                    }
                }

                # Convert the user data to JSON format
                $kasmDisableUserParamsJson = $kasmDisableUserParams | ConvertTo-Json

                # Make the API request to disable the user in Kasm Workspaces
                $kasmHeaders = @{
                    "Content-Type" = "application/json"
                }
                $kasmResponse = Invoke-RestMethod -Uri $apiEndpoint -Method Post -Headers $kasmHeaders -Body $kasmDisableUserParamsJson

                # Check the Kasm Workspaces API response
                if ($kasmResponse.user.disabled -eq $true) {
                    Write-Host "User '$logonname' successfully offboarded in Active Directory and Kasm Workspaces."
                } else {
                    # Print the API response for debugging purposes
                    Write-Host "Kasm Workspaces API Response: $($kasmResponse.message)"

                    # Handle the error
                    Write-Host "Failed to offboard user '$logonname' in Kasm Workspaces."
                }
            } catch {
                Write-Host "Error offboarding user '$logonname': $_"
            }
        }
    }
} else {
    Write-Host "CSV file not found at $csvPath."
}
