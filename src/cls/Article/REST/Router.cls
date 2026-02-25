/// Service REST pour exposer les articles
/// Dispatch class pour router les requêtes HTTP
Class Article.REST.Router Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "utf-8";

Parameter HandleCorsRequest = 1;

/// Taille de page par défaut pour la pagination
Parameter DEFAULTPAGESIZE = 20;

/// Taille de page maximale autorisée
Parameter MAXPAGESIZE = 100;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <!-- Auth endpoints (publics) -->
    <Route Url="/auth/login" Method="POST" Call="Login" />
    <Route Url="/auth/me" Method="GET" Call="GetCurrentUser" />
    
    <!-- Endpoint de santé -->
    <Route Url="/health" Method="GET" Call="HealthCheck" />
    
    <!-- Endpoint de détection des changements (polling) -->
    <Route Url="/articles/changes" Method="GET" Call="GetChanges" />
    
    <!-- Recherche d'articles par catégorie (AVANT :id pour éviter conflit) -->
    <Route Url="/articles/category/:category" Method="GET" Call="GetByCategory" />
    
    <!-- Recherche d'articles par statut (AVANT :id pour éviter conflit) -->
    <Route Url="/articles/status/:status" Method="GET" Call="GetByStatus" />
    
    <!-- Liste tous les articles -->
    <Route Url="/articles" Method="GET" Call="GetAllArticles" />
    
    <!-- Crée un nouvel article (protégé JWT) -->
    <Route Url="/articles" Method="POST" Call="CreateArticle" />
    
    <!-- Récupère un article par ID -->
    <Route Url="/articles/:id" Method="GET" Call="GetArticle" />
    
    <!-- Met à jour un article existant (protégé JWT) -->
    <Route Url="/articles/:id" Method="PUT" Call="UpdateArticle" />
    
    <!-- Supprime un article (protégé JWT) -->
    <Route Url="/articles/:id" Method="DELETE" Call="DeleteArticle" />
</Routes>
}

// =============================================================================
// AUTHENTIFICATION JWT — Contrôle d'accès
// =============================================================================

/// Intercepte TOUTES les requêtes avant le dispatch vers les routes
/// Vérifie le token JWT pour les routes protégées (POST, PUT, DELETE)
/// Les routes publiques (GET, OPTIONS, /auth/*, /health) passent sans token
ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    Set pContinue = 1
    
    // Headers CORS (inclure Authorization)
    Do ..SetResponseHeaderIfEmpty("Access-Control-Allow-Origin", "*")
    Do ..SetResponseHeaderIfEmpty("Access-Control-Allow-Headers", "Authorization, Content-Type, Accept")
    Do ..SetResponseHeaderIfEmpty("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    
    // Toujours extraire le token si présent (même sur routes publiques)
    Set token = ##class(Article.Auth.JWT).ExtractBearerToken(%request)
    If token '= "" {
        Set payload = ##class(Article.Auth.JWT).ValidateToken(token, .sc)
        If $IsObject(payload) {
            Do %request.Set("jwtUser", payload.sub)
            Do %request.Set("jwtRoles", payload.roles)
        }
    }
    
    // Routes publiques : pas besoin de JWT, on continue
    If ..IsPublicRoute(pUrl, pMethod) {
        Return $$$OK
    }
    
    // Routes protégées : vérifier qu'on a un utilisateur authentifié
    If %request.Get("jwtUser") = "" {
        Set pContinue = 0
        If token = "" {
            Return ..ReportError(401, "Token d'authentification requis", "AUTH_REQUIRED")
        }
        // Token présent mais invalide
        Set errorMsg = $System.Status.GetErrorText(sc)
        Return ..ReportError(401, errorMsg, "AUTH_INVALID")
    }
    
    Return $$$OK
}

/// Détermine si une route est publique (accessible sans JWT)
/// Publics : GET articles, OPTIONS (CORS preflight), /auth/*, /health
ClassMethod IsPublicRoute(pUrl As %String, pMethod As %String) As %Boolean
{
    // Preflight CORS toujours public
    If pMethod = "OPTIONS" Return 1
    
    // Auth endpoints : seul /auth/login est public
    If pUrl = "/auth/login" Return 1
    
    // Health check public
    If pUrl = "/health" Return 1
    
    // Tous les GET sont publics (consultation sans auth)
    If pMethod = "GET" Return 1
    
    // POST, PUT, DELETE → protégé
    Return 0
}

