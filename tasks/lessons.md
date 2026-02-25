# Lessons Learned

## Error Patterns

### Erreur 1 — HTML orphelin dans &html<>
- **Date**: 2026-02-25
- **Context**: ArticleForm.cls — Le HTML du thumbnail et du resize panel était en dehors de tout bloc `&html<>`
- **What went wrong**: `<SYNTAX>OnPage+70^Article.Web.ArticleForm.1` — le compilateur CSP interprétait `<div class="form-group">` comme du ObjectScript
- **Root cause**: Dans `&html<...>`, le compilateur compte les `<` et `>`. Un `>>` en fin de ligne (ex: `</div>>`) ramène le compteur à 0 et ferme le bloc. Tout HTML après cette fermeture devient du code ObjectScript invalide.
- **Correct solution**: Ajouter un `&html<` avant chaque section HTML orpheline
- **Preventive rule**: Après chaque édition d'un `&html<>`, compter les `<>` pour vérifier que le bloc se ferme au bon endroit. Vérifier que aucun HTML brut ne se trouve entre deux blocs.

### Erreur 2 — ##(editId)# au lieu de #(editId)#
- **Date**: 2026-02-25
- **Context**: ArticleForm.cls ligne 27 — affichage de l'ID dans le message 404
- **What went wrong**: `##(editId)#` utilise la syntaxe compile-time (évaluée à la compilation, pas au runtime)
- **Root cause**: Confusion entre `#()#` (runtime) et `##()##` (compile-time). `editId` est une variable locale Set au runtime.
- **Correct solution**: Utiliser `#(editId)#`
- **Preventive rule**: `##()##` uniquement pour les expressions constantes. Variables locales = toujours `#()#`.

### Erreur 3 — Clic thumbnail en boucle infinie
- **Date**: 2026-02-25
- **Context**: ArticleForm.cls — le clic sur thumbUpload appelait thumbFile.click(), mais thumbFile est enfant de thumbUpload
- **What went wrong**: L'événement clic sur thumbFile bubbles vers thumbUpload → re-déclenche thumbFile.click() → boucle infinie
- **Root cause**: Pas de `stopPropagation()` sur le file input enfant
- **Correct solution**: `thumbFile.addEventListener('click', function(e) { e.stopPropagation(); })`
- **Preventive rule**: Toujours stopper la propagation quand un input file est enfant d'un élément avec un listener click.

### Erreur 4 — CSS Quill chargé en bas de page
- **Date**: 2026-02-25
- **Context**: ArticleForm.cls — la toolbar Quill s'affichait sans style
- **What went wrong**: Le `<link>` CSS de Quill était émis après tout le HTML du formulaire
- **Root cause**: Le bloc CDN (CSS + JS) était tout en bas, après le `</form>`
- **Correct solution**: Charger le CSS dans le `<head>` (après DrawHead), garder le JS en bas
- **Preventive rule**: Les CSS de libs tierces toujours dans le `<head>`, avant le HTML qui les utilise.

---

## Rules

- Always decompose non-trivial tasks before implementation.
- Never ship without verification.
- Fix root causes, not symptoms.
- Avoid patch-style fixes when architectural correction is needed.
- Update this file after every meaningful correction.