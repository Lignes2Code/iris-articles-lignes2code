# Scripts de déploiement Synology

Ce dossier contient les scripts pour automatiser le déploiement et la maintenance du projet IRIS Articles sur un NAS Synology.

## 🚀 Déploiement rapide

### 1. Configuration initiale

```bash
# Copier le fichier d'exemple et le configurer
cp .env.example .env
nano .env
```

**Variables obligatoires à configurer dans `.env` :**
```bash
SYNOLOGY_HOST=192.168.1.100        # IP de votre NAS
SYNOLOGY_USER=admin                # Utilisateur SSH
SYNOLOGY_PASSWORD=votre_mot_de_passe  # Mot de passe SSH
```

### 2. Test de connexion

```bash
./deploy-synology.sh test
```

### 3. Déploiement complet

```bash
./deploy-synology.sh
```

## 🛠️ Script principal : `deploy-synology.sh`

### Fonctionnalités

- ✅ **Test automatique** de la connexion SSH
- ✅ **Sauvegarde** avant déploiement (optionnel)
- ✅ **Transfert** automatique des fichiers
- ✅ **Construction** et démarrage du conteneur
- ✅ **Vérification** du déploiement
- ✅ **Nettoyage** des images obsolètes

### Commandes disponibles

| Commande | Description |
|----------|-------------|
| `./deploy-synology.sh` | Déploiement complet |
| `./deploy-synology.sh test` | Test de connexion SSH |
| `./deploy-synology.sh logs` | Afficher les logs |
| `./deploy-synology.sh status` | Statut du conteneur |
| `./deploy-synology.sh stop` | Arrêter le conteneur |
| `./deploy-synology.sh restart` | Redémarrer le conteneur |

### Prérequis (installation automatique)

Le script teste et installe automatiquement :
- `sshpass` (connexion SSH avec mot de passe)
- `rsync` (transfert de fichiers)
- `docker` (construction des images)

## 🔧 Script de maintenance : `maintenance-synology.sh`

### Installation sur le NAS

1. **Transférer le script** (fait automatiquement par `deploy-synology.sh`)

2. **Configurer le Planificateur de tâches** dans DSM :
   - **Panneau de configuration** → **Planificateur de tâches**
   - **Créer** → **Tâche planifiée** → **Script défini par l'utilisateur**
   - **Nom** : `Maintenance IRIS Articles`
   - **Utilisateur** : `root`
   - **Planification** : Quotidienne à 02h00
   - **Commande** : `/volume1/docker/iris-articles/scripts/maintenance-synology.sh all`

### Tâches de maintenance disponibles

| Tâche | Description | Fréquence recommandée |
|-------|-------------|----------------------|
| `health` | Vérification santé conteneur | Toutes les heures |
| `backup` | Sauvegarde des données | Quotidienne |
| `cleanup` | Nettoyage logs et fichiers temp | Quotidienne |
| `monitor` | Monitoring traitement fichiers | Toutes les 6h |
| `performance` | Test performance de base | Quotidienne |
| `status` | Rapport de statut complet | Quotidienne |
| `all` | Toutes les tâches sauf backup | Quotidienne |
| `full` | Toutes les tâches y compris backup | Hebdomadaire |

### Exemples d'utilisation

```bash
# Sur le NAS via SSH
ssh admin@192.168.1.100

# Vérification rapide
/volume1/docker/iris-articles/scripts/maintenance-synology.sh health

# Sauvegarde manuelle
/volume1/docker/iris-articles/scripts/maintenance-synology.sh backup

# Rapport de statut
/volume1/docker/iris-articles/scripts/maintenance-synology.sh status

# Maintenance complète
/volume1/docker/iris-articles/scripts/maintenance-synology.sh full
```

### Configuration du Planificateur

#### Tâche quotidienne (maintenance générale)
```
Nom: Maintenance IRIS Articles
Script: /volume1/docker/iris-articles/scripts/maintenance-synology.sh all
Heure: 02:00
Notification email: Activée (en cas d'erreur)
```

#### Tâche hebdomadaire (sauvegarde complète)
```
Nom: Sauvegarde IRIS Articles
Script: /volume1/docker/iris-articles/scripts/maintenance-synology.sh backup
Jour: Dimanche
Heure: 03:00
Notification email: Activée
```

#### Tâche de monitoring (toutes les heures)
```
Nom: Monitoring IRIS Articles
Script: /volume1/docker/iris-articles/scripts/maintenance-synology.sh health
Intervalle: Toutes les heures
Notification email: Activée (en cas d'erreur uniquement)
```

