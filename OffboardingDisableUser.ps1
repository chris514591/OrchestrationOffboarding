# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file containing user information
$csvPath = "S:\Fileshare\HR\LeavingHires.csv"

# Kasm Workspaces API credentials
$apiKey = "7fUH9ZV9HvWv"
$apiSecret = "Zb7iiChJVyFWNSuQwYdcAGHypV2oCU7g"
$apiEndpoint = "https://172.16.1.21/api/public/delete_user"  # Updated API endpoint URL for deleting users in Kasm Workspaces

# Bypass SSL/TLS certificate checks (for debugging/testing purposes)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Check if the CSV file exists
if (Test-Path $csvPath) {
    # Read the CSV file
    $userList = Import-Csv $csvPath

    # Loop through each user in the CSV
    foreach ($user in $userList) {
        $logonname = $user.logonname  # Logonname from the CSV

        try {
            # Query the Kasm Workspaces API to find the user ID based on the username
            $kasmFindUserParams = @{
                "api_key" = $apiKey
                "api_key_secret" = $apiSecret
                "username" = $logonname
            }

            # Convert the find user data to JSON format
            $kasmFindUserParamsJson = $kasmFindUserParams | ConvertTo-Json

            # Make the API request to find the user in Kasm Workspaces
            $kasmHeaders = @{
                "Content-Type" = "application/json"
            }
            $kasmFindUserResponse = Invoke-RestMethod -Uri $apiEndpoint -Method Post -Headers $kasmHeaders -Body $kasmFindUserParamsJson

            if ($kasmFindUserResponse -ne $null -and $kasmFindUserResponse.user_id -ne $null) {
                # Get the user ID from the API response
                $userId = $kasmFindUserResponse.user_id

                # Delete the user account in Active Directory
                Remove-ADUser -Identity $logonname -Confirm:$false

                # Define the user data for deleting the user in Kasm Workspaces
                $kasmDeleteUserParams = @{
                    "api_key" = $apiKey
                    "api_key_secret" = $apiSecret
                    "target_user" = @{
                        "user_id" = $userId
                    }
                    "force" = $true  # Set to true to delete the user's sessions and delete the user
                }

                # Convert the user data to JSON format
                $kasmDeleteUserParamsJson = $kasmDeleteUserParams | ConvertTo-Json

                # Make the API request to delete the user in Kasm Workspaces
                $kasmDeleteUserResponse = Invoke-RestMethod -Uri $apiEndpoint -Method Post -Headers $kasmHeaders -Body $kasmDeleteUserParamsJson

                # Check for a successful response
                if ($kasmDeleteUserResponse -eq $null) {
                    Write-Host "User '$logonname' successfully offboarded in Active Directory and deleted in Kasm Workspaces."
                } else {
                    # Print the API response for debugging purposes
                    Write-Host "Kasm Workspaces API Response: $($kasmDeleteUserResponse | ConvertTo-Json -Depth 5)"

                    # Handle the error
                    Write-Host "Failed to offboard user '$logonname' in Kasm Workspaces."
                }
            } else {
                # Handle the case where the user was not found in Kasm Workspaces
                Write-Host "User '$logonname' not found in Kasm Workspaces."
            }
        } catch {
            Write-Host "Error offboarding user '$logonname': $_"
        }
    }
} else {
    Write-Host "CSV file not found at $csvPath."
}