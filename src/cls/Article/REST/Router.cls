/// Service REST pour exposer les articles
/// Dispatch class pour router les requêtes HTTP
Class Article.REST.Router Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "utf-8";

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <!-- Liste tous les articles -->
    <Route Url="/articles" Method="GET" Call="GetAllArticles" />
    
    <!-- Récupère un article par ID -->
    <Route Url="/articles/:id" Method="GET" Call="GetArticle" />
    
    <!-- Crée un nouvel article -->
    <Route Url="/articles" Method="POST" Call="CreateArticle" />
    
    <!-- Met à jour un article existant -->
    <Route Url="/articles/:id" Method="PUT" Call="UpdateArticle" />
    
    <!-- Supprime un article -->
    <Route Url="/articles/:id" Method="DELETE" Call="DeleteArticle" />
    
    <!-- Recherche d'articles par catégorie -->
    <Route Url="/articles/category/:category" Method="GET" Call="GetByCategory" />
    
    <!-- Recherche d'articles par statut -->
    <Route Url="/articles/status/:status" Method="GET" Call="GetByStatus" />
    
    <!-- Endpoint de santé -->
    <Route Url="/health" Method="GET" Call="HealthCheck" />
</Routes>
}

/// GET /articles - Retourne tous les articles
ClassMethod GetAllArticles() As %Status
{
    Set sc = $$$OK
    Try {
        Set sql = "SELECT ID, Title, Author, Category, Status, DateCreated, DateModified, Source FROM Article_Data.Article ORDER BY DateCreated DESC"
        Set stmt = ##class(%SQL.Statement).%New()
        Set sc = stmt.%Prepare(sql)
        If $$$ISERR(sc) { Do ..ReportHttpStatusCode(500) Quit }
        
        Set rs = stmt.%Execute()
        Set articles = []
        
        While rs.%Next() {
            Set article = {}
            Set article.id = rs.%Get("ID")
            Set article.title = rs.%Get("Title")
            Set article.author = rs.%Get("Author")
            Set article.category = rs.%Get("Category")
            Set article.status = rs.%Get("Status")
            Set article.dateCreated = rs.%Get("DateCreated")
            Set article.dateModified = rs.%Get("DateModified")
            Set article.source = rs.%Get("Source")
            Do articles.%Push(article)
        }
        
        Set response = {}
        Set response.count = articles.%Size()
        Set response.articles = articles
        
        Write response.%ToJSON()
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Do ..ReportHttpStatusCode(500)
        Set error = {}
        Set error.error = ex.DisplayString()
        Write error.%ToJSON()
    }
    Return sc
}

/// GET /articles/:id - Retourne un article par ID
ClassMethod GetArticle(pId As %String) As %Status
{
    Set sc = $$$OK
    Try {
        If '##class(Article.Data.Article).%ExistsId(pId) {
            Do ..ReportHttpStatusCode(404)
            Set error = {}
            Set error.error = "Article non trouvé"
            Set error.id = pId
            Write error.%ToJSON()
            Return sc
        }
        
        Set article = ##class(Article.Data.Article).%OpenId(pId)
        Set json = {}
        Set sc = article.%JSONExportToString(.jsonStr)
        If $$$ISERR(sc) { Do ..ReportHttpStatusCode(500) Quit }
        
        // Ajouter l'ID manuellement
        Set jsonObj = {}.%FromJSON(jsonStr)
        Set jsonObj.id = pId
        
        Write jsonObj.%ToJSON()
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Do ..ReportHttpStatusCode(500)
        Set error = {}
        Set error.error = ex.DisplayString()
        Write error.%ToJSON()
    }
    Return sc
}

/// POST /articles - Crée un nouvel article
ClassMethod CreateArticle() As %Status
{
    Set sc = $$$OK
    Try {
        Set body = %request.Content
        If '$IsObject(body) {
            Do ..ReportHttpStatusCode(400)
            Set error = {}
            Set error.error = "Corps de la requête invalide"
            Write error.%ToJSON()
            Return sc
        }
        
        Set jsonStr = ""
        While 'body.AtEnd {
            Set jsonStr = jsonStr _ body.Read()
        }
        
        Set article = ##class(Article.Data.Article).%New()
        Set sc = article.%JSONImport(jsonStr)
        If $$$ISERR(sc) {
            Do ..ReportHttpStatusCode(400)
            Set error = {}
            Set error.error = "Données JSON invalides"
            Write error.%ToJSON()
            Return sc
        }
        
        Set article.Source = "rest"
        Set article.DateCreated = $ZDateTime($Horolog, 3)
        Set article.DateModified = article.DateCreated
        
        Set sc = article.%Save()
        If $$$ISERR(sc) {
            Do ..ReportHttpStatusCode(500)
            Set error = {}
            Set error.error = "Erreur lors de la sauvegarde"
            Write error.%ToJSON()
            Return sc
        }
        
        Do ..ReportHttpStatusCode(201)
        Set response = {}
        Set response.id = article.%Id()
        Set response.message = "Article créé avec succès"
        Write response.%ToJSON()
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Do ..ReportHttpStatusCode(500)
        Set error = {}
        Set error.error = ex.DisplayString()
        Write error.%ToJSON()
    }
    Return sc
}