## 📁 Structure des fichiers

```
iris-articles-lignes2code/
├── .env.example              # Modèle de configuration
├── .env                      # Configuration personnelle (ignoré par git)
├── deploy-synology.sh        # Script de déploiement principal
├── docker-compose-synology.yml  # Généré automatiquement
└── scripts/
    ├── maintenance-synology.sh   # Script de maintenance
    └── README.md                # Cette documentation
```

## 🔒 Sécurité

### Fichiers sensibles (exclus du git)

- `.env` - Contient les mots de passe SSH
- `docker-compose-synology.yml` - Chemins absolus spécifiques

Ces fichiers sont automatiquement exclus du contrôle de version via `.gitignore`.

### Bonnes pratiques

1. **Utilisateur dédié** : Créez un utilisateur spécifique pour Docker (pas `admin`)
2. **SSH sécurisé** : 
   - Changez le port SSH par défaut (22 → 2222)
   - Utilisez des clés SSH au lieu des mots de passe
   - Désactivez SSH après configuration
3. **Réseau isolé** : Configurez un VLAN dédié pour Docker
4. **Certificats SSL** : Activez HTTPS avec Let's Encrypt dans DSM
5. **Sauvegardes externes** : Synchronisez les sauvegardes vers une autre localisation

## 📊 Monitoring et logs

### Fichiers de logs

| Fichier | Emplacement | Description |
|---------|-------------|-------------|
| **Maintenance** | `/volume1/docker/iris-articles/maintenance.log` | Logs du script de maintenance |
| **Conteneur** | `docker logs iris-articles-synology` | Logs IRIS natifs |
| **DSM** | **Gestionnaire de ressources** → **Performance** | Monitoring système |

### Alertes automatiques

Le script de maintenance génère des alertes pour :
- **Conteneur arrêté** (redémarrage automatique)
- **API non responsive** (avec logs de diagnostic)
- **Utilisation CPU/RAM élevée** (> 80%/85%)
- **Espace disque faible** (> 85%)
- **Fichiers bloqués** en traitement (> 1h)
- **Trop de fichiers en attente** (> 10)

### Dashboard de monitoring

Accès via DSM :
1. **Gestionnaire de ressources** pour CPU/RAM/Disque
2. **Docker** → **Conteneur** → `iris-articles-synology` pour les logs
3. **File Station** → `/docker/iris-articles/maintenance.log` pour les rapports

## 🚨 Dépannage

### Problèmes courants

#### Script de déploiement ne fonctionne pas
```bash
# Vérifier les permissions
ls -la deploy-synology.sh
# doit afficher -rwxr-xr-x

# Rendre exécutable si nécessaire  
chmod +x deploy-synology.sh

# Vérifier la configuration
./deploy-synology.sh test
```

#### Connexion SSH refusée
```bash
# Vérifier que SSH est activé dans DSM
# Panneau de configuration → Terminal & SNMP → SSH

# Tester manuellement
ssh -p 22 admin@192.168.1.100

# Vérifier le fichier .env
cat .env | grep SYNOLOGY_
```

#### Conteneur n'démarre pas
```bash
# Vérifier les logs
./deploy-synology.sh logs

# Vérifier l'espace disque sur le NAS
ssh admin@192.168.1.100 'df -h'

# Forcer la reconstruction
# Modifier .env : FORCE_REBUILD=true
./deploy-synology.sh
```

#### Port déjà utilisé
```bash
# Identifier le processus
ssh admin@192.168.1.100 'sudo netstat -tulpn | grep :52773'

# Modifier le port dans .env
# HOST_PORT_WEB=52774
```

### Support et contacts

- 📖 **Documentation complète** : [DEPLOYMENT_SYNOLOGY.md](../DEPLOYMENT_SYNOLOGY.md)
- 🐛 **Issues** : Créer un ticket GitHub avec les logs
- 💬 **Questions** : Utiliser les discussions GitHub

---

## 🎯 Guide de démarrage rapide (TL;DR)

```bash
# 1. Configuration
cp .env.example .env
nano .env  # Remplir SYNOLOGY_HOST, SYNOLOGY_USER, SYNOLOGY_PASSWORD

# 2. Test
./deploy-synology.sh test

# 3. Déploiement
./deploy-synology.sh

# 4. Vérification
curl http://192.168.1.100:52773/api/articles/health
```

🎉 **Votre IRIS Articles est maintenant accessible 24h/24 sur votre NAS Synology !**