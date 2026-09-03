param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$HookName
)

$ErrorActionPreference = "Stop"

try {
    [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
    $payloadText = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($payloadText)) {
        throw "The hook payload is empty."
    }

    $payload = $payloadText | ConvertFrom-Json
    $record = [ordered]@{
        loggedAt = [DateTimeOffset]::Now.ToString("o")
        hook = $HookName
        payload = $payload
    }
    $jsonLine = $record | ConvertTo-Json -Depth 100 -Compress

    $logsDirectory = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($PSScriptRoot, "..", "logs")
    )
    [System.IO.Directory]::CreateDirectory($logsDirectory) | Out-Null

    $logFile = [System.IO.Path]::Combine($logsDirectory, "copilot-hooks.jsonl")
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllText(
        $logFile,
        $jsonLine + [Environment]::NewLine,
        $utf8WithoutBom
    )
}
catch {
    [Console]::Error.WriteLine(
        "Failed to log Copilot hook '{0}': {1}" -f $HookName, $_.Exception.Message
    )
    exit 1
}
