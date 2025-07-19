# inception
project inception (docker) for 42

# DOCUMENTATION


---


## DOCKER NGINX

Nginx est un serveur web performant et léger, conçu pour gérer efficacement un grand nombre de connexions simultanées.
Dans le projet Inception, il sert à recevoir les requêtes HTTP/HTTPS des clients et à les transmettre, selon le cas :
- soit directement (pour des fichiers statiques comme HTML ou CSS),
- soit à un service en arrière-plan comme PHP-FPM (pour exécuter WordPress).
C’est le point d’entrée du site web, le composant qui fait l’interface entre le monde extérieur et les services internes du projet.


Pour realiser le docker Nginx , il faut d abord creer un fichier de configuration pour Nginx, puis un  Dockerfile qui creera le docker a partir d une image Debian ou Alpine.

### FICHIER DE CONFIGURATION NGINX `nginx.conf`

Un fichier de configuration Nginx est constitué de blocs suivis d’accolades `{}` contenant les instructions. Chaque instruction est constituée de son nom, d’un espace, puis de son ou ses arguments séparés par des espaces s’il y en a plusieurs, terminée par un point-virgule `;`. Certains blocs seront contenus à l’intérieur d’un bloc "parent".

Exemple minimal de `nginx.conf` :

```nginx
events {}

http {
    server {
        listen 80;
        server_name localhost;

        location / {
            return 200 "Hello, Nginx!\n";
        }
    }
}
```

#### Bloc `events {}`

Il configure la manière dont Nginx gère les connexions réseau (par exemple, combien de connexions simultanées peuvent être traitées). Pour une configuration simple ou un usage dans Docker, on peut laisser ce bloc vide : `events {}`

#### Bloc `http {}`

Il définit toutes les directives liées au protocole HTTP : les serveurs web que Nginx va gérer, les logs, les types de contenu, etc.

Il peut contenir les directives suivantes :

* `access_log` Détermine où sont redirigés les logs d’accès. On lui donne l’argument `/proc/self/fd/1`, qui est un chemin spécial dans Linux permettant à un processus (comme Nginx) d’écrire directement dans sa sortie standard (stdout). Docker capte automatiquement stdout et stderr de chaque conteneur, ce qui permet d’accéder aux logs de Nginx avec une simple commande : `docker logs <nom_du_conteneur>`

* `error_log` Idem mais pour les logs d’erreurs, qu’on redirige vers la sortie d’erreur avec l’argument `/proc/self/fd/2`

* `include` Sert à inclure le contenu d’un autre fichier dans le fichier de configuration principal de Nginx. On lui passe l’argument `/etc/nginx/mime.types` afin de charger les types **MIME** (associations entre extensions de fichiers et leur type de contenu, comme .html → text/html ou .png → image/png), indispensable pour servir des fichiers statiques.

* `default_type` Définit le type MIME par défaut si aucun n’est trouvé. On lui donne l’argument `application/octet-stream`, qui signifie que c’est un fichier binaire générique (ce qui déclenchera le plus souvent un téléchargement par le client).

Le bloc `http` contient aussi le ou les blocs `server` (un seul pour les besoins de Inception).

#### Bloc `server {}`

Ce bloc définit un serveur virtuel, c’est-à-dire une instance de serveur web que Nginx va gérer. Il doit obligatoirement être placé à l’intérieur d’un bloc `http`.

Il peut contenir les directives suivantes :

* `listen` Définit le port sur lequel le serveur va écouter les requêtes. Pour un serveur HTTP classique, on utilise `listen 80;`. Pour un serveur HTTPS (comme dans Inception), on utilise `listen 443 ssl;`. Si la configuration Nginx contient uniquement `listen 443 ssl;`, alors le serveur ne répond qu’aux requêtes HTTPS. Toute tentative de connexion via HTTP (port 80) échouera. Pour une expérience fluide, on peut ajouter un second bloc server qui écoute le port 80 et redirige vers HTTPS:

