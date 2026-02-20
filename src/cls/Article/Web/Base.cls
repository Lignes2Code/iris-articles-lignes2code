/// Classe de base abstraite pour les pages web CSP
/// Fournit le CSS commun, le header et le footer partagés
Class Article.Web.Base Extends %CSP.Page [ Abstract ]
{

Parameter CONTENTTYPE = "text/html";

Parameter CHARSET = "utf-8";

/// Écrit le début du document HTML avec le <head>
ClassMethod DrawHead(pTitle As %String = "Lignes2Code") As %Status
{
    &html<<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>#($ZConvert(pTitle, "O", "HTML"))# - Lignes2Code</title>>
    Do ..DrawCSS()
    &html<</head>
<body>>
    Return $$$OK
}

/// Écrit le CSS partagé entre toutes les pages
ClassMethod DrawCSS()
{
    &html<<style>
/* Reset & base */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f0f2f5; color: #1a1a2e; line-height: 1.6; }
/* Header */
header { background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%); color: #fff; padding: 2rem 1rem; text-align: center; }
header h1 { font-size: 2rem; font-weight: 700; margin-bottom: 0.3rem; }
header p { opacity: 0.8; font-size: 1rem; }
header nav { margin-top: 1rem; }
header nav a { color: #fff; text-decoration: none; margin: 0 0.8rem; opacity: 0.85; font-size: 0.95rem; }
header nav a:hover { opacity: 1; text-decoration: underline; }
/* Container & grid */
.container { max-width: 1100px; margin: 2rem auto; padding: 0 1rem; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 1.5rem; }
/* Cards */
.card { background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 12px rgba(0,0,0,0.08); transition: transform 0.2s, box-shadow 0.2s; }
.card:hover { transform: translateY(-4px); box-shadow: 0 8px 24px rgba(0,0,0,0.12); }
.card-thumb { width: 100%; height: 200px; object-fit: cover; background: #e0e0e0; display: flex; align-items: center; justify-content: center; color: #999; font-size: 3rem; }
.card-thumb img { width: 100%; height: 200px; object-fit: cover; }
.card-body { padding: 1.2rem; }
.card-body h2 { font-size: 1.15rem; margin-bottom: 0.5rem; }
.card-body h2 a { color: #0f3460; text-decoration: none; }
.card-body h2 a:hover { text-decoration: underline; }
/* Meta & badges */
.meta { font-size: 0.82rem; color: #777; margin-bottom: 0.6rem; }
.meta span { margin-right: 1rem; }
.badge { display: inline-block; padding: 0.15rem 0.6rem; border-radius: 20px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; }
.badge-published { background: #d4edda; color: #155724; }
.badge-draft { background: #fff3cd; color: #856404; }
.badge-archived { background: #f8d7da; color: #721c24; }
/* Hero (page détail) */
.hero { position: relative; width: 100%; min-height: 300px; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%); display: flex; align-items: flex-end; }
.hero img { position: absolute; top: 0; left: 0; width: 100%; height: 100%; object-fit: cover; opacity: 0.7; }
.hero-overlay { position: relative; z-index: 1; width: 100%; padding: 2rem; background: linear-gradient(transparent, rgba(0,0,0,0.7)); color: #fff; }
.hero-overlay h1 { font-size: 2.2rem; font-weight: 700; text-shadow: 0 2px 8px rgba(0,0,0,0.5); }
.hero-overlay .meta { margin-top: 0.5rem; font-size: 0.9rem; opacity: 0.9; }
.hero-overlay .meta span { margin-right: 1.2rem; }
/* Content */
.content { background: #fff; border-radius: 12px; padding: 2rem; box-shadow: 0 2px 12px rgba(0,0,0,0.06); margin-bottom: 2rem; }
.content img { max-width: 100%; height: auto; border-radius: 8px; margin: 1rem 0; }
.content h1, .content h2, .content h3 { margin: 1.2rem 0 0.6rem; color: #0f3460; }
.content p { margin-bottom: 1rem; }
/* Gallery */
.gallery { margin-top: 2rem; }
.gallery h3 { margin-bottom: 1rem; color: #0f3460; font-size: 1.2rem; }
.gallery-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 1rem; }
.gallery-grid img { width: 100%; height: 180px; object-fit: cover; border-radius: 8px; cursor: pointer; transition: transform 0.2s; }
.gallery-grid img:hover { transform: scale(1.03); }
/* Table info */
.info-table { width: 100%; border-collapse: collapse; margin-top: 1rem; font-size: 0.9rem; }
.info-table td { padding: 0.5rem 0.8rem; border-bottom: 1px solid #eee; }
.info-table td:first-child { font-weight: 600; color: #555; width: 160px; }
/* Divers */
.back { display: inline-block; margin-bottom: 1rem; color: #0f3460; text-decoration: none; font-weight: 600; }
.back:hover { text-decoration: underline; }
.empty { text-align: center; padding: 3rem; color: #999; }
.msg { text-align: center; }
.msg h1 { font-size: 4rem; color: #ccc; }
.msg p { color: #999; }
.msg a { color: #0f3460; }
footer { text-align: center; padding: 2rem; color: #999; font-size: 0.85rem; }
</style>>
}

/// Écrit le header de navigation commun
ClassMethod DrawHeader(pTitle As %String = "Articles", pSubtitle As %String = "")
{
    Set urlList = ..Link("Article.Web.ArticleList.cls")
    Set urlForm = ..Link("Article.Web.ArticleForm.cls")
    &html<<header>
<h1>&#128221; #($ZConvert(pTitle, "O", "HTML"))#</h1>>
    If pSubtitle '= "" {
        &html<<p>#($ZConvert(pSubtitle, "O", "HTML"))#</p>>
    } Else {
        &html<<p>Lignes2Code &mdash; Propuls&eacute; par InterSystems IRIS</p>>
    }
    &html<<nav>
<a href="#(urlList)#">&#127968; Tous les articles</a>
<a href="#(urlForm)#">&#10133; Nouvel article</a>
<a href="/api/articles/health">&#128154; API Health</a>
</nav>
</header>>
}

/// Écrit le footer commun
ClassMethod DrawFooter()
{
    &html<<footer>Articles &mdash; Lignes2Code &copy; #($Piece($ZDateTime($Horolog, 3), "-", 1))#</footer>
</body>
</html>>
}

}
