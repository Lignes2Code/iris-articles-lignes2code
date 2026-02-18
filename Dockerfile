ARG IMAGE=intersystems/iris-community:latest-cd
FROM $IMAGE

USER root

# Mise à jour des paquets de sécurité (bonne pratique InterSystems)
RUN apt-get update && apt-get -y upgrade \
    && apt-get -y install unattended-upgrades \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER 51773

# Copier le code source ObjectScript
COPY --chown=51773:51773 src/cls/ /home/irisowner/src/cls/

# Copier le script d'initialisation
COPY --chown=51773:51773 src/iris-init.script /home/irisowner/iris-init.script

# Copier le fichier CPF merge pour la configuration
COPY --chown=51773:51773 config/merge.cpf /home/irisowner/merge.cpf

# Créer les répertoires de données
RUN mkdir -p /home/irisowner/data/input /home/irisowner/data/output

# Initialiser IRIS : charger les classes, configurer REST, installer WebTerminal, démarrer la production
RUN iris start IRIS \
    && iris terminal IRIS < /home/irisowner/iris-init.script \
    && iris stop IRIS quietly
