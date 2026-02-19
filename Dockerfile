ARG IMAGE=intersystems/iris-community:latest-cd
FROM $IMAGE

USER root

RUN apt-get update && apt-get -y upgrade \
    && apt-get -y install unattended-upgrades \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER 51773

# Copier les sources et la configuration
COPY --chown=51773:51773 src/cls/ /home/irisowner/src/cls/
COPY --chown=51773:51773 src/iris-init.script /home/irisowner/iris-init.script
COPY --chown=51773:51773 config/merge.cpf /home/irisowner/merge.cpf
COPY  --chown=51773:51773 config/WebTerminal-v4.9.5.xml /tmp/WebTerminal-v4.9.5.xml

RUN mkdir -p /home/irisowner/data/input /home/irisowner/data/output

# Le merge.cpf avec [Actions] crée l'application web REST
ENV ISC_CPF_MERGE_FILE=/home/irisowner/merge.cpf

# Charger et compiler les classes ObjectScript
RUN iris start IRIS \
    && iris terminal IRIS < /home/irisowner/iris-init.script \
    && iris stop IRIS quietly
