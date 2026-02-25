/// Business Operation qui sauvegarde un article dans la base de données
/// Reçoit les messages du Business Service FileService
Class Article.Operation.SaveArticle Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

/// Traitement du message de requête ArticleRequest
/// JSONData est maintenant un %Stream.GlobalCharacter pour supporter les gros payloads
Method SaveArticleFromFile(pRequest As Article.Message.ArticleRequest, Output pResponse As Article.Message.ArticleResponse) As %Status
{
    Set sc = $$$OK
    Set pResponse = ##class(Article.Message.ArticleResponse).%New()
    
    Try {
        $$$LOGINFO("Traitement de l'article depuis le fichier : " _ pRequest.SourceFileName)
        
        // Le JSONData est un stream - rembobiner avant de lire
        Do pRequest.JSONData.Rewind()
        
        // Détecter si c'est un tableau ou un objet en lisant le premier caractère
        Set firstChar = $ZStrip(pRequest.JSONData.Read(1), "<>W")
        Do pRequest.JSONData.Rewind()
        
        If firstChar = "[" {
            // Tableau d'articles - parser depuis le stream
            Set array = [].%FromJSON(pRequest.JSONData)
            Set iter = array.%GetIterator()
            Set count = 0
            Set ids = ""
            
            While iter.%GetNext(.key, .articleJson) {
                Set articleSc = ..SaveOneArticle(articleJson, .articleId)
                If $$$ISERR(articleSc) {
                    $$$LOGERROR("Erreur lors de la sauvegarde de l'article #" _ key _ " : " _ $System.Status.GetErrorText(articleSc))
                    Continue
                }
                Set count = count + 1
                Set ids = ids _ $Select(ids'="": ",", 1:"") _ articleId
            }
            
            Set pResponse.Success = (count > 0)
            Set pResponse.ArticleId = ids
            Set pResponse.StatusMessage = count _ " article(s) enregistré(s) depuis " _ pRequest.SourceFileName
        } Else {
            // Article unique - parser depuis le stream
            Set articleJson = {}.%FromJSON(pRequest.JSONData)
            Set sc = ..SaveOneArticle(articleJson, .articleId)
            
            If $$$ISERR(sc) {
                Set pResponse.Success = 0
                Set pResponse.StatusMessage = "Erreur : " _ $System.Status.GetErrorText(sc)
                Return sc
            }
            
            Set pResponse.Success = 1
            Set pResponse.ArticleId = articleId
            Set pResponse.StatusMessage = "Article enregistré avec succès depuis " _ pRequest.SourceFileName
        }
        
        $$$LOGINFO(pResponse.StatusMessage)
    }
    Catch ex {
        Set sc = ex.AsStatus()
        Set pResponse.Success = 0
        Set pResponse.StatusMessage = "Exception : " _ ex.DisplayString()
        $$$LOGERROR("Exception dans SaveArticle : " _ ex.DisplayString())
    }
    Return sc
}

/// Sauvegarde un article unique à partir d'un objet JSON dynamique
/// Import 100% manuel via ImportFromDynObj (pas de %JSONImport → pas de MAXSTRING)
Method SaveOneArticle(pJson As %DynamicObject, Output pId As %String) As %Status
{
    Set sc = $$$OK
    Set pId = ""
    
    Try {
        Set article = ##class(Article.Data.Article).%New()
        
        // Import stream-safe : aucun %JSONImport, aucun %GetNext sur les gros champs
        Set sc = article.ImportFromDynObj(pJson)
        If $$$ISERR(sc) {
            $$$LOGERROR("Erreur lors de l'import : " _ $System.Status.GetErrorText(sc))
            Return sc
        }
        
        // Forcer la source et les dates
        Set article.Source = "file"
        Set article.DateCreated = $ZDateTime($Horolog, 3)
        Set article.DateModified = article.DateCreated
        
        // Si le statut n'est pas défini, mettre en brouillon
        If article.Status = "" Set article.Status = "draft"
        
        Set sc = article.%Save()
        If $$$ISERR(sc) Return sc
        
        Set pId = article.%Id()
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
