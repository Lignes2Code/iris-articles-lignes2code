# 🔒 Guide de Sécurité - IRIS Articles

## ⚠️ IMPORTANT - Configuration de Production

Ce repository contient un projet de **démonstration et développement**. Avant tout déploiement en production, veuillez appliquer les mesures de sécurité suivantes :

## 🎯 Actions Obligatoires

### 1. **Secret JWT** 
📁 `src/cls/Article/Auth/JWT.cls`

**❌ NE PAS utiliser la valeur par défaut**
```objectscript
Parameter SECRET = "CHANGE_ME_IN_PRODUCTION_USE_ENV_VAR";
```

**✅ Solution recommandée :**
- Générez un secret fort : `openssl rand -hex 32`
- Stockez-le dans une variable d'environnement
- Modifiez le code pour lire : `$SYSTEM.Util.GetEnviron("JWT_SECRET")`

### 2. **Mot de passe Administrateur**
📁 `config/merge.cpf`

**❌ Le hash par défaut a été supprimé du repository**
**✅ Actions requises :**
- Définissez un mot de passe fort après déploiement
- Créez des comptes utilisateur spécifiques (pas _SYSTEM)
- Activez l'audit des connexions

### 3. **Configuration Base de Données**
**✅ Actions recommandées :**
- Changez tous les mots de passe par défaut IRIS
- Activez le chiffrement des données au repos
- Configurez SSL/TLS pour les connexions

## 🛡️ Bonnes Pratiques 

### Variables d'Environnement
Créez un fichier `.env` (NON versioned) :
```bash
# Secrets de production
JWT_SECRET=votre-secret-jwt-super-fort-64-caracteres-minimum
DB_PASSWORD=votre-mot-de-passe-db-complexe
IRIS_ADMIN_PASSWORD=votre-mot-de-passe-admin

# Configuration
IRIS_NAMESPACE=PRODUCTION
LOG_LEVEL=INFO
```

### Docker en Production
```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  iris:
    image: iris-articles:latest
    environment:
      - JWT_SECRET=${JWT_SECRET}
      - DB_PASSWORD=${DB_PASSWORD}
    volumes:
      - iris_data:/dur/iris_conf.d:z
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.iris.tls=true"
```

## 🔍 Audit de Sécurité

### Fichiers à surveiller
- [ ] `config/*.cpf` - Aucun secret en dur
- [ ] `src/cls/Article/Auth/JWT.cls` - Secret sécurisé
- [ ] `docker-compose.yml` - Pas de mots de passe
- [ ] `.env` - Fichier bien ignoré par Git

### Tests de sécurité
```bash
# Vérifier qu'aucun secret n'est commité
git secrets --scan

# Scanner les vulnérabilités
trivy fs .

# Audit des mots de passe faibles
grep -r "password.*=" --include="*.cls" --include="*.json"
```

## 🚨 En cas de Compromission

1. **Changez immédiatement :**
   - Secret JWT
   - Mots de passe admin IRIS
   - Clés API externes

2. **Invalidez tous les tokens JWT actifs**
3. **Auditez les logs de connexion**
4. **Notifiez les utilisateurs**

## 📞 Support

Pour toute question de sécurité :
- 📧 Email : security@lignes2code.com
- 🐛 Issues : Marquez `[SECURITY]` dans le titre

---
**⚠️ Ce fichier doit être lu et appliqué avant tout déploiement en production !**