/// Helper pour setter un header de réponse s'il n'est pas déjà défini
ClassMethod SetResponseHeaderIfEmpty(pHeader As %String, pValue As %String)
{
    If %response.GetHeader(pHeader) = "" {
        Do %response.SetHeader(pHeader, pValue)
    }
}

// =============================================================================
// ENDPOINTS AUTH — Login et profil
// =============================================================================

/// POST /auth/login — Authentification, retourne un JWT
/// Body : {"username": "...", "password": "..."}
/// Réponse : {"token": "...", "username": "...", "roles": "...", "expiresIn": 3600}
ClassMethod Login() As %Status
{
    Try {
        Set body = %request.Content
        If '$IsObject(body) {
            Return ..ReportError(400, "Corps de la requête invalide", "INVALID_BODY")
        }
        
        Set json = {}.%FromJSON(body)
        Set username = json.username
        Set password = json.password
        
        If (username = "") || (password = "") {
            Return ..ReportError(400, "Username et password requis", "MISSING_CREDENTIALS")
        }
        
        // Authentifier via IRIS Security (utilisateurs système)
        Set loginSc = $SYSTEM.Security.Login(username, password)
        If $$$ISERR(loginSc) {
            Return ..ReportError(401, "Identifiants invalides", "INVALID_CREDENTIALS")
        }
        
        // Tout utilisateur IRIS authentifié est considéré admin pour l'application
        Set roles = "admin"
        
        // Générer le token JWT
        Set token = ##class(Article.Auth.JWT).GenerateToken(username, roles)
        
        Set response = {}
        Set response.token = token
        Set response.username = username
        Set response.roles = roles
        Set response.expiresIn = ##class(Article.Auth.JWT).#EXPIRATION
        Write response.%ToJSON()
    }
    Catch ex {
        Return ..ReportError(500, "Erreur interne", "INTERNAL_ERROR")
    }
    Return $$$OK
}

/// GET /auth/me — Retourne les informations de l'utilisateur connecté
/// Nécessite un token JWT valide (protégé par OnPreDispatch)
ClassMethod GetCurrentUser() As %Status
{
    Try {
        Set username = %request.Get("jwtUser")
        If username = "" {
            Return ..ReportError(401, "Non authentifié", "AUTH_REQUIRED")
        }
        
        Set response = {}
        Set response.username = username
        Set response.roles = %request.Get("jwtRoles")
        Write response.%ToJSON()
    }
    Catch ex {
        Return ..ReportError(500, "Erreur interne", "INTERNAL_ERROR")
    }
    Return $$$OK
}

// =============================================================================
// HELPERS — Gestion d'erreurs et utilitaires factorisés
// =============================================================================

/// Helper centralisé pour renvoyer une erreur JSON
/// Évite la duplication du pattern ReportHttpStatusCode + Write error.%ToJSON()
ClassMethod ReportError(pHttpCode As %Integer, pMessage As %String, pCode As %String = "") As %Status
{
    Do ..ReportHttpStatusCode(pHttpCode)
    Set error = {}
    Set error.error = pMessage
    If pCode '= "" Set error.code = pCode
    Write error.%ToJSON()
    Return $$$OK
}

/// Helper pour écrire une réponse JSON de succès avec un code HTTP
ClassMethod ReportSuccess(pHttpCode As %Integer, pData As %DynamicObject) As %Status
{
    If pHttpCode '= 200 Do ..ReportHttpStatusCode(pHttpCode)
    Write pData.%ToJSON()
    Return $$$OK
}

