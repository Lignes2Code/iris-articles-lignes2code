/// Business Process simple entre FileService et SaveArticle
/// Enrichit et valide les données avant sauvegarde
Class Article.Process.ArticleBusinessProcess Extends Ens.BusinessProcess
{

/// Point d'entrée obligatoire Ens.BusinessProcess - dispatch vers ProcessArticleRequest
Method OnRequest(pRequest As Article.Message.ArticleRequest, Output pResponse As Article.Message.ArticleResponse) As %Status
{
    Return ..ProcessArticleRequest(pRequest, .pResponse)
}

/// Point d'entrée du processus depuis FileService
Method ProcessArticleRequest(pRequest As Article.Message.ArticleRequest, Output pResponse As Article.Message.ArticleResponse) As %Status
{
    Set sc = $$$OK
    Set pResponse = ##class(Article.Message.ArticleResponse).%New()
    
    Try {
        $$$LOGINFO("Processus Article - Traitement fichier: " _ pRequest.SourceFileName)
        
        // 1. VALIDATION ET ENRICHISSEMENT
        Set enrichedRequest = ..EnrichArticleData(pRequest)
        If '$IsObject(enrichedRequest) {
            Set pResponse.Success = 0
            Set pResponse.StatusMessage = "Erreur d'enrichissement des données"
            Return $$$OK
        }
        
        // 2. ENVOI VERS SAVEARTICLE
        Set saveResponse = ""
        Set sc = ..SendRequestSync("Article.Operation.SaveArticle", enrichedRequest, .saveResponse)
        
        If $$$ISERR(sc) {
            Set pResponse.Success = 0
            Set pResponse.StatusMessage = "Erreur lors de l'envoi vers SaveArticle: " _ $System.Status.GetErrorText(sc)
            Return sc
        }
        
        // 3. POST-TRAITEMENT
        Do ..PostProcessArticle(saveResponse)
        
        // 4. RETOURNER LA RÉPONSE
        Set pResponse.Success = saveResponse.Success
        Set pResponse.ArticleId = saveResponse.ArticleId
        Set pResponse.StatusMessage = "Processus: " _ saveResponse.StatusMessage
        
        $$$LOGINFO("Processus Article terminé - " _ pResponse.StatusMessage)
        
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Set pResponse.Success = 0
        Set pResponse.StatusMessage = "Exception processus: " _ ex.DisplayString()
        $$$LOGERROR("Exception dans ArticleBusinessProcess: " _ ex.DisplayString())
    }
    
    Return sc
}

/// Enrichit les données article avant traitement
Method EnrichArticleData(pRequest As Article.Message.ArticleRequest) As Article.Message.ArticleRequest
{
    Try {
        // Créer une copie enrichie
        Set enrichedReq = ##class(Article.Message.ArticleRequest).%New()
        Set enrichedReq.SourceFileName = pRequest.SourceFileName
        
        // Copier le stream JSON
        Do pRequest.JSONData.Rewind()
        Do enrichedReq.JSONData.CopyFrom(pRequest.JSONData)
        Do enrichedReq.JSONData.Rewind()
        
        // ENRICHISSEMENT 1: Ajouter métadonnées de processus
        Set jsonData = {}.%FromJSON(enrichedReq.JSONData)
        Do enrichedReq.JSONData.Rewind()
        
        If $IsObject(jsonData) {
            // Si c'est un objet unique
            If jsonData.%IsA("%DynamicObject") {
                Do ..EnrichSingleArticle(jsonData)
                
                // Réécrire le JSON enrichi (stream pour éviter MAXSTRING)
                Do enrichedReq.JSONData.Clear()
                Do jsonData.%ToJSON(enrichedReq.JSONData)
                
            } ElseIf jsonData.%IsA("%DynamicArray") {
                // Si c'est un array d'articles
                Do ..EnrichArticleArray(jsonData)
                
                // Réécrire le JSON enrichi (stream pour éviter MAXSTRING)
                Do enrichedReq.JSONData.Clear() 
                Do jsonData.%ToJSON(enrichedReq.JSONData)
            }
        }
        
        Return enrichedReq
        
    }
    Catch ex {
        $$$LOGERROR("Erreur enrichissement: " _ ex.DisplayString())
        Return ""
    }
}

/// Enrichit un article unique
Method EnrichSingleArticle(pArticleJson As %DynamicObject)
{
    // Ajouter source processus
    Set pArticleJson."_processSource" = "BusinessProcess"
    Set pArticleJson."_processedAt" = $ZDateTime($Horolog, 3, 1)
    
    // Valeurs par défaut si manquantes
    If pArticleJson.%Get("status") = "" {
        Set pArticleJson.status = "draft"
    }
    If pArticleJson.%Get("category") = "" {
        Set pArticleJson.category = "tech"
    }
    
    // Auto-génération slug si titre présent
    Set title = pArticleJson.%Get("title")
    If title '= "" && (pArticleJson.%Get("slug") = "") {
        Set slug = ..GenerateSlug(title)
        Set pArticleJson.slug = slug
    }
    
    // Validation taille contenu
    Set content = pArticleJson.%Get("content")
    If $Length(content) > 1000000 {  // 1MB limit
        Set pArticleJson."_warning" = "Contenu très volumineux (" _ $Length(content) _ " chars)"
    }
}

