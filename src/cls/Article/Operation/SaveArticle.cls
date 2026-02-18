/// Business Operation qui sauvegarde un article dans la base de données
/// Reçoit les messages du Business Service FileService
Class Article.Operation.SaveArticle Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

/// Traitement du message de requête ArticleRequest
Method SaveArticleFromFile(pRequest As Article.Message.ArticleRequest, Output pResponse As Article.Message.ArticleResponse) As %Status
{
    Set sc = $$$OK
    Set pResponse = ##class(Article.Message.ArticleResponse).%New()
    
    Try {
        $$$LOGINFO("Traitement de l'article depuis le fichier : " _ pRequest.SourceFileName)
        
        Set jsonData = pRequest.JSONData
        
        // Vérifier si c'est un tableau JSON (plusieurs articles)
        Set firstChar = $ZStrip($Extract(jsonData, 1, 1), "<>W")
        
        If firstChar = "[" {
            // Tableau d'articles
            Set array = [].%FromJSON(jsonData)
            Set iter = array.%GetIterator()
            Set count = 0
            Set ids = ""
            
            While iter.%GetNext(.key, .articleJson) {
                Set sc = ..SaveOneArticle(articleJson, .articleId)
                If $$$ISERR(sc) {
                    $$$LOGERROR("Erreur lors de la sauvegarde de l'article #" _ key _ " : " _ $System.Status.GetErrorText(sc))
                    Continue
                }
                Set count = count + 1
                Set ids = ids _ $Select(ids'="": ",", 1:"") _ articleId
            }
            
            Set pResponse.Success = (count > 0)
            Set pResponse.ArticleId = ids
            Set pResponse.StatusMessage = count _ " article(s) enregistré(s) depuis " _ pRequest.SourceFileName
        } Else {
            // Article unique
            Set articleJson = {}.%FromJSON(jsonData)
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
Method SaveOneArticle(pJson As %DynamicObject, Output pId As %String) As %Status
{
    Set sc = $$$OK
    Set pId = ""
    
    Try {
        Set article = ##class(Article.Data.Article).%New()
        
        // Mapper les propriétés JSON vers l'objet Article
        If pJson.%IsDefined("title") Set article.Title = pJson.title
        If pJson.%IsDefined("content") Set article.Content = pJson.content
        If pJson.%IsDefined("author") Set article.Author = pJson.author
        If pJson.%IsDefined("category") Set article.Category = pJson.category
        If pJson.%IsDefined("status") {
            Set article.Status = pJson.status
        } Else {
            Set article.Status = "draft"
        }
        
        Set article.Source = "file"
        Set article.DateCreated = $ZDateTime($Horolog, 3)
        Set article.DateModified = article.DateCreated
        
        Set sc = article.%Save()
        If $$$ISERR(sc) Return sc
        
        Set pId = article.%Id()
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
