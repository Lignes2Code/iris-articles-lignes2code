# Déploiement sur NAS Synology

Guide complet pour déployer le projet IRIS Articles Lignes2Code sur un NAS Synology avec Docker.

## Prérequis

### Configuration minimale recommandée

- **NAS Synology** avec DSM 7.0+ 
- **RAM** : 4 Go minimum (8 Go recommandé)
- **Stockage** : 5 Go d'espace libre minimum
- **CPU** : x86_64 (Intel/AMD) - requis pour InterSystems IRIS

### Packages Synology requis

1. **Docker** (via Package Center)
2. **File Station** (préinstallé)
3. **SSH** (optionnel, pour administration en ligne de commande)

## Méthode 1 : Déploiement via Docker Compose (Recommandée)

### 1. Préparer l'environnement

#### 1.1 Activer SSH (optionnel)

```bash
# Dans DSM : Panneau de configuration > Terminal & SNMP
# Cocher "Activer le service SSH"
# Port par défaut : 22
```

#### 1.2 Créer la structure de dossiers

Via **File Station** ou **SSH** :

```bash
# Connectez-vous en SSH à votre NAS
ssh admin@[IP_SYNOLOGY]

# Créer le dossier du projet
sudo mkdir -p /volume1/docker/iris-articles
cd /volume1/docker/iris-articles

# Créer la structure nécessaire
sudo mkdir -p {data/{input,output,durable},config,src/cls}
sudo chmod -R 755 /volume1/docker/iris-articles
sudo chown -R admin:users /volume1/docker/iris-articles
```

#### 1.3 Transférer les fichiers du projet

**Option A : Via File Station (Interface web)**

1. Ouvrir **File Station** dans DSM
2. Naviguer vers `/docker/iris-articles/`
3. Uploader tous les fichiers du projet :
   - `docker-compose.yml`
   - `Dockerfile`
   - Dossier `src/` complet
   - Dossier `config/` complet
   - Fichiers d'exemple dans `data/`

**Option B : Via SCP depuis votre machine de développement**

```bash
# Depuis votre machine locale
scp -r /chemin/vers/iris-articles-lignes2code/* admin@[IP_SYNOLOGY]:/volume1/docker/iris-articles/
```

#### 1.4 Adapter docker-compose.yml pour Synology

Créer un fichier `docker-compose-synology.yml` :

```yaml
version: '3.8'

services:
  iris:
    build: .
    container_name: iris-articles-synology
    ports:
      - "52773:52773"  # Web Server (Portal, REST API, CSP)
      - "1972:1972"    # SuperServer
    volumes:
      # Données durables IRIS (attention au chemin Synology)
      - /volume1/docker/iris-articles/data/durable:/dur/iris_conf.d/:rw
      # Dossier surveillé pour import
      - /volume1/docker/iris-articles/data/input:/home/irisowner/data/input:rw
      # Dossier de sortie (fichiers traités)
      - /volume1/docker/iris-articles/data/output:/home/irisowner/data/output:rw
    environment:
      - ISC_DATA_DIRECTORY=/dur/iris_conf.d/
      - TZ=Europe/Paris
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

# Optionnel : volumes nommés (alternative aux bind mounts)
# volumes:
#   iris_data:
#   iris_input:
#   iris_output:
```

### 2. Déployer le conteneur

#### 2.1 Via SSH

```bash
# Se connecter au NAS
ssh admin@[IP_SYNOLOGY]
cd /volume1/docker/iris-articles

# Construire et démarrer
sudo docker compose -f docker-compose-synology.yml up -d --build

# Vérifier le statut
sudo docker compose -f docker-compose-synology.yml ps

# Suivre les logs
sudo docker compose -f docker-compose-synology.yml logs -f iris
```

#### 2.2 Vérifier le déploiement

```bash
# Tester l'API
curl http://[IP_SYNOLOGY]:52773/api/articles/health

# Réponse attendue :
# {"status":"OK","service":"Articles API - Lignes2Code","timestamp":"...","version":"1.1.0"}
```

## Méthode 2 : Déploiement via interface Docker de Synology

### 1. Ouvrir Docker dans DSM

1. Aller dans **Package Center** → **Docker** → **Ouvrir**
2. Naviguer vers l'onglet **Image**

