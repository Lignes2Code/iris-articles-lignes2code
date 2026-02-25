/// Page CSP : Formulaire de création/modification d'article avec éditeur enrichi
/// Création : génère un fichier JSON dans data/input/ traité par la production
/// Modification : met à jour l'article directement en base (?id=X)
Class Article.Web.ArticleForm Extends Article.Web.Base
{

ClassMethod OnPage() As %Status
{
    Set sc = $$$OK
    Try {
        // Traitement du POST
        If %request.Method = "POST" {
            Set sc = ..ProcessForm()
            Return sc
        }

        // Détecter le mode : édition si ?id=X
        Set editId = %request.Get("id")
        Set isEdit = (editId '= "") && ##class(Article.Data.Article).%ExistsId(editId)

        If (editId '= "") && 'isEdit {
            Set %response.Status = "404 Not Found"
            Do ..DrawHead("Article non trouv&eacute;")
            Set urlList = ..Link("Article.Web.ArticleList.cls")
            &html<
<div style="display:flex;justify-content:center;align-items:center;min-height:80vh;">
<div class="msg"><h1>404</h1><p>Article #(editId)# non trouv&eacute;</p>
<p><a href="#(urlList)#">&#8592; Retour &agrave; la liste</a></p></div>
</div>
</body></html>>
            Return sc
        }

        // Charger l'article existant si mode édition
        If isEdit {
            Set article = ##class(Article.Data.Article).%OpenId(editId)
            Set pageTitle = "Modifier l'article"
        } Else {
            Set article = ""
            Set pageTitle = "Nouvel article"
        }

        // Affichage du formulaire (GET)
        Do ..DrawHead(pageTitle)
        // Charger Quill CSS tôt pour un rendu correct de la toolbar
        Write "<link href=""https://cdn.jsdelivr.net/npm/quill@2.0.3/dist/quill.snow.css"" rel=""stylesheet"" />", !
        Do ..DrawHeader(pageTitle)
        Do ..DrawFormCSS()

        &html<<div class="container">
<form id="articleForm" method="POST" enctype="application/x-www-form-urlencoded">>
        // Champ caché pour l'ID en mode édition
        If isEdit {
            &html<<input type="hidden" id="editId" value="#(editId)#" />>
        }

        // Pré-remplir les valeurs
        Set valTitle = $Select(isEdit: $ZConvert(article.Title, "O", "HTML"), 1: "")
        Set valAuthor = $Select(isEdit: $ZConvert(article.Author, "O", "HTML"), 1: "")
        Set valCategory = $Select(isEdit: $ZConvert(article.Category, "O", "HTML"), 1: "")
        Set valStatus = $Select(isEdit: article.Status, 1: "draft")

        &html<
<div class="form-group">
<label for="title">Titre *</label>
<input type="text" id="title" name="title" required placeholder="Titre de l'article" value="#(valTitle)#" />
</div>

<div class="form-row">
<div class="form-group">
<label for="author">Auteur *</label>
<input type="text" id="author" name="author" required placeholder="Nom de l'auteur" value="#(valAuthor)#" />
</div>
<div class="form-group">
<label for="category">Cat&eacute;gorie</label>
<input type="text" id="category" name="category" placeholder="Ex: technique, tutoriel..." value="#(valCategory)#" />
</div>
<div class="form-group">
<label for="status">Statut</label>
<select id="status" name="status">
<option value="draft" #($Select(valStatus="draft": "selected", 1: ""))#>Brouillon</option>
<option value="published" #($Select(valStatus="published": "selected", 1: ""))#>Publi&eacute;</option>
<option value="archived" #($Select(valStatus="archived": "selected", 1: ""))#>Archiv&eacute;</option>
</select>
</div>
</div>>

        &html<
<div class="form-group">
<label>Image d'en-t&ecirc;te (vignette) *</label>
<label for="thumbFile" class="thumb-upload" id="thumbUpload">
<div class="thumb-preview" id="thumbPreview">>
        // En mode édition avec thumbnail existant, l'afficher
        If isEdit && $IsObject(article.Thumbnail) && (article.Thumbnail.Base64Data.Size > 0) {
            &html<<span id="thumbPlaceholder" style="display:none;">&#128247; Cliquez ou glissez une image ici</span>>
            Write "<img id=""thumbImg"" src="""
            Do article.Thumbnail.WriteDataURI()
            Write """ />"
        } Else {
            &html<<span id="thumbPlaceholder">&#128247; Cliquez ou glissez une image ici</span>
<img id="thumbImg" style="display:none;" />>
        }
        &html<</div>
</label>
<input type="file" id="thumbFile" accept="image/*" style="display:none;" />
<input type="hidden" id="thumbBase64" name="thumbBase64" />
<input type="hidden" id="thumbMime" name="thumbMime" />
<input type="hidden" id="thumbName" name="thumbName" />>

        &html<
<div id="resizePanel" class="resize-panel" style="display:none;">
<div class="resize-header">
<span>&#9881; Redimensionner l'image</span>
<span id="resizeOrigInfo" class="resize-info"></span>
</div>
<div class="resize-controls">
<div class="resize-presets">
<button type="button" class="preset-btn" data-w="800" data-h="400">Carte (800&times;400)</button>
<button type="button" class="preset-btn" data-w="1200" data-h="400">Hero (1200&times;400)</button>
<button type="button" class="preset-btn" data-w="600" data-h="600">Carr&eacute; (600&times;600)</button>
<button type="button" class="preset-btn" data-w="0" data-h="0">Original</button>
</div>
<div class="resize-inputs">
<label>Largeur <input type="number" id="resizeW" min="50" max="4000" /> px</label>
<label>Hauteur <input type="number" id="resizeH" min="50" max="4000" /> px</label>
<label class="resize-lock"><input type="checkbox" id="resizeLock" checked /> &#128279; Ratio</label>
</div>
<div class="resize-slider">
<label>&#128270; &Eacute;chelle : <span id="resizePercent">100</span>%</label>
<input type="range" id="resizeScale" min="10" max="100" value="100" />
</div>
</div>
<div class="resize-preview-area">
<canvas id="resizeCanvas"></canvas>
</div>
<div class="resize-actions">
<button type="button" class="btn btn-primary btn-sm" id="resizeApply">&#10003; Appliquer</button>
<button type="button" class="btn btn-secondary btn-sm" id="resizeReset">&#8634; R&eacute;initialiser</button>
</div>
</div>
</div>

<div class="form-group">
<label>Contenu de l'article *</label>
<div id="editor"></div>
<input type="hidden" id="content" name="content" />
</div>

<div class="form-actions">
<button type="submit" class="btn btn-primary" id="submitBtn">>
        If isEdit {
            &html<&#128190; Enregistrer les modifications>
        } Else {
            &html<&#128190; G&eacute;n&eacute;rer le fichier JSON>
        }
        &html<</button>
<a href="#(..Link("Article.Web.ArticleList.cls"))#" class="btn btn-secondary">Annuler</a>
</div>

</form>
</div>>

        // Quill.js (CSS déjà chargé en haut de page)
        Write "<script src=""https://cdn.jsdelivr.net/npm/quill@2.0.3/dist/quill.js""></script>", !

        // Scripts via Write (pas &html) pour éviter les conflits avec > et {}
        Do ..DrawScripts(isEdit, $Select(isEdit: article, 1: ""))

        Do ..DrawFooter()
    }
    Catch ex {
        Set sc = ex.AsStatus()
        &html<<html><body><h1>Erreur</h1><p>#($ZConvert(ex.DisplayString(), "O", "HTML"))#</p></body></html>>
    }
    Return sc
}

/// Traite le POST : écrit le JSON dans data/input/
ClassMethod ProcessForm() As %Status
{
    Set sc = $$$OK
    Set %response.ContentType = "application/json"
    Set %response.CharSet = "utf-8"
    Try {
        // Vérifier l'authentification JWT
        Set token = ##class(Article.Auth.JWT).ExtractBearerToken(%request)
        If token = "" {
            Set %response.Status = "401 Unauthorized"
            Set errObj = ##class(%DynamicObject).%New()
            Set errObj.error = "Authentification requise"
            Write errObj.%ToJSON()
            Return $$$OK
        }
        Set claims = ##class(Article.Auth.JWT).ValidateToken(token, .jwtStatus)
        If '$IsObject(claims) {
            Set %response.Status = "401 Unauthorized"
            Set errObj = ##class(%DynamicObject).%New()
            Set errObj.error = "Token invalide: " _ $System.Status.GetErrorText(jwtStatus)
            Write errObj.%ToJSON()
            Return $$$OK
        }
        // Lire le body comme un stream (évite MAXSTRING pour les gros JSON avec images base64)
        Set body = %request.Content
        If '$IsObject(body) {
            Set r = ##class(%DynamicObject).%New()
            Set r.success = 0
            Set r.error = "Corps de requête vide"
            Write r.%ToJSON()
            Return sc
        }

        // Copier le body dans un stream temporaire pour pouvoir le relire
        Set stream = ##class(%Stream.TmpCharacter).%New()
        While 'body.AtEnd {
            Set chunk = body.Read(32000)
            Do stream.Write(chunk)
        }
        Do stream.Rewind()

        If stream.Size = 0 {
            Set r = ##class(%DynamicObject).%New()
            Set r.success = 0
            Set r.error = "Données JSON vides"
            Write r.%ToJSON()
            Return sc
        }

        // Parser le JSON depuis le stream (%DynamicObject gère les gros streams nativement)
        Set jsonObj = ##class(%DynamicObject).%FromJSON(stream)
        Set title = jsonObj.%Get("title")
        Do stream.Rewind()

        If title = "" {
            Set r = ##class(%DynamicObject).%New()
            Set r.success = 0
            Set r.error = "Titre manquant"
            Write r.%ToJSON()
            Return sc
        }

        // Générer le nom de fichier
        Set ts = $ZDateTime($Horolog, 3, 1)
        Set ts = $Replace(ts, " ", "_")
        Set ts = $Replace(ts, ":", ".")
        // Nettoyer le titre pour le nom de fichier
        Set cleanTitle = $ZConvert(title, "L")
        Set cleanTitle = $Replace(cleanTitle, " ", "-")
        // Limiter à 50 caractères
        If $Length(cleanTitle) > 50 Set cleanTitle = $Extract(cleanTitle, 1, 50)
        Set fileName = cleanTitle _ "_" _ ts _ ".json"

        // Écrire le stream directement dans data/input/
        Set inputDir = "/home/irisowner/data/input/"
        Set filePath = inputDir _ fileName

        Set fileStream = ##class(%Stream.FileCharacter).%New()
        Set sc = fileStream.LinkToFile(filePath)
        If $$$ISERR(sc) {
            Set r = ##class(%DynamicObject).%New()
            Set r.success = 0
            Set r.error = "Impossible de créer le fichier: " _ $System.Status.GetErrorText(sc)
            Write r.%ToJSON()
            Return $$$OK
        }
        // Copier le stream du body vers le fichier par chunks
        Do stream.Rewind()
        While 'stream.AtEnd {
            Set chunk = stream.Read(32000)
            Do fileStream.Write(chunk)
        }
        Set sc = fileStream.%Save()
        If $$$ISERR(sc) {
            Set r = ##class(%DynamicObject).%New()
            Set r.success = 0
            Set r.error = "Erreur d'écriture: " _ $System.Status.GetErrorText(sc)
            Write r.%ToJSON()
            Return $$$OK
        }

        Set response = ##class(%DynamicObject).%New()
        Set response.success = 1
        Set response.message = "Fichier JSON généré avec succès"
        Set response.fileName = fileName
        Write response.%ToJSON()
    }
    Catch ex {
        Set r = ##class(%DynamicObject).%New()
        Set r.success = 0
        Set r.error = $ZConvert(ex.DisplayString(), "O", "JS")
        Write r.%ToJSON()
    }
    Return $$$OK
}

/// Scripts JavaScript du formulaire (via Write pour éviter les conflits &html avec > et {})
ClassMethod DrawScripts(isEdit As %Boolean, article As Article.Data.Article = "")
{
    Set q = $Char(34) // guillemet double
    Set nl = $Char(10) // nouvelle ligne
    Set loginUrl = ..Link("Article.Web.Login.cls")
    Set listUrl = ..Link("Article.Web.ArticleList.cls")

    Write "<script>", nl

    // Initialiser Quill avec toolbar intégrée (générée par Quill, pas de HTML custom)
    Write "var quill = new Quill('#editor', {", nl
    Write "    modules: {", nl
    Write "        toolbar: [", nl
    Write "            [{ header: [1, 2, 3, false] }],", nl
    Write "            ['bold', 'italic', 'underline', 'strike'],", nl
    Write "            [{ list: 'ordered' }, { list: 'bullet' }],", nl
    Write "            ['blockquote', 'code-block'],", nl
    Write "            ['link', 'image'],", nl
    Write "            [{ color: [] }, { background: [] }],", nl
    Write "            [{ align: [] }],", nl
    Write "            ['clean']", nl
    Write "        ]", nl
    Write "    },", nl
    Write "    theme: 'snow',", nl
    Write "    placeholder: 'R\u00e9digez votre article ici...'", nl
    Write "});", nl

    // Gestionnaire personnalisé d'insertion d'images dans l'éditeur
    Write "var qlToolbar = quill.getModule('toolbar');", nl
    Write "qlToolbar.addHandler('image', function() {", nl
    Write "    var imgInput = document.createElement('input');", nl
    Write "    imgInput.type = 'file'; imgInput.accept = 'image/*';", nl
    Write "    imgInput.click();", nl
    Write "    imgInput.onchange = function() {", nl
    Write "        if (!imgInput.files.length) return;", nl
    Write "        var reader = new FileReader();", nl
    Write "        reader.onload = function(ev) {", nl
    Write "            var range = quill.getSelection(true);", nl
    Write "            quill.insertEmbed(range.index, 'image', ev.target.result);", nl
    Write "            quill.setSelection(range.index + 1);", nl
    Write "        };", nl
    Write "        reader.readAsDataURL(imgInput.files[0]);", nl
    Write "    };", nl
    Write "});", nl

    // Redimensionnement en temps réel des images dans l'éditeur
    Write "var editorOverlay = null, editorImgTarget = null;", nl
    Write "quill.root.addEventListener('click', function(ev) {", nl
    Write "    if (ev.target && ev.target.tagName === 'IMG') { showEditorResize(ev.target); }", nl
    Write "    else { hideEditorResize(); }", nl
    Write "});", nl
    Write "function showEditorResize(img) {", nl
    Write "    hideEditorResize();", nl
    Write "    editorImgTarget = img;", nl
    Write "    img.style.outline = '2px solid #0f3460';", nl
    Write "    editorOverlay = document.createElement('div');", nl
    Write "    editorOverlay.className = 'editor-resize-overlay';", nl
    Write "    var handle = document.createElement('div');", nl
    Write "    handle.className = 'editor-resize-handle';", nl
    Write "    editorOverlay.appendChild(handle);", nl
    Write "    var dims = document.createElement('div');", nl
    Write "    dims.className = 'editor-resize-dims';", nl
    Write "    dims.textContent = (img.width || img.naturalWidth) + ' \u00d7 ' + (img.height || img.naturalHeight);", nl
    Write "    editorOverlay.appendChild(dims);", nl
    Write "    var edEl = quill.root;", nl
    Write "    var ir = img.getBoundingClientRect(), er = edEl.getBoundingClientRect();", nl
    Write "    editorOverlay.style.left = (ir.left - er.left + edEl.scrollLeft) + 'px';", nl
    Write "    editorOverlay.style.top = (ir.top - er.top + edEl.scrollTop) + 'px';", nl
    Write "    editorOverlay.style.width = img.width + 'px';", nl
    Write "    editorOverlay.style.height = img.height + 'px';", nl
    Write "    edEl.appendChild(editorOverlay);", nl
    Write "    handle.addEventListener('mousedown', function(me) {", nl
    Write "        me.preventDefault(); me.stopPropagation();", nl
    Write "        var sx = me.clientX, sw = img.width || img.naturalWidth;", nl
    Write "        var rat = (img.height || img.naturalHeight) / sw;", nl
    Write "        function onM(e2) {", nl
    Write "            var nw = Math.max(30, sw + e2.clientX - sx);", nl
    Write "            var nh = Math.round(nw * rat);", nl
    Write "            img.setAttribute('width', nw); img.setAttribute('height', nh);", nl
    Write "            img.style.width = nw + 'px'; img.style.height = nh + 'px';", nl
    Write "            editorOverlay.style.width = nw + 'px'; editorOverlay.style.height = nh + 'px';", nl
    Write "            dims.textContent = nw + ' \u00d7 ' + nh;", nl
    Write "        }", nl
    Write "        function onU() { document.removeEventListener('mousemove', onM); document.removeEventListener('mouseup', onU); }", nl
    Write "        document.addEventListener('mousemove', onM);", nl
    Write "        document.addEventListener('mouseup', onU);", nl
    Write "    });", nl
    Write "}", nl
    Write "function hideEditorResize() {", nl
    Write "    if (editorOverlay) { editorOverlay.remove(); editorOverlay = null; }", nl
    Write "    if (editorImgTarget) { editorImgTarget.style.outline = ''; editorImgTarget = null; }", nl
    Write "}", nl
    Write "quill.root.addEventListener('scroll', hideEditorResize);", nl

    // En mode édition : injecter le contenu existant
    If isEdit && $IsObject(article) {
        // Contenu dans Quill
        Write "quill.root.innerHTML = "
        If $IsObject(article.Content) && (article.Content.Size > 0) {
            Do article.Content.Rewind()
            Write q
            While 'article.Content.AtEnd {
                Set chunk = article.Content.Read(32000)
                // Décoder les octets UTF-8 stockés dans le stream GlobalCharacter
                Set chunk = $ZCONVERT(chunk, "I", "UTF8")
                Set chunk = $Replace(chunk, "\", "\\")
                Set chunk = $Replace(chunk, q, "\" _ q)
                Set chunk = $Replace(chunk, $Char(10), "\n")
                Set chunk = $Replace(chunk, $Char(13), "\r")
                Write chunk
            }
            Write q
        } Else {
            Write "''"
        }
        Write ";", nl

        // Pré-remplir les champs du thumbnail
        If $IsObject(article.Thumbnail) && (article.Thumbnail.Base64Data.Size > 0) {
            Write "document.getElementById('thumbMime').value = '" _ $ZConvert(article.Thumbnail.MimeType, "O", "JS") _ "';", nl
            Write "document.getElementById('thumbName').value = '" _ $ZConvert(article.Thumbnail.Name, "O", "JS") _ "';", nl
            Write "document.getElementById('thumbBase64').value = '"
            Do article.Thumbnail.Base64Data.Rewind()
            While 'article.Thumbnail.Base64Data.AtEnd {
                Write article.Thumbnail.Base64Data.Read(32000)
            }
            Write "';", nl
        }
    }

    // Variables DOM
    Write "var thumbUpload = document.getElementById('thumbUpload');", nl
    Write "var thumbFile = document.getElementById('thumbFile');", nl
    Write "var thumbImg = document.getElementById('thumbImg');", nl
    Write "var thumbPlaceholder = document.getElementById('thumbPlaceholder');", nl
    // Clic géré nativement par <label for="thumbFile"> — pas de JS nécessaire
    Write "thumbUpload.addEventListener('dragenter', function(e) { e.preventDefault(); e.stopPropagation(); });", nl
    Write "thumbUpload.addEventListener('dragover', function(e) { e.preventDefault(); e.stopPropagation(); this.classList.add('dragover'); });", nl
    Write "thumbUpload.addEventListener('dragleave', function(e) { e.stopPropagation(); this.classList.remove('dragover'); });", nl
    Write "thumbUpload.addEventListener('drop', function(e) {", nl
    Write "    e.preventDefault(); e.stopPropagation(); this.classList.remove('dragover');", nl
    Write "    if (e.dataTransfer.files.length) handleThumbFile(e.dataTransfer.files[0]);", nl
    Write "});", nl
    Write "thumbFile.addEventListener('change', function() {", nl
    Write "    if (this.files.length) handleThumbFile(this.files[0]);", nl
    Write "});", nl

    // Variables resize
    Write "var resizePanel = document.getElementById('resizePanel');", nl
    Write "var resizeCanvas = document.getElementById('resizeCanvas');", nl
    Write "var resizeCtx = resizeCanvas.getContext('2d');", nl
    Write "var resizeW = document.getElementById('resizeW');", nl
    Write "var resizeH = document.getElementById('resizeH');", nl
    Write "var resizeLock = document.getElementById('resizeLock');", nl
    Write "var resizeScale = document.getElementById('resizeScale');", nl
    Write "var resizePercent = document.getElementById('resizePercent');", nl
    Write "var resizeOrigInfo = document.getElementById('resizeOrigInfo');", nl
    Write "var originalImage = null;", nl
    Write "var origW = 0, origH = 0;", nl
    Write "var currentThumbFile = null;", nl

    // handleThumbFile
    Write "function handleThumbFile(file) {", nl
    Write "    if (!file.type.startsWith('image/')) { alert('Veuillez choisir une image.'); return; }", nl
    Write "    thumbUpload.classList.remove('thumb-error');", nl
    Write "    currentThumbFile = file;", nl
    Write "    var reader = new FileReader();", nl
    Write "    reader.onload = function(e) {", nl
    Write "        originalImage = new Image();", nl
    Write "        originalImage.onload = function() {", nl
    Write "            origW = originalImage.naturalWidth;", nl
    Write "            origH = originalImage.naturalHeight;", nl
    Write "            resizeOrigInfo.textContent = 'Original : ' + origW + ' \u00d7 ' + origH + ' px';", nl
    Write "            resizeW.value = origW; resizeH.value = origH;", nl
    Write "            resizeScale.value = 100; resizePercent.textContent = '100';", nl
    Write "            resizePanel.style.display = 'block';", nl
    Write "            drawResizePreview(); applyResizedImage();", nl
    Write "        };", nl
    Write "        originalImage.src = e.target.result;", nl
    Write "    };", nl
    Write "    reader.readAsDataURL(file);", nl
    Write "}", nl

    // drawResizePreview
    Write "function drawResizePreview() {", nl
    Write "    if (!originalImage) return;", nl
    Write "    var w = parseInt(resizeW.value) || origW;", nl
    Write "    var h = parseInt(resizeH.value) || origH;", nl
    Write "    var maxPrev = 500;", nl
    Write "    var scale = Math.min(maxPrev / w, maxPrev / h, 1);", nl
    Write "    resizeCanvas.width = Math.round(w * scale);", nl
    Write "    resizeCanvas.height = Math.round(h * scale);", nl
    Write "    resizeCtx.clearRect(0, 0, resizeCanvas.width, resizeCanvas.height);", nl
    Write "    resizeCtx.drawImage(originalImage, 0, 0, resizeCanvas.width, resizeCanvas.height);", nl
    Write "}", nl

    // applyResizedImage
    Write "function applyResizedImage() {", nl
    Write "    if (!originalImage) return;", nl
    Write "    var w = parseInt(resizeW.value) || origW;", nl
    Write "    var h = parseInt(resizeH.value) || origH;", nl
    Write "    var tmpCanvas = document.createElement('canvas');", nl
    Write "    tmpCanvas.width = w; tmpCanvas.height = h;", nl
    Write "    var tmpCtx = tmpCanvas.getContext('2d');", nl
    Write "    tmpCtx.drawImage(originalImage, 0, 0, w, h);", nl
    Write "    var mime = currentThumbFile ? currentThumbFile.type : 'image/jpeg';", nl
    Write "    var outMime = (mime === 'image/png') ? 'image/png' : 'image/jpeg';", nl
    Write "    var quality = (outMime === 'image/jpeg') ? 0.92 : undefined;", nl
    Write "    var dataURL = tmpCanvas.toDataURL(outMime, quality);", nl
    Write "    thumbImg.src = dataURL; thumbImg.style.display = 'block';", nl
    Write "    thumbPlaceholder.style.display = 'none';", nl
    Write "    var base64 = dataURL.split(',')[1];", nl
    Write "    document.getElementById('thumbBase64').value = base64;", nl
    Write "    document.getElementById('thumbMime').value = outMime;", nl
    Write "    document.getElementById('thumbName').value = currentThumbFile ? currentThumbFile.name : 'thumbnail';", nl
    Write "}", nl

    // Resize events
    Write "resizeW.addEventListener('input', function() {", nl
    Write "    if (resizeLock.checked && origW > 0) {", nl
    Write "        var ratio = origH / origW;", nl
    Write "        resizeH.value = Math.round(parseInt(this.value) * ratio);", nl
    Write "    }", nl
    Write "    updateScaleFromDims(); drawResizePreview(); applyResizedImage();", nl
    Write "});", nl
    Write "resizeH.addEventListener('input', function() {", nl
    Write "    if (resizeLock.checked && origH > 0) {", nl
    Write "        var ratio = origW / origH;", nl
    Write "        resizeW.value = Math.round(parseInt(this.value) * ratio);", nl
    Write "    }", nl
    Write "    updateScaleFromDims(); drawResizePreview(); applyResizedImage();", nl
    Write "});", nl
    Write "resizeScale.addEventListener('input', function() {", nl
    Write "    var pct = parseInt(this.value);", nl
    Write "    resizePercent.textContent = pct;", nl
    Write "    resizeW.value = Math.round(origW * pct / 100);", nl
    Write "    resizeH.value = Math.round(origH * pct / 100);", nl
    Write "    drawResizePreview(); applyResizedImage();", nl
    Write "});", nl

    // updateScaleFromDims
    Write "function updateScaleFromDims() {", nl
    Write "    var pct = Math.round((parseInt(resizeW.value) / origW) * 100);", nl
    Write "    resizeScale.value = Math.min(Math.max(pct, 10), 100);", nl
    Write "    resizePercent.textContent = resizeScale.value;", nl
    Write "}", nl

    // Presets
    Write "document.querySelectorAll('.preset-btn').forEach(function(btn) {", nl
    Write "    btn.addEventListener('click', function(e) {", nl
    Write "        e.preventDefault(); e.stopPropagation();", nl
    Write "        var pw = parseInt(this.dataset.w);", nl
    Write "        var ph = parseInt(this.dataset.h);", nl
    Write "        if (pw === 0 && ph === 0) { resizeW.value = origW; resizeH.value = origH; }", nl
    Write "        else { resizeW.value = pw; resizeH.value = ph; }", nl
    Write "        updateScaleFromDims(); drawResizePreview(); applyResizedImage();", nl
    Write "    });", nl
    Write "});", nl

    // Bouton Appliquer
    Write "document.getElementById('resizeApply').addEventListener('click', function(e) {", nl
    Write "    e.preventDefault(); e.stopPropagation();", nl
    Write "    applyResizedImage();", nl
    Write "    resizePanel.querySelector('.resize-header span').textContent = '\u2713 Dimensions appliqu\u00e9es : ' + resizeW.value + ' \u00d7 ' + resizeH.value + ' px';", nl
    Write "});", nl

    // Bouton Réinitialiser
    Write "document.getElementById('resizeReset').addEventListener('click', function(e) {", nl
    Write "    e.preventDefault(); e.stopPropagation();", nl
    Write "    resizeW.value = origW; resizeH.value = origH;", nl
    Write "    resizeScale.value = 100; resizePercent.textContent = '100';", nl
    Write "    drawResizePreview(); applyResizedImage();", nl
    Write "    resizePanel.querySelector('.resize-header span').textContent = '\u2699 Redimensionner l\u0027image';", nl
    Write "});", nl

    // Vérification auth au chargement
    Write "(function() {", nl
    Write "    if (!isAuthenticated()) {", nl
    Write "        alert('Vous devez \u00eatre connect\u00e9 pour cr\u00e9er ou modifier un article.');", nl
    Write "        window.location.href = '" _ loginUrl _ "';", nl
    Write "        return;", nl
    Write "    }", nl
    Write "})();", nl

    // Soumission du formulaire
    Write "document.getElementById('articleForm').addEventListener('submit', function(e) {", nl
    Write "    e.preventDefault();", nl
    Write "    var title = document.getElementById('title').value.trim();", nl
    Write "    var author = document.getElementById('author').value.trim();", nl
    Write "    if (!title || !author) { alert('Titre et auteur sont obligatoires.'); return; }", nl
    Write "    if (!document.getElementById('thumbBase64').value) {", nl
    Write "        alert('La photo d\u0027en-t\u00eate est obligatoire.');", nl
    Write "        document.getElementById('thumbUpload').classList.add('thumb-error');", nl
    Write "        return;", nl
    Write "    }", nl
    Write "    var htmlContent = quill.root.innerHTML;", nl
    Write "    if (htmlContent === '<p><br></p>' || !htmlContent.trim()) {", nl
    Write "        alert('Le contenu de l\u0027article est obligatoire.');", nl
    Write "        return;", nl
    Write "    }", nl

    // Extraire les images inline
    Write "    var images = [];", nl
    Write "    var tempDiv = document.createElement('div');", nl
    Write "    tempDiv.innerHTML = htmlContent;", nl
    Write "    var imgElements = tempDiv.querySelectorAll('img');", nl
    Write "    imgElements.forEach(function(img, idx) {", nl
    Write "        var src = img.getAttribute('src');", nl
    Write "        if (src && src.startsWith('data:')) {", nl
    Write "            var parts = src.split(',');", nl
    Write "            var mimeMatch = parts[0].match(/data:(.*?);/);", nl
    Write "            var mime = mimeMatch ? mimeMatch[1] : 'image/png';", nl
    Write "            var b64 = parts[1];", nl
    Write "            var name = 'image-' + (idx + 1) + '.' + mime.split('/')[1];", nl
    Write "            images.push({ name: name, mimeType: mime, data: b64 });", nl
    Write "        }", nl
    Write "    });", nl

    Write "    document.getElementById('content').value = htmlContent;", nl

    // Construire le JSON article
    Write "    var article = {", nl
    Write "        title: title, content: htmlContent, author: author,", nl
    Write "        category: document.getElementById('category').value.trim(),", nl
    Write "        status: document.getElementById('status').value,", nl
    Write "        images: images", nl
    Write "    };", nl

    // Thumbnail
    Write "    var tb64 = document.getElementById('thumbBase64').value;", nl
    Write "    if (tb64) {", nl
    Write "        article.thumbnail = {", nl
    Write "            name: document.getElementById('thumbName').value,", nl
    Write "            mimeType: document.getElementById('thumbMime').value,", nl
    Write "            data: tb64", nl
    Write "        };", nl
    Write "    }", nl

    Write "    var submitBtn = document.getElementById('submitBtn');", nl
    Write "    submitBtn.disabled = true;", nl
    Write "    var editIdEl = document.getElementById('editId');", nl
    Write "    var isEditMode = editIdEl && editIdEl.value;", nl

    // Mode édition (PUT)
    Write "    if (isEditMode) {", nl
    Write "        submitBtn.textContent = 'Enregistrement en cours...';", nl
    Write "        fetch('/api/articles/articles/' + editIdEl.value, {", nl
    Write "            method: 'PUT', headers: getAuthHeaders(), body: JSON.stringify(article)", nl
    Write "        })", nl
    Write "        .then(function(resp) {", nl
    Write "            if (resp.status === 401) {", nl
    Write "                alert('Session expir\u00e9e. Veuillez vous reconnecter.');", nl
    Write "                localStorage.removeItem('jwt_token'); localStorage.removeItem('jwt_user'); localStorage.removeItem('jwt_roles');", nl
    Write "                window.location.href = '" _ loginUrl _ "'; return Promise.reject('unauthorized');", nl
    Write "            }", nl
    Write "            return resp.json();", nl
    Write "        })", nl
    Write "        .then(function(data) {", nl
    Write "            if (data.message) { window.location.href = '" _ listUrl _ "'; }", nl
    Write "            else { alert('Erreur: ' + (data.error || 'inconnue')); submitBtn.disabled = false; submitBtn.textContent = '\uD83D\uDCBE Enregistrer les modifications'; }", nl
    Write "        })", nl
    Write "        .catch(function(err) {", nl
    Write "            if (err === 'unauthorized') return;", nl
    Write "            alert('Erreur r\u00e9seau: ' + err); submitBtn.disabled = false; submitBtn.textContent = '\uD83D\uDCBE Enregistrer les modifications';", nl
    Write "        });", nl

    // Mode création (POST)
    Write "    } else {", nl
    Write "        submitBtn.textContent = 'G\u00e9n\u00e9ration en cours...';", nl
    Write "        fetch(window.location.href, {", nl
    Write "            method: 'POST', headers: getAuthHeaders(), body: JSON.stringify(article)", nl
    Write "        })", nl
    Write "        .then(function(resp) {", nl
    Write "            if (resp.status === 401) {", nl
    Write "                alert('Session expir\u00e9e. Veuillez vous reconnecter.');", nl
    Write "                localStorage.removeItem('jwt_token'); localStorage.removeItem('jwt_user'); localStorage.removeItem('jwt_roles');", nl
    Write "                window.location.href = '" _ loginUrl _ "'; return Promise.reject('unauthorized');", nl
    Write "            }", nl
    Write "            return resp.json();", nl
    Write "        })", nl
    Write "        .then(function(data) {", nl
    Write "            if (data.success) { window.location.href = '" _ listUrl _ "'; }", nl
    Write "            else { alert('Erreur: ' + (data.error || 'inconnue')); submitBtn.disabled = false; submitBtn.textContent = '\uD83D\uDCBE G\u00e9n\u00e9rer le fichier JSON'; }", nl
    Write "        })", nl
    Write "        .catch(function(err) {", nl
    Write "            if (err === 'unauthorized') return;", nl
    Write "            alert('Erreur r\u00e9seau: ' + err); submitBtn.disabled = false; submitBtn.textContent = '\uD83D\uDCBE G\u00e9n\u00e9rer le fichier JSON';", nl
    Write "        });", nl
    Write "    }", nl
    Write "});", nl

    Write "</script>", nl
}

/// CSS spécifique au formulaire
ClassMethod DrawFormCSS()
{
    &html<<style>
/* Formulaire */
.form-group { margin-bottom: 1.5rem; }
.form-group label { display: block; font-weight: 600; margin-bottom: 0.4rem; color: #1a1a2e; font-size: 0.95rem; }
.form-group input[type="text"], .form-group select {
    width: 100%; padding: 0.7rem 1rem; border: 2px solid #e0e0e0; border-radius: 8px;
    font-size: 1rem; transition: border-color 0.2s; background: #fff;
}
.form-group input[type="text"]:focus, .form-group select:focus {
    outline: none; border-color: #0f3460; box-shadow: 0 0 0 3px rgba(15,52,96,0.1);
}
.form-row { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem; }
@media (max-width: 768px) { .form-row { grid-template-columns: 1fr; } }

/* Vignette upload */
.thumb-upload { cursor: pointer; display: block; }
.thumb-preview {
    width: 100%; min-height: 180px; max-height: 300px; border: 3px dashed #ccc; border-radius: 12px;
    display: flex; align-items: center; justify-content: center; overflow: hidden;
    transition: border-color 0.2s, background 0.2s; background: #fafafa;
}
.thumb-preview:hover, .thumb-upload.dragover .thumb-preview { border-color: #0f3460; background: #f0f4ff; }
.thumb-upload.thumb-error .thumb-preview { border-color: #e74c3c; background: #fff5f5; }
.thumb-upload.thumb-error .thumb-preview span { color: #e74c3c; }
.thumb-preview span { color: #999; font-size: 1.1rem; }
.thumb-preview img { width: 100%; height: 100%; max-height: 300px; object-fit: contain; border-radius: 9px; }

/* Panneau de redimensionnement */
.resize-panel {
    margin-top: 1rem; background: #f8f9fa; border: 2px solid #e0e0e0; border-radius: 12px;
    padding: 1.2rem; animation: slideDown 0.3s ease;
}
@keyframes slideDown { from { opacity: 0; transform: translateY(-10px); } to { opacity: 1; transform: translateY(0); } }
.resize-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; font-weight: 600; color: #0f3460; }
.resize-info { font-weight: 400; font-size: 0.85rem; color: #777; }
.resize-controls { display: flex; flex-direction: column; gap: 0.8rem; }
.resize-presets { display: flex; gap: 0.5rem; flex-wrap: wrap; }
.preset-btn {
    padding: 0.4rem 0.8rem; border: 2px solid #0f3460; border-radius: 6px; background: #fff;
    color: #0f3460; font-size: 0.82rem; font-weight: 600; cursor: pointer; transition: all 0.2s;
}
.preset-btn:hover { background: #0f3460; color: #fff; }
.resize-inputs { display: flex; gap: 1rem; align-items: center; flex-wrap: wrap; }
.resize-inputs label { font-size: 0.9rem; color: #555; display: flex; align-items: center; gap: 0.4rem; }
.resize-inputs input[type="number"] {
    width: 80px; padding: 0.3rem 0.5rem; border: 2px solid #e0e0e0; border-radius: 6px;
    font-size: 0.9rem; text-align: center;
}
.resize-inputs input[type="number"]:focus { outline: none; border-color: #0f3460; }
.resize-lock { font-size: 0.85rem !important; cursor: pointer; user-select: none; }
.resize-slider { display: flex; align-items: center; gap: 0.8rem; }
.resize-slider label { font-size: 0.9rem; color: #555; white-space: nowrap; }
.resize-slider input[type="range"] { flex: 1; accent-color: #0f3460; }
.resize-preview-area {
    margin-top: 1rem; display: flex; justify-content: center; background: #1a1a2e;
    border-radius: 8px; padding: 0.5rem; min-height: 100px;
}
.resize-preview-area canvas { max-width: 100%; border-radius: 4px; }
.resize-actions { display: flex; gap: 0.5rem; margin-top: 1rem; }
.btn-sm { padding: 0.5rem 1.2rem; font-size: 0.9rem; }

/* Editeur Quill */
#editor { min-height: 350px; background: #fff; border-radius: 0 0 8px 8px; font-size: 1rem; }
.ql-toolbar { border-radius: 8px 8px 0 0 !important; background: #fafafa; border-color: #e0e0e0 !important; }
.ql-container { border-radius: 0 0 8px 8px !important; border-color: #e0e0e0 !important; }
.ql-editor { position: relative; }
.ql-editor img { cursor: pointer; max-width: 100%; transition: outline 0.15s; }
.ql-editor img:hover { outline: 1px dashed #0f3460; }
/* Overlay de redimensionnement des images dans l'editeur */
.editor-resize-overlay { position: absolute; border: 2px solid #0f3460; pointer-events: none; z-index: 10; box-sizing: border-box; }
.editor-resize-handle { position: absolute; right: 2px; bottom: 2px; width: 14px; height: 14px; background: #0f3460; border: 2px solid #fff; border-radius: 3px; cursor: nwse-resize; pointer-events: all; box-shadow: 0 1px 4px rgba(0,0,0,0.3); }
.editor-resize-dims { position: absolute; bottom: 4px; left: 4px; background: rgba(15,52,96,0.85); color: #fff; padding: 1px 8px; border-radius: 3px; font-size: 11px; pointer-events: none; white-space: nowrap; }

/* Boutons */
.form-actions { display: flex; gap: 1rem; margin-top: 2rem; margin-bottom: 2rem; }
.btn {
    padding: 0.8rem 2rem; border: none; border-radius: 8px; font-size: 1rem;
    font-weight: 600; cursor: pointer; text-decoration: none; display: inline-flex;
    align-items: center; gap: 0.5rem; transition: all 0.2s;
}
.btn-primary { background: linear-gradient(135deg, #0f3460, #16213e); color: #fff; }
.btn-primary:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(15,52,96,0.3); }
.btn-primary:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
.btn-secondary { background: #e0e0e0; color: #333; }
.btn-secondary:hover { background: #d0d0d0; }
</style>>
}

}
