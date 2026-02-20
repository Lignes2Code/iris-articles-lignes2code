/// Business Service qui surveille un dossier pour importer des articles JSON
/// Utilise l'adaptateur fichier entrant (EnsLib.File.InboundAdapter)
Class Article.Service.FileService Extends Ens.BusinessService
{

Parameter ADAPTER = "EnsLib.File.InboundAdapter";

/// Nom de la cible (Business Operation) vers laquelle envoyer les messages
Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "Article.Operation.SaveArticle" ];

Parameter SETTINGS = "TargetConfigName:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

/// Méthode appelée par l'adaptateur quand un nouveau fichier est détecté
Method OnProcessInput(pInput As %Stream.Object, Output pOutput As %RegisteredObject) As %Status
{
    Set sc = $$$OK
    Try {
        $$$LOGINFO("Fichier détecté : " _ pInput.Attributes("Filename"))
        
        // Lire le contenu du fichier en UTF-8
        If pInput.%IsA("%Stream.FileCharacter") || pInput.%IsA("%Stream.FileBinary") {
            Set pInput.TranslateTable = "UTF8"
        }
        
        // Log des premiers caractères pour debug
        Set preview = pInput.Read(200)
        Do pInput.Rewind()
        $$$LOGINFO("Contenu du fichier (début) : " _ preview _ "...")
        
        // Créer le message de requête avec stream
        Set request = ##class(Article.Message.ArticleRequest).%New()
        Set request.SourceFileName = pInput.Attributes("Filename")
        
        // Copier le stream d'entrée vers le stream du message (pas de MAXSTRING)
        Set sc = request.JSONData.CopyFrom(pInput)
        If $$$ISERR(sc) {
            $$$LOGERROR("Erreur copie stream : " _ $System.Status.GetErrorText(sc))
            Return sc
        }
        
        // Envoyer le message à l'opération cible
        Set sc = ..SendRequestSync(..TargetConfigName, request, .response)
        
        If $$$ISERR(sc) {
            $$$LOGERROR("Erreur lors de l'envoi du message : " _ $System.Status.GetErrorText(sc))
        } Else {
            If $IsObject(response) && response.Success {
                $$$LOGINFO("Article enregistré avec succès. ID : " _ response.ArticleId)
            } Else {
                $$$LOGWARNING("L'article n'a pas été enregistré correctement")
            }
        }
    }
    Catch ex {
        Set sc = ex.AsStatus()
        $$$LOGERROR("Exception dans FileService : " _ ex.DisplayString())
    }
    Return sc
}

}