```nginx
server {
    listen 80;
    server_name localhost <votre_login>.42.fr;
    return 301 https://$host$request_uri;
}
```

* `server_name` Spécifie les noms de domaine ou adresses IP que ce serveur va accepter. Exemple : `server_name localhost;` ou `server_name ${DOMAIN_NAME} localhost;` si on utilise une variable d’environnement dans Docker (le nom de domaine pour Inception sera "<votre_login>.42.fr").

* `root` Indique le chemin du dossier racine du site, c’est-à-dire là où se trouvent les fichiers à servir. Exemple : `root /var/www/wordpress;`. Ce chemin correspond au volume monté dans le conteneur Nginx pour accéder aux fichiers WordPress. Dans le projet Inception, WordPress tourne dans son propre conteneur (wordpress), mais le conteneur Nginx a aussi besoin d’accéder aux fichiers statiques de WordPress pour pouvoir les servir (HTML, CSS, images, fichiers PHP à passer à PHP-FPM, etc.). *→ Voir plus bas le paragraphe sur les volumes*.

* `index` Spécifie le ou les fichiers à rechercher par défaut lorsqu’un utilisateur accède à un répertoire. Exemple : `index index.php index.html index.htm;`.

* `ssl_certificate` et `ssl_certificate_key` Obligatoires si on active SSL avec `listen 443 ssl;`. Ces directives désignent le chemin vers le certificat SSL et sa clé privée. Exemple :

  ```
  ssl_certificate     /etc/ssl/certs/nginx.crt;
  ssl_certificate_key /etc/ssl/private/nginx.key;
  ```

* `ssl_protocols` Permet de choisir les versions de TLS autorisées. Exemple : `ssl_protocols TLSv1.2 TLSv1.3;` (recommandé pour la sécurité).

> **Note : SSL, TLS et HTTPS**
>
> Le terme **SSL** (*Secure Sockets Layer*) est couramment utilisé, mais il est techniquement dépassé : aujourd’hui, on utilise en réalité **TLS** (*Transport Layer Security*), une version plus moderne et plus sécurisée du protocole.
>
> Malgré cela, le mot **“SSL” reste largement employé** dans la documentation, les outils (comme `ssl_certificate`) et les configurations, même lorsqu’on parle de TLS.
>
> Quand un serveur web utilise SSL/TLS, il chiffre les communications avec le client. Cela permet d’assurer :
>
> * la **confidentialité** des échanges (personne ne peut lire les données),
> * l’**authenticité** du serveur (via le certificat),
> * l’**intégrité** des données échangées.
>
> C’est ce qui différencie :
>
> * **HTTP** : communication en clair, non sécurisée
> * **HTTPS** : communication **chiffrée** et **sécurisée** via SSL/TLS
>
> Pour activer HTTPS sur un serveur Nginx, il faut :
>
> * un **certificat** (`.crt`)
> * une **clé privée** (`.key`)
> * et la directive `listen 443 ssl;` dans le bloc `server {}`
>
> Dans le cadre du projet Inception, on utilise des certificats auto-signés, créés automatiquement lors de la construction du conteneur Nginx.
> Cela se fera dans le Dockerfile, à l’aide de la commande `openssl`.
> Ces certificats ne sont pas validés par une autorité de certification : ils sont uniquement destinés à un usage local ou pédagogique.
> Le navigateur affichera une alerte de sécurité, ce qui est normal.

Le bloc `server` peut également contenir des blocs `location` qui définissent le comportement pour certaines URL (comme `/`, ou toutes les URLs se terminant par `.php`, etc.).

#### Blocs `location {}`

Un bloc `location` permet de définir un **comportement spécifique pour une ou plusieurs URL**. Il s’écrit à l’intérieur d’un bloc `server` et commence par un motif (chemin ou expression régulière) suivi d’accolades contenant des directives.

