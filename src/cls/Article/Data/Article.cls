/// Classe persistante représentant un Article
/// Stocké dans la base de données IRIS et exposé via REST
Class Article.Data.Article Extends (%Persistent, %JSON.Adaptor, %Populate)
{

/// Titre de l'article
Property Title As %String(MAXLEN = 500) [ Required ];

/// Contenu de l'article (texte enrichi HTML, stream pour supporter les images base64 inline volumineuses)
Property Content As %Stream.GlobalCharacter;

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

/// Identifiant calculé pour l'export JSON (inclut l'ID dans la sérialisation)
Property ArticleId As %Integer [ Calculated, Transient ];

Method ArticleIdGet() As %Integer
{
    Return ..%Id()
}

/// Vignette de l'article (image d'en-tête en buffer base64)
Property Thumbnail As Article.Data.ArticleImage;

/// Liste des images contenues dans l'article (buffers base64)
Property Images As list Of Article.Data.ArticleImage;

/// Mapping JSON : noms de champs en minuscules (camelCase)
XData BasicReference [ XMLNamespace = "http://www.intersystems.com/jsonmapping" ]
{
<Mapping xmlns="http://www.intersystems.com/jsonmapping">
  <Property Name="ArticleId" FieldName="id" Include="OUTPUTONLY"/>
  <Property Name="Title" FieldName="title"/>
  <Property Name="Content" FieldName="content"/>
  <Property Name="Author" FieldName="author"/>
  <Property Name="Category" FieldName="category"/>
  <Property Name="DateCreated" FieldName="dateCreated"/>
  <Property Name="DateModified" FieldName="dateModified"/>
  <Property Name="Status" FieldName="status"/>
  <Property Name="Source" FieldName="source"/>
  <Property Name="Thumbnail" FieldName="thumbnail" Mapping="BasicReference"/>
  <Property Name="Images" FieldName="images" Mapping="BasicReference"/>
</Mapping>
}

/// Mapping JSON allégé pour les listes (sans Content ni Images)
XData ListReference [ XMLNamespace = "http://www.intersystems.com/jsonmapping" ]
{
<Mapping xmlns="http://www.intersystems.com/jsonmapping">
  <Property Name="ArticleId" FieldName="id" Include="OUTPUTONLY"/>
  <Property Name="Title" FieldName="title"/>
  <Property Name="Author" FieldName="author"/>
  <Property Name="Category" FieldName="category"/>
  <Property Name="DateCreated" FieldName="dateCreated"/>
  <Property Name="DateModified" FieldName="dateModified"/>
  <Property Name="Status" FieldName="status"/>
  <Property Name="Source" FieldName="source"/>
</Mapping>
}

/// Import stream-safe depuis un %DynamicObject (évite MAXSTRING avec %JSONImport)
/// Utilise %Get(key,,"stream") pour content et les données base64 des images
Method ImportFromDynObj(pJson As %DynamicObject) As %Status
{
    Set sc = $$$OK
    Try {
        If pJson.%IsDefined("title") Set ..Title = pJson.%Get("title")
        If pJson.%IsDefined("author") Set ..Author = pJson.%Get("author")
        If pJson.%IsDefined("category") Set ..Category = pJson.%Get("category")
        If pJson.%IsDefined("status") Set ..Status = pJson.%Get("status")
        If pJson.%IsDefined("source") Set ..Source = pJson.%Get("source")
        
        // Content comme stream (peut être très volumineux avec images base64 inline)
        If pJson.%IsDefined("content") {
            Set contentStream = pJson.%Get("content",,"stream")
            If $IsObject(contentStream) {
                Do contentStream.Rewind()
                Do ..Content.CopyFrom(contentStream)
            }
        }
        
        // Thumbnail
        If pJson.%IsDefined("thumbnail") {
            Set thumbJson = pJson.%Get("thumbnail")
            If $IsObject(thumbJson) {
                Set thumb = ##class(Article.Data.ArticleImage).%New()
                Set sc = thumb.ImportFromDynObj(thumbJson)
                If $$$ISERR(sc) Return sc
                Set ..Thumbnail = thumb
            }
        }
        
        // Images array
        If pJson.%IsDefined("images") {
            Set imagesArray = pJson.%Get("images")
            If $IsObject(imagesArray) {
                Set iter = imagesArray.%GetIterator()
                While iter.%GetNext(.key, .imgJson) {
                    If $IsObject(imgJson) {
                        Set img = ##class(Article.Data.ArticleImage).%New()
                        Set sc = img.ImportFromDynObj(imgJson)
                        If $$$ISERR(sc) Continue
                        Do ..Images.Insert(img)
                    }
                }
            }
        }
    }
    Catch ex {
        Set sc = ex.AsStatus()
    }
    Return sc
}

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
<Value name="10">
<Value>Thumbnail</Value>
</Value>
<Value name="11">
<Value>Images</Value>
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
