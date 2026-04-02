![IRIS Articles Banner](https://img.shields.io/badge/InterSystems-IRIS-blue?style=for-the-badge&logo=intersystems)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker)
![ObjectScript](https://img.shields.io/badge/ObjectScript-API-green?style=for-the-badge)

# 🚀 IRIS Articles - Lignes2Code

> **Projet de démonstration** InterSystems IRIS avec API REST, pages web CSP et interopérabilité pour la gestion d'articles.

## ✨ Fonctionnalités

- 🔐 **API REST** sécurisée avec authentification JWT
- 🌐 **Interface web** avec pages CSP natives IRIS
- 🔄 **Interopérabilité** avec surveillance de dossiers
- 🐳 **Docker Compose** pour déploiement facile
- 📁 **Import automatique** de fichiers JSON
- 🔒 **Sécurité renforcée** avec guides de production

## 🎯 Public cible

- **Développeurs InterSystems IRIS** cherchant des exemples concrets
- **Étudiants** en base de données et interopérabilité  
- **Architectes** évaluant IRIS pour leurs projets
- **Communauté Lignes2Code** pour l'apprentissage

## ⚡ Démarrage rapide

```bash
# 1. Cloner le projet
git clone https://github.com/Lignes2Code/iris-articles-lignes2code.git
cd iris-articles-lignes2code

# 2. Démarrer avec Docker
mkdir -p data/durable && chmod 777 data/durable
docker compose up -d --build

# 3. Tester l'API
curl http://127.0.0.1:52773/api/articles/health

# 4. Accéder aux interfaces
firefox http://127.0.0.1:52773/web/articles/Article.Web.ArticleList.cls
```

## 📚 Documentation

- 📖 [**README complet**](README.md) - Guide détaillé d'installation et utilisation
- 🔒 [**Guide sécurité**](SECURITY.md) - Configuration production
- ✅ [**Checklist sécurité**](SECURITY_CHECKLIST.md) - Vérifications avant déploiement
- 🚀 [**Script d'ouverture**](open-iris.sh) - Lancement automatique des pages

## 🛠️ Technologies utilisées

![InterSystems IRIS](https://img.shields.io/badge/InterSystems_IRIS-Community-0078D4)
![ObjectScript](https://img.shields.io/badge/ObjectScript-Native-green)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED)
![JWT](https://img.shields.io/badge/JWT-HS256-000000)
![REST API](https://img.shields.io/badge/REST-API-FF6B35)

## 📦 Structure du projet

```
iris-articles-lignes2code/
├── 🐳 docker-compose.yml & Dockerfile
├── 📁 src/cls/Article/          # Classes ObjectScript
│   ├── Auth/     # Authentification JWT
│   ├── Data/     # Modèles persistants
│   ├── REST/     # API REST
│   ├── Web/      # Pages CSP
│   ├── Service/  # Services d'interopérabilité
│   └── ...
├── 📂 data/                     # Données et exemples
└── 📋 docs/                     # Documentation
```

## 🔐 Sécurité

⚠️ **Ce projet est configuré pour la démonstration et le développement.**

Pour un usage en production :
1. 📖 Lisez le [guide sécurité](SECURITY.md)
2. ✅ Suivez la [checklist](SECURITY_CHECKLIST.md)
3. 🔑 Configurez vos secrets (JWT, mots de passe)

## 🤝 Contribution

Ce repository est en **lecture seule** pour préserver l'intégrité éducative.

Cependant, vous pouvez :
- 🐛 **Signaler des bugs** via les Issues
- 💡 **Proposer des améliorations** dans les Issues
- 🍴 **Forker le projet** pour vos propres modifications
- 📧 **Nous contacter** : contact@lignes2code.com

## 📜 Licence

MIT License - Libre d'usage pour l'apprentissage et projets personnels.

## 👨‍💻 Auteur

**Lignes2Code** - Formations et projets InterSystems IRIS

- 🌐 Site web : [lignes2code.com](https://lignes2code.com)
- 📧 Contact : contact@lignes2code.com
- 🐙 GitHub : [@Lignes2Code](https://github.com/Lignes2Code)

---

⭐ **N'hésitez pas à mettre une étoile** si ce projet vous aide dans votre apprentissage d'InterSystems IRIS !
