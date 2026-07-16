ARG IMAGE=intersystems/iris-community:latest-cd
FROM $IMAGE

USER root

RUN apt-get update && apt-get -y upgrade \
    git \
    nano \
    sudo \
    libnss3-tools && \
    echo -e "${ISC_PACKAGE_MGRUSER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    wget -q https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64 && \
    chmod +x mkcert-v1.4.4-linux-amd64 && \
    mv mkcert-v1.4.4-linux-amd64 /usr/local/bin/mkcert && \
    rm -rf /var/lib/apt/lists/*
    
# Assurez que le répertoire /dur/iris_conf.d/ est accessible en écriture
RUN mkdir -p /dur/iris_conf.d/ && \
    chown -R ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /dur/iris_conf.d/ && \
    chmod -R 775 /dur/iris_conf.d/
    
USER 51773

# Copier les sources et la configuration
COPY --chown=51773:51773 src/cls/ /home/irisowner/src/cls/
COPY --chown=51773:51773 src/iris-init.script /home/irisowner/iris-init.script
COPY --chown=51773:51773 src/create-admin-user.script /home/irisowner/create-admin-user.script
COPY --chown=51773:51773 config/merge.cpf /home/irisowner/merge.cpf
COPY  --chown=51773:51773 config/WebTerminal-v4.9.5.xml /tmp/WebTerminal-v4.9.5.xml

RUN mkdir -p /home/irisowner/data/input /home/irisowner/data/output


# Le merge.cpf avec [Actions] crée l'application web REST
ENV ISC_CPF_MERGE_FILE=/home/irisowner/merge.cpf

# Charger et compiler les classes ObjectScript
RUN iris start IRIS \
    && iris terminal IRIS < /home/irisowner/iris-init.script \
    && iris stop IRIS quietly
