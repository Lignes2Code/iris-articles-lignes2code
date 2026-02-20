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
            &html<<body style="display:flex;justify-content:center;align-items:center;min-height:100vh;background:#f0f2f5;">
<div class="msg"><h1>404</h1><p>Article ##(editId)# non trouv&eacute;</p>
<p><a href="#(urlList)#">&#8592; Retour &agrave; la liste</a></p></div>
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

<div class="form-group">
<label>Image d'en-t&ecirc;te (vignette) *</label>
<div class="thumb-upload" id="thumbUpload">
<div class="thumb-preview" id="thumbPreview">
<span id="thumbPlaceholder">>
        // En mode édition avec thumbnail existant, l'afficher
        If isEdit && $IsObject(article.Thumbnail) && (article.Thumbnail.Base64Data.Size > 0) {
            &html<style="display:none;">&#128247; Cliquez ou glissez une image ici</span>>
            Write "<img id=""thumbImg"" src="""
            Do article.Thumbnail.WriteDataURI()
            Write """ />"
        } Else {
            &html<>&#128247; Cliquez ou glissez une image ici</span>
<img id="thumbImg" style="display:none;" />>
        }
        &html<</div>
<input type="file" id="thumbFile" accept="image/*" style="display:none;" />
<input type="hidden" id="thumbBase64" name="thumbBase64" />
<input type="hidden" id="thumbMime" name="thumbMime" />
<input type="hidden" id="thumbName" name="thumbName" />
</div>>

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
<div id="toolbar">
<span class="ql-formats">
<select class="ql-header">
<option value="1">Titre 1</option>
<option value="2">Titre 2</option>
<option value="3">Titre 3</option>
<option selected>Normal</option>
</select>
</span>
<span class="ql-formats">
<button class="ql-bold"></button>
<button class="ql-italic"></button>
<button class="ql-underline"></button>
<button class="ql-strike"></button>
</span>
<span class="ql-formats">
<button class="ql-list" value="ordered"></button>
<button class="ql-list" value="bullet"></button>
<button class="ql-blockquote"></button>
<button class="ql-code-block"></button>
</span>
<span class="ql-formats">
<button class="ql-link"></button>
<button class="ql-image"></button>
</span>
<span class="ql-formats">
<select class="ql-color"></select>
<select class="ql-background"></select>
</span>
<span class="ql-formats">
<select class="ql-align"></select>
</span>
<span class="ql-formats">
<button class="ql-clean"></button>
</span>
</div>
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

        // Quill.js CDN
        &html<
<link href="https://cdn.jsdelivr.net/npm/quill@2.0.3/dist/quill.snow.css" rel="stylesheet" />
<script src="https://cdn.jsdelivr.net/npm/quill@2.0.3/dist/quill.js"></script>
<script>
// Initialiser Quill
var quill = new Quill('#editor', {
    modules: {
        toolbar: '#toolbar'
    },
    theme: 'snow',
    placeholder: 'R\u00e9digez votre article ici...'
});
>>

        // En mode édition : injecter le contenu et les données du thumbnail
        If isEdit {
            &html<<script>>
            // Contenu dans Quill
            Write "quill.root.innerHTML = "
            // Sérialiser le contenu du stream en JSON string
            If $IsObject(article.Content) && (article.Content.Size > 0) {
                Do article.Content.Rewind()
                // Début de la chaîne JSON
                Write """"
                While 'article.Content.AtEnd {
                    Set chunk = article.Content.Read(32000)
                    // Échapper pour JavaScript string
                    Set chunk = $Replace(chunk, "\", "\\")
                    Set chunk = $Replace(chunk, """", "\""")
                    Set chunk = $Replace(chunk, $Char(10), "\n")
                    Set chunk = $Replace(chunk, $Char(13), "\r")
                    Write chunk
                }
                Write """"
            } Else {
                Write "''"
            }
            Write ";"

            // Pré-remplir les champs cachés du thumbnail
            If $IsObject(article.Thumbnail) && (article.Thumbnail.Base64Data.Size > 0) {
                Write "document.getElementById('thumbMime').value = '" _ $ZConvert(article.Thumbnail.MimeType, "O", "JS") _ "';"
                Write "document.getElementById('thumbName').value = '" _ $ZConvert(article.Thumbnail.Name, "O", "JS") _ "';"
                // Écrire le base64 du thumbnail dans le champ caché
                Write "document.getElementById('thumbBase64').value = '"
                Do article.Thumbnail.Base64Data.Rewind()
                While 'article.Thumbnail.Base64Data.AtEnd {
                    Write article.Thumbnail.Base64Data.Read(32000)
                }
                Write "';"
            }
            &html<</script>>
        }

        &html<
