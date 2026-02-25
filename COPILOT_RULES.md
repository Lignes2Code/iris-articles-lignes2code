# Copilot Operational Rules

- Decompose any non-trivial task before implementation.
- Propose a plan for multi-file or architectural changes.
- Identify impacted files before editing.
- Validate architectural consequences before coding.
- Prefer root cause fixes over quick patches.
- Verify behavior before marking a task complete.
- Challenge non-trivial implementations for elegance.

---

## Règles InterSystems IRIS / CSP ObjectScript

Quand tu modifies ou crées une classe CSP (.cls) héritant de %CSP.Page :

### Blocs &html<>
- Le compilateur CSP compte chaque `<` et `>` pour déterminer la fin du bloc. Chaque `<tag>` incrémente +1, chaque `>` décrémente -1. Le bloc se ferme quand le compteur retombe à 0.
- **JAMAIS** de HTML brut en dehors d'un `&html<>`, `Write ""`, ou `#()#`.
- Après chaque modification d'un `&html<>`, **VÉRIFIER** que le compteur `< >` est équilibré et que le code ObjectScript qui suit n'est pas "avalé" par le bloc.
- En cas de doute, préférer `Write ""` plutôt que `&html<>` pour le HTML complexe.
- Un `>>` à la fin d'une ligne HTML (ex: `</div>>`) ferme le `&html<>` — tout HTML après est orphelin.

### Expressions runtime vs compile-time
- `#(expr)#` = runtime (variables locales comme editId, article, etc.)
- `##(expr)##` = compile-time (constantes, `$ZDATETIME($H)`)
- Ne **JAMAIS** utiliser `##()##` pour une variable locale définie au runtime.

### Ordre de chargement
- Les CSS de bibliothèques tierces (Quill, etc.) doivent être chargés dans le `<head>` **AVANT** le HTML qui les utilise.
- Les scripts JS peuvent être chargés en bas de page.

### Événements DOM
- Quand un `<input type="file">` est enfant d'un élément cliquable, **toujours** ajouter `e.stopPropagation()` sur l'input pour éviter les boucles infinies de clic.
- Sur les zones de drag & drop, **toujours** gérer `dragenter`, `dragover`, `dragleave` et `drop` avec `preventDefault()` + `stopPropagation()`.

### Validation obligatoire
- Après toute modification d'un fichier .cls CSP, **compter manuellement** les blocs `&html<...>` pour vérifier qu'aucun HTML n'est orphelin.
- Vérifier que chaque section de HTML est contenue dans exactement un des mécanismes : `&html<>`, `Write`, ou expression `#()#`.
- Tester mentalement la compilation : lire le code ligne par ligne comme le ferait le compilateur CSP.