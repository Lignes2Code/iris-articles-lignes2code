/// Message de réponse pour l'enregistrement d'un article
Class Article.Message.ArticleResponse Extends Ens.Response
{

/// ID de l'article créé/mis à jour
Property ArticleId As %String;

/// Message de statut
Property StatusMessage As %String(MAXLEN = 500);

/// Indicateur de succès
Property Success As %Boolean;

Storage Default
{
<Data name="ArticleResponseDefaultData">
<Subscript>"ArticleResponse"</Subscript>
<Value name="1">
<Value>ArticleId</Value>
</Value>
<Value name="2">
<Value>StatusMessage</Value>
</Value>
<Value name="3">
<Value>Success</Value>
</Value>
</Data>
<DefaultData>ArticleResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
