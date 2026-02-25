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
<a href="#(viewURL)#" class="card-thumb">>
            If $IsObject(article.Thumbnail) && (article.Thumbnail.Base64Data.Size > 0) {
                Do article.Thumbnail.WriteImgTag()
            } Else {
                &html<&#128196;>
            }
            &html<</a>
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
            Set titleJS = $Replace(titleHTML, "'", "&#39;")
            &html<<div class="card-actions auth-only" style="display:none;"><a href="#(editURL)#" class="btn-card-edit">&#9998; Modifier</a><button class="btn-card-delete" onclick="deleteArticle('#(id)#', '#(titleJS)#'); return false;">&#128465; Supprimer</button></div>>
            &html<</div>
</div>>
        }

        &html<</div>>

        If count = 0 {
            &html<<p class="empty">Aucun article pour le moment.</p>>
        }

        &html<</div>>
        Do ..DrawFooter()

        // Script de polling pour mise à jour dynamique (toutes les 3s)
        Write "<script>", !
        Write "(function() {", !
        Write "    var lastChange = '';", !
        Write "    var pollInterval = 3000;", !
        Write "    function pollChanges() {", !
        Write "        fetch('/api/articles/articles/changes')", !
        Write "        .then(function(r) { return r.json(); })", !
        Write "        .then(function(data) {", !
        Write "            if (lastChange === '') { lastChange = data.lastChange || ''; return; }", !
        Write "            if (data.lastChange && data.lastChange !== lastChange) {", !
        Write "                lastChange = data.lastChange;", !
        Write "                refreshArticles();", !
        Write "            }", !
        Write "        })", !
        Write "        .catch(function() {});", !
        Write "    }", !
        Write "    function refreshArticles() {", !
        Write "        fetch('/api/articles/articles?size=100')", !
        Write "        .then(function(r) { return r.json(); })", !
        Write "        .then(function(data) {", !
        Write "            var grid = document.querySelector('.grid');", !
        Write "            if (!grid) {", !
        Write "                var container = document.querySelector('.container');", !
        Write "                if (!container) return;", !
        Write "                var empty = container.querySelector('.empty');", !
        Write "                if (empty) empty.remove();", !
        Write "                grid = document.createElement('div');", !
        Write "                grid.className = 'grid';", !
        Write "                container.appendChild(grid);", !
        Write "            }", !
        Write "            grid.innerHTML = '';", !
        Write "            if (!data.articles || data.articles.length === 0) {", !
        Write "                grid.innerHTML = '<p class=""empty"">Aucun article pour le moment.</p>';", !
        Write "                return;", !
        Write "            }", !
        Write "            data.articles.forEach(function(a) {", !
        Write "                var badge = 'badge-' + (a.status || 'draft');", !
        Write "                var viewUrl = 'Article.Web.ArticleView.cls?id=' + a.id;", !
        Write "                var editUrl = 'Article.Web.ArticleForm.cls?id=' + a.id;", !
        Write "                var title = a.title || 'Sans titre';", !
        Write "                var titleSafe = title.replace(/'/g, '&#39;');", !
        Write "                var card = '<div class=""card"">'", !
        Write "                    + '<a href=""' + viewUrl + '"" class=""card-thumb"">&#128196;</a>'", !
        Write "                    + '<div class=""card-body"">'", !
        Write "                    + '<h2><a href=""' + viewUrl + '"">' + title + '</a></h2>'", !
        Write "                    + '<div class=""meta"">'", !
        Write "                    + '<span>&#9998; ' + (a.author || '') + '</span>'", !
        Write "                    + '<span>&#128197; ' + (a.dateCreated || '').split(' ')[0] + '</span>'", !
        Write "                    + '<span class=""badge ' + badge + '"">' + (a.status || '') + '</span>'", !
        Write "                    + '</div>';", !
        Write "                if (a.category) card += '<div class=""meta""><span>&#128193; ' + a.category + '</span></div>';", !
        Write "                card += '<div class=""card-actions auth-only"" style=""display:none;"">'", !
        Write "                    + '<a href=""' + editUrl + '"" class=""btn-card-edit"">&#9998; Modifier</a>'", !
        Write "                    + '<button class=""btn-card-delete"" onclick=""deleteArticle(\\'' + a.id + '\\', \\'' + titleSafe + '\\'); return false;"">&#128465; Supprimer</button>'", !
        Write "                    + '</div></div></div>';", !
        Write "                grid.innerHTML += card;", !
        Write "            });", !
        Write "            if (typeof checkAuth === 'function') checkAuth();", !
        Write "        })", !
        Write "        .catch(function() {});", !
        Write "    }", !
        Write "    setInterval(pollChanges, pollInterval);", !
        Write "    pollChanges();", !
        Write "})();", !
        Write "</script>", !
    }
    Catch ex {
        Set sc = ex.AsStatus()
        &html<<html><body><h1>Erreur</h1><p>#($ZConvert(ex.DisplayString(), "O", "HTML"))#</p></body></html>>
    }
    Return sc
}

}
