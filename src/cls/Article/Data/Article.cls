/// Classe persistante représentant un Article
/// Stocké dans la base de données IRIS et exposé via REST
Class Article.Data.Article Extends (%Persistent, %JSON.Adaptor, %Populate)
{

/// Titre de l'article
Property Title As %String(MAXLEN = 500) [ Required ];

/// Contenu de l'article
Property Content As %String(MAXLEN = 10000);

/// Auteur de l'article
Property Author As %String(MAXLEN = 200);

/// Catégorie de l'article
Property Category As %String(MAXLEN = 100);

/// Date de création
Property DateCreated As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

/// Date de dernière modification
Property DateModified As %TimeStamp;

/// Statut de l'article (draft, published, archived)
Property Status As %String(VALUELIST = ",draft,published,archived") [ InitialExpression = "draft" ];

/// Source de l'article (rest, file, manual)
Property Source As %String(MAXLEN = 50);

/// Index sur le titre
Index TitleIdx On Title;

/// Index sur la catégorie
Index CategoryIdx On Category;

/// Index sur le statut
Index StatusIdx On Status;

/// Index sur l'auteur
Index AuthorIdx On Author;

Storage Default
{
<Data name="ArticleDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Title</Value>
</Value>
<Value name="3">
<Value>Content</Value>
</Value>
<Value name="4">
<Value>Author</Value>
</Value>
<Value name="5">
<Value>Category</Value>
</Value>
<Value name="6">
<Value>DateCreated</Value>
</Value>
<Value name="7">
<Value>DateModified</Value>
</Value>
<Value name="8">
<Value>Status</Value>
</Value>
<Value name="9">
<Value>Source</Value>
</Value>
</Data>
<DataLocation>^Article.Data.ArticleD</DataLocation>
<DefaultData>ArticleDefaultData</DefaultData>
<IdLocation>^Article.Data.ArticleD</IdLocation>
<IndexLocation>^Article.Data.ArticleI</IndexLocation>
<StreamLocation>^Article.Data.ArticleS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
