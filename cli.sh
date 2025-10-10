#!/usr/bin/env bash
# CLI helper pour démarrer docker-compose et entrer dans les containers ou afficher les logs
# Usage: chmod +x cli.sh && ./cli.sh

set -euo pipefail

DCMD=""
if docker compose version >/dev/null 2>&1; then
  DCMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DCMD="docker-compose"
else
  echo "Aucune commande 'docker compose' ni 'docker-compose' trouvée. Installez docker-compose." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

start_compose() {
  echo "Démarrage de docker-compose en arrière-plan..."
  # shellcheck disable=SC2086
  $DCMD up -d
  echo "Containers lancés."
}

list_services() {
  # shellcheck disable=SC2086
  $DCMD config --services 2>/dev/null || true
}

enter_service_shell() {
  local svc="$1"
  echo "Tentative d'ouvrir un shell dans le service: $svc"
  # try sh then bash using docker compose exec
  # shellcheck disable=SC2086
  if $DCMD exec -it "$svc" sh; then
    return 0
  fi
  if $DCMD exec -it "$svc" bash; then
    return 0
  fi

  # Fallback: find running container and use docker exec
  local cid
  cid=$(docker ps --filter "name=$svc" --format "{{.ID}}" | head -n1 || true)
  if [ -n "$cid" ]; then
    if docker exec -it "$cid" sh; then
      return 0
    fi
    docker exec -it "$cid" bash || true
  else
    echo "Impossible d'ouvrir un shell: container pour le service '$svc' introuvable ou non démarré." >&2
    return 1
  fi
}

show_logs() {
  local svc="$1"
  if [ -n "$svc" ]; then
    echo "Affichage des logs pour le service: $svc (Ctrl+C pour quitter)"
    # shellcheck disable=SC2086
    $DCMD logs -f "$svc"
  else
    echo "Affichage des logs du compose (Ctrl+C pour quitter)"
    # shellcheck disable=SC2086
    $DCMD logs -f
  fi
}

# détecte une commande prisma utilisable (prisma, npx prisma, bunx prisma)
detect_prisma_cmd() {
  # Prefer running prisma inside the server container if a suitable service exists and is running.
  # Looks for a service name commonly used for the server: server, api, app.
  local svc cid
  svc=$(list_services | grep -E "server|api|app" | head -n1 || true)
  if [ -n "$svc" ]; then
    # check container is running for that service
    cid=$(docker ps --filter "name=$svc" --format '{{.ID}}' | head -n1 || true)
    if [ -n "$cid" ]; then
      # use docker compose exec to run prisma inside the container
      # return the exec prefix (do NOT append prisma here) so caller can try npx/bunx fallbacks
      echo "$DCMD exec -it $svc"
      return 0
    else
      echo "Service '$svc' trouvé dans le compose mais le container ne semble pas démarré." >&2
      # fall through to local detection
    fi
  fi

  # Fallback: run prisma locally via prisma, npx or bunx
  if command -v bunx >/dev/null 2>&1; then
    echo "bunx prisma"
  elif command -v npx >/dev/null 2>&1; then
    echo "npx prisma"
  elif command -v prisma >/dev/null 2>&1; then
    echo "prisma"
  else
    echo ""
  fi
}

# check if a command exists inside a container (using shell -c to let shell resolve PATH)
container_has_cmd() {
  # $1 = container exec prefix (e.g. "$DCMD exec -it server"), $2 = command to check (just the executable name)
  local prefix="$1" cmd="$2"
  # run a shell inside the container that checks for the command; hide stderr
  if $prefix sh -c "command -v $cmd >/dev/null 2>&1"; then
    return 0
  fi
  return 1
}