/// Extrait et valide les paramètres de pagination depuis la requête
/// Retourne page (1-based) et size avec des valeurs sûres
ClassMethod GetPaginationParams(Output pPage As %Integer, Output pSize As %Integer)
{
    Set pPage = +%request.Get("page", 1)
    Set pSize = +%request.Get("size", ..#DEFAULTPAGESIZE)
    
    // Garde-fous
    If pPage < 1 Set pPage = 1
    If pSize < 1 Set pSize = ..#DEFAULTPAGESIZE
    If pSize > ..#MAXPAGESIZE Set pSize = ..#MAXPAGESIZE
}

/// Exécute une requête paginée avec filtre optionnel et retourne la réponse JSON
/// pWhereField/pWhereValue : champ et valeur pour la clause WHERE (optionnels)
/// Factorise GetAllArticles, GetByCategory, GetByStatus
ClassMethod ExecuteArticleQuery(pWhereField As %String = "", pWhereValue As %String = "") As %Status
{
    Set sc = $$$OK
    Try {
        Do ..GetPaginationParams(.page, .size)
        
        // Construire le SQL avec ou sans filtre
        Set baseSql = "FROM Article_Data.Article"
        If pWhereField '= "" {
            Set baseSql = baseSql _ " WHERE " _ pWhereField _ " = ?"
        }
        
        // Compter le total
        Set countSql = "SELECT COUNT(*) As total " _ baseSql
        Set stmt = ##class(%SQL.Statement).%New()
        Set sc = stmt.%Prepare(countSql)
        If $$$ISERR(sc) Return ..ReportError(500, "Erreur de préparation SQL", "SQL_ERROR")
        
        If pWhereField '= "" {
            Set rs = stmt.%Execute(pWhereValue)
        } Else {
            Set rs = stmt.%Execute()
        }
        Do rs.%Next()
        Set total = rs.%Get("total")
        
        // Calculer la pagination
        Set totalPages = $Select(total = 0: 0, 1: ((total - 1) \ size) + 1)
        Set offset = (page - 1) * size
        
        // Requête paginée
        Set dataSql = "SELECT ID " _ baseSql _ " ORDER BY DateCreated DESC"
        // IRIS SQL : %STARTSWITH n'aide pas ici, utiliser TOP + offset manuellement
        // En IRIS SQL, pas de LIMIT/OFFSET standard → on utilise %SQLRESTRICT ou on itère
        Set stmt2 = ##class(%SQL.Statement).%New()
        Set sc = stmt2.%Prepare(dataSql)
        If $$$ISERR(sc) Return ..ReportError(500, "Erreur de préparation SQL", "SQL_ERROR")
        
        If pWhereField '= "" {
            Set rs2 = stmt2.%Execute(pWhereValue)
        } Else {
            Set rs2 = stmt2.%Execute()
        }
        
        Set articles = []
        Set rowNum = 0
        Set collected = 0
        
        While rs2.%Next() {
            Set rowNum = rowNum + 1
            // Sauter les lignes avant l'offset
            If rowNum <= offset Continue
            // Arrêter après avoir collecté 'size' articles
            If collected >= size Quit
            
            Set articleObj = ##class(Article.Data.Article).%OpenId(rs2.%Get("ID"))
            If $IsObject(articleObj) {
                Set exportSc = articleObj.%JSONExportToString(.jsonStr, "ListReference")
                If $$$ISOK(exportSc) {
                    Do articles.%Push({}.%FromJSON(jsonStr))
                    Set collected = collected + 1
                }
            }
        }
        
        // Construire la réponse paginée
        Set response = {}
        Set response.articles = articles
        Set response.total = total
        Set response.page = page
        Set response.size = size
        Set response.totalPages = totalPages
        Set response.count = articles.%Size()
        
        // Ajouter le champ de filtre s'il y en a un
        If pWhereField '= "" {
            Set filterKey = $ZConvert(pWhereField, "L")
            Do response.%Set(filterKey, pWhereValue)
        }
        
        Write response.%ToJSON()
    }
    Catch ex {
        Return ..ReportError(500, ex.DisplayString(), "INTERNAL_ERROR")
    }
    Return sc
}

