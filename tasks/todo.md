# Task Plan — Authentification JWT + Corrections

## Phase 1 — Corrections de bugs

- [x] Fix bug images PUT : `Images.Clear()` avant réinsertion dans `ImportFromDynObj`
- [x] Fix thumbnail PUT : reset si null/vide, remplacement propre sinon
- [x] Fix erreur silencieuse batch : variable `articleSc` séparée, `$$$LOGERROR` pour les images
- [x] Fix `DateModified` : mis à jour automatiquement dans `ImportFromDynObj`

## Phase 2 — Refactoring et améliorations du Router

- [x] Factoriser la gestion d'erreurs (`ReportError` helper)
- [x] Factoriser `GetByCategory`/`GetByStatus` → `ExecuteArticleQuery`
- [x] Ajouter la pagination (`?page=&size=`)
- [x] Ajouter la validation des entrées (title, status)
- [x] Retourner l'objet complet après création

## Phase 3 — Sécurité XSS

- [x] Headers CSP dans les pages web (OnPreHTTP : X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy)
- [x] Sanitisation HTML server-side (SanitizeHtml, StripTag, StripEventHandlers dans Base.cls)
- [x] Protection ArticleView : contenu filtré via SanitizeHtml avant rendu

## Phase 4 — Authentification JWT

- [x] Créer `Article.Auth.JWT` (HMAC-SHA256, Base64URL, GenerateToken, ValidateToken, ExtractBearerToken)
- [x] Créer `Article.Data.User` (hash SHA-256 itéré 10000x + sel, CreateUser, VerifyCredentials)
- [x] Modifier `Router.cls` : `OnPreDispatch`, `IsPublicRoute`, routes auth, login
- [x] Route `POST /auth/login` → retourne JWT
- [x] Route `GET /auth/me` → infos utilisateur connecté
- [x] GET articles publics, POST/PUT/DELETE protégés par JWT

## Phase 5 — Interface Web CSP

- [x] Page de login (`Article.Web.Login`) avec appel AJAX JWT + localStorage
- [x] Header login/logout dans `Base.cls` avec `checkAuth()`, `doLogout()`, `getAuthHeaders()`
- [x] Bouton "Nouvel article" conditionné à l'auth dans le header
- [x] Bouton "Modifier" conditionné dans `ArticleList` (class `auth-only`)
- [x] Bouton "Modifier cet article" conditionné dans `ArticleView` (class `auth-only`)
- [x] Token JWT dans les appels `fetch()` du formulaire (PUT)
- [x] Vérification auth au chargement du formulaire → redirect login
- [x] Gestion 401 dans les réponses PUT → redirect login

## Phase 6 — Configuration

- [x] Créer admin par défaut dans `iris-init.script` (`admin` / `Admin123!` / rôle `admin`)
- [x] Authentification JWT dans `ProcessForm` (création via CSP)
- [x] Token JWT dans les appels `fetch()` du formulaire (création POST)
- [x] Gestion 401 dans les réponses POST création → redirect login
- [x] Mettre à jour README.md (auth, pagination, sécurité, structure, exemples cURL)

## Vérification

- [ ] Reconstruire le conteneur Docker (`docker compose up -d --build`)
- [ ] Vérifier la création de l'admin au démarrage (logs)
- [ ] Tester login : `POST /api/articles/auth/login` avec `admin` / `Admin123!`
- [ ] Tester route publique : `GET /api/articles/articles` sans token
- [ ] Tester route protégée : `POST /api/articles/articles` avec et sans token
- [ ] Tester UI : boutons masqués avant login, visibles après
- [ ] Tester formulaire : création et édition avec token

## Résumé des modifications

### Fichiers créés
- `src/cls/Article/Auth/JWT.cls` — Utilitaire JWT HS256
- `src/cls/Article/Data/User.cls` — Modèle utilisateur avec hash sécurisé
- `src/cls/Article/Web/Login.cls` — Page de connexion

### Fichiers modifiés
- `src/cls/Article/Data/Article.cls` — Fix bugs ImportFromDynObj (images, thumbnail, DateModified)
- `src/cls/Article/Operation/SaveArticle.cls` — Fix variable scoping batch
- `src/cls/Article/REST/Router.cls` — Refactoring complet + auth JWT
- `src/cls/Article/Web/Base.cls` — Headers sécurité + sanitisation XSS + nav auth
- `src/cls/Article/Web/ArticleList.cls` — Boutons conditionnés à l'auth
- `src/cls/Article/Web/ArticleView.cls` — Bouton conditionné + sanitisation contenu
- `src/cls/Article/Web/ArticleForm.cls` — Auth JWT dans fetch + check auth + 401
- `src/iris-init.script` — Création admin par défaut
- `README.md` — Documentation complète (auth, sécurité, pagination, structure)
- Technical debt introduced?
- Would a staff engineer approve this?