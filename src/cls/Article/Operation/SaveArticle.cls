/// Business Operation qui sauvegarde un article dans la base de données  
/// Reçoit maintenant les messages du Business Process (données pre-enrichies)
Class Article.Operation.SaveArticle Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

/// Traitement du message de requête ArticleRequest (depuis ArticleBusinessProcess)
/// Les données sont déjà enrichies et validées par le processus
Method SaveArticleFromFile(pRequest As Article.Message.ArticleRequest, Output pResponse As Article.Message.ArticleResponse) As %Status
{
    Set sc = $$$OK
    Set pResponse = ##class(Article.Message.ArticleResponse).%New()
    
    Try {
        $$$LOGINFO("Sauvegarde article (depuis processus) : " _ pRequest.SourceFileName)
        
        // Le JSONData a été enrichi par le Business Process
        Do pRequest.JSONData.Rewind()
        
        // Détecter si c'est un tableau ou un objet
        Set firstChar = $ZStrip(pRequest.JSONData.Read(1), "<>W")
        Do pRequest.JSONData.Rewind()
        
        If firstChar = "[" {
            // Tableau d'articles enrichis
            Set array = [].%FromJSON(pRequest.JSONData)
            Set iter = array.%GetIterator()
            Set count = 0
            Set ids = ""
            
            While iter.%GetNext(.key, .articleJson) {
                // Nettoyer les métadonnées du processus avant sauvegarde
                Do ..CleanProcessMetadata(articleJson)
                
                Set articleSc = ..SaveOneArticle(articleJson, .articleId)
                If $$$ISERR(articleSc) {
                    $$$LOGERROR("Erreur sauvegarde article #" _ key _ " : " _ $System.Status.GetErrorText(articleSc))
                    Continue
                }
                Set count = count + 1
                Set ids = ids _ $Select(ids'="": ",", 1:"") _ articleId
            }
            
            Set pResponse.Success = (count > 0)
            Set pResponse.ArticleId = ids
            Set pResponse.StatusMessage = count _ " article(s) sauvegardé(s)"
            
        } Else {
            // Article unique enrichi
            Set articleJson = {}.%FromJSON(pRequest.JSONData)
            
            // Nettoyer les métadonnées du processus avant sauvegarde  
            Do ..CleanProcessMetadata(articleJson)
            
            Set sc = ..SaveOneArticle(articleJson, .articleId)
            
            If $$$ISERR(sc) {
                Set pResponse.Success = 0
                Set pResponse.StatusMessage = "Erreur sauvegarde : " _ $System.Status.GetErrorText(sc)
                Return sc
            }
            
            Set pResponse.Success = 1
            Set pResponse.ArticleId = articleId
            Set pResponse.StatusMessage = "Article sauvegardé avec succès"
        }
        
        $$$LOGINFO("Operation terminée: " _ pResponse.StatusMessage)
        
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Set pResponse.Success = 0
        Set pResponse.StatusMessage = "Exception sauvegarde : " _ ex.DisplayString()
        $$$LOGERROR("Exception dans SaveArticle : " _ ex.DisplayString())
    }
    Return sc
}

/// Nettoie les métadonnées ajoutées par le Business Process
Method CleanProcessMetadata(pArticleJson As %DynamicObject)
{
    // Supprimer les champs ajoutés par le processus
    Do pArticleJson.%Remove("_processSource")
    Do pArticleJson.%Remove("_processedAt")
    Do pArticleJson.%Remove("_batchIndex") 
    Do pArticleJson.%Remove("_batchTotal")
    Do pArticleJson.%Remove("_warning")
}

/// Sauvegarde pure d'un article (données déjà validées/enrichies)
Method SaveOneArticle(pJson As %DynamicObject, Output pId As %String) As %Status
{
    Set sc = $$$OK
    Set pId = ""
    
    Try {
        Set article = ##class(Article.Data.Article).%New()
        
        // Import des données enrichies
        Set sc = article.ImportFromDynObj(pJson)
        If $$$ISERR(sc) {
            $$$LOGERROR("Erreur import données : " _ $System.Status.GetErrorText(sc))
            Return sc
        }
        
        // Métadonnées système (forcer la source si pas définie)
        If article.Source = "" Set article.Source = "file"
        If article.DateCreated = "" Set article.DateCreated = $ZDateTime($Horolog, 3)
        Set article.DateModified = $ZDateTime($Horolog, 3)
        
        // Défauts (normalement déjà gérés par le processus)
        If article.Status = "" Set article.Status = "draft"
        If article.Category = "" Set article.Category = "tech"
        
        // Sauvegarde transactionnelle
        Set sc = article.%Save()
        If $$$ISERR(sc) Return sc
        
        Set pId = article.%Id()
        
        // Notification simple (pas de stats complètes → fait par le processus)
        Set ^Article.LastChange = $ZDateTime($Horolog, 3, 1)
        
        $$$LOGINFO("Article ID=" _ pId _ " sauvegardé avec " _ article.Images.Count() _ " image(s)")
        
    }
    Catch ex {
        Set sc = ex.AsStatus()
    }
    Return sc
}
        // Notifier les pages web d'un changement (polling)
        Set ^Article.LastChange = $ZDateTime($Horolog, 3, 1)
        $$$LOGINFO("Article enregistré ID=" _ pId _ " avec " _ article.Images.Count() _ " image(s)")
    }
    Catch ex {
        Set sc = ex.AsStatus()
    }
    Return sc
}

XData MessageMap
{
<MapItems>
    <MapItem MessageType="Article.Message.ArticleRequest">
        <Method>SaveArticleFromFile</Method>
    </MapItem>
</MapItems>
}

}