<script>
var thumbUpload = document.getElementById('thumbUpload');
var thumbFile = document.getElementById('thumbFile');
var thumbImg = document.getElementById('thumbImg');
var thumbPlaceholder = document.getElementById('thumbPlaceholder');

thumbUpload.addEventListener('click', function() { thumbFile.click(); });
thumbUpload.addEventListener('dragover', function(e) { e.preventDefault(); this.classList.add('dragover'); });
thumbUpload.addEventListener('dragleave', function() { this.classList.remove('dragover'); });
thumbUpload.addEventListener('drop', function(e) {
    e.preventDefault();
    this.classList.remove('dragover');
    if (e.dataTransfer.files.length) handleThumbFile(e.dataTransfer.files[0]);
});
thumbFile.addEventListener('change', function() {
    if (this.files.length) handleThumbFile(this.files[0]);
});

// --- Redimensionnement d'image ---
var resizePanel = document.getElementById('resizePanel');
var resizeCanvas = document.getElementById('resizeCanvas');
var resizeCtx = resizeCanvas.getContext('2d');
var resizeW = document.getElementById('resizeW');
var resizeH = document.getElementById('resizeH');
var resizeLock = document.getElementById('resizeLock');
var resizeScale = document.getElementById('resizeScale');
var resizePercent = document.getElementById('resizePercent');
var resizeOrigInfo = document.getElementById('resizeOrigInfo');
var originalImage = null; // Image() object
var origW = 0, origH = 0;
var currentThumbFile = null;

function handleThumbFile(file) {
    if (!file.type.startsWith('image/')) { alert('Veuillez choisir une image.'); return; }
    thumbUpload.classList.remove('thumb-error');
    currentThumbFile = file;
    var reader = new FileReader();
    reader.onload = function(e) {
        // Charger l'image originale
        originalImage = new Image();
        originalImage.onload = function() {
            origW = originalImage.naturalWidth;
            origH = originalImage.naturalHeight;
            resizeOrigInfo.textContent = 'Original : ' + origW + ' \u00d7 ' + origH + ' px';
            resizeW.value = origW;
            resizeH.value = origH;
            resizeScale.value = 100;
            resizePercent.textContent = '100';
            // Afficher le panneau de redimensionnement
            resizePanel.style.display = 'block';
            drawResizePreview();
            // Mettre \u00e0 jour la preview principale
            applyResizedImage();
        };
        originalImage.src = e.target.result;
    };
    reader.readAsDataURL(file);
}

function drawResizePreview() {
    if (!originalImage) return;
    var w = parseInt(resizeW.value) || origW;
    var h = parseInt(resizeH.value) || origH;
    // Limiter le canvas de preview \u00e0 500px max
    var maxPrev = 500;
    var scale = Math.min(maxPrev / w, maxPrev / h, 1);
    resizeCanvas.width = Math.round(w * scale);
    resizeCanvas.height = Math.round(h * scale);
    resizeCtx.clearRect(0, 0, resizeCanvas.width, resizeCanvas.height);
    resizeCtx.drawImage(originalImage, 0, 0, resizeCanvas.width, resizeCanvas.height);
}

function applyResizedImage() {
    if (!originalImage) return;
    var w = parseInt(resizeW.value) || origW;
    var h = parseInt(resizeH.value) || origH;
    // Cr\u00e9er un canvas temporaire aux dimensions finales
    var tmpCanvas = document.createElement('canvas');
    tmpCanvas.width = w;
    tmpCanvas.height = h;
    var tmpCtx = tmpCanvas.getContext('2d');
    tmpCtx.drawImage(originalImage, 0, 0, w, h);
    // Extraire le r\u00e9sultat
    var mime = currentThumbFile ? currentThumbFile.type : 'image/jpeg';
    // Utiliser un format compatible canvas
    var outMime = (mime === 'image/png') ? 'image/png' : 'image/jpeg';
    var quality = (outMime === 'image/jpeg') ? 0.92 : undefined;
    var dataURL = tmpCanvas.toDataURL(outMime, quality);
    thumbImg.src = dataURL;
    thumbImg.style.display = 'block';
    thumbPlaceholder.style.display = 'none';
    var base64 = dataURL.split(',')[1];
    document.getElementById('thumbBase64').value = base64;
    document.getElementById('thumbMime').value = outMime;
    document.getElementById('thumbName').value = currentThumbFile ? currentThumbFile.name : 'thumbnail';
}