Il peut y avoir plusieurs blocs `location`, chacun correspondant à un cas précis.

Voici les plus utilisés dans Inception :

* `location / {}`
  Ce bloc s’applique à la **racine du site** (toutes les requêtes qui ne correspondent à rien de plus précis).
  Exemple :

  ```nginx
  location / {
      try_files $uri $uri/ =404;
  }
  ```

Cela signifie : "essaie d’abord de servir le fichier tel quel (`$uri`), puis en tant que répertoire (`$uri/`), et si rien n’est trouvé, renvoie une erreur 404". Cette directive est essentielle pour éviter que Nginx tente d’interpréter des chemins inexistants.

* `location ~ \.php$ {}`

Ce bloc redirige toutes les requêtes vers des fichiers PHP vers PHP-FPM (FastCGI), qui tourne dans un conteneur séparé (ici : `wordpress`). Il permet à Nginx de **déléguer l’exécution des scripts PHP** au bon service.

#### Le bloc `location ~ \.php$ {}` en détail


```
location ~ \.php$ {
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_pass wordpress:9000;
    fastcgi_index index.php;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_param PATH_INFO $fastcgi_path_info;
}
```

Explication des directives :

* `fastcgi_split_path_info` Sépare le chemin du fichier PHP et le reste de l’URL.
  Exemple : `/index.php/xyz` → fichier : `index.php`, path\_info : `/xyz`

* `fastcgi_pass` Indique où envoyer la requête : ici vers le conteneur `wordpress` sur le port `9000`, où tourne PHP-FPM.

* `fastcgi_index` Définit le fichier par défaut à exécuter si aucun fichier n’est précisé dans l’URL (ex : `/admin/` → `index.php`).

* `include fastcgi_params` Inclut un fichier standard contenant les variables d’environnement nécessaires à FastCGI (ex : `REQUEST_METHOD`, `SCRIPT_NAME`, etc.).

* `fastcgi_param SCRIPT_FILENAME` Spécifie le chemin complet du fichier PHP à exécuter, en combinant le `document_root` et le nom du fichier PHP demandé.

* `fastcgi_param PATH_INFO` Transmet à PHP la partie de l’URL située **après** le fichier `.php`, utile pour certains frameworks.

> Les directives `fastcgi_pass`, `include fastcgi_params`, et `fastcgi_param SCRIPT_FILENAME` sont **indispensables** pour exécuter du PHP avec Nginx. Les autres sont **fortement recommandées** pour une compatibilité maximale.


### DOCKERFILE

Un `Dockerfile` est un fichier texte qui contient **l’ensemble des instructions nécessaires pour construire une image Docker**.
Chaque instruction est lue ligne par ligne et exécutée dans l’ordre, pour créer une image qui servira de base à un conteneur.

Un `Dockerfile` peut contenir différentes directives, les plus courantes étant :

* `FROM`
  Spécifie l’**image de base** sur laquelle construire. Cette image sera téléchargée depuis le Docker Hub
  
* `LABEL`
  Ajoute des **informations descriptives** (métadonnées) à l’image, comme l’auteur ou une description.

* `RUN`
  Exécute une commande **au moment de la construction de l’image** (ex : installation de paquets). On peut enchaîner plusieurs commandes dans une même ligne `RUN` en les séparant par des `&&`, ce qui permet de créer une image noins lourde qu'une image créée à partir d 'un Dockefile contenant de multiples lignes `RUN`.

* `COPY`
  Copie un fichier ou un dossier **depuis le contexte de build local** vers le système de fichiers de l’image (depuis la machine hôte ou la VM vers vers le conteneur).
  Exemple :

* `EXPOSE`
  Indique **le port sur lequel le conteneur écoutera** une fois lancé. C’est **informatif** (il ne publie pas le port automatiquement).

* `CMD`
  Définit la **commande par défaut** à exécuter quand le conteneur démarre.