/// PUT /articles/:id - Met à jour un article
ClassMethod UpdateArticle(pId As %String) As %Status
{
    Set sc = $$$OK
    Try {
        If '##class(Article.Data.Article).%ExistsId(pId) {
            Do ..ReportHttpStatusCode(404)
            Set error = {}
            Set error.error = "Article non trouvé"
            Write error.%ToJSON()
            Return sc
        }
        
        Set body = %request.Content
        If '$IsObject(body) {
            Do ..ReportHttpStatusCode(400)
            Set error = {}
            Set error.error = "Corps de la requête invalide"
            Write error.%ToJSON()
            Return sc
        }
        
        Set jsonStr = ""
        While 'body.AtEnd {
            Set jsonStr = jsonStr _ body.Read()
        }
        
        Set article = ##class(Article.Data.Article).%OpenId(pId)
        Set sc = article.%JSONImport(jsonStr)
        If $$$ISERR(sc) {
            Do ..ReportHttpStatusCode(400)
            Set error = {}
            Set error.error = "Données JSON invalides"
            Write error.%ToJSON()
            Return sc
        }
        
        Set article.DateModified = $ZDateTime($Horolog, 3)
        
        Set sc = article.%Save()
        If $$$ISERR(sc) {
            Do ..ReportHttpStatusCode(500)
            Set error = {}
            Set error.error = "Erreur lors de la mise à jour"
            Write error.%ToJSON()
            Return sc
        }
        
        Set response = {}
        Set response.id = pId
        Set response.message = "Article mis à jour avec succès"
        Write response.%ToJSON()
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Do ..ReportHttpStatusCode(500)
        Set error = {}
        Set error.error = ex.DisplayString()
        Write error.%ToJSON()
    }
    Return sc
}

/// DELETE /articles/:id - Supprime un article
ClassMethod DeleteArticle(pId As %String) As %Status
{
    Set sc = $$$OK
    Try {
        If '##class(Article.Data.Article).%ExistsId(pId) {
            Do ..ReportHttpStatusCode(404)
            Set error = {}
            Set error.error = "Article non trouvé"
            Write error.%ToJSON()
            Return sc
        }
        
        Set sc = ##class(Article.Data.Article).%DeleteId(pId)
        If $$$ISERR(sc) {
            Do ..ReportHttpStatusCode(500)
            Set error = {}
            Set error.error = "Erreur lors de la suppression"
            Write error.%ToJSON()
            Return sc
        }
        
        Set response = {}
        Set response.id = pId
        Set response.message = "Article supprimé avec succès"
        Write response.%ToJSON()
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Do ..ReportHttpStatusCode(500)
        Set error = {}
        Set error.error = ex.DisplayString()
        Write error.%ToJSON()
    }
    Return sc
}

/// GET /articles/category/:category - Articles par catégorie
ClassMethod GetByCategory(pCategory As %String) As %Status
{
    Set sc = $$$OK
    Try {
        Set sql = "SELECT ID, Title, Author, Category, Status, DateCreated, DateModified, Source FROM Article_Data.Article WHERE Category = ? ORDER BY DateCreated DESC"
        Set stmt = ##class(%SQL.Statement).%New()
        Set sc = stmt.%Prepare(sql)
        If $$$ISERR(sc) { Do ..ReportHttpStatusCode(500) Quit }
        
        Set rs = stmt.%Execute(pCategory)
        Set articles = []
        
        While rs.%Next() {
            Set article = {}
            Set article.id = rs.%Get("ID")
            Set article.title = rs.%Get("Title")
            Set article.author = rs.%Get("Author")
            Set article.category = rs.%Get("Category")
            Set article.status = rs.%Get("Status")
            Set article.dateCreated = rs.%Get("DateCreated")
            Set article.dateModified = rs.%Get("DateModified")
            Set article.source = rs.%Get("Source")
            Do articles.%Push(article)
        }
        
        Set response = {}
        Set response.count = articles.%Size()
        Set response.category = pCategory
        Set response.articles = articles
        
        Write response.%ToJSON()
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Do ..ReportHttpStatusCode(500)
        Set error = {}
        Set error.error = ex.DisplayString()
        Write error.%ToJSON()
    }
    Return sc
}

/// GET /articles/status/:status - Articles par statut
ClassMethod GetByStatus(pStatus As %String) As %Status
{
    Set sc = $$$OK
    Try {
        Set sql = "SELECT ID, Title, Author, Category, Status, DateCreated, DateModified, Source FROM Article_Data.Article WHERE Status = ? ORDER BY DateCreated DESC"
        Set stmt = ##class(%SQL.Statement).%New()
        Set sc = stmt.%Prepare(sql)
        If $$$ISERR(sc) { Do ..ReportHttpStatusCode(500) Quit }
        
        Set rs = stmt.%Execute(pStatus)
        Set articles = []
        
        While rs.%Next() {
            Set article = {}
            Set article.id = rs.%Get("ID")
            Set article.title = rs.%Get("Title")
            Set article.author = rs.%Get("Author")
            Set article.category = rs.%Get("Category")
            Set article.status = rs.%Get("Status")
            Set article.dateCreated = rs.%Get("DateCreated")
            Set article.dateModified = rs.%Get("DateModified")
            Set article.source = rs.%Get("Source")
            Do articles.%Push(article)
        }
        
        Set response = {}
        Set response.count = articles.%Size()
        Set response.status = pStatus
        Set response.articles = articles
        
        Write response.%ToJSON()
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Do ..ReportHttpStatusCode(500)
        Set error = {}
        Set error.error = ex.DisplayString()
        Write error.%ToJSON()
    }
    Return sc
}

/// GET /health - Vérification de santé du service
ClassMethod HealthCheck() As %Status
{
    Set response = {}
    Set response.status = "OK"
    Set response.service = "Articles API - Lignes2Code"
    Set response.timestamp = $ZDateTime($Horolog, 3)
    Set response.version = "1.0.0"
    Write response.%ToJSON()
    Return $$$OK
}

}