// \u00c9v\u00e9nements du panneau de redimensionnement
resizeW.addEventListener('input', function() {
    if (resizeLock.checked && origW > 0) {
        var ratio = origH / origW;
        resizeH.value = Math.round(parseInt(this.value) * ratio);
    }
    updateScaleFromDims();
    drawResizePreview();
    applyResizedImage();
});
resizeH.addEventListener('input', function() {
    if (resizeLock.checked && origH > 0) {
        var ratio = origW / origH;
        resizeW.value = Math.round(parseInt(this.value) * ratio);
    }
    updateScaleFromDims();
    drawResizePreview();
    applyResizedImage();
});
resizeScale.addEventListener('input', function() {
    var pct = parseInt(this.value);
    resizePercent.textContent = pct;
    resizeW.value = Math.round(origW * pct / 100);
    resizeH.value = Math.round(origH * pct / 100);
    drawResizePreview();
    applyResizedImage();
});

function updateScaleFromDims() {
    var pct = Math.round((parseInt(resizeW.value) / origW) * 100);
    resizeScale.value = Math.min(Math.max(pct, 10), 100);
    resizePercent.textContent = resizeScale.value;
}

// Presets
document.querySelectorAll('.preset-btn').forEach(function(btn) {
    btn.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        var pw = parseInt(this.dataset.w);
        var ph = parseInt(this.dataset.h);
        if (pw === 0 && ph === 0) {
            resizeW.value = origW;
            resizeH.value = origH;
        } else {
            resizeW.value = pw;
            resizeH.value = ph;
        }
        updateScaleFromDims();
        drawResizePreview();
        applyResizedImage();
    });
});

// Bouton Appliquer
document.getElementById('resizeApply').addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    applyResizedImage();
    resizePanel.querySelector('.resize-header span').textContent = '\u2713 Dimensions appliqu\u00e9es : ' + resizeW.value + ' \u00d7 ' + resizeH.value + ' px';
});

// Bouton R\u00e9initialiser
document.getElementById('resizeReset').addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    resizeW.value = origW;
    resizeH.value = origH;
    resizeScale.value = 100;
    resizePercent.textContent = '100';
    drawResizePreview();
    applyResizedImage();
    resizePanel.querySelector('.resize-header span').textContent = '\u2699 Redimensionner l\'image';
});

