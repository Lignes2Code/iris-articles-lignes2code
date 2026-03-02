/// Page CSP affichant le détail d'un article
/// Accessible via /web/articles/Article.Web.ArticleView.cls?id=123
Class Article.Web.ArticleView Extends Article.Web.Base
{

ClassMethod OnPage() As %Status
{
    Set sc = $$$OK
    Try {
        // Récupérer l'ID depuis les paramètres de requête
        Set pId = %request.Get("id")

        // Cas : pas d'ID fourni
        If pId = "" {
            Do ..DrawHead("Article non trouv&eacute;")
            Set urlList = ..Link("Article.Web.ArticleList.cls")
            &html<<body style="display:flex;justify-content:center;align-items:center;min-height:100vh;background:#f0f2f5;">
<div class="msg"><h1>400</h1><p>Param&egrave;tre 'id' manquant</p>
<p><a href="#(urlList)#">&#8592; Retour &agrave; la liste</a></p></div>
</body></html>>
            Return sc
        }

        // Cas : article inexistant
        If '##class(Article.Data.Article).%ExistsId(pId) {
            Set %response.Status = "404 Not Found"
            Do ..DrawHead("Article non trouv&eacute;")
            Set urlList = ..Link("Article.Web.ArticleList.cls")
            &html<<body style="display:flex;justify-content:center;align-items:center;min-height:100vh;background:#f0f2f5;">
<div class="msg"><h1>404</h1><p>Article ##(pId)# non trouv&eacute;</p>
<p><a href="#(urlList)#">&#8592; Retour &agrave; la liste</a></p></div>
</body></html>>
            Return sc
        }

        Set article = ##class(Article.Data.Article).%OpenId(pId)
        // Lire les streams une seule fois (décodage UTF-8 car stocké en octets bruts)
        Do article.Title.Rewind() Set titleText = $ZCONVERT(article.Title.Read(), "I", "UTF8")
        Do article.Author.Rewind() Set authorText = $ZCONVERT(article.Author.Read(), "I", "UTF8")
        Do article.Category.Rewind() Set categoryText = $ZCONVERT(article.Category.Read(), "I", "UTF8")
        
        Do ..DrawHead(titleText)
        Do ..DrawHeader(titleText)

        // Hero / Vignette
        &html<<div class="hero">>
        If $IsObject(article.Thumbnail) && (article.Thumbnail.Base64Data.Size > 0) {
            Write "<img "
            Write "alt=""" _ $ZConvert(titleText, "O", "HTML") _ """ "
            Write "src="""
            Do article.Thumbnail.WriteDataURI()
            Write """ />"
        }
        Set badgeClass = "badge-" _ article.Status
        &html<<div class="hero-overlay">
<h1>#($ZConvert(titleText, "O", "HTML"))#</h1>
<div class="meta">
<span>&#9998; #($ZConvert(authorText, "O", "HTML"))#</span>
<span>&#128197; #($Piece(article.DateCreated, " ", 1))#</span>
<span class="badge #(badgeClass)#">#($ZConvert(article.Status, "O", "HTML"))#</span>
</div>
</div>
</div>>

        Set urlList = ..Link("Article.Web.ArticleList.cls")
        Set urlEditParms("id") = pId
        Set urlEdit = ..Link("Article.Web.ArticleForm.cls", .urlEditParms)
        Set titleJS = $Replace($ZConvert(titleText, "O", "HTML"), "'", "&#39;")
        &html<<div class="container">
<div class="view-actions">
<a class="back" href="#(urlList)#">&#8592; Retour aux articles</a>
<div>
<a class="btn btn-edit auth-only" style="display:none;" href="#(urlEdit)#">&#9998; Modifier cet article</a>
<button class="btn btn-delete auth-only" style="display:none;" onclick="deleteArticle('#(pId)#', '#(titleJS)#'); return false;">&#128465; Supprimer</button>
</div>
</div>
<div class="content">>
        // Écrire le contenu HTML avec sanitisation basique (protection XSS)
        // Quill.js produit du HTML propre, mais on retire les balises dangereuses par sécurité
        If $IsObject(article.Content) && (article.Content.Size > 0) {
            Do article.Content.Rewind()
            While 'article.Content.AtEnd {
                Set chunk = article.Content.Read(32000)
                // Décoder les octets UTF-8 stockés dans le stream GlobalCharacter
                // (%Get("content",,"stream") retourne du UTF-8 brut, stocké tel quel)
                Set chunk = $ZCONVERT(chunk, "I", "UTF8")
                // Retirer les balises <script> et <iframe> (protection XSS)
                Set chunk = ..SanitizeHtml(chunk)
                Write chunk
            }
        } Else {
            &html<<p style="color:#999;font-style:italic;">Aucun contenu</p>>
        }
        &html<</div>>

        // Galerie d'images
        If article.Images.Count() > 0 {
            &html<<div class="content gallery">
<h3>&#128247; Images de l'article (#(article.Images.Count())#)</h3>
<div class="gallery-grid">>
            For i = 1:1:article.Images.Count() {
                Set img = article.Images.GetAt(i)
                If $IsObject(img) && (img.Base64Data.Size > 0) {
                    Do img.WriteImgTag()
                }
            }
            &html<</div>
</div>>
        }

        // Métadonnées
        &html<<div class="content">
<h3>&#128203; Informations</h3>
<table class="info-table">
<tr><td>ID</td><td>#(pId)#</td></tr>
<tr><td>Cat&eacute;gorie</td><td>#($ZConvert(categoryText, "O", "HTML"))#</td></tr>
<tr><td>Source</td><td>#($ZConvert(article.Source, "O", "HTML"))#</td></tr>
<tr><td>Cr&eacute;&eacute; le</td><td>#(article.DateCreated)#</td></tr>>
        If article.DateModified '= "" {
            &html<<tr><td>Modifi&eacute; le</td><td>#(article.DateModified)#</td></tr>>
        }
        &html<<tr><td>Images</td><td>#(article.Images.Count())# image(s)</td></tr>
</table>
</div>
</div>>

        Do ..DrawFooter()
    }
    Catch ex {
        Set sc = ex.AsStatus()
        &html<<html><body><h1>Erreur</h1><p>#($ZConvert(ex.DisplayString(), "O", "HTML"))#</p></body></html>>
    }
    Return sc
}

}
