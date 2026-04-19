param(
    [string]$AppKey = ""
)

Write-Host "============================"
Write-Host " GrokPi Admin Utility (.ps1)"
Write-Host "============================"

if ($AppKey -eq "") {
    $secureKey = Read-Host "Enter App Key (Admin Password)" -AsSecureString
    $AppKey = [System.Net.NetworkCredential]::new("", $secureKey).Password
}

$token = $AppKey
Write-Host "Login successful!" -ForegroundColor Green

while ($true) {
    Write-Host "`n--- Upstream Token Management ---"
    Write-Host "1. Add Upstream Grok Token(s)"
    Write-Host "2. List Upstream Tokens"
    Write-Host "3. Delete Upstream Token"
    Write-Host "`n--- Client API Key Management ---"
    Write-Host "4. Create a new Client API Key"
    Write-Host "5. List Client API Keys"
    Write-Host "6. Delete a Client API Key"
    Write-Host "`n7. Exit"
    $choice = Read-Host "Choice [1-7]"

    if ($choice -eq "1") {
        $upTokens = Read-Host "Enter tokens (comma separated for multiple)"
        $tokenArray = $upTokens -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        if ($tokenArray.Length -gt 0) {
            $addBody = @{ operation = "import"; tokens = $tokenArray } | ConvertTo-Json -Depth 5
            try {
                $null = Invoke-RestMethod -Uri "http://127.0.0.1:8080/admin/tokens/batch" -Method Post -Headers @{ "Authorization" = "Bearer $token" } -ContentType "application/json" -Body $addBody
                Write-Host "Tokens added successfully!" -ForegroundColor Green
            } catch {
                Write-Host "Failed to add tokens." -ForegroundColor Red
            }
        }
    }
    elseif ($choice -eq "2") {
        try {
            $listRes = Invoke-RestMethod -Uri "http://127.0.0.1:8080/admin/tokens?page_size=100" -Method Get -Headers @{ "Authorization" = "Bearer $token" }
            if ($listRes.data.Count -gt 0) {
                Write-Host "`n--- Upstream Token List ---" -ForegroundColor Cyan
                $listRes.data | Select-Object id, status, chat_quota, token | Format-Table
            } else {
                Write-Host "No upstream tokens found." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Failed to fetch upstream tokens." -ForegroundColor Red
        }
    }
    elseif ($choice -eq "3") {
        $delId = Read-Host "Enter the Token ID to delete (e.g. 1)"
        if ($delId -ne "") {
            try {
                $null = Invoke-RestMethod -Uri "http://127.0.0.1:8080/admin/tokens/$delId" -Method Delete -Headers @{ "Authorization" = "Bearer $token" }
                Write-Host "Successfully deleted Token ID: $delId" -ForegroundColor Green
            } catch {
                Write-Host "Failed to delete Token ID: $delId." -ForegroundColor Red
            }
        }
    }
    elseif ($choice -eq "4") {
        $keyName = Read-Host "Enter an alias/name for the new API Key"
        if ($keyName -eq "") { $keyName = "UnnamedKey" }
        $keyBody = @{ name = $keyName; limit_type = "unlimited" } | ConvertTo-Json -Depth 5
        try {
            $kRes = Invoke-RestMethod -Uri "http://127.0.0.1:8080/admin/apikeys" -Method Post -Headers @{ "Authorization" = "Bearer $token" } -ContentType "application/json" -Body $keyBody
            Write-Host "Successfully created API Key: $($kRes.key)" -ForegroundColor Green
        } catch {
            Write-Host "Failed to create API key." -ForegroundColor Red
        }
    }
    elseif ($choice -eq "5") {
        try {
            $listRes = Invoke-RestMethod -Uri "http://127.0.0.1:8080/admin/apikeys?page_size=100" -Method Get -Headers @{ "Authorization" = "Bearer $token" }
            if ($listRes.data.Count -gt 0) {
                Write-Host "`n--- Client API Key List ---" -ForegroundColor Cyan
                $listRes.data | Select-Object id, name, status, key | Format-Table
            } else {
                Write-Host "No client API keys found." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Failed to fetch client API keys." -ForegroundColor Red
        }
    }
    elseif ($choice -eq "6") {
        $delId = Read-Host "Enter the API Key ID to delete"
        if ($delId -ne "") {
            try {
                $null = Invoke-RestMethod -Uri "http://127.0.0.1:8080/admin/apikeys/$delId" -Method Delete -Headers @{ "Authorization" = "Bearer $token" }
                Write-Host "Successfully deleted API Key ID: $delId" -ForegroundColor Green
            } catch {
                Write-Host "Failed to delete API Key ID: $delId." -ForegroundColor Red
            }
        }
    }
    elseif ($choice -eq "7") {
        break
    }
}
