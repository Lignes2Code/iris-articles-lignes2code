# IRIS Articles - Lignes2Code

Projet InterSystems IRIS pour le stockage et l'exposition d'articles via un service REST, avec import automatique via l'interopérabilité (dossier surveillé).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Container IRIS                                │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │  Dossier     │───>│  Business    │───>│  Business        │  │
│  │  Surveillé   │    │  Service     │    │  Operation       │  │
│  │  (*.json)    │    │  FileService │    │  SaveArticle     │  │
│  └──────────────┘    └──────────────┘    └────────┬─────────┘  │
│                                                    │            │
│                                          ┌─────────▼─────────┐ │
│  ┌──────────────┐                        │  Article.Data     │ │
│  │  API REST    │───────────────────────>│  .Article         │ │
│  │  /api/       │<───────────────────────│  (Persistant)     │ │
│  │  articles    │                        └────────┬──────────┘ │
│  └──────────────┘                                 │            │
│                                                   │            │
│  ┌──────────────┐                                 │            │
│  │  Pages CSP   │─────────────────────────────────┘            │
│  │  /web/       │  (Article.Web.Base, ArticleList,             │
│  │  articles    │   ArticleView — %CSP.Page)                   │
│  └──────────────┘                                              │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Portal (52773) │ WebTerminal │ REST API │ Pages CSP    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Prérequis

- Docker & Docker Compose
- ~2 Go d'espace disque

## Démarrage rapide

### 1. Construire et démarrer le conteneur

```bash
# Préparer les permissions du dossier durable %SYS
mkdir -p data/durable
chmod 777 data/durable

# Construire l'image et démarrer
docker compose up -d --build
```

### 2. Vérifier le démarrage

```bash
# Suivre les logs
docker compose logs -f iris

# Vérifier que le conteneur tourne
docker compose ps
```

### 3. Accéder aux outils

| Outil | URL | Identifiants |
|-------|-----|-------------|
| **Management Portal** | http://localhost:52773/csp/sys/UtilHome.csp | `_SYSTEM` / `SYS` |
| **WebTerminal** | http://localhost:52773/terminal/ | `_SYSTEM` / `SYS` |
| **API REST Health** | http://localhost:52773/api/articles/health | - |
| **Pages Articles (CSP)** | http://localhost:52773/web/articles/Article.Web.ArticleList.cls | - |

> **Note :** Au premier accès, IRIS demandera de changer le mot de passe par défaut (`SYS`).

## API REST - Endpoints

### Articles

| Méthode | Endpoint | Description |
|---------|---------|-------------|
| `GET` | `/api/articles/health` | Vérification de santé |
| `GET` | `/api/articles/articles` | Lister tous les articles |
| `GET` | `/api/articles/articles/:id` | Récupérer un article |
| `POST` | `/api/articles/articles` | Créer un article |
| `PUT` | `/api/articles/articles/:id` | Modifier un article |
| `DELETE` | `/api/articles/articles/:id` | Supprimer un article |
| `GET` | `/api/articles/articles/category/:cat` | Articles par catégorie |
| `GET` | `/api/articles/articles/status/:status` | Articles par statut |

### Pages Web CSP

| URL | Description |
|-----|-------------|
| `/web/articles/Article.Web.ArticleList.cls` | Liste de tous les articles (HTML) |
| `/web/articles/Article.Web.ArticleView.cls?id=1` | Détail d'un article (HTML) |

### Exemples cURL

```bash
# Vérifier la santé du service
curl http://localhost:52773/api/articles/health

# Créer un article
curl -X POST http://localhost:52773/api/articles/articles \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Mon premier article",
    "content": "Le contenu de mon article...",
    "author": "Lignes2Code",
    "category": "technique",
    "status": "published"
  }'

# Lister tous les articles
curl http://localhost:52773/api/articles/articles

# Récupérer un article par ID
curl http://localhost:52773/api/articles/articles/1

# Modifier un article
curl -X PUT http://localhost:52773/api/articles/articles/1 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Mon article modifié",
    "content": "Nouveau contenu..."
  }'

# Supprimer un article
curl -X DELETE http://localhost:52773/api/articles/articles/1
```

