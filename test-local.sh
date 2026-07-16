#!/bin/bash

# =================================================================
# Script de test local pour génération configuration IRIS
# =================================================================

set -euo pipefail

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Chargement du .env local
load_config() {
    if [[ ! -f .env ]]; then
        log_error "Fichier .env non trouvé!"
        exit 1
    fi
    
    set -a
    source .env
    set +a
    
    if [[ -z "${IRIS_ADMIN_USER:-}" || -z "${IRIS_ADMIN_PASSWORD:-}" ]]; then
        log_error "Variables IRIS_ADMIN_USER et IRIS_ADMIN_PASSWORD requises dans .env"
        exit 1
    fi
    
    log_success "Configuration chargée: utilisateur=$IRIS_ADMIN_USER"
}

# Génération du hash de mot de passe compatible IRIS
generate_iris_password_hash() {
    local password="$1"
    local salt="$2"
    
    # IRIS utilise un format spécifique: SHA-512 avec salt et iterations
    local combined="${salt}${password}"
    
    # Utiliser openssl pour SHA-512 (plus rapide et compatible)
    local hash=$(echo -n "$combined" | openssl dgst -sha512 -binary | base64 | tr -d '\n')
    
    # Ajouter iterations réduites pour compatibilité et performance
    for (( i=0; i<100; i++ )); do
        hash=$(echo -n "${hash}${password}" | openssl dgst -sha512 -binary | base64 | tr -d '\n')
    done
    
    echo "$hash"
}

# Génération du sel
generate_salt() {
    openssl rand -hex 32
}

# Test de la génération du hash
test_hash_generation() {
    log_info "=== TEST GÉNÉRATION HASH IRIS ==="
    
    local salt=$(generate_salt)
    local password_hash=$(generate_iris_password_hash "$IRIS_ADMIN_PASSWORD" "$salt")
    local full_hash="${salt}:${password_hash}"
    
    log_success "Salt généré: $salt"
    log_success "Hash généré (longueur: ${#password_hash})"
    log_success "Hash complet IRIS généré"
    
    # Stocker pour utilisation (sans affichage pour éviter pollution)
    export GENERATED_HASH="$full_hash"
}

# Génération du hash de mot de passe au format IRIS
generate_iris_password_hash() {
    local password="$1"
    
    # IRIS utilise un format simple : Base64 du SHA-1 ou SHA-256
    # Essayons le format le plus simple pour commencer
    echo -n "$password" | openssl dgst -sha256 -binary | base64 | tr -d '\n'
}

# Test de la génération du hash
test_hash_generation() {
    log_info "=== TEST GÉNÉRATION HASH IRIS ==="
    
    local password_hash=$(generate_iris_password_hash "$IRIS_ADMIN_PASSWORD")
    
    log_success "Hash généré (SHA256-Base64)"
    log_success "Format: ${password_hash:0:32}..."
    
    # Stocker pour utilisation
    export GENERATED_HASH="$password_hash"
}

# Génération de la configuration IRIS
generate_config() {
    log_info "=== GÉNÉRATION CONFIGURATION IRIS ==="
    
    if [[ ! -f "config/merge.cpf.template" ]]; then
        log_error "Template config/merge.cpf.template non trouvé!"
        exit 1
    fi
    
    log_info "L'utilisateur admin sera créé via ObjectScript lors de l'initialisation"
    log_info "Génération du fichier CPF simplifié..."
    
    # Copier directement le template car plus de variables à remplacer
    cp config/merge.cpf.template config/merge.cpf
    
    log_success "Configuration générée dans config/merge.cpf"
    log_info "Contenu généré:"
    cat config/merge.cpf
}

# Test complet
test_complete_build() {
    log_info "=== TEST CONSTRUCTION CONTENEUR LOCAL ==="
    
    # Arrêter le conteneur actuel si nécessaire
    log_info "Arrêt du conteneur existant..."
    docker compose down 2>/dev/null || true
    
    # Construire avec la nouvelle configuration
    log_info "Construction de l'image avec nouvelle configuration..."
    docker compose build --no-cache
    
    # Démarrer
    log_info "Démarrage du conteneur..."
    docker compose up -d
    
    # Attendre le démarrage
    log_info "Attente du démarrage (30 secondes)..."
    sleep 30
    
    # Vérifier la santé
    log_info "Test de l'API..."
    if curl -f -s http://localhost:52773/api/articles/health >/dev/null 2>&1; then
        log_success "API opérationnelle!"
        
        # Test de connexion avec le nouvel utilisateur
        log_info "Test de connexion utilisateur: $IRIS_ADMIN_USER"
        local auth_response=$(curl -s -X POST http://localhost:52773/api/articles/auth/login \
          -H "Content-Type: application/json" \
          -d "{\"username\": \"$IRIS_ADMIN_USER\", \"password\": \"$IRIS_ADMIN_PASSWORD\"}")
        
        if echo "$auth_response" | grep -q "token"; then
            log_success "Authentification réussie avec le nouvel utilisateur!"
            echo "$auth_response" | jq '.' 2>/dev/null || echo "$auth_response"
        else
            log_error "Échec de l'authentification"
            echo "Réponse: $auth_response"
            return 1
        fi
    else
        log_error "API non responsive"
        log_info "Logs du conteneur:"
        docker compose logs --tail 20
        return 1
    fi
}

# Affichage des informations de connexion
show_connection_info() {
    log_success "=== INFORMATIONS DE CONNEXION ==="
    echo
    log_info "URLs locales:"
    echo "  Management Portal: http://localhost:52773/csp/sys/UtilHome.csp"
    echo "  WebTerminal:       http://localhost:52773/terminal/"
    echo "  API REST:          http://localhost:52773/api/articles/health"
    echo "  Pages Articles:    http://localhost:52773/web/articles/Article.Web.ArticleList.cls"
    echo
    log_info "Nouvel utilisateur créé:"
    echo "  Utilisateur: $IRIS_ADMIN_USER"
    echo "  Mot de passe: $IRIS_ADMIN_PASSWORD"
    echo "  Rôles: $IRIS_ADMIN_ROLES"
    echo
    log_warning "NOTE: L'ancien utilisateur _SYSTEM/SYS n'est plus disponible"
}

# Script principal
main() {
    local action="${1:-all}"
    
    log_info "=========================================="
    log_info "    TEST LOCAL IRIS ARTICLES"
    log_info "=========================================="
    echo
    
    load_config
    
    case "$action" in
        "config")
            generate_config
            ;;
        "hash")
            test_hash_generation
            ;;
        "build")
            generate_config
            test_complete_build
            show_connection_info
            ;;
        "all")
            generate_config
            test_complete_build
            show_connection_info
            ;;
        *)
            echo "Usage: $0 {config|hash|build|all}"
            echo
            echo "Actions:"
            echo "  config  - Génère seulement la configuration"
            echo "  hash    - Test seulement la génération du hash"
            echo "  build   - Reconstruit et teste le conteneur"
            echo "  all     - Tout faire (par défaut)"
            exit 1
            ;;
    esac
    
    log_success "Test terminé avec succès! 🎉"
}

main "$@"