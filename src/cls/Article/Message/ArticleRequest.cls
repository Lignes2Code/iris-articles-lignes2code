/// Message de requête pour l'enregistrement d'un article via l'interopérabilité
Class Article.Message.ArticleRequest Extends Ens.Request
{

/// Données JSON brutes de l'article
Property JSONData As %String(MAXLEN = 10000);

/// Nom du fichier source
Property SourceFileName As %String(MAXLEN = 500);

Storage Default
{
<Data name="ArticleRequestDefaultData">
<Subscript>"ArticleRequest"</Subscript>
<Value name="1">
<Value>JSONData</Value>
</Value>
<Value name="2">
<Value>SourceFileName</Value>
</Value>
</Data>
<DefaultData>ArticleRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
