#!/bin/bash

# =================================================================
# Script de maintenance automatique IRIS Articles
# À installer sur le NAS Synology via Planificateur de tâches
# =================================================================

# Configuration (à adapter selon votre installation)
PROJECT_DIR="/volume1/docker/iris-articles"
BACKUP_DIR="/volume1/backups/iris-articles"
CONTAINER_NAME="iris-articles-synology"
RETENTION_DAYS=30
LOG_FILE="/volume1/docker/iris-articles/maintenance.log"

# Fonction de log avec timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérification de la santé du conteneur
check_container_health() {
    log "=== VÉRIFICATION SANTÉ CONTENEUR ==="
    
    # Vérifier si le conteneur fonctionne
    if ! docker ps --filter name="$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}" | grep -q "$CONTAINER_NAME"; then
        log "ALERTE: Le conteneur $CONTAINER_NAME n'est pas en cours d'exécution!"
        
        # Tentative de redémarrage automatique
        log "Tentative de redémarrage du conteneur..."
        cd "$PROJECT_DIR" || exit 1
        
        if docker compose -f docker-compose-synology.yml up -d; then
            log "SUCCESS: Conteneur redémarré automatiquement"
            sleep 30  # Attendre le démarrage
        else
            log "ERREUR: Impossible de redémarrer le conteneur automatiquement"
            return 1
        fi
    fi
    
    # Test de l'API REST
    if curl -f -s http://localhost:52773/api/articles/health >/dev/null 2>&1; then
        log "SUCCESS: API REST opérationnelle"
    else
        log "ALERTE: L'API REST ne répond pas"
        
        # Récupérer les logs pour diagnostic
        log "Logs du conteneur (20 dernières lignes):"
        docker logs "$CONTAINER_NAME" --tail 20 2>&1 | tee -a "$LOG_FILE"
        
        return 1
    fi
    
    # Vérification de l'utilisation des ressources
    local cpu_usage=$(docker stats "$CONTAINER_NAME" --no-stream --format "{{.CPUPerc}}" | sed 's/%//')
    local mem_usage=$(docker stats "$CONTAINER_NAME" --no-stream --format "{{.MemPerc}}" | sed 's/%//')
    
    log "Utilisation CPU: ${cpu_usage}% | Mémoire: ${mem_usage}%"
    
    # Alertes sur utilisation excessive
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        log "ALERTE: Utilisation CPU élevée (${cpu_usage}%)"
    fi
    
    if (( $(echo "$mem_usage > 85" | bc -l) )); then
        log "ALERTE: Utilisation mémoire élevée (${mem_usage}%)"
    fi
    
    log "Vérification santé terminée"
}

# Sauvegarde des données
backup_data() {
    log "=== SAUVEGARDE DES DONNÉES ==="
    
    local backup_date=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/iris-articles-backup-$backup_date.tar.gz"
    
    # Créer le dossier de backup si nécessaire
    mkdir -p "$BACKUP_DIR"
    
    # Arrêter temporairement le conteneur pour une sauvegarde cohérente
    log "Arrêt temporaire du conteneur pour sauvegarde..."
    cd "$PROJECT_DIR" || exit 1
    docker compose -f docker-compose-synology.yml stop
    
    # Sauvegarde des données IRIS
    log "Création de la sauvegarde: $backup_file"
    if tar -czf "$backup_file" \
        -C "$PROJECT_DIR" \
        data/durable/ \
        data/input/ \
        data/output/ \
        docker-compose-synology.yml \
        2>/dev/null; then
        
        log "SUCCESS: Sauvegarde créée ($(du -h "$backup_file" | cut -f1))"
    else
        log "ERREUR: Échec de la sauvegarde"
    fi
    
    # Redémarrer le conteneur
    log "Redémarrage du conteneur..."
    docker compose -f docker-compose-synology.yml start
    
    # Attendre le redémarrage
    sleep 30
    
    # Nettoyage des anciennes sauvegardes
    log "Nettoyage des sauvegardes anciennes (>$RETENTION_DAYS jours)..."
    find "$BACKUP_DIR" -name "iris-articles-backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete
    local remaining=$(find "$BACKUP_DIR" -name "iris-articles-backup-*.tar.gz" | wc -l)
    log "Sauvegardes conservées: $remaining"
    
    log "Sauvegarde terminée"
}

# Nettoyage des logs IRIS
cleanup_logs() {
    log "=== NETTOYAGE LOGS ==="
    
    # Nettoyage des logs Docker
    docker system prune -f >/dev/null 2>&1
    
    # Rotation du fichier de log de maintenance
    if [[ -f "$LOG_FILE" && $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt 10485760 ]]; then  # 10MB
        log "Rotation du fichier de log (>10MB)"
        mv "$LOG_FILE" "${LOG_FILE}.old"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Nouveau fichier de log après rotation" > "$LOG_FILE"
    fi
    
    # Nettoyage des fichiers temporaires dans data/input (traitement échoué)
    local temp_files=$(find "$PROJECT_DIR/data/input" -name "*.tmp" -o -name "*.processing" 2>/dev/null | wc -l)
    if [[ $temp_files -gt 0 ]]; then
        log "Suppression de $temp_files fichiers temporaires"
        find "$PROJECT_DIR/data/input" -name "*.tmp" -o -name "*.processing" -mmin +60 -delete 2>/dev/null
    fi
    
    log "Nettoyage terminé"
}

