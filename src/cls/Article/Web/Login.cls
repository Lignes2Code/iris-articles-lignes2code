/// Page CSP de connexion
/// Formulaire login avec appel AJAX vers l'API JWT
Class Article.Web.Login Extends Article.Web.Base
{

ClassMethod OnPage() As %Status
{
    Set sc = $$$OK
    Do ..DrawHead("Connexion")
    Do ..DrawCSS()
    &html<
<style>
.login-container {
    display: flex; justify-content: center; align-items: center;
    min-height: 80vh; padding: 2rem;
}
.login-card {
    background: #fff; border-radius: 16px; padding: 2.5rem;
    box-shadow: 0 4px 24px rgba(0,0,0,0.1); width: 100%; max-width: 420px;
}
.login-card h2 {
    text-align: center; color: #0f3460; margin-bottom: 0.3rem; font-size: 1.6rem;
}
.login-card .subtitle {
    text-align: center; color: #777; font-size: 0.9rem; margin-bottom: 2rem;
}
.login-card .form-group { margin-bottom: 1.2rem; }
.login-card label { display: block; font-weight: 600; color: #333; margin-bottom: 0.3rem; font-size: 0.9rem; }
.login-card input[type="text"],
.login-card input[type="password"] {
    width: 100%; padding: 0.7rem 1rem; border: 2px solid #e0e0e0; border-radius: 8px;
    font-size: 1rem; transition: border-color 0.2s;
}
.login-card input:focus { border-color: #0f3460; outline: none; }
.login-btn {
    width: 100%; padding: 0.8rem; background: linear-gradient(135deg, #0f3460, #16213e);
    color: #fff; border: none; border-radius: 8px; font-size: 1rem; font-weight: 600;
    cursor: pointer; transition: all 0.2s; margin-top: 0.5rem;
}
.login-btn:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(15,52,96,0.3); }
.login-btn:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
.login-error {
    background: #f8d7da; color: #721c24; padding: 0.7rem 1rem; border-radius: 8px;
    font-size: 0.85rem; margin-bottom: 1rem; display: none;
}
.login-success {
    background: #d4edda; color: #155724; padding: 0.7rem 1rem; border-radius: 8px;
    font-size: 0.85rem; margin-bottom: 1rem; display: none;
}
.login-footer { text-align: center; margin-top: 1.5rem; font-size: 0.85rem; color: #999; }
.login-footer a { color: #0f3460; text-decoration: none; font-weight: 600; }
.login-footer a:hover { text-decoration: underline; }
</style>
<body>>
    Do ..DrawHeader("Connexion", "Authentifiez-vous pour g&eacute;rer les articles")
    
    Set urlList = ..Link("Article.Web.ArticleList.cls")
    
    &html<
<div class="login-container">
<div class="login-card">
<h2>&#128274; Connexion</h2>
<p class="subtitle">Acc&eacute;dez &agrave; la gestion des articles</p>

<div id="loginError" class="login-error"></div>
<div id="loginSuccess" class="login-success"></div>

<form id="loginForm" onsubmit="return false;">
<div class="form-group">
<label for="username">Nom d'utilisateur</label>
<input type="text" id="username" name="username" required placeholder="Votre identifiant" autocomplete="username" />
</div>
<div class="form-group">
<label for="password">Mot de passe</label>
<input type="password" id="password" name="password" required placeholder="Votre mot de passe" autocomplete="current-password" />
</div>
<button type="submit" id="loginBtn" class="login-btn">Se connecter</button>
</form>

<div class="login-footer">
<a href="#(urlList)#">&#8592; Retour aux articles</a>
</div>
</div>
</div>

<script>
// V\u00e9rifier si d\u00e9j\u00e0 connect\u00e9
(function() {
    var token = localStorage.getItem('jwt_token');
    if (token) {
        // V\u00e9rifier si le token est encore valide
        fetch('/api/articles/auth/me', {
            headers: { 'Authorization': 'Bearer ' + token }
        })
        .then(function(resp) {
            if (resp.ok) {
                document.getElementById('loginSuccess').style.display = 'block';
                document.getElementById('loginSuccess').textContent = 'Vous \u00eates d\u00e9j\u00e0 connect\u00e9. Redirection...';
                setTimeout(function() {
                    window.location.href = '#(urlList)#';
                }, 1000);
            } else {
                // Token expir\u00e9/invalide, le supprimer
                localStorage.removeItem('jwt_token');
                localStorage.removeItem('jwt_user');
                localStorage.removeItem('jwt_roles');
            }
        })
        .catch(function() {
            localStorage.removeItem('jwt_token');
            localStorage.removeItem('jwt_user');
            localStorage.removeItem('jwt_roles');
        });
    }
})();

document.getElementById('loginForm').addEventListener('submit', function() {
    var username = document.getElementById('username').value.trim();
    var password = document.getElementById('password').value;
    var btn = document.getElementById('loginBtn');
    var errorDiv = document.getElementById('loginError');
    var successDiv = document.getElementById('loginSuccess');

    errorDiv.style.display = 'none';
    successDiv.style.display = 'none';

    if (!username || !password) {
        errorDiv.textContent = 'Veuillez remplir tous les champs.';
        errorDiv.style.display = 'block';
        return;
    }

    btn.disabled = true;
    btn.textContent = 'Connexion en cours...';

    fetch('/api/articles/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: username, password: password })
    })
    .then(function(resp) {
        return resp.json().then(function(data) {
            return { ok: resp.ok, data: data };
        });
    })
    .then(function(result) {
        if (result.ok && result.data.token) {
            // Stocker le token et les infos utilisateur
            localStorage.setItem('jwt_token', result.data.token);
            localStorage.setItem('jwt_user', result.data.username);
            localStorage.setItem('jwt_roles', result.data.roles);

            successDiv.textContent = 'Connect\u00e9 ! Redirection...';
            successDiv.style.display = 'block';

            setTimeout(function() {
                window.location.href = '#(urlList)#';
            }, 800);
        } else {
            errorDiv.textContent = result.data.error || 'Identifiants invalides.';
            errorDiv.style.display = 'block';
            btn.disabled = false;
            btn.textContent = 'Se connecter';
        }
    })
    .catch(function(err) {
        errorDiv.textContent = 'Erreur r\u00e9seau : ' + err.message;
        errorDiv.style.display = 'block';
        btn.disabled = false;
        btn.textContent = 'Se connecter';
    });
});
</script>>

    Do ..DrawFooter()
    Return sc
}

}
