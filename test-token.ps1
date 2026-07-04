$tok = [System.Environment]::GetEnvironmentVariable('ALPHADESK_GH_TOKEN', 'User')
$h = @{ Authorization = "token $tok"; Accept = "application/vnd.github.v3+json" }
$r = Invoke-WebRequest -Uri "https://api.github.com/user" -Headers $h -UseBasicParsing
Write-Host "Status: $($r.StatusCode)"
Write-Host "Scopes: $($r.Headers['X-OAuth-Scopes'])"
$u = $r.Content | ConvertFrom-Json
Write-Host "User: $($u.login)"
