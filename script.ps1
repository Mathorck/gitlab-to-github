# Charger le fichier .env pour récupérer les variables d'environnement
$envFilePath = ".env"

# Charger les variables du fichier .env
if (Test-Path $envFilePath) {
    Get-Content $envFilePath | ForEach-Object {
        $key, $value = $_ -split '='
        [System.Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
    }
} else {
    Write-Host "Le fichier .env est introuvable. Veuillez vérifier le chemin."
    exit
}

# Récupérer les variables d'environnement
$githubUsername = [System.Environment]::GetEnvironmentVariable("GITHUB_USERNAME")
$githubToken = [System.Environment]::GetEnvironmentVariable("GITHUB_TOKEN")
$githubApiUrl = "https://api.github.com/repos/$githubUsername"  # API GitHub pour vérifier les dépôts
$repositoriesFile = "repositories.txt"  # Fichier texte contenant les URLs des dépôts GitLab

# Lire chaque ligne du fichier contenant les URLs des dépôts GitLab
$gitlabRepos = Get-Content -Path $repositoriesFile

foreach ($gitlabRepoUrl in $gitlabRepos) {
    # Extraire le nom du dépôt à partir de l'URL GitLab
    $repoName = $gitlabRepoUrl.Split('/')[-1].Replace(".git", "")
    $githubRepoUrl = "https://github.com/$githubUsername/$repoName.git"
    $githubRepoApiUrl = "$githubApiUrl/$repoName"

    Write-Host "Traitement du dépôt : $repoName"

    # Cloner le dépôt GitLab en mode miroir
    git clone --mirror $gitlabRepoUrl

    # Vérifier si le répertoire cloné existe
    if (Test-Path $repoName) {
        # Aller dans le répertoire cloné
        Set-Location -Path $repoName
    } else {
        Write-Host "Le répertoire cloné n'a pas été trouvé : $repoName"
        continue
    }

    # Vérifier si le dépôt existe déjà sur GitHub via l'API
    $response = Invoke-RestMethod -Uri $githubRepoApiUrl -Method Get -Headers @{
        Authorization = "token $githubToken"
    } -ErrorAction SilentlyContinue

    if ($response) {
        Write-Host "Le dépôt existe déjà sur GitHub. Mise à jour des changements..."
        # Si le dépôt existe, on va simplement commiter les derniers changements
        git add -A
        git commit -m "Mise à jour du dépôt avec les derniers changements"
        git push origin main  # Remplacer 'main' par la branche principale si nécessaire
    } else {
        Write-Host "Le dépôt n'existe pas encore sur GitHub. Création du dépôt..."
        # Si le dépôt n'existe pas, créer un nouveau dépôt GitHub via l'API
        $body = @{
            name = $repoName
            private = $false  # Choisis 'true' si tu veux un dépôt privé
        } | ConvertTo-Json

        Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers @{
            Authorization = "token $githubToken"
            "Content-Type" = "application/json"
        } -Body $body

        # Ajouter le remote GitHub et pousser les données
        git remote add github $githubRepoUrl
        git push --mirror github
    }

    # Retourner au répertoire parent
    Set-Location -Path ..

    # Supprimer le répertoire cloné localement (optionnel)
    if (Test-Path $repoName) {
        Remove-Item -Recurse -Force $repoName
    }
}

Write-Host "Tous les dépôts ont été traités."