/// Enrichit un array d'articles
Method EnrichArticleArray(pArrayJson As %DynamicArray)
{
    Set iterator = pArrayJson.%GetIterator()
    While iterator.%GetNext(.key, .articleJson) {
        Do ..EnrichSingleArticle(articleJson)
        
        // Ajouter index batch
        Set articleJson."_batchIndex" = key
        Set articleJson."_batchTotal" = pArrayJson.%Size()
    }
}

/// Génère un slug SEO-friendly
Method GenerateSlug(pTitle As %String) As %String
{
    Set slug = $ZConvert(pTitle, "L")  // Minuscules
    
    // Remplacer caractères spéciaux
    Set slug = $Translate(slug, "àáäâèéëêìíïîòóöôùúüûç", "aaaaeeeeiiiioooouuuuc")
    Set slug = $Translate(slug, " ,.;:!?()[]{}""'-", "----------------")
    
    // Nettoyer tirets multiples
    While $Find(slug, "--") {
        Set slug = $Replace(slug, "--", "-")
    }
    
    // Supprimer tirets début/fin
    If $Extract(slug, 1) = "-" Set slug = $Extract(slug, 2, *)
    If $Extract(slug, *) = "-" Set slug = $Extract(slug, 1, *-1)
    
    // Limiter longueur
    If $Length(slug) > 50 Set slug = $Extract(slug, 1, 50)
    
    Return slug
}

/// Post-traitement après sauvegarde
Method PostProcessArticle(pSaveResponse As Article.Message.ArticleResponse)
{
    Try {
        // STATISTICS: Compter articles traités
        Set ^Article.Process.Stats("Processed") = $Get(^Article.Process.Stats("Processed")) + 1
        Set ^Article.Process.Stats("LastProcessed") = $ZDateTime($Horolog, 3, 1)
        
        // Si succès, logger les détails
        If pSaveResponse.Success {
            Set ^Article.Process.Stats("Success") = $Get(^Article.Process.Stats("Success")) + 1
            
            // Analyser les articles créés
            Set articleIds = pSaveResponse.ArticleId
            If $Find(articleIds, ",") {
                // Batch: compter le nombre d'articles
                Set count = $Length(articleIds, ",")
                Set ^Article.Process.Stats("BatchArticles") = $Get(^Article.Process.Stats("BatchArticles")) + count
            } Else {
                // Article unique
                Set ^Article.Process.Stats("SingleArticles") = $Get(^Article.Process.Stats("SingleArticles")) + 1
            }
        } Else {
            Set ^Article.Process.Stats("Errors") = $Get(^Article.Process.Stats("Errors")) + 1
            $$$LOGWARNING("Échec traitement: " _ pSaveResponse.StatusMessage)
        }
        
        // NOTIFICATION: Alerter si accumulation d'erreurs
        Set errorRate = $Get(^Article.Process.Stats("Errors")) / ($Get(^Article.Process.Stats("Processed")) + 1)
        If errorRate > 0.1 {  // Plus de 10% d'erreurs
            $$$LOGWARNING("Taux d'erreur élevé dans le processus: " _ (errorRate * 100) _ "%")
        }
        
    }
    Catch ex {
        $$$LOGWARNING("Erreur post-traitement: " _ ex.DisplayString())
    }
}

/// Utilitaire pour obtenir les statistiques du processus
ClassMethod GetProcessStats() As %DynamicObject
{
    Set stats = {}
    
    Set stats.processed = $Get(^Article.Process.Stats("Processed"))
    Set stats.success = $Get(^Article.Process.Stats("Success")) 
    Set stats.errors = $Get(^Article.Process.Stats("Errors"))
    Set stats.singleArticles = $Get(^Article.Process.Stats("SingleArticles"))
    Set stats.batchArticles = $Get(^Article.Process.Stats("BatchArticles"))
    Set stats.lastProcessed = $Get(^Article.Process.Stats("LastProcessed"))
    
    // Calculer taux de succès
    Set total = stats.processed
    If total > 0 {
        Set stats.successRate = (stats.success / total) * 100
        Set stats.errorRate = (stats.errors / total) * 100
    } Else {
        Set stats.successRate = 0
        Set stats.errorRate = 0
    }
    
    Return stats
}

XData BPL
{
<process language='objectscript' request='Article.Message.ArticleRequest' response='Article.Message.ArticleResponse'>
<sequence>
  <call name='ProcessArticle' target='ProcessArticleRequest' async='false'>
    <request type='Article.Message.ArticleRequest'/>
    <response type='Article.Message.ArticleResponse'/>
  </call>
</sequence>
</process>
}

}