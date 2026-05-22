#!/usr/bin/env bash
#
# Generate demo products via POST /api/products.
#
# Prerequisites:
#   - docker compose up (postgres + elasticsearch)
#   - ./gradlew bootRun
#
# After changing ES analyzer/mapping, recreate the index then re-seed:
#   curl -X DELETE http://localhost:9200/products
#   restart bootRun, then run this script again
#
# Usage:
#   ./scripts/seed_products.sh
#   ./scripts/seed_products.sh --count 50
#   ./scripts/seed_products.sh --base-url http://localhost:8080 --count 20
#   ./scripts/seed_products.sh --dry-run
#   ./scripts/seed_products.sh --verify-search

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
COUNT=30
TIMEOUT=10
SEED=""
DRY_RUN=false
VERIFY_SEARCH=false

usage() {
  cat <<'EOF'
Usage: seed_products.sh [options]

Options:
  --base-url URL     Spring Boot base URL (default: http://localhost:8080)
  --count N          Number of products to create (default: 30)
  --timeout SEC      HTTP timeout in seconds (default: 10)
  --seed N           Random seed (uses $RANDOM only; set once at start)
  --dry-run          Print JSON payloads without POST
  --verify-search    Run sample search queries after seeding
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      BASE_URL="$2"
      shift 2
      ;;
    --count)
      COUNT="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --seed)
      SEED="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verify-search)
      VERIFY_SEARCH=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -lt 1 ]]; then
  echo "count must be a positive integer" >&2
  exit 1
fi

if [[ -n "$SEED" ]]; then
  RANDOM="$SEED"
fi

# Catalog: "prefix|description template|price_lo|price_hi|kw1,kw2,kw3"
CATALOG=(
  '無線藍牙耳機|主動降噪 {kw}，續航 30 小時，支援快充與多裝置切換。|1290|4990|降噪,藍牙,耳機'
  '機械式鍵盤|青軸手感，RGB 背光，適合 {kw} 與日常文書輸入。|1890|6990|電競,鍵盤,機械軸'
  '27 吋 4K 螢幕|IPS 面板，99% sRGB，適合 {kw} 與影像剪輯。|5990|18990|螢幕,4K,顯示器'
  '輕量羽絨外套|防潑水面料，保暖透氣，適合 {kw} 與通勤穿搭。|1590|4590|外套,羽絨,冬季'
  '有機咖啡豆|中深焙，帶有 {kw} 香氣，250g 真空包裝。|320|890|咖啡,有機,手沖'
  '人體工學辦公椅|可調腰靠與頭枕，長時間 {kw} 仍保持舒適。|3990|12990|辦公椅,人體工學,久坐'
  '行動電源|20000mAh，支援 PD 快充，外出 {kw} 必備。|690|2490|行動電源,快充,PD'
  '不鏽鋼保溫瓶|雙層真空，保冷 24 小時，適合 {kw} 與運動。|450|1290|保溫瓶,不鏽鋼,戶外'
)

ADJECTIVES=(Pro Lite Max Air Ultra Classic Plus)
COLORS=(黑 白 銀 藍 綠 紅)
BRANDS=(Nova Zen Apex Pulse Core Luma Stride)

pick_adj()   { echo "${ADJECTIVES[$((RANDOM % ${#ADJECTIVES[@]}))]}"; }
pick_color() { echo "${COLORS[$((RANDOM % ${#COLORS[@]}))]}"; }
pick_brand() { echo "${BRANDS[$((RANDOM % ${#BRANDS[@]}))]}"; }

pick_catalog_line() {
  echo "${CATALOG[$((RANDOM % ${#CATALOG[@]}))]}"
}

pick_from_csv() {
  local csv="$1"
  local IFS=,
  local -a items
  read -r -a items <<< "$csv"
  echo "${items[$((RANDOM % ${#items[@]}))]}"
}