// Soumission du formulaire
document.getElementById('articleForm').addEventListener('submit', function(e) {
    e.preventDefault();

    var title = document.getElementById('title').value.trim();
    var author = document.getElementById('author').value.trim();
    if (!title || !author) { alert('Titre et auteur sont obligatoires.'); return; }

    // V\u00e9rifier que la photo d'en-t\u00eate est pr\u00e9sente
    if (!document.getElementById('thumbBase64').value) {
        alert('La photo d\'en-t\u00eate est obligatoire. Elle sera utilis\u00e9e comme image de la carte de l\'article.');
        document.getElementById('thumbUpload').classList.add('thumb-error');
        return;
    }

    // R\u00e9cup\u00e9rer le HTML de Quill
    var htmlContent = quill.root.innerHTML;
    if (htmlContent === '<p><br></p>' || !htmlContent.trim()) {
        alert('Le contenu de l\'article est obligatoire.');
        return;
    }

    // Extraire les images inline du contenu Quill (base64)
    var images = [];
    var tempDiv = document.createElement('div');
    tempDiv.innerHTML = htmlContent;
    var imgElements = tempDiv.querySelectorAll('img');
    imgElements.forEach(function(img, idx) {
        var src = img.getAttribute('src');
        if (src && src.startsWith('data:')) {
            var parts = src.split(',');
            var mimeMatch = parts[0].match(/data:(.*?);/);
            var mime = mimeMatch ? mimeMatch[1] : 'image/png';
            var b64 = parts[1];
            var name = 'image-' + (idx + 1) + '.' + mime.split('/')[1];
            images.push({ name: name, mimeType: mime, data: b64 });
        }
    });

    document.getElementById('content').value = htmlContent;

    // Construire le JSON
    var article = {
        title: title,
        content: htmlContent,
        author: author,
        category: document.getElementById('category').value.trim(),
        status: document.getElementById('status').value,
        images: images
    };

    // Ajouter la vignette si pr\u00e9sente
    var tb64 = document.getElementById('thumbBase64').value;
    if (tb64) {
        article.thumbnail = {
            name: document.getElementById('thumbName').value,
            mimeType: document.getElementById('thumbMime').value,
            data: tb64
        };
    }

    // Envoyer en POST
    var submitBtn = document.getElementById('submitBtn');
    submitBtn.disabled = true;

    // D\u00e9tecter le mode \u00e9dition
    var editIdEl = document.getElementById('editId');
    var isEditMode = editIdEl && editIdEl.value;

    if (isEditMode) {
        // Mode \u00e9dition : PUT vers l'API REST
        submitBtn.textContent = 'Enregistrement en cours...';
        fetch('/api/articles/articles/' + editIdEl.value, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(article)
        })
        .then(function(resp) { return resp.json(); })
        .then(function(data) {
            if (data.message) {
                window.location.href = '#(..Link("Article.Web.ArticleList.cls"))#';
            } else {
                alert('Erreur: ' + (data.error || 'inconnue'));
                submitBtn.disabled = false;
                submitBtn.textContent = '\uD83D\uDCBE Enregistrer les modifications';
            }
        })
        .catch(function(err) {
            alert('Erreur r\u00e9seau: ' + err);
            submitBtn.disabled = false;
            submitBtn.textContent = '\uD83D\uDCBE Enregistrer les modifications';
        });
    } else {
        // Mode cr\u00e9ation : POST vers le formulaire (g\u00e9n\u00e8re le fichier JSON)
        submitBtn.textContent = 'G\u00e9n\u00e9ration en cours...';
        fetch(window.location.href, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(article)
        })
        .then(function(resp) { return resp.json(); })
        .then(function(data) {
            if (data.success) {
                window.location.href = '#(..Link("Article.Web.ArticleList.cls"))#';
            } else {
                alert('Erreur: ' + (data.error || 'inconnue'));
                submitBtn.disabled = false;
                submitBtn.textContent = '\uD83D\uDCBE G\u00e9n\u00e9rer le fichier JSON';
            }
        })
        .catch(function(err) {
            alert('Erreur r\u00e9seau: ' + err);
            submitBtn.disabled = false;
            submitBtn.textContent = '\uD83D\uDCBE G\u00e9n\u00e9rer le fichier JSON';
        });
    }
});
</script>>

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
        // Lire le body comme un stream (évite MAXSTRING pour les gros JSON avec images base64)
        Set body = %request.Content
        If '$IsObject(body) {
            Write "{""success"":false,""error"":""Corps de requête vide""}"
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
            Write "{""success"":false,""error"":""Données JSON vides""}"
            Return sc
        }

        // Parser le JSON depuis le stream (%DynamicObject gère les gros streams nativement)
        Set jsonObj = ##class(%DynamicObject).%FromJSON(stream)
        Set title = jsonObj.%Get("title")
        Do stream.Rewind()

        If title = "" {
            Write "{""success"":false,""error"":""Titre manquant""}"
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
            Write "{""success"":false,""error"":""Impossible de créer le fichier: " _ $System.Status.GetErrorText(sc) _ """}"
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
            Write "{""success"":false,""error"":""Erreur d'écriture: " _ $System.Status.GetErrorText(sc) _ """}"
            Return $$$OK
        }

        Set response = {}
        Set response.success = 1
        Set response.message = "Fichier JSON généré avec succès"
        Set response.fileName = fileName
        Write response.%ToJSON()
    }
    Catch ex {
        Write "{""success"":false,""error"":""" _ $ZConvert(ex.DisplayString(), "O", "JS") _ """}"
    }
    Return $$$OK
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
.thumb-upload { cursor: pointer; }
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
.ql-toolbar { border-radius: 8px 8px 0 0 !important; background: #fafafa; }
.ql-container { border-radius: 0 0 8px 8px !important; border-color: #e0e0e0 !important; }
.ql-toolbar { border-color: #e0e0e0 !important; }

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
