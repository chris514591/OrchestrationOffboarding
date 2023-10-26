# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file containing user information
$csvPath = "S:\Fileshare\HR\LeavingHires.csv"

# Define the path to the config file
$configPath = "C:\offboardingconfig.json"

# Check if the config file exists
if (Test-Path $configPath) {
    $configData = Get-Content $configPath | ConvertFrom-Json
    $apiKey = $configData.apiKey
    $apiSecret = $configData.apiSecret
} else {
    Write-Host "Config file not found at $configPath. Make sure the file exists and contains the API Key and Secret."
    exit
}

# Define the Kasm Workspaces API endpoint URL
$apiEndpoint = "https://172.16.1.21/api/public"  # Replace with the correct API endpoint URL

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
        if (![string]::IsNullOrWhiteSpace($logonname)) {
            try {
                # Get the user information from Kasm Workspaces using the username
                $kasmUserParams = @{
                    "api_key" = $apiKey
                    "api_key_secret" = $apiSecret
                    "target_user" = @{
                        "username" = $logonname  # Use the Logonname as the username
                    }
                }

                # Convert the user data to JSON format
                $kasmUserParamsJson = $kasmUserParams | ConvertTo-Json

                $getUserResponse = Invoke-RestMethod -Uri "$apiEndpoint/get_user" -Method Post -Headers @{ "Content-Type" = "application/json" } -Body $kasmUserParamsJson

                if ($getUserResponse.user -ne $null) {
                    # Retrieve the KasmID from the Kasm Workspaces response
                    $kasmID = $getUserResponse.user.user_id

                    # Create the user data for updating in Kasm Workspaces
                    $kasmUserUpdateParams = @{
                        "api_key" = $apiKey
                        "api_key_secret" = $apiSecret
                        "target_user" = @{
                            "user_id" = $kasmID
                            "username" = $logonname  # Use the Logonname as the username
                            "disabled" = $true       # Disable the user in Kasm Workspaces
                        }
                    }

                    # Convert the user update data to JSON format
                    $kasmUserUpdateParamsJson = $kasmUserUpdateParams | ConvertTo-Json

                    # Make the API request to update the user in Kasm Workspaces
                    $kasmUpdateResponse = Invoke-RestMethod -Uri "$apiEndpoint/update_user" -Method Post -Headers @{ "Content-Type" = "application/json" } -Body $kasmUserUpdateParamsJson

                    # Check the Kasm Workspaces API response
                    if ($kasmUpdateResponse.user -ne $null) {
                        Write-Host "Kasm Workspaces account for user '$logonname' (KasmID: $kasmID) has been disabled."
                    } else {
                        # Print the API response for debugging purposes
                        Write-Host "Kasm Workspaces API Response: $kasmUpdateResponse"

                        # Handle the error when the user is not found in Kasm Workspaces
                        Write-Host "User '$logonname' not found in Kasm Workspaces."
                    }
                } else {
                    Write-Host "User '$logonname' not found in Kasm Workspaces."
                }
            } catch {
                Write-Host "Error retrieving or disabling Kasm Workspaces account for user '$logonname': $_"
            }
        }
    }
} else {
    Write-Host "CSV file not found at $csvPath."
}
