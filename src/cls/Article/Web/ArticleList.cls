/// Page CSP listant tous les articles
/// Accessible via /web/articles/Article.Web.ArticleList.cls
Class Article.Web.ArticleList Extends Article.Web.Base
{

ClassMethod OnPage() As %Status
{
    Set sc = $$$OK
    Try {
        Do ..DrawHead("Tous les articles")
        Do ..DrawHeader("Articles")

        &html<<div class="container">>

        // Charger les articles
        Set sql = "SELECT ID FROM Article_Data.Article ORDER BY DateCreated DESC"
        Set stmt = ##class(%SQL.Statement).%New()
        Set sc = stmt.%Prepare(sql)
        If $$$ISERR(sc) {
            &html<<p class="empty">Erreur lors du chargement des articles.</p>>
            Do ..DrawFooter()
            Return sc
        }

        Set rs = stmt.%Execute()
        Set count = 0
        &html<<div class="grid">>

        While rs.%Next() {
            Set id = rs.%Get("ID")
            Set article = ##class(Article.Data.Article).%OpenId(id)
            If '$IsObject(article) Continue
            Set count = count + 1

            // URL vers la page détail via Link()
            Set urlParms("id") = id
            Set viewURL = ..Link("Article.Web.ArticleView.cls", .urlParms)
            Set editURL = ..Link("Article.Web.ArticleForm.cls", .urlParms)

            // Préparer les valeurs HTML-safe
            Set badgeClass = "badge-" _ article.Status
            Set titleHTML = $ZConvert(article.Title, "O", "HTML")
            Set authorHTML = $ZConvert(article.Author, "O", "HTML")
            Set statusHTML = $ZConvert(article.Status, "O", "HTML")

            &html<<div class="card">
<div class="card-thumb">>
            If $IsObject(article.Thumbnail) && (article.Thumbnail.Base64Data.Size > 0) {
                Do article.Thumbnail.WriteImgTag()
            } Else {
                &html<&#128196;>
            }
            &html<</div>
<div class="card-body">
<h2><a href="#(viewURL)#">#(titleHTML)#</a></h2>
<div class="meta">
<span>&#9998; #(authorHTML)#</span>
<span>&#128197; #($Piece(article.DateCreated, " ", 1))#</span>
<span class="badge #(badgeClass)#">#(statusHTML)#</span>
</div>>
            If article.Category '= "" {
                &html<<div class="meta"><span>&#128193; #($ZConvert(article.Category, "O", "HTML"))#</span></div>>
            }
            &html<<div class="card-actions"><a href="#(editURL)#" class="btn-card-edit">&#9998; Modifier</a></div>>
            &html<</div>
</div>>
        }

        &html<</div>>

        If count = 0 {
            &html<<p class="empty">Aucun article pour le moment.</p>>
        }

        &html<</div>>
        Do ..DrawFooter()
    }
    Catch ex {
        Set sc = ex.AsStatus()
        &html<<html><body><h1>Erreur</h1><p>#($ZConvert(ex.DisplayString(), "O", "HTML"))#</p></body></html>>
    }
    Return sc
}

}
