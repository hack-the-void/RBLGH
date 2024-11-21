# Emplacement des logs (UNC)
$logPath = "\\serveur\dossier\RB_Logs"

# Vérification du partage réseau
if (-not (Test-Path -Path $logPath)) {
    Write-Output "Le partage réseau n'est pas disponible ou inaccessible."
    exit
}

# Création du dossier de logs
if (-not (Test-Path -Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force
}
Write-Output "Création du dossier de logs : $logPath"

# 1. Exporter les journaux Windows
Write-Output "Exportation des journaux Windows."
wevtutil epl System "$logPath\System.evtx"
wevtutil epl Application "$logPath\Application.evtx"
wevtutil epl Security "$logPath\Security.evtx"

# 2. Informations réseau
Write-Output "Collecte des informations réseau."
cmd /c "ipconfig /all > `"$logPath\ipconfig.txt`""
cmd /c "netstat -anob > `"$logPath\netstat.txt`""

# Extraction des adresses IP locales depuis ipconfig
Write-Output "Extraction des adresses IP locales."
$ips = (Get-Content "$logPath\ipconfig.txt" | Where-Object { $_ -match "IPv4 Address" } | ForEach-Object {
    ($_ -split ":")[1].Trim()
})
$ips | Out-File "$logPath\local_ips.txt"
Write-Output "Adresses IP locales détectées : $($ips -join ', ')"

# 3. Ping toutes les IP sur le réseau local
Write-Output "Ping des IP sur le réseau local."
$ipBase = ($ips | Select-Object -First 1) -replace "\.\d+$", "" # Récupérer le préfixe réseau
$pingResults = @()
for ($i = 1; $i -le 254; $i++) {
    $ipToPing = "$ipBase.$i"
    Write-Output "Pinging $ipToPing..."
    if (Test-Connection -ComputerName $ipToPing -Count 1 -Quiet) {
        $pingResults += "$ipToPing is reachable."
    } else {
        $pingResults += "$ipToPing is not reachable."
    }
}
$pingResults | Out-File "$logPath\ping_results.txt"

# 4. Liste des processus et tâches planifiées
Write-Output "Récupération des processus actifs."
cmd /c "tasklist /v > `"$logPath\tasklist.txt`""
Write-Output "Récupération des connexions réseau des processus."
cmd /c "netstat -anob > `"$logPath\network_processes.txt`""

Write-Output "Récupération des tâches planifiées."
cmd /c "schtasks /query /fo LIST /v > `"$logPath\tasks_scheduled.txt`""

# 5. Programmes installés
Write-Output "Récupération des programmes installés."
cmd /c "wmic product get name,version > `"$logPath\programs.txt`""

# 6. Fichiers temporaires
Write-Output "Récupération des fichiers temporaires."
Get-ChildItem -Path "$env:temp" -Recurse | Out-File "$logPath\temp_files.txt"

# 7. Fichiers récents
Write-Output "Récupération des fichiers récents."
Get-ChildItem -Path C:\ -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-15) } |
    Select-Object FullName, LastWriteTime |
    Out-File "$logPath\recent_files.txt"

# 8. Fin
Write-Output "Terminé. Tous les fichiers sont dans : $logPath"
