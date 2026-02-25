/// Classe de base abstraite pour les pages web CSP
/// Fournit le CSS commun, le header et le footer partagés
Class Article.Web.Base Extends %CSP.Page [ Abstract ]
{

Parameter CONTENTTYPE = "text/html";

Parameter CHARSET = "utf-8";

/// Headers de sécurité HTTP appliqués à toutes les pages
ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
    // Protection XSS : empêche le navigateur de deviner le type MIME
    Do %response.SetHeader("X-Content-Type-Options", "nosniff")
    // Protection contre le clickjacking
    Do %response.SetHeader("X-Frame-Options", "SAMEORIGIN")
    // XSS filter du navigateur
    Do %response.SetHeader("X-XSS-Protection", "1; mode=block")
    // Referrer policy
    Do %response.SetHeader("Referrer-Policy", "strict-origin-when-cross-origin")
    Return 1
}

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
.card-thumb { width: 100%; height: 200px; background: #1a1a2e; display: flex; align-items: center; justify-content: center; color: #999; font-size: 3rem; }
.card-thumb img { width: 100%; height: 200px; object-fit: contain; }
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
.hero img { position: absolute; top: 0; left: 0; width: 100%; height: 100%; object-fit: contain; opacity: 0.7; }
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
.view-actions { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }
.btn-edit {
    display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.5rem 1.2rem;
    background: linear-gradient(135deg, #0f3460, #16213e); color: #fff; border-radius: 8px;
    text-decoration: none; font-weight: 600; font-size: 0.9rem; transition: all 0.2s;
}
.btn-edit:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(15,52,96,0.3); }
.card-actions { margin-top: 0.8rem; padding-top: 0.6rem; border-top: 1px solid #eee; }
.btn-card-edit {
    display: inline-flex; align-items: center; gap: 0.3rem; padding: 0.3rem 0.8rem;
    background: #f0f4ff; color: #0f3460; border-radius: 6px; text-decoration: none;
    font-weight: 600; font-size: 0.8rem; transition: all 0.2s;
}
.btn-card-edit:hover { background: #0f3460; color: #fff; }
.empty { text-align: center; padding: 3rem; color: #999; }
.msg { text-align: center; }
.msg h1 { font-size: 4rem; color: #ccc; }
.msg p { color: #999; }
.msg a { color: #0f3460; }
footer { text-align: center; padding: 2rem; color: #999; font-size: 0.85rem; }
</style>>
}

/// Écrit le header de navigation commun
/// Inclut un indicateur de connexion (login/logout) basé sur localStorage
ClassMethod DrawHeader(pTitle As %String = "Articles", pSubtitle As %String = "")
{
    Set urlList = ..Link("Article.Web.ArticleList.cls")
    Set urlForm = ..Link("Article.Web.ArticleForm.cls")
    Set urlLogin = ..Link("Article.Web.Login.cls")
    &html<<header>
<h1>&#128221; #($ZConvert(pTitle, "O", "HTML"))#</h1>>
    If pSubtitle '= "" {
        &html<<p>#($ZConvert(pSubtitle, "O", "HTML"))#</p>>
    } Else {
        &html<<p>Lignes2Code &mdash; Propuls&eacute; par InterSystems IRIS</p>>
    }
    &html<<nav>
<a href="#(urlList)#">&#127968; Tous les articles</a>
<a href="#(urlForm)#" class="auth-only" style="display:none;">&#10133; Nouvel article</a>
<a href="/api/articles/health">&#128154; API Health</a>
<a href="#(urlLogin)#" id="nav-login" class="noauth-only">&#128274; Connexion</a>
<a href="#" id="nav-logout" class="auth-only" style="display:none;" onclick="doLogout(); return false;">&#128275; <span id="nav-user"></span> &mdash; D&eacute;connexion</a>
</nav>
</header>
<script>
function checkAuth() {
    var token = localStorage.getItem('jwt_token');
    var user = localStorage.getItem('jwt_user');
    var authEls = document.querySelectorAll('.auth-only');
    var noauthEls = document.querySelectorAll('.noauth-only');
    if (token && user) {
        for (var i = 0; i < authEls.length; i++) authEls[i].style.display = '';
        for (var i = 0; i < noauthEls.length; i++) noauthEls[i].style.display = 'none';
        var userEl = document.getElementById('nav-user');
        if (userEl) userEl.textContent = user;
    } else {
        for (var i = 0; i < authEls.length; i++) authEls[i].style.display = 'none';
        for (var i = 0; i < noauthEls.length; i++) noauthEls[i].style.display = '';
    }
}
function doLogout() {
    localStorage.removeItem('jwt_token');
    localStorage.removeItem('jwt_user');
    localStorage.removeItem('jwt_roles');
    checkAuth();
    window.location.reload();
}
function getAuthHeaders() {
    var token = localStorage.getItem('jwt_token');
    var headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = 'Bearer ' + token;
    return headers;
}
function isAuthenticated() {
    return !!localStorage.getItem('jwt_token');
}
checkAuth();
</script>>
}

/// Écrit le footer commun
ClassMethod DrawFooter()
{
    &html<<footer>Articles &mdash; Lignes2Code &copy; #($Piece($ZDateTime($Horolog, 3), "-", 1))#</footer>
</body>
</html>>
}

/// Sanitise un fragment HTML en retirant les balises dangereuses
/// Retire <script>, </script>, <iframe>, </iframe> et les event handlers on*=""
ClassMethod SanitizeHtml(pHtml As %String) As %String
{
    Set result = pHtml
    // Retirer les balises <script>...</script> et leur contenu
    // Pattern simplifié : retirer les balises ouvrantes/fermantes
    Set result = ..StripTag(result, "script")
    Set result = ..StripTag(result, "iframe")
    Set result = ..StripTag(result, "object")
    Set result = ..StripTag(result, "embed")
    // Retirer les event handlers inline (onerror, onclick, onload, etc.)
    // Remplacer " on" par " data-blocked-" dans les attributs
    Set result = ..StripEventHandlers(result)
    Return result
}

/// Retire les balises ouvrantes et fermantes d'un type donné (insensible à la casse)
ClassMethod StripTag(pHtml As %String, pTag As %String) As %String
{
    Set result = pHtml
    Set tagLower = $ZConvert(pTag, "L")
    Set tagUpper = $ZConvert(pTag, "U")
    // Balises ouvrantes : <script...> (avec ou sans attributs)
    Set pos = 1
    For {
        Set posLower = $Find(result, "<" _ tagLower, pos)
        Set posUpper = $Find(result, "<" _ tagUpper, pos)
        // Prendre la première occurrence trouvée
        If (posLower = 0) && (posUpper = 0) Quit
        If posLower = 0 { Set startPos = posUpper }
        ElseIf posUpper = 0 { Set startPos = posLower }
        Else { Set startPos = $Select(posLower < posUpper: posLower, 1: posUpper) }
        // Trouver la fin de la balise
        Set endPos = $Find(result, ">", startPos)
        If endPos = 0 Quit
        // Retirer la balise
        Set result = $Extract(result, 1, startPos - $Length(tagLower) - 2) _ $Extract(result, endPos, *)
        Set pos = startPos - $Length(tagLower) - 1
        If pos < 1 Set pos = 1
    }
    // Balises fermantes : </script>
    Set result = $Replace(result, "</" _ tagLower _ ">", "")
    Set result = $Replace(result, "</" _ tagUpper _ ">", "")
    Return result
}

/// Retire les event handlers inline (onclick, onerror, onload, etc.)
ClassMethod StripEventHandlers(pHtml As %String) As %String
{
    Set result = pHtml
    // Remplacer " on" suivi d'un mot et "=" par " data-blocked-"
    // Approche simple : traiter les cas les plus courants
    Set events = $ListBuild("onclick","onerror","onload","onmouseover","onmouseout","onfocus","onblur","onsubmit","onchange","oninput","onkeydown","onkeyup","onkeypress")
    Set ptr = 0
    While $ListNext(events, ptr, event) {
        Set result = $Replace(result, " " _ event _ "=", " data-blocked-" _ event _ "=")
        Set result = $Replace(result, " " _ $ZConvert(event, "U") _ "=", " data-blocked-" _ event _ "=")
    }
    Return result
}

}