create_migration() {
  local prisma
  prisma=$(detect_prisma_cmd)
  if [ -z "$prisma" ]; then
    echo "Commande prisma introuvable. Installez prisma ou utilisez npx/bunx." >&2
    return 1
  fi

  read -r -p "Nom de la migration (ex: add-users-table) : " name
  if [ -z "${name:-}" ]; then
    echo "Nom vide. Annulation."
    return 1
  fi

  echo "Création de la migration: $name"
  # If runner is a container exec prefix (starts with $DCMD exec), try multiple in-container runners
  if [[ "$prisma" == "$DCMD exec"* ]]; then
    # prefer checking before running to avoid loud OCI exec failures
    if container_has_cmd "$prisma" bunx; then
      if $prisma bunx prisma migrate dev --name "$name" --create-only; then
        return 0
      fi
    fi
    if container_has_cmd "$prisma" npx; then
      if $prisma npx prisma migrate dev --name "$name" --create-only; then
        return 0
      fi
    fi
    if container_has_cmd "$prisma" prisma; then
      if $prisma prisma migrate dev --name "$name" --create-only; then
        return 0
      fi
    fi

    # nothing usable inside the container: fall back to local execution if possible
    echo "Aucune commande prisma trouvée dans le container pour le service, tentative locale..."
    if command -v prisma >/dev/null 2>&1; then
      eval "prisma migrate dev --name \"$name\" --create-only"
      return $?
    elif command -v npx >/dev/null 2>&1; then
      eval "npx prisma migrate dev --name \"$name\" --create-only"
      return $?
    elif command -v bunx >/dev/null 2>&1; then
      eval "bunx prisma migrate dev --name \"$name\" --create-only"
      return $?
    else
      echo "Commande prisma introuvable localement aussi. Installez prisma ou utilisez npx/bunx." >&2
      return 1
    fi
  else
    # shellcheck disable=SC2086
    eval "$prisma migrate dev --name \"$name\" --create-only"
  fi
}

apply_migrations() {
  local prisma
  prisma=$(detect_prisma_cmd)
  if [ -z "$prisma" ]; then
    echo "Commande prisma introuvable. Installez prisma ou utilisez npx/bunx." >&2
    return 1
  fi

  echo "Application de toutes les migrations pending..."
  if [[ "$prisma" == "$DCMD exec"* ]]; then
    if container_has_cmd "$prisma" bunx; then
      if $prisma bunx prisma migrate deploy; then
        return 0
      fi
    fi
    if container_has_cmd "$prisma" npx; then
      if $prisma npx prisma migrate deploy; then
        return 0
      fi
    fi
    if container_has_cmd "$prisma" prisma; then
      if $prisma prisma migrate deploy; then
        return 0
      fi
    fi

    echo "Aucune commande prisma trouvée dans le container pour le service, tentative locale..."
    if command -v prisma >/dev/null 2>&1; then
      eval "prisma migrate deploy"
      return $?
    elif command -v npx >/dev/null 2>&1; then
      eval "npx prisma migrate deploy"
      return $?
    elif command -v bunx >/dev/null 2>&1; then
      eval "bunx prisma migrate deploy"
      return $?
    else
      echo "Commande prisma introuvable localement aussi. Installez prisma ou utilisez npx/bunx." >&2
      return 1
    fi
  else
    # shellcheck disable=SC2086
    eval "$prisma migrate deploy"
  fi
}