### 2. Construire l'image

#### 2.1 Préparer les fichiers

Via **File Station**, s'assurer que tous les fichiers sont dans `/docker/iris-articles/`

#### 2.2 Construire via ligne de commande puis importer

```bash
# Sur votre machine de développement
docker build -t iris-articles:synology .
docker save iris-articles:synology > iris-articles-synology.tar

# Transférer l'image sur le NAS
scp iris-articles-synology.tar admin@[IP_SYNOLOGY]:/volume1/docker/

# Sur le NAS, charger l'image
ssh admin@[IP_SYNOLOGY]
sudo docker load < /volume1/docker/iris-articles-synology.tar
```

### 3. Créer le conteneur via l'interface web

1. Dans **Docker** → **Image**, sélectionner `iris-articles:synology`
2. Cliquer **Lancer**
3. **Paramètres de conteneur** :
   - **Nom** : `iris-articles-synology`
   - **Exécuter le conteneur après création** : ✅

4. **Paramètres avancés** :
   - **Redémarrage automatique** : ✅
   - **Variables d'environnement** :
     ```
     ISC_DATA_DIRECTORY=/dur/iris_conf.d/
     TZ=Europe/Paris
     ```

5. **Configuration des ports** :
   ```
   Port local : 52773 → Port de conteneur : 52773
   Port local : 1972  → Port de conteneur : 1972
   ```

6. **Montage de volume** :
   ```
   /volume1/docker/iris-articles/data/durable → /dur/iris_conf.d/
   /volume1/docker/iris-articles/data/input   → /home/irisowner/data/input
   /volume1/docker/iris-articles/data/output  → /home/irisowner/data/output
   ```

## Méthode 3 : Avec Portainer (Interface avancée)

### 1. Installer Portainer

```bash
# Via SSH sur le NAS
sudo docker run -d \
  --name portainer \
  --restart=always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /volume1/docker/portainer_data:/data \
  portainer/portainer-ce:latest
```

### 2. Déployer via Portainer

1. Accéder à http://[IP_SYNOLOGY]:9000
2. **Stacks** → **Add stack**
3. Coller le contenu de `docker-compose-synology.yml`
4. Cliquer **Deploy the stack**

## Configuration réseau et accès

### URLs d'accès après déploiement

| Service | URL | Identifiants |
|---------|-----|-------------|
| **Management Portal** | `http://[IP_SYNOLOGY]:52773/csp/sys/UtilHome.csp` | `_SYSTEM` / `SYS` |
| **WebTerminal** | `http://[IP_SYNOLOGY]:52773/terminal/` | `_SYSTEM` / `SYS` |
| **API REST** | `http://[IP_SYNOLOGY]:52773/api/articles/health` | - |
| **Pages Articles** | `http://[IP_SYNOLOGY]:52773/web/articles/Article.Web.ArticleList.cls` | - |

### Configuration pare-feu (DSM)

1. **Panneau de configuration** → **Sécurité** → **Pare-feu**
2. Créer une règle pour autoriser les ports :
   - **Port 52773** : Interface web IRIS
   - **Port 1972** : SuperServer IRIS (optionnel, pour clients externes)

### Accès externe (DDNS/VPN)

#### Option A : DDNS Synology

1. **Panneau de configuration** → **Accès externe** → **DDNS**
2. Configurer un nom de domaine gratuit `monnas.synology.me`
3. Rediriger les ports dans votre box internet :
   ```
   Port externe 52773 → IP_NAS:52773
   ```

#### Option B : VPN Synology

1. **Package Center** → **VPN Server**
2. Configurer OpenVPN ou L2TP/IPSec
3. Accès sécurisé via VPN uniquement

## Maintenance et sauvegarde

### Sauvegarde automatique

Créer un script de sauvegarde :

