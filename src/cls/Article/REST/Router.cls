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
    <!-- Endpoint de santé -->
    <Route Url="/health" Method="GET" Call="HealthCheck" />
    
    <!-- Recherche d'articles par catégorie (AVANT :id pour éviter conflit) -->
    <Route Url="/articles/category/:category" Method="GET" Call="GetByCategory" />
    
    <!-- Recherche d'articles par statut (AVANT :id pour éviter conflit) -->
    <Route Url="/articles/status/:status" Method="GET" Call="GetByStatus" />
    
    <!-- Liste tous les articles -->
    <Route Url="/articles" Method="GET" Call="GetAllArticles" />
    
    <!-- Crée un nouvel article -->
    <Route Url="/articles" Method="POST" Call="CreateArticle" />
    
    <!-- Récupère un article par ID -->
    <Route Url="/articles/:id" Method="GET" Call="GetArticle" />
    
    <!-- Met à jour un article existant -->
    <Route Url="/articles/:id" Method="PUT" Call="UpdateArticle" />
    
    <!-- Supprime un article -->
    <Route Url="/articles/:id" Method="DELETE" Call="DeleteArticle" />
</Routes>
}

/// GET /articles - Retourne tous les articles
ClassMethod GetAllArticles() As %Status
{
    Set sc = $$$OK
    Try {
        Set sql = "SELECT ID FROM Article_Data.Article ORDER BY DateCreated DESC"
        Set stmt = ##class(%SQL.Statement).%New()
        Set sc = stmt.%Prepare(sql)
        If $$$ISERR(sc) { Do ..ReportHttpStatusCode(500) Quit }
        
        Set rs = stmt.%Execute()
        Set articles = []
        
        While rs.%Next() {
            Set articleObj = ##class(Article.Data.Article).%OpenId(rs.%Get("ID"))
            If $IsObject(articleObj) {
                Set sc = articleObj.%JSONExportToString(.jsonStr, "ListReference")
                If $$$ISOK(sc) {
                    Set articleJson = {}.%FromJSON(jsonStr)
                    Do articles.%Push(articleJson)
                }
            }
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
        // Export en stream pour supporter les gros contenus avec images base64
        Set stream = ##class(%Stream.TmpCharacter).%New()
        Set sc = article.%JSONExportToStream(.stream, "BasicReference")
        If $$$ISERR(sc) { Do ..ReportHttpStatusCode(500) Quit }
        
        Do stream.Rewind()
        While 'stream.AtEnd {
            Write stream.Read(32000)
        }
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
        
        // Parser le JSON depuis le stream (évite MAXSTRING)
        Set jsonObj = ##class(%DynamicObject).%FromJSON(body)
        
        Set article = ##class(Article.Data.Article).%New()
        Set sc = article.ImportFromDynObj(jsonObj)
        If $$$ISERR(sc) {
            Do ..ReportHttpStatusCode(400)
            Set error = {}
            Set error.error = "Données JSON invalides : " _ $System.Status.GetErrorText(sc)
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
        
        // Parser le JSON depuis le stream
        Set jsonObj = ##class(%DynamicObject).%FromJSON(body)
        
        Set article = ##class(Article.Data.Article).%OpenId(pId)
        Set sc = article.ImportFromDynObj(jsonObj)
        If $$$ISERR(sc) {
            Do ..ReportHttpStatusCode(400)
            Set error = {}
            Set error.error = "Données JSON invalides : " _ $System.Status.GetErrorText(sc)
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
        Set sql = "SELECT ID FROM Article_Data.Article WHERE Category = ? ORDER BY DateCreated DESC"
        Set stmt = ##class(%SQL.Statement).%New()
        Set sc = stmt.%Prepare(sql)
        If $$$ISERR(sc) { Do ..ReportHttpStatusCode(500) Quit }
        
        Set rs = stmt.%Execute(pCategory)
        Set articles = []
        
        While rs.%Next() {
            Set articleObj = ##class(Article.Data.Article).%OpenId(rs.%Get("ID"))
            If $IsObject(articleObj) {
                Set sc = articleObj.%JSONExportToString(.jsonStr, "ListReference")
                If $$$ISOK(sc) {
                    Set articleJson = {}.%FromJSON(jsonStr)
                    Do articles.%Push(articleJson)
                }
            }
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
        Set sql = "SELECT ID FROM Article_Data.Article WHERE Status = ? ORDER BY DateCreated DESC"
        Set stmt = ##class(%SQL.Statement).%New()
        Set sc = stmt.%Prepare(sql)
        If $$$ISERR(sc) { Do ..ReportHttpStatusCode(500) Quit }
        
        Set rs = stmt.%Execute(pStatus)
        Set articles = []
        
        While rs.%Next() {
            Set articleObj = ##class(Article.Data.Article).%OpenId(rs.%Get("ID"))
            If $IsObject(articleObj) {
                Set sc = articleObj.%JSONExportToString(.jsonStr, "ListReference")
                If $$$ISOK(sc) {
                    Set articleJson = {}.%FromJSON(jsonStr)
                    Do articles.%Push(articleJson)
                }
            }
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