rollback_migration() {
  local prisma
  prisma=$(detect_prisma_cmd)
  if [ -z "$prisma" ]; then
    echo "Commande prisma introuvable. Installez prisma ou utilisez npx/bunx." >&2
    return 1
  fi

  echo "Rollback (reset) va effacer la base de données et réappliquer les migrations si demandé."
  read -r -p "Confirmez-vous le reset de la base de données ? (oui/non) : " confirm
  if [ "$confirm" != "oui" ] && [ "$confirm" != "y" ]; then
    echo "Annulation."
    return 1
  fi

  echo "Exécution: prisma migrate reset --force"
  if [[ "$prisma" == "$DCMD exec"* ]]; then
    if container_has_cmd "$prisma" bunx; then
      if $prisma bunx prisma migrate reset --force; then
        return 0
      fi
    fi
    if container_has_cmd "$prisma" npx; then
      if $prisma npx prisma migrate reset --force; then
        return 0
      fi
    fi
    if container_has_cmd "$prisma" prisma; then
      if $prisma prisma migrate reset --force; then
        return 0
      fi
    fi

    echo "Aucune commande prisma trouvée dans le container pour le service, tentative locale..."
    if command -v prisma >/dev/null 2>&1; then
      eval "prisma migrate reset --force"
      return $?
    elif command -v npx >/dev/null 2>&1; then
      eval "npx prisma migrate reset --force"
      return $?
    elif command -v bunx >/dev/null 2>&1; then
      eval "bunx prisma migrate reset --force"
      return $?
    else
      echo "Commande prisma introuvable localement aussi. Installez prisma ou utilisez npx/bunx." >&2
      return 1
    fi
  else
    # shellcheck disable=SC2086
    eval "$prisma migrate reset --force"
  fi
}

migration_menu() {
  while true; do
    echo
    echo "================= Menu Migrations Prisma ================="
    echo "1) Créer une migration (create-only)"
    echo "2) Appliquer toutes les migrations (deploy)"
    echo "3) Rollback (reset) - destructif"
    echo "4) Retour"
    echo "=========================================================="
    read -r -p "Choix: " mchoice
    case "$mchoice" in
      1) create_migration ;;
      2) apply_migrations ;;
      3) rollback_migration ;;
      4) return 0 ;;
      *) echo "Option inconnue." ;;
    esac
  done
}

main_menu() {
  while true; do
    echo
    echo "================ docker-compose CLI ================"
    echo "1) Lancer docker-compose (detected: $DCMD)"
    echo "2) Lister les services"
    echo "3) Entrer dans un service (sh/bash)"
    echo "4) Afficher les logs d'un service"
    echo "5) Afficher tous les logs"
    echo "6) Migrations Prisma"
    echo "7) Quitter"
    echo "===================================================="
    read -r -p "Choix: " choice
    case "$choice" in
      1)
        start_compose
        ;;
      2)
        echo "Services détectés:"
        list_services | nl -ba -w3 -s": " || true
        ;;
      3)
        mapfile -t services < <(list_services)
        if [ ${#services[@]} -eq 0 ]; then
          echo "Aucun service trouvé. Exécutez d'abord l'option 1 pour démarrer le compose ou vérifiez votre fichier docker-compose.yml"
          continue
        fi
        echo "Choisir un service (numéro ou nom):"
        for i in "${!services[@]}"; do
          idx=$((i+1))
          printf "%3d) %s\n" "$idx" "${services[i]}"
        done
        read -r -p "Service: " svcchoice
        if [[ "$svcchoice" =~ ^[0-9]+$ ]]; then
          sel=${services[$((svcchoice-1))]:-}
        else
          sel="$svcchoice"
        fi
        if [ -z "$sel" ]; then
          echo "Sélection invalide.";
        else
          enter_service_shell "$sel"
        fi
        ;;
      4)
        mapfile -t services < <(list_services)
        if [ ${#services[@]} -eq 0 ]; then
          echo "Aucun service trouvé."
          continue
        fi
        echo "Choisir un service pour voir ses logs (numéro ou nom):"
        for i in "${!services[@]}"; do
          idx=$((i+1))
          printf "%3d) %s\n" "$idx" "${services[i]}"
        done
        read -r -p "Service: " svcchoice
        if [[ "$svcchoice" =~ ^[0-9]+$ ]]; then
          sel=${services[$((svcchoice-1))]:-}
        else
          sel="$svcchoice"
        fi
        if [ -z "$sel" ]; then
          echo "Sélection invalide.";
        else
          show_logs "$sel"
        fi
        ;;
      5)
        show_logs ""
        ;;
      6)
        migration_menu
        ;;
      7)
        echo "Quitter."
        exit 0
        ;;
      *)
        echo "Option inconnue.";
        ;;
    esac
  done
}

# Run
start_compose
main_menu
