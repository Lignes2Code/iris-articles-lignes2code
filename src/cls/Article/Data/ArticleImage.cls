/// Classe sérielle représentant une image d'article en buffer base64
/// Stockée directement dans l'objet Article au format JSON
Class Article.Data.ArticleImage Extends (%SerialObject, %JSON.Adaptor)
{

/// Nom du fichier image
Property Name As %String(MAXLEN = 500);

/// Type MIME de l'image (image/png, image/jpeg, image/gif, image/webp, etc.)
Property MimeType As %String(MAXLEN = 100);

/// Données de l'image encodées en base64 (stream pour supporter les grosses images)
Property Base64Data As %Stream.GlobalCharacter;

/// Mapping JSON
XData BasicReference [ XMLNamespace = "http://www.intersystems.com/jsonmapping" ]
{
<Mapping xmlns="http://www.intersystems.com/jsonmapping">
  <Property Name="Name" FieldName="name"/>
  <Property Name="MimeType" FieldName="mimeType"/>
  <Property Name="Base64Data" FieldName="data"/>
</Mapping>
}

/// Import stream-safe depuis un %DynamicObject (évite MAXSTRING)
Method ImportFromDynObj(pJson As %DynamicObject) As %Status
{
    Set sc = $$$OK
    Try {
        If pJson.%IsDefined("name") Set ..Name = pJson.%Get("name")
        If pJson.%IsDefined("mimeType") Set ..MimeType = pJson.%Get("mimeType")
        If pJson.%IsDefined("data") {
            Set dataStream = pJson.%Get("data",,"stream")
            If $IsObject(dataStream) {
                Do dataStream.Rewind()
                Do ..Base64Data.CopyFrom(dataStream)
            }
        }
    }
    Catch ex {
        Set sc = ex.AsStatus()
    }
    Return sc
}

/// Écrit l'URI data: directement vers la sortie courante (stream-safe)
Method WriteDataURI()
{
    Write "data:" _ ..MimeType _ ";base64,"
    Do ..Base64Data.Rewind()
    While '..Base64Data.AtEnd {
        Write ..Base64Data.Read(32000)
    }
}

/// Écrit la balise <img> HTML directement vers la sortie courante (stream-safe)
Method WriteImgTag()
{
    Set alt = $Select(..Name '= "": $ZConvert(..Name, "O", "HTML"), 1: "image")
    Write "<img src=""data:" _ ..MimeType _ ";base64,"
    Do ..Base64Data.Rewind()
    While '..Base64Data.AtEnd {
        Write ..Base64Data.Read(32000)
    }
    Write """ alt=""" _ alt _ """ />"
}

Storage Default
{
<Data name="ArticleImageState">
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>MimeType</Value>
</Value>
<Value name="3">
<Value>Base64Data</Value>
</Value>
</Data>
<State>ArticleImageState</State>
<StreamLocation>^Article.Data.ArticleImageS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
