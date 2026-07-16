#!/bin/bash

# =================================================================
# Script de déploiement automatique pour NAS Synology
# Projet: IRIS Articles Lignes2Code
# =================================================================

set -euo pipefail  # Arrêt en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions utilitaires
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Vérification des prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    local missing_tools=()
    
    command -v sshpass >/dev/null 2>&1 || missing_tools+=("sshpass")
    command -v rsync >/dev/null 2>&1 || missing_tools+=("rsync")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Outils manquants: ${missing_tools[*]}"
        log_info "Installation automatique..."
        
        # Détection de l'OS et installation
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y "${missing_tools[@]}"
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y "${missing_tools[@]}"
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm "${missing_tools[@]}"
        else
            log_error "Gestionnaire de paquets non supporté. Installez manuellement: ${missing_tools[*]}"
            exit 1
        fi
    fi
    
    log_success "Prérequis vérifiés"
}

# Chargement du fichier .env
load_config() {
    if [[ ! -f .env ]]; then
        log_error "Fichier .env non trouvé!"
        log_info "Copiez .env.example vers .env et configurez vos valeurs:"
        log_info "cp .env.example .env && nano .env"
        exit 1
    fi
    
    # Chargement des variables
    set -a  # Exporter automatiquement les variables
    source .env
    set +a
    
    # Validation des variables obligatoires
    local required_vars=("SYNOLOGY_HOST" "SYNOLOGY_USER" "SYNOLOGY_PASSWORD" "IRIS_ADMIN_USER" "IRIS_ADMIN_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Variable $var non définie dans .env"
            exit 1
        fi
    done
    
    # Validation de la sécurité du mot de passe admin
    if [[ ${#IRIS_ADMIN_PASSWORD} -lt 8 ]]; then
        log_error "Le mot de passe IRIS_ADMIN_PASSWORD doit contenir au moins 8 caractères"
        exit 1
    fi
    
    log_success "Configuration chargée depuis .env"
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

# Génération du sel aléatoire
generate_salt() {
    # Générer un sel de 32 octets en hexadécimal
    openssl rand -hex 32
}

# Génération configuration IRIS à partir du template
generate_iris_config() {
    log_info "Génération de la configuration IRIS personnalisée..."
    
    local salt=$(generate_salt)
    local password_hash=$(generate_iris_password_hash "$IRIS_ADMIN_PASSWORD" "$salt")
    
    # Créer le hash complet au format IRIS : sel + hash
    local iris_hash="${salt}:${password_hash}"
    
    log_info "Génération du hash pour l'utilisateur: $IRIS_ADMIN_USER"
    
    # Vérifier que le template existe
    if [[ ! -f "config/merge.cpf.template" ]]; then
        log_error "Template config/merge.cpf.template non trouvé!"
        exit 1
    fi
    
    # Remplacer les placeholders dans le template
    export IRIS_ADMIN_USER="$IRIS_ADMIN_USER"
    export IRIS_ADMIN_PASSWORD_HASH="$iris_hash"
    export IRIS_ADMIN_ROLES="${IRIS_ADMIN_ROLES:-\%All}"
    
    # Substitution robuste ligne par ligne
    while IFS= read -r line; do
        line="${line//\{\{IRIS_ADMIN_USER\}\}/$IRIS_ADMIN_USER}"
        line="${line//\{\{IRIS_ADMIN_PASSWORD_HASH\}\}/$iris_hash}"
        line="${line//\{\{IRIS_ADMIN_ROLES\}\}/${IRIS_ADMIN_ROLES:-\%All}}"
        echo "$line"
    done < "config/merge.cpf.template" > "config/merge.cpf"
    
    log_success "Configuration IRIS générée: config/merge.cpf"
}
test_ssh_connection() {
    log_info "Test de connexion SSH vers $SYNOLOGY_USER@$SYNOLOGY_HOST:$SYNOLOGY_PORT..."
    
    if sshpass -p "$SYNOLOGY_PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p "$SYNOLOGY_PORT" "$SYNOLOGY_USER@$SYNOLOGY_HOST" "echo 'Connexion SSH OK'" >/dev/null 2>&1; then
        log_success "Connexion SSH établie"
    else
        log_error "Impossible de se connecter en SSH"
        log_info "Vérifiez:"
        log_info "- L'IP du NAS: $SYNOLOGY_HOST"
        log_info "- Le nom d'utilisateur: $SYNOLOGY_USER"
        log_info "- Le mot de passe dans .env"
        log_info "- Que SSH est activé sur le NAS (Panneau de configuration > Terminal & SNMP)"
        exit 1
    fi
}

# Exécution de commande SSH
ssh_exec() {
    sshpass -p "$SYNOLOGY_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$SYNOLOGY_PORT" "$SYNOLOGY_USER@$SYNOLOGY_HOST" "$@"
}

# Copie de fichiers via SCP
scp_copy() {
    local src="$1"
    local dst="$2"
    sshpass -p "$SYNOLOGY_PASSWORD" scp -o StrictHostKeyChecking=no -P "$SYNOLOGY_PORT" -r "$src" "$SYNOLOGY_USER@$SYNOLOGY_HOST:$dst"
}

# Sauvegarde avant déploiement
backup_existing() {
    if [[ "${BACKUP_BEFORE_DEPLOY:-true}" == "true" ]]; then
        log_info "Création d'une sauvegarde avant déploiement..."
        
        local backup_date=$(date +%Y%m%d_%H%M%S)
        
        ssh_exec "
            if [[ -d '$SYNOLOGY_PROJECT_PATH' ]]; then
                sudo mkdir -p '$SYNOLOGY_BACKUP_PATH'
                sudo tar -czf '$SYNOLOGY_BACKUP_PATH/pre-deploy-backup-$backup_date.tar.gz' -C '$SYNOLOGY_PROJECT_PATH' . 2>/dev/null || true
                echo 'Sauvegarde créée: pre-deploy-backup-$backup_date.tar.gz'
            fi
        "
        
        log_success "Sauvegarde terminée"
    fi
}

# Préparation de l'environnement sur le NAS
prepare_synology_environment() {
    log_info "Préparation de l'environnement Synology..."
    
    ssh_exec "
        # Création de la structure de dossiers
        sudo mkdir -p '$SYNOLOGY_PROJECT_PATH'/{data/{input,output,durable},config,src/cls,scripts}
        
        # Configuration des permissions
        sudo chown -R $SYNOLOGY_USER:users '$SYNOLOGY_PROJECT_PATH'
        sudo chmod -R 755 '$SYNOLOGY_PROJECT_PATH'
        sudo chmod 777 '$SYNOLOGY_PROJECT_PATH/data/durable' || true
        
        # Vérification de Docker
        if ! command -v docker >/dev/null 2>&1; then
            echo 'ERREUR: Docker n'\''est pas installé sur le NAS'
            echo 'Installez Docker via Package Center dans DSM'
            exit 1
        fi
        
        echo 'Environnement Synology préparé'
    "
    
    log_success "Environnement préparé"
}

# Génération du docker-compose pour Synology
generate_docker_compose() {
    log_info "Génération du fichier docker-compose-synology.yml..."
    
    cat > docker-compose-synology.yml << EOF
version: '3.8'

services:
  iris:
    build: .
    container_name: ${CONTAINER_NAME:-iris-articles-synology}
    ports:
      - "${HOST_PORT_WEB:-52773}:52773"  # Web Server
      - "${HOST_PORT_SUPER:-1972}:1972"  # SuperServer
    volumes:
      - ${SYNOLOGY_PROJECT_PATH}/data/durable:/dur/iris_conf.d/:rw
      - ${SYNOLOGY_PROJECT_PATH}/data/input:/home/irisowner/data/input:rw
      - ${SYNOLOGY_PROJECT_PATH}/data/output:/home/irisowner/data/output:rw
    environment:
      - ISC_DATA_DIRECTORY=/dur/iris_conf.d/
      - TZ=${TIMEZONE:-Europe/Paris}
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:52773/api/articles/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    restart: unless-stopped
    networks:
      - iris-network

networks:
  iris-network:
    driver: bridge
EOF
    
    log_success "Fichier docker-compose-synology.yml généré"
}

# Transfert des fichiers
transfer_files() {
    log_info "Transfert des fichiers vers le NAS..."
    
    # Liste des fichiers à transférer
    local files_to_copy=(
        "docker-compose-synology.yml"
        "Dockerfile" 
        "src/"
        "config/"
        "data/input/"
        "data/output/"
    )
    
    for file in "${files_to_copy[@]}"; do
        if [[ -e "$file" ]]; then
            log_info "Transfert: $file"
            scp_copy "$file" "$SYNOLOGY_PROJECT_PATH/"
        else
            log_warning "Fichier non trouvé: $file"
        fi
    done
    
    # Transfert du script de maintenance si existe
    if [[ -f "scripts/backup-iris-articles.sh" ]]; then
        scp_copy "scripts/backup-iris-articles.sh" "$SYNOLOGY_PROJECT_PATH/scripts/"
    fi
    
    log_success "Fichiers transférés"
}

# Arrêt de l'ancien conteneur
stop_existing_container() {
    log_info "Arrêt de l'ancien conteneur..."
    
    ssh_exec "
        cd '$SYNOLOGY_PROJECT_PATH'
        
        # Arrêt via docker-compose si existe
        if [[ -f docker-compose-synology.yml ]]; then
            sudo docker compose -f docker-compose-synology.yml down 2>/dev/null || true
        fi
        
        # Arrêt forcé du conteneur par nom
        sudo docker stop '${CONTAINER_NAME:-iris-articles-synology}' 2>/dev/null || true
        sudo docker rm '${CONTAINER_NAME:-iris-articles-synology}' 2>/dev/null || true
    "
    
    log_success "Ancien conteneur arrêté"
}

# Construction et démarrage du conteneur
build_and_start() {
    log_info "Construction et démarrage du conteneur..."
    
    local rebuild_flag=""
    if [[ "${FORCE_REBUILD:-false}" == "true" ]]; then
        rebuild_flag="--build"
    fi
    
    ssh_exec "
        cd '$SYNOLOGY_PROJECT_PATH'
        
        # Construction et démarrage
        sudo docker compose -f docker-compose-synology.yml up -d $rebuild_flag
        
        # Attendre quelques secondes pour le démarrage
        sleep 10
    "
    
    log_success "Conteneur démarré"
}

# Nettoyage des images obsolètes
cleanup_docker() {
    if [[ "${CLEANUP_OLD_IMAGES:-true}" == "true" ]]; then
        log_info "Nettoyage des images Docker obsolètes..."
        
        ssh_exec "
            # Nettoyage des images non utilisées
            sudo docker image prune -f >/dev/null 2>&1 || true
            
            # Nettoyage des volumes anonymes
            sudo docker volume prune -f >/dev/null 2>&1 || true
            
            echo 'Nettoyage Docker terminé'
        "
        
        log_success "Docker nettoyé"
    fi
}

# Vérification du déploiement
verify_deployment() {
    log_info "Vérification du déploiement..."
    
    # Test du statut du conteneur
    local container_status=$(ssh_exec "sudo docker ps --filter name=${CONTAINER_NAME:-iris-articles-synology} --format '{{.Status}}'")
    
    if [[ -z "$container_status" ]]; then
        log_error "Le conteneur n'est pas en cours d'exécution!"
        
        # Affichage des logs pour diagnostic
        log_info "Logs du conteneur:"
        ssh_exec "sudo docker logs '${CONTAINER_NAME:-iris-articles-synology}' --tail 50"
        exit 1
    fi
    
    log_success "Conteneur en cours d'exécution: $container_status"
    
    # Test de l'API (avec retry)
    log_info "Test de l'API REST..."
    local max_attempts=6
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Tentative $attempt/$max_attempts..."
        
        if ssh_exec "curl -f -s http://localhost:${HOST_PORT_WEB:-52773}/api/articles/health >/dev/null 2>&1"; then
            log_success "API REST opérationnelle!"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "L'API ne répond pas après $max_attempts tentatives"
            log_info "URL de test: http://$SYNOLOGY_HOST:${HOST_PORT_WEB:-52773}/api/articles/health"
            exit 1
        fi
        
        ((attempt++))
        sleep 10
    done
}

# Affichage des informations de connexion
display_connection_info() {
    log_success "=== DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ==="
    echo
    log_info "URLs d'accès:"
    echo "  Management Portal: http://$SYNOLOGY_HOST:${HOST_PORT_WEB:-52773}/csp/sys/UtilHome.csp"
    echo "  WebTerminal:       http://$SYNOLOGY_HOST:${HOST_PORT_WEB:-52773}/terminal/"
    echo "  API REST:          http://$SYNOLOGY_HOST:${HOST_PORT_WEB:-52773}/api/articles/health"
    echo "  Pages Articles:    http://$SYNOLOGY_HOST:${HOST_PORT_WEB:-52773}/web/articles/Article.Web.ArticleList.cls"
    echo
    log_info "Identifiants par défaut: _SYSTEM / SYS"
    echo
    
    if [[ -n "${EXTERNAL_DOMAIN:-}" ]]; then
        log_info "Accès externe (si configuré):"
        echo "  https://$EXTERNAL_DOMAIN:${HOST_PORT_WEB:-52773}/"
        echo
    fi
    
    log_info "Commandes utiles:"
    echo "  Logs:     ssh $SYNOLOGY_USER@$SYNOLOGY_HOST 'sudo docker logs ${CONTAINER_NAME:-iris-articles-synology} -f'"
    echo "  Statut:   ssh $SYNOLOGY_USER@$SYNOLOGY_HOST 'sudo docker ps'"
    echo "  Arrêt:    ssh $SYNOLOGY_USER@$SYNOLOGY_HOST 'cd $SYNOLOGY_PROJECT_PATH && sudo docker compose -f docker-compose-synology.yml down'"
    echo
}

# Envoi de notification email (optionnel)
send_notification() {
    if [[ -n "${NOTIFICATION_EMAIL:-}" && -n "${SMTP_SERVER:-}" ]]; then
        log_info "Envoi de notification email..."
        # Implémentation basique - à adapter selon vos besoins
        # echo "Déploiement IRIS Articles réussi sur $SYNOLOGY_HOST" | mail -s "Déploiement Synology" "$NOTIFICATION_EMAIL" || true
    fi
}

# Script principal
main() {
    echo "=========================================="
    echo "   DÉPLOIEMENT IRIS ARTICLES SYNOLOGY"
    echo "=========================================="
    echo
    
    check_prerequisites
    load_config
    generate_iris_config
    test_ssh_connection
    backup_existing
    prepare_synology_environment
    generate_docker_compose
    transfer_files
    stop_existing_container
    build_and_start
    cleanup_docker
    verify_deployment
    display_connection_info
    send_notification
    
    log_success "Déploiement terminé avec succès! 🎉"
}

# Gestion des options de ligne de commande
case "${1:-}" in
    "test")
        load_config
        test_ssh_connection
        log_success "Test de connexion réussi!"
        ;;
    "logs")
        load_config
        log_info "Affichage des logs..."
        ssh_exec "sudo docker logs '${CONTAINER_NAME:-iris-articles-synology}' -f"
        ;;
    "status")
        load_config
        log_info "Statut du conteneur:"
        ssh_exec "sudo docker ps --filter name=${CONTAINER_NAME:-iris-articles-synology}"
        ;;
    "stop")
        load_config
        log_info "Arrêt du conteneur..."
        ssh_exec "cd '$SYNOLOGY_PROJECT_PATH' && sudo docker compose -f docker-compose-synology.yml down"
        log_success "Conteneur arrêté"
        ;;
    "restart")
        load_config
        log_info "Redémarrage du conteneur..."
        ssh_exec "cd '$SYNOLOGY_PROJECT_PATH' && sudo docker compose -f docker-compose-synology.yml restart"
        log_success "Conteneur redémarré"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [OPTION]"
        echo
        echo "Options:"
        echo "  (aucune)  Déploiement complet"
        echo "  test      Test de connexion SSH uniquement"
        echo "  logs      Afficher les logs du conteneur"
        echo "  status    Afficher le statut du conteneur"
        echo "  stop      Arrêter le conteneur"
        echo "  restart   Redémarrer le conteneur"
        echo "  help      Afficher cette aide"
        echo
        ;;
    *)
        main
        ;;
esac