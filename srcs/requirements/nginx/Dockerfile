# instructions en majuscule
# FROM : image de depart
# WORKDIR : repertoire de travail dans le cadre du build (plusieurs possibles)
# ARG : definir des variables de build (clef=valeur)
# ENV : variables d environnement pour le build et lancement (clef=valeur)
# USER : utilisateur pour les cmdes suivantes et user qui lance le processus
# ADD : ajoute fichiers ou repertoires - peut etre une url, un repo git... (ADD source destination)
# COPY : idem que ADD mais ne peut pas utiliser des fichiers distants
# RUN : lance des commandes shell, utile aussi pour les layers (apt, etc)
# CMD : commande lancee dans le conteneur sous forme de liste (ex : CMD ["python3","-m","flask","run"])
# ENTRYPOINT : plus ou moins comme CMD
# LABEL : ajout de metadatas (cle=valeur)
#docker  EXPOSE : ports en ecoute par le processus, plusieurs lignes possibles (ex : EXPOSE 80/tcp)
# VOLUME : declare les volumes de maniere separee, sous forme de liste (ex : VOLUME ["/var/www","/var/log/apache2"])

# escape=\

FROM debian:11.11
RUN apt-get update \
	&& apt-get install -y nginx curl openssl procps \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /etc/ssl/certs \
	&& mkdir -p /etc/ssl/private \
	&& openssl req -x509 -nodes -days 365 \
	-out /etc/ssl/certs/nginx.crt \
	-keyout /etc/ssl/private/nginx.key \
	-subj "/C=FR/ST=Occitanie/L=Perpignan/O=42/OU=42/CN=chdonnat.42.fr/UID=chdonnat" \
	&& mkdir -p /var/run/nginx \
	&& mkdir -p /var/www/wordpress \
	&& mkdir -p /var/www/html
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/index.html /var/www/html/index.html
EXPOSE 443
CMD ["nginx", "-g", "daemon off;"]