* `ENTRYPOINT`
  Très semblable à `CMD` mais définit un programme à exécuter au lieu d'une commande.

Pour plus de lisibilité, on peut couper les longues lignes avec des retours à la ligne précédés du caractère `\`.

Exemple :

```dockerfile
FROM nginx:alpine
LABEL maintainer="votre_login@student.42.fr"
COPY ./html /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### COMMANDES DE BASES POUR UTILISER UN DOCKERFILE

Voici les commandes les plus courantes :

* `docker build`
  Sert à créer une image Docker à partir d’un Dockerfile.

  ```bash
  docker build -t nom_de_l_image .
  ```

  * `-t` sert à donner un nom à l’image (exemple : `nginx42`)
  * `.` indique le contexte de build (le dossier contenant le `Dockerfile`)

* `docker images`
  Affiche la liste des images Docker disponibles localement.

  ```bash
  docker images
  ```
  
* `docker run`
  Sert à lancer un conteneur à partir d’une image.

  ```bash
  docker run -d -p 8080:80 --name mon_conteneur nom_de_l_image
  ```

  * `-d` exécute le conteneur en arrière-plan (mode "détaché")
  * `-p` publie le port du conteneur sur le port de la machine hôte (`hôte:conteneur`)
  * `--name` donne un nom personnalisé au conteneur

* `docker ps`
  Affiche les conteneurs en cours d’exécution.

  ```bash
  docker ps
  ```
  
* `docker logs`
  Affiche les logs d’un conteneur (utile si `access_log` est redirigé vers `stdout` dans Nginx).

  ```bash
  docker logs mon_conteneur
  ```

* `docker stop`
  Arrête un conteneur en cours d’exécution.

  ```bash
  docker stop mon_conteneur
  ```

* `docker rm`
  Supprime un conteneur arrêté.

  ```bash
  docker rm mon_conteneur
  ```

* `docker rmi`
  Supprime une image Docker.

  ```bash
  docker rmi nom_de_l_image
  ```

* `docker system prune -a -f`
  Supprime tout ce qui est inutilisé par Docker :
  * conteneurs arrêtés
  * volumes non utilisés (optionnel, voir plus bas)
  * réseaux non utilisés
  * images non utilisées par un conteneur actif


  ```bash
  docker system prune -a -f
  ```

  * `-a` (ou `--all`) supprime toutes les images non utilisées, même celles qui ne sont pas "dangling" (non taguées). Sans `-a`, seules les images "dangling" sont supprimées.
  * `-f` force la suppression sans demander confirmation.


Parfait, voici une **explication rédigée pour ton README**, dans ton style, qui explique **pas à pas la logique** ayant conduit à l’écriture de ce `Dockerfile`. On garde le ton pédagogique et progressif, avec des retours aux concepts vus précédemment.


### CONSTRUCTION DU DOCKERFILE NGINX

Maintenant que l’on a vu les principales directives d’un `Dockerfile`, on peut comprendre étape par étape la construction de l’image Nginx pour le projet Inception.

Voici le fichier utilisé :

```dockerfile
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
```

#### *`FROM debian:11.11`*

On part d’une image Debian minimale (`11.11`). On aurait aussi pu utiliser `bookworm`, mais ici on utilise une version précise pour éviter les différences futures.

#### *`RUN ...`*

Cette instruction enchaîne plusieurs commandes dans une seule ligne, séparées par `&&`, pour des raisons de lisibilité et d’optimisation (éviter des couches inutiles dans l’image).

Voici ce que fait chaque partie :

* `apt-get update`
  Met à jour la liste des paquets disponibles.

* `apt-get install -y nginx curl openssl procps`
  Installe :

  * `nginx` : le serveur web
  * `curl` : outil de test HTTP (optionnel mais utile)
  * `openssl` : pour générer un certificat SSL auto-signé
  * `procps` : pour des outils comme `ps` (optionnel mais utile en debug)

