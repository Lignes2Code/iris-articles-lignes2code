#!/bin/bash

# Script pour ouvrir les pages IRIS avec les bons paramètres
# Contourne les problèmes de sécurité Chrome avec localhost

echo "🚀 Ouverture des pages IRIS Articles..."

# Fonction pour essayer différents navigateurs
open_browser() {
    local url="$1"
    local page_name="$2"
    
    echo "📄 Ouverture $page_name: $url"
    
    # Essayer Chrome en mode développement
    if command -v google-chrome >/dev/null 2>&1; then
        google-chrome --disable-web-security \
                     --disable-features=VizDisplayCompositor \
                     --user-data-dir=/tmp/iris_chrome_session \
                     --allow-running-insecure-content \
                     --disable-site-isolation-trials \
                     --new-window \
                     "$url" >/dev/null 2>&1 &
        echo "✅ Ouvert dans Chrome (mode développement)"
        return 0
    fi
    
    # Essayer Firefox
    if command -v firefox >/dev/null 2>&1; then
        firefox --new-window "$url" >/dev/null 2>&1 &
        echo "✅ Ouvert dans Firefox"
        return 0
    fi
    
    # Essayer Edge (Chromium)
    if command -v microsoft-edge >/dev/null 2>&1; then
        microsoft-edge --disable-web-security \
                      --user-data-dir=/tmp/iris_edge_session \
                      --new-window \
                      "$url" >/dev/null 2>&1 &
        echo "✅ Ouvert dans Edge"
        return 0
    fi
    
    # Fallback sur le navigateur par défaut
    xdg-open "$url" >/dev/null 2>&1 &
    echo "⚠️  Ouvert dans le navigateur par défaut"
}

# Vérifier que le conteneur IRIS est en marche
echo "🔍 Vérification du service IRIS..."
if ! curl -s http://127.0.0.1:52773/api/articles/health >/dev/null; then
    echo "❌ Service IRIS non accessible sur le port 52773"
    echo "💡 Démarrez d'abord le conteneur avec: docker compose up -d"
    exit 1
fi

echo "✅ Service IRIS détecté"

# URLs avec 127.0.0.1 pour éviter les problèmes localhost
PORTAL_URL="http://127.0.0.1:52773/csp/sys/UtilHome.csp"
ARTICLES_URL="http://127.0.0.1:52773/web/articles/Article.Web.ArticleList.cls"
WEBTERMINAL_URL="http://127.0.0.1:52773/terminal/"

# Menu interactif
echo ""
echo "📋 Quelle page voulez-vous ouvrir ?"
echo "1) Management Portal (Administration IRIS)"
echo "2) Articles Web (Interface utilisateur)" 
echo "3) WebTerminal (Terminal web IRIS)"
echo "4) Toutes les pages"
echo "5) Quitter"
echo ""

read -p "Votre choix (1-5): " choice

case $choice in
    1)
        open_browser "$PORTAL_URL" "Management Portal"
        echo ""
        echo "🔐 Identifiants: _SYSTEM / SYS"
        ;;
    2)
        open_browser "$ARTICLES_URL" "Articles Web"
        ;;
    3)
        open_browser "$WEBTERMINAL_URL" "WebTerminal"
        echo ""
        echo "🔐 Identifiants: _SYSTEM / SYS"
        ;;
    4)
        open_browser "$PORTAL_URL" "Management Portal"
        sleep 2
        open_browser "$ARTICLES_URL" "Articles Web" 
        sleep 2
        open_browser "$WEBTERMINAL_URL" "WebTerminal"
        echo ""
        echo "🔐 Identifiants: _SYSTEM / SYS"
        ;;
    5)
        echo "👋 À bientôt !"
        exit 0
        ;;
    *)
        echo "❌ Choix invalide"
        exit 1
        ;;
esac

echo ""
echo "🎉 Page(s) ouverte(s) ! Si vous voyez encore des erreurs :"
echo "   1. Essayez de rafraîchir la page (F5)"
echo "   2. Acceptez les certificats auto-signés si demandé"  
echo "   3. Ou utilisez l'API REST qui fonctionne: curl http://127.0.0.1:52773/api/articles/health"