## Import d'articles via dossier surveillé (Interopérabilité)

La production d'interopérabilité surveille le dossier `data/input/` pour les fichiers `*.json`.

### Import d'un article unique

Copier un fichier JSON dans le dossier surveillé :

```bash
cp data/sample-article.json data/input/
```

Format attendu :

```json
{
    "title": "Titre de l'article",
    "content": "Contenu...",
    "author": "Auteur",
    "category": "catégorie",
    "status": "published"
}
```

### Import d'un lot d'articles

```bash
cp data/sample-articles-batch.json data/input/
```

Format (tableau JSON) :

```json
[
    { "title": "Article 1", "content": "...", "author": "..." },
    { "title": "Article 2", "content": "...", "author": "..." }
]
```

Les fichiers traités sont automatiquement archivés dans `data/output/`.

## Production d'interopérabilité

### Composants

| Composant | Classe | Rôle |
|-----------|--------|------|
| **Business Service** | `Article.Service.FileService` | Surveille `data/input/` pour les fichiers `*.json` (toutes les 5 secondes) |
| **Business Operation** | `Article.Operation.SaveArticle` | Parse le JSON et sauvegarde les articles en base |

### Supervision via le Management Portal

1. Aller sur http://localhost:52773/csp/sys/UtilHome.csp
2. Naviguer vers **Interoperability** > **Configurer** > **Production**
3. Sélectionner le namespace **USER**
4. La production `Article.Production.ArticleProduction` s'affiche

### Messages

- `Article.Message.ArticleRequest` : Contient le JSON brut et le nom du fichier source
- `Article.Message.ArticleResponse` : Contient l'ID de l'article créé et le statut

## Structure du projet

```
iris-articles-lignes2code/
├── docker-compose.yml          # Configuration Docker Compose
├── Dockerfile                  # Image IRIS personnalisée
├── config/
│   └── merge.cpf               # Fichier de configuration CPF merge
├── data/
│   ├── input/                  # Dossier surveillé (y déposer les JSON)
│   ├── output/                 # Fichiers traités (archivés)
│   ├── durable/                # Données persistantes IRIS (durable %SYS)
│   ├── sample-article.json     # Exemple : article unique
│   └── sample-articles-batch.json  # Exemple : lot d'articles
└── src/
    ├── iris-init.script        # Script d'initialisation IRIS
    └── cls/
        └── Article/
            ├── Data/
            │   └── Article.cls           # Classe persistante Article
            ├── Web/
            │   ├── Base.cls              # Classe CSP abstraite (CSS, header, footer)
            │   ├── ArticleList.cls       # Page CSP : liste des articles
            │   └── ArticleView.cls       # Page CSP : détail d'un article
            ├── REST/
            │   └── Router.cls            # Routeur REST (JSON uniquement)
            ├── Message/
            │   ├── ArticleRequest.cls     # Message de requête
            │   └── ArticleResponse.cls    # Message de réponse
            ├── Service/
            │   └── FileService.cls        # Business Service (surveillance fichiers)
            ├── Operation/
            │   └── SaveArticle.cls        # Business Operation (sauvegarde)
            └── Production/
                └── ArticleProduction.cls  # Définition de la production
```

## Ports exposés

| Port | Usage |
|------|-------|
| `52773` | Serveur web IRIS (Portal, WebTerminal, REST API) |
| `1972` | Superserveur IRIS (connexion depuis un IDE, JDBC, etc.) |

## Arrêt et nettoyage

```bash
# Arrêter le conteneur
docker compose down

# Arrêter et supprimer les volumes (reset complet)
docker compose down -v
rm -rf data/durable/*

# Reconstruire l'image après modification du code
docker compose up -d --build
```

## Technologies

- **InterSystems IRIS Community Edition** (image `intersystems/iris-community:latest-cd`)
- **Docker Compose**
- **ObjectScript** (langage natif InterSystems IRIS)
- **WebTerminal** (terminal web open-source pour IRIS)