* `apt-get clean && rm -rf /var/lib/apt/lists/*`
  Nettoie les fichiers inutiles après installation pour réduire la taille de l’image.

* `mkdir -p /etc/ssl/certs` et `/etc/ssl/private`
  Crée les dossiers qui vont contenir le certificat SSL et la clé privée.

* `openssl req -x509 ...`
  Génère un **certificat SSL auto-signé**, valable un an (`365 jours`).
  Ce certificat sera utilisé par Nginx pour activer le **HTTPS**.

> Génération d’un certificat SSL auto-signé avec `openssl`
>
> Dans le projet Inception, on a besoin d’un certificat SSL pour activer le HTTPS dans Nginx.
> Plutôt que d’utiliser un certificat signé par une autorité (comme Let's Encrypt), on génère un **certificat auto-signé** lors de la construction du conteneur.
>
> La commande suivante est utilisée dans le `Dockerfile` :
>
> ```dockerfile
> openssl req -x509 -nodes -days 365 \
>   -out /etc/ssl/certs/nginx.crt \
>   -keyout /etc/ssl/private/nginx.key \
>   -subj "/C=FR/ST=Occitanie/L=Perpignan/O=42/OU=42/CN=chdonnat.42.fr"
> ```
>
> Cette commande permet de :
>
> * Générer un **certificat auto-signé** (`-x509`) sans passer par une autorité externe
> * **Ne pas chiffrer** la clé privée (`-nodes`) — indispensable en Docker, pour éviter toute saisie de mot de passe
> * Définir une **durée de validité** de 365 jours (`-days 365`)
> * Spécifier les chemins de sortie du certificat et de la clé (`-out`, `-keyout`)
> * Fournir toutes les **informations d’identité** directement en ligne avec l’option `-subj`
>
> Ce certificat et sa clé sont ensuite utilisés dans la configuration Nginx pour activer HTTPS :
>
> ```nginx
> ssl_certificate     /etc/ssl/certs/nginx.crt;
> ssl_certificate_key /etc/ssl/private/nginx.key;
> ```

* `mkdir -p /var/run/nginx`
  Crée le dossier nécessaire pour que Nginx puisse écrire son PID. Nginx a besoin d’un endroit pour stocker son fichier PID (Process ID) lorsqu’il démarre. Par défaut, ce fichier est : `/var/run/nginx.pid`. Mais le fichier ne peut être créé que si le répertoire, or ce dossier n'existe pas forcément par défaut (comme dans un conteneur Debian minimal). Si le dossier n’existe pas et que Nginx essaie d’y écrire, le serveur échouera au démarrage.

* `mkdir -p /var/www/wordpress` et `/var/www/html`
  Crée les répertoires où seront stockés les fichiers du site WordPress et éventuellement une page statique d’accueil (pour faire des test par exemple).
  Ces dossiers correspondent aussi aux **volumes partagés** entre Nginx et d'autres conteneurs (comme WordPress).

#### *`COPY`*

* `COPY conf/nginx.conf /etc/nginx/nginx.conf`
  Copie le fichier de configuration Nginx personnalisé dans l’image, à l’endroit attendu par Nginx.

* `COPY conf/index.html /var/www/html/index.html`
  Copie une page d’accueil statique par défaut (utile pour tester que le serveur fonctionne même sans WordPress).


#### *`EXPOSE 443`*

Indique que le serveur écoute sur le **port HTTPS** (443). Cela ne publie pas le port tout seul, mais **documente** que ce conteneur est conçu pour recevoir des connexions SSL.

#### *`CMD ["nginx", "-g", "daemon off;"]`*

Démarre Nginx en mode **non-daemonisé**, ce qui est indispensable dans un conteneur Docker (sinon le processus principal quitte immédiatement et le conteneur s’arrête).

> Pourquoi utiliser `daemon off;` avec Nginx dans Docker ?
> 
> Quand on exécute un conteneur Docker, il attend qu’un processus principal s’exécute en "PID 1".
> Ce processus devient le "processus maître" du conteneur.
> Si ce processus se termine, le conteneur s’arrête immédiatement.
>
> Le PID 1 dans un conteneur joue un rôle spécial :
> * Il est le parent de tous les autres processus.
> * Il doit rester actif tant que le conteneur tourne.
> * Il doit capturer les signaux (comme SIGTERM) pour permettre un arrêt propre.
>
> Si le processus PID 1 se termine (ou entre en arrière-plan), Docker considère que le conteneur est fini, et l’arrête.
>
> L’option `-g` permet de passer une directive de configuration globale directement en ligne de commande, sans modifier le fichier `nginx.conf`.
>
> `daemon off;` permet de désactiver le mode daemon (arrière-plan) pour que Nginx reste au premier plan en tant que processus principal (PID 1) du conteneur.


---


## DOCKER MARIADB

MariaDB est un système de gestion de base de données relationnelle (SGBDR), compatible avec MySQL.
Il est utilisé par WordPress pour stocker toutes les données dynamiques du site : utilisateurs, articles, paramètres, commentaires, etc.


Dans le projet Inception, MariaDB fonctionne comme un service autonome (dans son propre conteneur) auquel WordPress se connecte via un nom d’hôte (mariadb) et un ensemble d’identifiants (base de données, nom d’utilisateur, mot de passe).


Pour realiser le docker MariaDB , il faut d abord creer un fichier de configuration pour MariaDB, puis un Dockerfile qui creera le docker a partir d une image Debian ou Alpine, et enfin un script d'initialisation.

### FICHIER DE CONFIGURATION MARIADB

Le fichier de configuration de MariaDB permet de définir les paramètres du serveur de base de données au démarrage : ports, noms de fichiers de log, limites de connexions, emplacements des bases, encodage, etc.


Dans le cadre d’Inception, ce fichier est généralement peu modifié. On se contente le plus souvent de créer un fichier SQL d’initialisation (exécuté au premier lancement) pour créer la base, l’utilisateur, et définir ses droits.

#### Comment le nommer et où le placer

MariaDB lit sa configuration à partir de plusieurs fichiers, dans un ordre bien défini. Le fichier principal est généralement situé à `/etc/mysql/my.cnf`.
Mais il inclut aussi automatiquement **tous les fichiers se terminant par `.cnf`** présents dans le dossier `/etc/mysql/conf.d/`.

C’est pourquoi, dans le projet Inception, on peut nommer le fichier de configuration : `50-server.cnf`.
Ce nom suit une **convention d’ordre alphabétique** pour garantir que le fichier soit lu **après les fichiers par défaut**, sans avoir à modifier le fichier `my.cnf` principal.

Il faudra s'assurer que le Dockerfile copie le fichier de configuration dans le conteneur MariaDB dans le dossier `/etc/mysql/conf.d/50-server.cnf`.

> Le nom `50-server.cnf` est recommandé car il est explicite, respecte les conventions, et permet de modifier uniquement ce qui est nécessaire sans toucher aux fichiers système.

#### Contenu d'un fichier de configuration `50-server.cnf`

Un fichier de configuration MariaDB est structuré en deux parties :

* **Des blocs (ou sections)**
  Chaque bloc est indiqué entre crochets, comme `[mysqld]` ou `[client]`.
  Chaque bloc s’applique à une partie spécifique de l’écosystème MariaDB :

  * `[mysqld]` : options pour le serveur MariaDB lui-même
  * `[mysql]` : options pour le client `mysql` (l’interface en ligne de commande)
  * `[client]` : options pour tous les clients (y compris `mysqldump`, `mysqladmin`, etc.)

* **Des directives**
  À l’intérieur de chaque bloc, on écrit des lignes sous la forme `clé = valeur` pour définir les paramètres à appliquer.

#### Exemple de structure utilisée dans Inception :

```ini
[mysqld]
datadir = /var/lib/mysql
socket  = /run/mysqld/mysqld.sock
bind_address = 0.0.0.0
port = 3306
user = mysql
```

> Le bloc `[mysqld]` est le seul obligatoire dans le contexte du projet Inception, car c’est lui qui configure le **comportement du serveur MariaDB** au démarrage.
> Les blocs `[client]` et `[mysql]` sont facultatifs, mais utiles si on veut interagir avec la base en ligne de commande depuis l’intérieur du conteneur.

#### Explication des directives

* `datadir = /var/lib/mysql`
  Spécifie le répertoire où sont stockées les **données des bases**.
  C’est aussi là que sera monté le volume Docker pour persister les données.
  *-> Voir le paragraphe sur les volumes plus loin.*

* `socket = /run/mysqld/mysqld.sock`
  Définit le chemin du **fichier socket UNIX** utilisé pour les connexions locales (utile pour des outils comme `mysql` en ligne de commande dans le conteneur).

* `bind_address = 0.0.0.0`
  Permet à MariaDB d'écouter sur **toutes les interfaces réseau** du conteneur.
  ➤ Cela permet à **WordPress (dans un autre conteneur)** de s’y connecter.

* `port = 3306`
  Définit le port utilisé par MariaDB (3306 est le port standard).

* `user = mysql`
  Indique l’utilisateur système Linux sous lequel MariaDB s’exécute.
  Par défaut dans Docker, l’utilisateur `mysql` est déjà configuré.

### DOCKERFILE MARIADB

Pour le Dockerfile de MariaDB, nous pouvons garder les choses simples. Il faut utiliser une image `debian` ou `alpine` comme l'exige le sujet, installer `mariadb-server`, copier le fichier de configuration réalisé précedemment dans le docker, exposer le port 3306 comme exigé dans le sujet.

Toutefois, lorsque MariaDB démarre pour la première fois, il initialise un répertoire de données vide (`/var/lib/mysql`) et configure la base de données système.
À ce moment-là, si aucun mot de passe ou configuration n’est défini, aucune base ni utilisateur personnalisé n’existe encore, et l’accès root peut être sans mot de passe – ce qui est dangereux en production.
C’est pourquoi, dans un déploiement automatisé (comme dans un conteneur Docker), il est essentiel de fournir dès le départ des variables suivantes pour :

* Créer une base de données personnalisée
  `DB_NAME` : permet d’indiquer à MariaDB quelle base créer automatiquement (ex. wordpress)
  Sans cette variable, il faudrait le faire manuellement après lancement

* Créer un utilisateur avec mot de passe
  `DB_USER` et `DB_USER_PASS` : permettent de créer un utilisateur dédié
  pour se connecter à la base sans utiliser le compte `root`
  **Bonnes pratiques de sécurité :** chaque application (ex. WordPress) doit avoir son propre utilisateur

* Protéger le compte root
  DB_ROOT_PASS : fixe un mot de passe sécurisé pour l’utilisateur root de MariaDB
  Sans cela, root pourrait ne pas avoir de mot de passe, ce qui pose un risque critique

Nous allons donc devoir créer un script (`entrypoint.sh` que nous enregistrerons dans le répertoire `tools`) à exécuter au lancement du conteneur MariaDB afin de configurer tout cela (exactement comme si nous tappions des commandes dans le conteneur après son lancement).

Le Dockerfile va donc aussi devoir copier ce script dans de conteneur, donner les droits d'exécutions à ce script, puis exécuter le script.

Pour ce faire, nous utiliserons la directive `ENTRYPOINT` au lieu de `CMD` car `ENTRYPOINT` permet d'exécuter des programmes contrairement à `CMD`.

```Dockerfile
FROM debian:11.11
RUN apt-get update -y \
&& apt-get install -y mariadb-server \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
EXPOSE 3306
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
```



