/// Page CSP : Formulaire de création d'article avec éditeur enrichi
/// Génère un fichier JSON dans data/input/ traité par la production
Class Article.Web.ArticleForm Extends Article.Web.Base
{

ClassMethod OnPage() As %Status
{
    Set sc = $$$OK
    Try {
        // Traitement du POST : écrire le JSON dans data/input/
        If %request.Method = "POST" {
            Set sc = ..ProcessForm()
            Return sc
        }

        // Affichage du formulaire (GET)
        Do ..DrawHead("Nouvel article")
        Do ..DrawHeader("Nouvel article")
        Do ..DrawFormCSS()

        &html<<div class="container">
<form id="articleForm" method="POST" enctype="application/x-www-form-urlencoded">

<div class="form-group">
<label for="title">Titre *</label>
<input type="text" id="title" name="title" required placeholder="Titre de l'article" />
</div>

<div class="form-row">
<div class="form-group">
<label for="author">Auteur *</label>
<input type="text" id="author" name="author" required placeholder="Nom de l'auteur" />
</div>
<div class="form-group">
<label for="category">Cat&eacute;gorie</label>
<input type="text" id="category" name="category" placeholder="Ex: technique, tutoriel..." />
</div>
<div class="form-group">
<label for="status">Statut</label>
<select id="status" name="status">
<option value="draft">Brouillon</option>
<option value="published">Publi&eacute;</option>
<option value="archived">Archiv&eacute;</option>
</select>
</div>
</div>

<div class="form-group">
<label>Image d'en-t&ecirc;te (vignette)</label>
<div class="thumb-upload" id="thumbUpload">
<div class="thumb-preview" id="thumbPreview">
<span id="thumbPlaceholder">&#128247; Cliquez ou glissez une image ici</span>
<img id="thumbImg" style="display:none;" />
</div>
<input type="file" id="thumbFile" accept="image/*" style="display:none;" />
<input type="hidden" id="thumbBase64" name="thumbBase64" />
<input type="hidden" id="thumbMime" name="thumbMime" />
<input type="hidden" id="thumbName" name="thumbName" />
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
<button type="submit" class="btn btn-primary" id="submitBtn">&#128190; G&eacute;n&eacute;rer le fichier JSON</button>
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

// Upload de la vignette
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

function handleThumbFile(file) {
    if (!file.type.startsWith('image/')) { alert('Veuillez choisir une image.'); return; }
    var reader = new FileReader();
    reader.onload = function(e) {
        thumbImg.src = e.target.result;
        thumbImg.style.display = 'block';
        thumbPlaceholder.style.display = 'none';
        // Extraire le base64 sans le pr\u00e9fixe data:...;base64,
        var base64 = e.target.result.split(',')[1];
        document.getElementById('thumbBase64').value = base64;
        document.getElementById('thumbMime').value = file.type;
        document.getElementById('thumbName').value = file.name;
    };
    reader.readAsDataURL(file);
}

// Soumission du formulaire
document.getElementById('articleForm').addEventListener('submit', function(e) {
    e.preventDefault();

    var title = document.getElementById('title').value.trim();
    var author = document.getElementById('author').value.trim();
    if (!title || !author) { alert('Titre et auteur sont obligatoires.'); return; }

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
            images.push({ name: name, mimeType: mime, base64Data: b64 });
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
            base64Data: tb64
        };
    }

    // Envoyer en POST (le serveur \u00e9crira le fichier JSON)
    var submitBtn = document.getElementById('submitBtn');
    submitBtn.disabled = true;
    submitBtn.textContent = 'G\u00e9n\u00e9ration en cours...';

    fetch(window.location.href, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(article)
    })
    .then(function(resp) { return resp.json(); })
    .then(function(data) {
        if (data.success) {
            // Rediriger vers la liste avec un message
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
.thumb-preview span { color: #999; font-size: 1.1rem; }
.thumb-preview img { width: 100%; height: 100%; max-height: 300px; object-fit: cover; border-radius: 9px; }

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
