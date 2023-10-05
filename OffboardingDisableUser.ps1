# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file containing user information
$csvPath = "S:\Fileshare\HR\LeavingHires.csv"

# Kasm Workspaces API credentials
$apiKey = "7fUH9ZV9HvWv"
$apiSecret = "Zb7iiChJVyFWNSuQwYdcAGHypV2oCU7g"
$apiEndpoint = "https://172.16.1.21/api/public/update_user"  # Updated API endpoint URL for Kasm Workspaces

# Bypass SSL/TLS certificate checks (for debugging/testing purposes)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Specify the target OU for former employees
$ouPath = "OU=Former Employees,DC=CDB,DC=lan"

# Check if the CSV file exists
if (Test-Path $csvPath) {
    # Read the CSV file
    $userList = Import-Csv $csvPath

    # Loop through each user in the CSV
    foreach ($user in $userList) {
        $logonname = $user.Logonname  # Logonname from the CSV

        # Check if the user exists in Active Directory
        $existingUser = Get-ADUser -Filter { (SamAccountName -eq $logonname) } -ErrorAction SilentlyContinue

        if ($existingUser -ne $null) {
            try {
                # Disable the user account in Active Directory
                Disable-ADAccount -Identity $logonname

                # Move the disabled user to the "Former Employees" OU
                Move-ADObject -Identity $existingUser -TargetPath $ouPath

                Write-Host "User '$logonname' in Active Directory has been disabled and moved to '$ouPath'."
            } catch {
                Write-Host "Error disabling user '$logonname' in Active Directory: $_"
            }
        } else {
            Write-Host "User '$logonname' not found in Active Directory."
        }

        # Check if the KasmID is not empty
        if (![string]::IsNullOrWhiteSpace($user.KasmID)) {
            # Create the user data for updating in Kasm Workspaces
            $kasmUserParams = @{
                "api_key" = $apiKey
                "api_key_secret" = $apiSecret
                "target_user" = @{
                    "user_id" = $user.KasmID  # Include the KasmID
                    "username" = $logonname  # Use the Logonname as the username
                    "disabled" = $true       # Disable the user in Kasm Workspaces
                }
            }

            # Convert the user data to JSON format
            $kasmUserParamsJson = $kasmUserParams | ConvertTo-Json

            try {
                # Make the API request to update the user in Kasm Workspaces
                $kasmHeaders = @{
                    "Content-Type" = "application/json"
                }
                $kasmResponse = Invoke-RestMethod -Uri $apiEndpoint -Method Post -Headers $kasmHeaders -Body $kasmUserParamsJson

                # Check the Kasm Workspaces API response
                if ($kasmResponse.user -ne $null) {
                    Write-Host "Kasm Workspaces account for user '$logonname' (KasmID: $($user.KasmID)) has been disabled."
                } else {
                    # Print the API response for debugging purposes
                    Write-Host "Kasm Workspaces API Response: $kasmResponse"

                    # Handle the error when the user is not found in Kasm Workspaces
                    Write-Host "User '$logonname' not found in Kasm Workspaces."
                }
            } catch {
                Write-Host "Error disabling Kasm Workspaces account for user '$logonname' (KasmID: $($user.KasmID)): $_"
            }
        }
    }
} else {
    Write-Host "CSV file not found at $csvPath."
}