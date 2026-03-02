/// Classe persistante représentant un Article
/// Stocké dans la base de données IRIS et exposé via REST
Class Article.Data.Article Extends (%Persistent, %JSON.Adaptor, %Populate)
{

/// Titre de l'article (stream pour support UTF-8 complet : accents, emoji, caractères spéciaux)
Property Title As %Stream.GlobalCharacter [ Required ];

/// Contenu de l'article (texte enrichi HTML, stream pour supporter les images base64 inline volumineuses)
Property Content As %Stream.GlobalCharacter;

/// Auteur de l'article (stream pour support UTF-8)
Property Author As %Stream.GlobalCharacter;

/// Catégorie de l'article (stream pour support UTF-8)
Property Category As %Stream.GlobalCharacter;

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
/// Utilise %Get(key,,"stream") pour tous les champs avec UTF-8 : title, author, category, content
Method ImportFromDynObj(pJson As %DynamicObject) As %Status
{
    Set sc = $$$OK
    Try {
        // Title comme stream (supp rte UTF-8 complet : accents, emoji, etc.)
        If pJson.%IsDefined("title") {
            Set titleStream = pJson.%Get("title",,"stream")
            If $IsObject(titleStream) {
                Do titleStream.Rewind()
                Do ..Title.CopyFrom(titleStream)
            }
        }
        
        // Author comme stream (support UTF-8)
        If pJson.%IsDefined("author") {
            Set authorStream = pJson.%Get("author",,"stream")
            If $IsObject(authorStream) {
                Do authorStream.Rewind()
                Do ..Author.CopyFrom(authorStream)
            }
        }
        
        // Category comme stream (support UTF-8)
        If pJson.%IsDefined("category") {
            Set categoryStream = pJson.%Get("category",,"stream")
            If $IsObject(categoryStream) {
                Do categoryStream.Rewind()
                Do ..Category.CopyFrom(categoryStream)
            }
        }
        
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
        
        // Mise à jour de la date de modification
        Set ..DateModified = $ZDateTime($Horolog, 3)
        
        // Thumbnail : remplacer l'existant (pas d'accumulation)
        If pJson.%IsDefined("thumbnail") {
            Set thumbJson = pJson.%Get("thumbnail")
            If $IsObject(thumbJson) {
                Set thumb = ##class(Article.Data.ArticleImage).%New()
                Set sc = thumb.ImportFromDynObj(thumbJson)
                If $$$ISERR(sc) Return sc
                Set ..Thumbnail = thumb
            } Else {
                // Si thumbnail est null/vide, on le supprime
                Set ..Thumbnail = ""
            }
        }
        
        // Images array : vider puis réinsérer (le PUT remplace, pas accumule)
        If pJson.%IsDefined("images") {
            Do ..Images.Clear()
            Set imagesArray = pJson.%Get("images")
            If $IsObject(imagesArray) {
                Set iter = imagesArray.%GetIterator()
                While iter.%GetNext(.key, .imgJson) {
                    If $IsObject(imgJson) {
                        Set img = ##class(Article.Data.ArticleImage).%New()
                        Set imgSc = img.ImportFromDynObj(imgJson)
                        If $$$ISERR(imgSc) {
                            // Log l'erreur mais continue avec les autres images
                            Set errMsg = "Erreur import image #" _ key _ " : " _ $System.Status.GetErrorText(imgSc)
                            Do ##class(%SYS.System).WriteToConsoleLog(errMsg)
                            Continue
                        }
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

/// Retourne un %DynamicObject avec les valeurs des streams (pour listes, sans content/images)
/// Utilisé par l'API REST pour une sérialisation correcte des streams
Method ToListJSON() As %DynamicObject
{
    Set json = {}
    Set json.id = ..%Id()
    
    // Lire les streams avec décodage UTF-8 (stockés en octets UTF-8 bruts)
    Do ..Title.Rewind()
    Set json.title = $ZCONVERT(..Title.Read(), "I", "UTF8")
    
    Do ..Author.Rewind()
    Set json.author = $ZCONVERT(..Author.Read(), "I", "UTF8")
    
    Do ..Category.Rewind()
    Set json.category = $ZCONVERT(..Category.Read(), "I", "UTF8")
    
    Set json.dateCreated = ..DateCreated
    Set json.dateModified = ..DateModified
    Set json.status = ..Status
    Set json.source = ..Source
    
    Return json
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
<Value name="12">
<Value>Content</Value>
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