```bash
#!/bin/bash
# /volume1/scripts/backup-iris-articles.sh

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/volume1/backups/iris-articles"
PROJECT_DIR="/volume1/docker/iris-articles"

mkdir -p $BACKUP_DIR

# Arrêter le conteneur
sudo docker compose -f $PROJECT_DIR/docker-compose-synology.yml stop

# Sauvegarder les données
tar -czf "$BACKUP_DIR/iris-data-$BACKUP_DATE.tar.gz" \
  -C $PROJECT_DIR/data durable/ input/ output/

# Sauvegarder la configuration
tar -czf "$BACKUP_DIR/iris-config-$BACKUP_DATE.tar.gz" \
  -C $PROJECT_DIR docker-compose-synology.yml Dockerfile config/ src/

# Redémarrer le conteneur
sudo docker compose -f $PROJECT_DIR/docker-compose-synology.yml start

# Nettoyer les sauvegardes anciennes (>30 jours)
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Sauvegarde terminée: $BACKUP_DATE"
```

### Programmation via Planificateur de tâches

1. **Panneau de configuration** → **Planificateur de tâches**
2. **Créer** → **Tâche planifiée** → **Script défini par l'utilisateur**
3. **Général** : Nom `Backup IRIS Articles`
4. **Planification** : Hebdomadaire, dimanche 02h00
5. **Paramètres de tâche** : `/volume1/scripts/backup-iris-articles.sh`

### Mise à jour du conteneur

```bash
# Se connecter au NAS
ssh admin@[IP_SYNOLOGY]
cd /volume1/docker/iris-articles

# Arrêter les services
sudo docker compose -f docker-compose-synology.yml down

# Mettre à jour le code source (via git ou upload manuel)
# ...

# Reconstruire et redémarrer
sudo docker compose -f docker-compose-synology.yml up -d --build

# Vérifier
sudo docker compose -f docker-compose-synology.yml logs -f iris
```

## Surveillance et monitoring

### Logs via interface Synology

1. **Docker** → **Conteneur** → `iris-articles-synology`
2. Onglet **Journal** pour voir les logs en temps réel

### Monitoring des ressources

1. **Gestionnaire de ressources** dans DSM
2. Surveiller l'utilisation CPU/RAM de Docker

### Alertes email

Configuration dans **Panneau de configuration** → **Notification** pour recevoir des alertes si le conteneur s'arrête.

## Dépannage

### Problèmes courants

#### Le conteneur ne démarre pas

```bash
# Vérifier les logs
sudo docker logs iris-articles-synology

# Vérifier l'espace disque
df -h /volume1/

# Vérifier les permissions
ls -la /volume1/docker/iris-articles/data/durable/
```

#### Erreur de port déjà utilisé

```bash
# Identifier le processus utilisant le port
sudo netstat -tulpn | grep :52773

# Arrêter le service conflictuel
sudo docker stop [CONTAINER_ID]
```

#### Problèmes de performance

- Augmenter la RAM allouée à Docker dans DSM
- Utiliser des volumes SSD si disponibles
- Limiter les ressources du conteneur :

```yaml
# Dans docker-compose-synology.yml
services:
  iris:
    # ...
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          memory: 2G
```

## Sécurité spécifique Synology

### Bonnes pratiques

1. **Créer un utilisateur dédié** pour Docker (pas admin)
2. **Désactiver SSH** après configuration initiale
3. **Utiliser HTTPS** : Configurer un certificat SSL dans DSM
4. **Réseau isolé** : Créer un réseau Docker dédié
5. **Firewall** : Restreindre l'accès aux IP autorisées
6. **Auto-update** : Activer la mise à jour automatique de DSM

### Configuration HTTPS

```yaml
# Ajout dans docker-compose-synology.yml pour reverse proxy Synology
services:
  iris:
    # ...
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.iris.rule=Host(`iris.monnas.synology.me`)"
      - "traefik.http.routers.iris.tls=true"
```

---

## Conclusion

Ce déploiement vous permet d'avoir votre service IRIS Articles accessible 24h/24 sur votre réseau local et potentiellement depuis l'extérieur. Le NAS Synology offre une excellente stabilité et des outils de backup automatiques pour sécuriser votre installation.

### Points d'attention

- **Performance** : IRIS peut nécessiter des ressources importantes
- **Sauvegrade** : Planifier des backups réguliers
- **Sécurité** : Ne pas exposer directement sur Internet sans VPN
- **Monitoring** : Surveiller régulièrement les ressources et logs

Pour toute question spécifique au déploiement Synology, consulter la [documentation officielle Docker de Synology](https://kb.synology.com/fr-fr/DSM/help/Docker).