/// Valide les champs d'un article avant création/mise à jour
/// Retourne $$$OK ou une erreur avec le message approprié
ClassMethod ValidateArticleInput(pJson As %DynamicObject, pIsCreate As %Boolean = 1) As %Status
{
    // Titre obligatoire à la création
    If pIsCreate {
        Set title = pJson.%Get("title")
        If (title = "") || ('pJson.%IsDefined("title")) {
            Return $$$ERROR($$$GeneralError, "Le titre est obligatoire")
        }
    }
    
    // Si title est fourni (création ou mise à jour), il ne doit pas être vide
    If pJson.%IsDefined("title") {
        Set title = pJson.%Get("title")
        If $ZStrip(title, "<>W") = "" {
            Return $$$ERROR($$$GeneralError, "Le titre ne peut pas être vide")
        }
    }
    
    // Valider le statut si fourni
    If pJson.%IsDefined("status") {
        Set status = pJson.%Get("status")
        If status '= "" {
            If ",draft,published,archived," '[ (","_status_",") {
                Return $$$ERROR($$$GeneralError, "Statut invalide. Valeurs autorisées : draft, published, archived")
            }
        }
    }
    
    Return $$$OK
}

/// Exporte un article complet en stream JSON (supporte les gros contenus base64)
ClassMethod WriteArticleAsStream(pArticle As Article.Data.Article) As %Status
{
    Set stream = ##class(%Stream.TmpCharacter).%New()
    Set sc = pArticle.%JSONExportToStream(.stream, "BasicReference")
    If $$$ISERR(sc) Return sc
    
    Do stream.Rewind()
    While 'stream.AtEnd {
        Write stream.Read(32000)
    }
    Return $$$OK
}

// =============================================================================
// ENDPOINTS — Routes REST
// =============================================================================

/// GET /articles - Retourne tous les articles (paginé)
/// Query params : ?page=1&size=20
ClassMethod GetAllArticles() As %Status
{
    Return ..ExecuteArticleQuery()
}

/// GET /articles/:id - Retourne un article par ID
ClassMethod GetArticle(pId As %String) As %Status
{
    Try {
        If '##class(Article.Data.Article).%ExistsId(pId) {
            Return ..ReportError(404, "Article non trouvé", "NOT_FOUND")
        }
        
        Set article = ##class(Article.Data.Article).%OpenId(pId)
        Set sc = ..WriteArticleAsStream(article)
        If $$$ISERR(sc) Return ..ReportError(500, "Erreur d'export de l'article", "EXPORT_ERROR")
    }
    Catch ex {
        Return ..ReportError(500, ex.DisplayString(), "INTERNAL_ERROR")
    }
    Return $$$OK
}

/// POST /articles - Crée un nouvel article
/// Retourne l'article complet créé (avec son ID)
ClassMethod CreateArticle() As %Status
{
    Try {
        Set body = %request.Content
        If '$IsObject(body) {
            Return ..ReportError(400, "Corps de la requête invalide", "INVALID_BODY")
        }
        
        Set jsonObj = ##class(%DynamicObject).%FromJSON(body)
        
        // Validation des entrées
        Set sc = ..ValidateArticleInput(jsonObj, 1)
        If $$$ISERR(sc) {
            Return ..ReportError(400, $System.Status.GetErrorText(sc), "VALIDATION_ERROR")
        }
        
        Set article = ##class(Article.Data.Article).%New()
        Set sc = article.ImportFromDynObj(jsonObj)
        If $$$ISERR(sc) {
            Return ..ReportError(400, "Données JSON invalides : " _ $System.Status.GetErrorText(sc), "IMPORT_ERROR")
        }
        
        Set article.Source = "rest"
        Set article.DateCreated = $ZDateTime($Horolog, 3)
        Set article.DateModified = article.DateCreated
        
        Set sc = article.%Save()
        If $$$ISERR(sc) {
            Return ..ReportError(500, "Erreur lors de la sauvegarde", "SAVE_ERROR")
        }
        
        // Retourner l'article complet (bonne pratique REST)
        Do ..ReportHttpStatusCode(201)
        // Notifier les pages web d'un changement
        Set ^Article.LastChange = $ZDateTime($Horolog, 3, 1)
        Return ..WriteArticleAsStream(article)
    }
    Catch ex {
        Return ..ReportError(500, ex.DisplayString(), "INTERNAL_ERROR")
    }
    Return $$$OK
}

