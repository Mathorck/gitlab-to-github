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
$githubApiUrl = "https://api.github.com/user/repos"  # URL correcte pour la création de dépôts via l'API GitHub
$repositoriesFile = "repositories.txt"  # Fichier texte contenant les URLs des dépôts GitLab

# Lire chaque ligne du fichier contenant les URLs des dépôts GitLab
$gitlabRepos = Get-Content -Path $repositoriesFile

foreach ($gitlabRepoUrl in $gitlabRepos) {
    # Extraire le nom du dépôt à partir de l'URL GitLab
    $repoName = $gitlabRepoUrl.Split('/')[-1].Replace(".git", "")
    $githubRepoUrl = "https://${githubUsername}:$githubToken@github.com/$githubUsername/$repoName.git"
    
    Write-Host "====== Traitement du depot : $repoName ======" -ForegroundColor Green
    Write-Host "=== Gitlab ===" -ForegroundColor Green
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
        Write-Host "Le repertoire clone n'a pas ete trouve : $repoName"
        continue
    }

    Write-Host "=== Github ===" -ForegroundColor Green

    # Vérifier si le dépôt existe déjà sur GitHub via l'API
    $githubRepoApiUrl = "https://api.github.com/repos/$githubUsername/$repoName"
    
    try {
        $response = Invoke-RestMethod -Uri $githubRepoApiUrl -Method Get -Headers @{
            Authorization = "token $githubToken"
        }

        # Si le dépôt existe déjà, on met à jour les changements
        Write-Host "Le depot existe deja sur GitHub. Mise a jour des changements..."

        # Forcer un ajout et un commit pour s'assurer que tout est bien pris en compte
        git add -A
        git commit -m "Mise a jour du depot avec les derniers changements" --allow-empty  # Utiliser --allow-empty pour forcer un commit même sans modifications locales
        
        # Vérifier si le remote 'origin' existe déjà et le supprimer
        $remotes = git remote -v
        if ($remotes -match "origin") {
            Write-Host "Le remote 'origin' existe déjà. Suppression du remote 'origin'."
            git remote remove origin
        }

        # Ajouter le remote GitHub et pousser les données **vers GitHub uniquement**
        git remote add origin $githubRepoUrl
        git push origin main --force  # Remplacer 'main' par 'master' ou la branche principale de ton dépôt
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Host "Le depot n'existe pas encore sur GitHub. Creation du depot..."

            # Créer le dépôt GitHub via l'API
            $body = @{
                name = $repoName
                private = $false  # Choisis 'true' si tu veux un dépôt privé
            } | ConvertTo-Json

            try {
                $createRepoResponse = Invoke-RestMethod -Uri $githubApiUrl -Method Post -Headers @{
                    Authorization = "token $githubToken"
                    "Content-Type" = "application/json"
                } -Body $body
                Write-Host "Depot cree avec succes sur GitHub."

                # Ajouter le remote GitHub et pousser les données **vers GitHub uniquement**
                git remote add origin $githubRepoUrl

                # Forcer l'initialisation de la branche principale
                git branch -M main  # Assurer que la branche 'main' est utilisée
                git push --set-upstream origin main --force  # Pousser vers GitHub
            } catch {
                Write-Host "Erreur lors de la création du dépôt sur GitHub. Assurez-vous que votre token a les permissions nécessaires." -ForegroundColor Red
                continue
            }
        } else {
            Write-Host "Erreur inattendue : $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
    }

    # Retourner au répertoire parent
    Set-Location -Path ..

    # Supprimer le répertoire cloné localement (optionnel)
    if (Test-Path $repoName) {
        Remove-Item -Recurse -Force $repoName
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Tous les depots ont ete traites." -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
