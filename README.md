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
| **Management Portal** | http://127.0.0.1:52773/csp/sys/UtilHome.csp | `_SYSTEM` / `SYS` |
| **WebTerminal** | http://127.0.0.1:52773/terminal/ | `_SYSTEM` / `SYS` |
| **API REST Health** | http://127.0.0.1:52773/api/articles/health | - |
| **Pages Articles (CSP)** | http://127.0.0.1:52773/web/articles/Article.Web.ArticleList.cls | - |

> **Note :** Au premier accès, IRIS demandera de changer le mot de passe par défaut (`SYS`).

## API REST - Endpoints

### Authentification

L'API utilise **JWT (JSON Web Token)** avec l'algorithme HS256 pour protéger les opérations d'écriture.

- Les routes **GET** (consultation) sont **publiques** — pas besoin de token.
- Les routes **POST**, **PUT**, **DELETE** (création, modification, suppression) nécessitent un **token JWT valide**.

| Méthode | Endpoint | Description | Auth |
|---------|---------|-------------|------|
| `POST` | `/api/articles/auth/login` | Authentification (retourne un token JWT) | Non |
| `GET` | `/api/articles/auth/me` | Informations sur l'utilisateur connecté | Oui |

**Compte par défaut :**

| Utilisateur | Mot de passe | Rôle |
|-------------|-------------|------|
| `_SYSTEM` | `SYS` | `%All` |

> **Important :** L'authentification JWT utilise les utilisateurs IRIS natifs. Tout utilisateur IRIS valide peut se connecter. Changez le secret JWT (`Article.Auth.JWT:SECRET`) en production.

### Articles

| Méthode | Endpoint | Description | Auth |
|---------|---------|-------------|------|
| `GET` | `/api/articles/health` | Vérification de santé | Non |
| `GET` | `/api/articles/articles` | Lister les articles (paginé) | Non |
| `GET` | `/api/articles/articles/:id` | Récupérer un article | Non |
| `POST` | `/api/articles/articles` | Créer un article | **Oui** |
| `PUT` | `/api/articles/articles/:id` | Modifier un article | **Oui** |
| `DELETE` | `/api/articles/articles/:id` | Supprimer un article | **Oui** |
| `GET` | `/api/articles/articles/category/:cat` | Articles par catégorie | Non |
| `GET` | `/api/articles/articles/status/:status` | Articles par statut | Non |

#### Pagination

Les routes de listing supportent la pagination via paramètres query :

| Paramètre | Défaut | Description |
|-----------|--------|-------------|
| `page` | 1 | Numéro de page |
| `pageSize` | 20 | Nombre d'articles par page (max: 100) |

### Pages Web CSP

| URL | Description | Auth |
|-----|-------------|------|
| `/web/articles/Article.Web.ArticleList.cls` | Liste des articles | Non |
| `/web/articles/Article.Web.ArticleView.cls?id=1` | Détail d'un article | Non |
| `/web/articles/Article.Web.ArticleForm.cls` | Créer un article | **Oui** |
| `/web/articles/Article.Web.ArticleForm.cls?id=1` | Modifier un article | **Oui** |
| `/web/articles/Article.Web.Login.cls` | Page de connexion | Non |

### Exemples cURL

```bash
# Vérifier la santé du service
curl http://127.0.0.1:52773/api/articles/health

# Se connecter et obtenir un token JWT
curl -X POST http://127.0.0.1:52773/api/articles/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "_SYSTEM", "password": "SYS"}'
# Réponse : {"token":"eyJ...", "username":"_SYSTEM", "roles":"%All", "expiresIn":3600}

# Stocker le token dans une variable
TOKEN=$(curl -s -X POST http://127.0.0.1:52773/api/articles/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "_SYSTEM", "password": "SYS"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Créer un article (authentifié)
curl -X POST http://127.0.0.1:52773/api/articles/articles \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "title": "Mon premier article",
    "content": "Le contenu de mon article...",
    "author": "Lignes2Code",
    "category": "technique",
    "status": "published"
  }'

# Lister les articles (public, paginé)
curl "http://127.0.0.1:52773/api/articles/articles?page=1&pageSize=10"

# Récupérer un article par ID (public)
curl http://127.0.0.1:52773/api/articles/articles/1

# Modifier un article (authentifié)
curl -X PUT http://127.0.0.1:52773/api/articles/articles/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "title": "Mon article modifié",
    "content": "Nouveau contenu..."
  }'

# Supprimer un article (authentifié)
curl -X DELETE http://127.0.0.1:52773/api/articles/articles/1 \
  -H "Authorization: Bearer $TOKEN"

# Voir les infos de l'utilisateur connecté
curl http://127.0.0.1:52773/api/articles/auth/me \
  -H "Authorization: Bearer $TOKEN"
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

1. Aller sur http://127.0.0.1:52773/csp/sys/UtilHome.csp
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
            ├── Auth/
            │   └── JWT.cls               # Utilitaire JWT (HS256, validation)
            ├── Data/
            │   ├── Article.cls           # Classe persistante Article
            │   ├── ArticleImage.cls      # Classe sérialisable Image
            │   └── User.cls              # Classe persistante Utilisateur
            ├── Web/
            │   ├── Base.cls              # Classe CSP abstraite (CSS, header, footer, auth JS)
            │   ├── ArticleList.cls       # Page CSP : liste des articles
            │   ├── ArticleView.cls       # Page CSP : détail d'un article
            │   ├── ArticleForm.cls       # Page CSP : formulaire création/édition
            │   └── Login.cls             # Page CSP : formulaire de connexion
            ├── REST/
            │   └── Router.cls            # Routeur REST (JSON, auth JWT)
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

## Sécurité

### Authentification JWT

- Algorithme **HS256** (HMAC-SHA256) via `$System.Encryption.HMACSHA`
- Tokens avec claims `sub`, `iat`, `exp`, `roles`, `iss`
- Expiration par défaut : **1 heure** (configurable dans `Article.Auth.JWT:EXPIRATION`)
- Secret configurable dans `Article.Auth.JWT:SECRET`

### Mots de passe

- Hachage **SHA-256** itéré **10 000 fois** avec sel aléatoire de 32 octets
- Fonction `$System.Encryption.SHAHash(256, ...)` native IRIS

### Protection XSS

- En-têtes de sécurité HTTP (`X-Content-Type-Options`, `X-Frame-Options`, `X-XSS-Protection`, `Referrer-Policy`)
- Sanitisation HTML du contenu des articles (suppression des balises `<script>`, `<iframe>`, `<object>`, `<embed>`, et des attributs `on*`)

### Routes protégées

| Route | GET | POST | PUT | DELETE |
|-------|-----|------|-----|--------|
| `/api/articles/articles` | Public | **Auth** | — | — |
| `/api/articles/articles/:id` | Public | — | **Auth** | **Auth** |
| `/api/articles/auth/login` | — | Public | — | — |
| `/api/articles/auth/me` | **Auth** | — | — | — |

## Technologies

- **InterSystems IRIS Community Edition** (image `intersystems/iris-community:latest-cd`)
- **Docker Compose**
- **ObjectScript** (langage natif InterSystems IRIS)
- **JWT HS256** (authentification applicative)
- **WebTerminal** (terminal web open-source pour IRIS)