/// PUT /articles/:id - Met à jour un article
ClassMethod UpdateArticle(pId As %String) As %Status
{
    Try {
        If '##class(Article.Data.Article).%ExistsId(pId) {
            Return ..ReportError(404, "Article non trouvé", "NOT_FOUND")
        }
        
        Set body = %request.Content
        If '$IsObject(body) {
            Return ..ReportError(400, "Corps de la requête invalide", "INVALID_BODY")
        }
        
        Set jsonObj = ##class(%DynamicObject).%FromJSON(body)
        
        // Validation des entrées (mode update : title pas obligatoire)
        Set sc = ..ValidateArticleInput(jsonObj, 0)
        If $$$ISERR(sc) {
            Return ..ReportError(400, $System.Status.GetErrorText(sc), "VALIDATION_ERROR")
        }
        
        Set article = ##class(Article.Data.Article).%OpenId(pId)
        Set sc = article.ImportFromDynObj(jsonObj)
        If $$$ISERR(sc) {
            Return ..ReportError(400, "Données JSON invalides : " _ $System.Status.GetErrorText(sc), "IMPORT_ERROR")
        }
        
        Set sc = article.%Save()
        If $$$ISERR(sc) {
            Return ..ReportError(500, "Erreur lors de la mise à jour", "SAVE_ERROR")
        }
        
        // Notifier les pages web d'un changement
        Set ^Article.LastChange = $ZDateTime($Horolog, 3, 1)
        
        Set response = {}
        Set response.id = +pId
        Set response.message = "Article mis à jour avec succès"
        Write response.%ToJSON()
    }
    Catch ex {
        Return ..ReportError(500, ex.DisplayString(), "INTERNAL_ERROR")
    }
    Return $$$OK
}

/// DELETE /articles/:id - Supprime un article
ClassMethod DeleteArticle(pId As %String) As %Status
{
    Try {
        If '##class(Article.Data.Article).%ExistsId(pId) {
            Return ..ReportError(404, "Article non trouvé", "NOT_FOUND")
        }
        
        Set sc = ##class(Article.Data.Article).%DeleteId(pId)
        If $$$ISERR(sc) {
            Return ..ReportError(500, "Erreur lors de la suppression", "DELETE_ERROR")
        }
        
        // Notifier les pages web d'un changement
        Set ^Article.LastChange = $ZDateTime($Horolog, 3, 1)
        
        Set response = {}
        Set response.id = +pId
        Set response.message = "Article supprimé avec succès"
        Write response.%ToJSON()
    }
    Catch ex {
        Return ..ReportError(500, ex.DisplayString(), "INTERNAL_ERROR")
    }
    Return $$$OK
}

/// GET /articles/category/:category - Articles par catégorie (paginé)
ClassMethod GetByCategory(pCategory As %String) As %Status
{
    Return ..ExecuteArticleQuery("Category", pCategory)
}

/// GET /articles/status/:status - Articles par statut (paginé)
ClassMethod GetByStatus(pStatus As %String) As %Status
{
    Return ..ExecuteArticleQuery("Status", pStatus)
}

/// GET /health - Vérification de santé du service
ClassMethod HealthCheck() As %Status
{
    Set response = {}
    Set response.status = "OK"
    Set response.service = "Articles API - Lignes2Code"
    Set response.timestamp = $ZDateTime($Horolog, 3)
    Set response.version = "1.1.0"
    Write response.%ToJSON()
    Return $$$OK
}

/// GET /articles/changes - Retourne le timestamp du dernier changement (polling léger)
/// Utilisé par les pages web pour détecter les nouveaux articles sans recharger
ClassMethod GetChanges() As %Status
{
    Set response = {}
    Set response.lastChange = $Get(^Article.LastChange, "")
    // Compter le total d'articles
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT COUNT(*) As total FROM Article_Data.Article")
    If $$$ISOK(sc) {
        Set rs = stmt.%Execute()
        If rs.%Next() {
            Set response.total = +rs.%Get("total")
        }
    } Else {
        Set response.total = 0
    }
    Write response.%ToJSON()
    Return $$$OK
}

}