random_price() {
  local lo=$1 hi=$2
  # price with 2 decimal places
  awk -v lo="$lo" -v hi="$hi" -v r="$RANDOM" \
    'BEGIN { srand(r); printf "%.2f", lo + (hi - lo) * rand() }'
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

build_product() {
  local index=$1
  local line prefix desc_tpl lo hi keywords_csv kw brand adj color name description price
  line="$(pick_catalog_line)"

  IFS='|' read -r prefix desc_tpl lo hi keywords_csv <<< "$line"
  kw="$(pick_from_csv "$keywords_csv")"
  brand="$(pick_brand)"
  adj="$(pick_adj)"
  color="$(pick_color)"

  name="${brand} ${prefix} ${adj} ${color} #$(printf '%04d' "$index")"
  description="${desc_tpl//\{kw\}/$kw}"

  if (( RANDOM % 10 < 4 )); then
    local extra
    extra="$(pick_from_csv "$keywords_csv")"
    description+=" 關鍵字：${kw}, ${extra}。"
  fi

  price="$(random_price "$lo" "$hi")"

  local name_json desc_json
  name_json="$(json_escape "$name")"
  desc_json="$(json_escape "$description")"

  printf '{"name":%s,"description":%s,"price":%s}\n' "$name_json" "$desc_json" "$price"
}

wait_for_app() {
  local url="${BASE_URL%/}/api/products?q=test"
  local i
  for ((i = 1; i <= 30; i++)); do
    if curl -sf --max-time 2 -G "$url" -o /dev/null 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

post_product() {
  local payload=$1
  curl -sf --max-time "$TIMEOUT" \
    -X POST "${BASE_URL%/}/api/products" \
    -H 'Content-Type: application/json' \
    -d "$payload"
}

search_products() {
  local keyword=$1
  curl -sf --max-time "$TIMEOUT" -G "${BASE_URL%/}/api/products" \
    --data-urlencode "q=${keyword}"
}

extract_field() {
  local json=$1 field=$2
  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r ".$field // empty"
  else
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$field',''))" <<<"$json"
  fi
}

main() {
  if [[ "$DRY_RUN" == false ]]; then
    echo "Checking API at ${BASE_URL} ..."
    if ! wait_for_app; then
      echo "Cannot reach ${BASE_URL}. Start the app first: ./gradlew bootRun" >&2
      exit 1
    fi
  fi

  local created=0 failed=0 i payload resp id name

  for ((i = 1; i <= COUNT; i++)); do
    payload="$(build_product "$i")"

    if [[ "$DRY_RUN" == true ]]; then
      echo "$payload"
      continue
    fi

    if resp="$(post_product "$payload" 2>&1)"; then
      id="$(extract_field "$resp" id)"
      name="$(extract_field "$resp" name)"
      echo "[$i/$COUNT] created id=${id} name=${name}"
      ((created++)) || true
    else
      echo "[$i/$COUNT] failed: $resp" >&2
      ((failed++)) || true
      if [[ "$resp" == *"Connection refused"* ]] || [[ "$resp" == *"Could not connect"* ]]; then
        echo "Is the app running? Try: ./gradlew bootRun" >&2
        break
      fi
    fi
  done

  if [[ "$DRY_RUN" == true ]]; then
    echo "dry-run: would create ${COUNT} products"
    exit 0
  fi

  echo ""
  echo "Done. created=${created} failed=${failed}"

  if [[ "$VERIFY_SEARCH" == true && "$created" -gt 0 ]]; then
    local kw hits
    echo ""
    echo "Sample search results:"
    for kw in 咖啡 鍵盤 4K 耳機; do
      if hits="$(search_products "$kw" 2>&1)"; then
        local n
        if command -v jq >/dev/null 2>&1; then
          n="$(echo "$hits" | jq 'length')"
          echo "  q='${kw}' -> ${n} hit(s)"
          echo "$hits" | jq -r '.[:3][] | "    - id=\(.id) \(.name)"'
        else
          n="$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' <<<"$hits")"
          echo "  q='${kw}' -> ${n} hit(s)"
        fi
      else
        echo "  q='${kw}' -> search failed: $hits" >&2
      fi
    done
  fi

  [[ "$failed" -eq 0 ]]
}

main "$@"