# Monitoring des fichiers en attente
monitor_file_processing() {
    log "=== MONITORING TRAITEMENT FICHIERS ==="
    
    local pending_files=$(find "$PROJECT_DIR/data/input" -name "*.json" 2>/dev/null | wc -l)
    local processed_files=$(find "$PROJECT_DIR/data/output" -name "*.json*" -mtime -1 2>/dev/null | wc -l)
    
    log "Fichiers en attente: $pending_files | Traités (24h): $processed_files"
    
    # Alerte si trop de fichiers en attente
    if [[ $pending_files -gt 10 ]]; then
        log "ALERTE: Trop de fichiers en attente de traitement ($pending_files)"
        
        # Liste des fichiers les plus anciens
        log "Fichiers les plus anciens:"
        find "$PROJECT_DIR/data/input" -name "*.json" -printf '%T+ %p\n' | sort | head -5 | tee -a "$LOG_FILE"
    fi
    
    # Vérifier s'il y a des fichiers bloqués (>1h en input)
    local stuck_files=$(find "$PROJECT_DIR/data/input" -name "*.json" -mmin +60 2>/dev/null | wc -l)
    if [[ $stuck_files -gt 0 ]]; then
        log "ALERTE: $stuck_files fichiers bloqués depuis plus d'1 heure"
    fi
}

# Test de performance de base
performance_test() {
    log "=== TEST PERFORMANCE ==="
    
    # Test simple de l'API
    local start_time=$(date +%s%N)
    if curl -f -s http://localhost:52773/api/articles/health >/dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local response_time=$(( (end_time - start_time) / 1000000 ))  # en millisecondes
        log "Temps de réponse API: ${response_time}ms"
        
        if [[ $response_time -gt 5000 ]]; then  # > 5 secondes
            log "ALERTE: Temps de réponse API lent (${response_time}ms)"
        fi
    else
        log "ERREUR: Impossible de tester les performances (API non disponible)"
    fi
    
    # Espace disque
    local disk_usage=$(df "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    log "Utilisation disque: ${disk_usage}%"
    
    if [[ $disk_usage -gt 85 ]]; then
        log "ALERTE: Espace disque faible (${disk_usage}%)"
    fi
}

# Rapport de statut complet
generate_status_report() {
    log "=== RAPPORT DE STATUT ==="
    
    # Statut du conteneur
    local container_status=$(docker ps --filter name="$CONTAINER_NAME" --format "{{.Status}}" || echo "Non trouvé")
    log "Statut conteneur: $container_status"
    
    # Version d'IRIS (si accessible)
    local iris_version=$(docker exec "$CONTAINER_NAME" iris version 2>/dev/null | grep "InterSystems IRIS" || echo "Non disponible")
    log "Version IRIS: $iris_version"
    
    # Statistiques base de données (nombre d'articles)
    local article_count=$(curl -s http://localhost:52773/api/articles/articles?pageSize=1 2>/dev/null | \
                         grep -o '"total":[0-9]*' | cut -d: -f2 || echo "N/A")
    log "Nombre d'articles: $article_count"
    
    # Uptime du conteneur
    local uptime=$(docker ps --filter name="$CONTAINER_NAME" --format "{{.Status}}" | \
                  grep -o "Up.*" || echo "Inconnu")
    log "Uptime: $uptime"
    
    # Taille des données
    local data_size=$(du -sh "$PROJECT_DIR/data/durable" 2>/dev/null | cut -f1 || echo "N/A")
    log "Taille données IRIS: $data_size"
    
    local backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "N/A")
    log "Taille sauvegardes: $backup_size"
}

# Fonction principale
main() {
    local task="${1:-all}"
    
    # Créer le fichier de log si inexistant
    touch "$LOG_FILE"
    
    log "=========================================="
    log "MAINTENANCE IRIS ARTICLES - TÂCHE: $task"
    log "=========================================="
    
    case "$task" in
        "health")
            check_container_health
            ;;
        "backup")
            backup_data
            ;;
        "cleanup")
            cleanup_logs
            ;;
        "monitor")
            monitor_file_processing
            ;;
        "performance")
            performance_test
            ;;
        "status")
            generate_status_report
            ;;
        "all")
            check_container_health
            monitor_file_processing
            performance_test
            cleanup_logs
            generate_status_report
            ;;
        "full")
            check_container_health
            backup_data
            monitor_file_processing
            performance_test
            cleanup_logs
            generate_status_report
            ;;
        *)
            echo "Usage: $0 {health|backup|cleanup|monitor|performance|status|all|full}"
            echo
            echo "Tâches disponibles:"
            echo "  health      - Vérification santé conteneur"
            echo "  backup      - Sauvegarde des données"
            echo "  cleanup     - Nettoyage logs et fichiers temp"
            echo "  monitor     - Monitoring traitement fichiers"
            echo "  performance - Test performance de base"
            echo "  status      - Rapport de statut complet"
            echo "  all         - Toutes les tâches sauf backup"
            echo "  full        - Toutes les tâches y compris backup"
            exit 1
            ;;
    esac
    
    log "Maintenance terminée: $(date)"
    log "=========================================="
}

# Exécution
main "$@"