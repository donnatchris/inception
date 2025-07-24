SHELL := /bin/bash
COMPOSE_PATH := srcs/docker-compose.yml
ENV_FILE := srcs/.env
REQUIRED_VARS := MDB_NAME \
                 MDB_USER \
                 MDB_ROOT_PASS \
                 MDB_USER_PASS \
                 DOMAIN_NAME \
                 WEBSITE_TITLE \
                 WP_ADMIN_LOGIN \
                 WP_ADMIN_EMAIL \
                 WP_ADMIN_PASS \
                 WP_USER_LOGIN \
                 WP_USER_EMAIL \
                 WP_USER_PASS

all: check_vars setup_dirs setup_hosts up

# Check if .env file exists in srcs/
check_env:
	@echo "Checking if $(ENV_FILE) exists..."
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "❌ Error: $(ENV_FILE) file not found. Please create it before running make."; \
		exit 1; \
	else \
		echo "✅ $(ENV_FILE) file found."; \
	fi

check_vars: check_env
	@echo "Checking required environment variables..."
	@set -a; . $(ENV_FILE); set +a; \
	for var in $(REQUIRED_VARS); do \
		val=$${!var}; \
		if [ -z "$$val" ]; then \
			echo "❌ Error: Environment variable '$$var' is not set or empty in $(ENV_FILE)"; \
			exit 1; \
		else \
			echo "✅ $$var"; \
		fi; \
	done

# Create ~/chdonnat/data/wordpress and ~/chdonnat/data/mariadb if they don't exist
setup_dirs:
	@echo "Checking /home/chdonnat/data/wordpress and /home/chdonnat/data/mariadb directories..."
	@if [ ! -d "/home/chdonnat/data/wordpress" ]; then \
		echo "Creating /home/chdonnat/data/wordpress directory"; \
		mkdir -p "/home/chdonnat/data/wordpress"; \
	fi
	@if [ ! -d "/home/chdonnat/data/mariadb" ]; then \
		echo "Creating /home/chdonnat/data/mariadb directory"; \
		mkdir -p "/home/chdonnat/data/mariadb"; \
	fi

# Add 127.0.0.1 DOMAIN_NAME to /etc/hosts if missing
setup_hosts:
	@DOMAIN_NAME=$$(grep '^DOMAIN_NAME=' $(ENV_FILE) | cut -d= -f2); \
	echo "Checking /etc/hosts entry for $$DOMAIN_NAME..."; \
	if ! grep -q "127.0.0.1 $$DOMAIN_NAME" /etc/hosts; then \
		echo "Adding '127.0.0.1 $$DOMAIN_NAME' to /etc/hosts (sudo required)"; \
		echo "127.0.0.1 $$DOMAIN_NAME" | sudo tee -a /etc/hosts > /dev/null; \
	else \
		echo "✅ /etc/hosts already contains the entry"; \
	fi

# Run docker compose up using the config in srcs/
up:
	@echo "🐳 Starting docker compose using $(COMPOSE_PATH)..."
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_PATH) up -d

# Stop containers and without removing images or deleting volumes
down:
	@echo "🛑 Stopping containers without removing images (data preserved)..."
	@docker compose -f srcs/docker-compose.yml down

# Stop containers and remove images without deleting volumes
clean:
	@echo "🛑 Stopping containers and removing images (data preserved)..."
	@docker compose -f srcs/docker-compose.yml down --rmi all

# Full reset: stop, remove containers & volumes, delete local data
reset:
	@echo "⚠️  WARNING: This will stop containers, destroy images, remove volumes, and delete local data in ~/chdonnat/data"
	@read -p "Are you sure you want to continue? [y/N] " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "❌ Reset aborted."; \
		exit 1; \
	fi
	@echo "Proceeding with full reset..."
	@docker compose -f srcs/docker-compose.yml down -v --rmi all
	@echo "Deleting local data directories..."
	sudo rm -rf /home/chdonnat/data/wordpress /home/chdonnat/data/mariadb

re: clean all
