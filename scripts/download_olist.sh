#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${DATA_DIR:-data/olist}"
OLIST_COMMIT="${OLIST_COMMIT:-663660edff1b4cd711a172027081915771628b9f}"
BASE_URL="${OLIST_BASE_URL:-https://raw.githubusercontent.com/mara/mara-olist-ecommerce-data/${OLIST_COMMIT}/data/olist-ecommerce}"

FILES=(
  "olist_customers_dataset.csv"
  "olist_geolocation_dataset.csv"
  "olist_order_items_dataset.csv"
  "olist_order_payments_dataset.csv"
  "olist_order_reviews_dataset.csv"
  "olist_orders_dataset.csv"
  "olist_products_dataset.csv"
  "olist_sellers_dataset.csv"
  "product_category_name_translation.csv"
)

mkdir -p "${DATA_DIR}"

download_file() {
  local url="$1"
  local target="$2"

  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error "${url}" --output "${target}"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "${url}" -O "${target}"
  else
    echo "curl or wget is required to download Olist data." >&2
    exit 1
  fi
}

echo "Downloading Olist CSV files to ${DATA_DIR}"

for file in "${FILES[@]}"; do
  target="${DATA_DIR}/${file}"
  tmp="${target}.tmp"

  echo "  - ${file}"
  download_file "${BASE_URL}/${file}" "${tmp}"

  if [ ! -s "${tmp}" ]; then
    echo "Downloaded file is empty: ${file}" >&2
    rm -f "${tmp}"
    exit 1
  fi

  mv "${tmp}" "${target}"
done

echo "Olist CSV files are ready."
