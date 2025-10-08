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

main_menu() {
  while true; do
    echo
    echo "================ docker-compose CLI ================"
    echo "1) Lancer docker-compose (detected: $DCMD)"
    echo "2) Lister les services"
    echo "3) Entrer dans un service (sh/bash)"
    echo "4) Afficher les logs d'un service"
    echo "5) Afficher tous les logs"
    echo "6) Quitter"
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
