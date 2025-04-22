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
    $githubRepoUrl = "https://${githubUsername}:$githubToken@github.com/$githubUsername/$repoName.git"
    $githubRepoApiUrl = "$githubApiUrl/$repoName"

    Write-Host "Traitement du depot : $repoName"

    # Vérifier si le répertoire existe déjà
    if (Test-Path $repoName) {
        Write-Host "Le repertoire existe deja. Suppression du repertoire precedent."
        Remove-Item -Recurse -Force $repoName
    }

    # Cloner le dépôt GitLab en mode standard (sans --mirror)
    git clone $gitlabRepoUrl

    # Vérifier si le répertoire cloné existe
    if (Test-Path $repoName) {
        # Aller dans le répertoire cloné
        Set-Location -Path $repoName
    } else {
        Write-Host "Le répertoire clone n'a pas ete trouve : $repoName"
        continue
    }

    # Vérifier si le dépôt existe déjà sur GitHub via l'API
    $response = Invoke-RestMethod -Uri $githubRepoApiUrl -Method Get -Headers @{
        Authorization = "token $githubToken"
    } -ErrorAction SilentlyContinue

    if ($response) {
        Write-Host "Le depot existe deja sur GitHub. Mise a jour des changements..."

        # Forcer un ajout et un commit pour s'assurer que tout est bien pris en compte
        git add -A
        git commit -m "Mise a jour du depot avec les derniers changements" --allow-empty  # Utiliser --allow-empty pour forcer un commit même sans modifications locales
        
        # Ajouter le remote GitHub et pousser les données **vers GitHub uniquement**
        git remote remove origin  # Retirer le remote GitLab
        git remote add origin $githubRepoUrl  # Ajouter le remote GitHub
        git push origin main --force  # Remplacer 'main' par 'master' ou la branche principale de ton dépôt
    } else {
        Write-Host "Le depot n'existe pas encore sur GitHub. Creation du depot..."
        # Si le dépôt n'existe pas, créer un nouveau dépôt GitHub via l'API
        $body = @{
            name = $repoName
            private = $false  # Choisis 'true' si tu veux un dépôt privé
        } | ConvertTo-Json

        Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers @{
            Authorization = "token $githubToken"
            "Content-Type" = "application/json"
        } -Body $body

        # Ajouter le remote GitHub et pousser les données **vers GitHub uniquement**
        git remote add origin $githubRepoUrl

        # Forcer l'initialisation de la branche principale
        git branch -M main  # Assurer que la branche 'main' est utilisée
        git push --set-upstream origin main --force  # Pousser vers GitHub
    }

    # Retourner au répertoire parent
    Set-Location -Path ..

    # Supprimer le répertoire cloné localement (optionnel)
    if (Test-Path $repoName) {
        Remove-Item -Recurse -Force $repoName
    }
}

Write-Host "Tous les depots ont ete traites."
