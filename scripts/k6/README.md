# k6 Elasticsearch load test

針對 `products` index 的混合 query 壓測腳本。

## 前置

```bash
docker compose up -d elasticsearch
# 確認 index 已建立 + 已灌資料 (參考 scripts/products_fake_1000000.sql.gz)
```

## 安裝 k6

```bash
brew install k6                          # macOS
# 或
sudo snap install k6                     # Linux
```

## 執行

```bash
# 預設: 10 VUs / 30s, 打 http://localhost:9200/products
k6 run scripts/k6/elasticsearch-load-test.js

# 自訂並發 / 時間 / 目標
k6 run \
  -e BASE_URL=http://localhost:9200 \
  -e INDEX=products \
  -e VUS=50 \
  -e DURATION=2m \
  scripts/k6/elasticsearch-load-test.js

# 需要 basic auth
k6 run -e AUTH=elastic:changeme scripts/k6/elasticsearch-load-test.js
```

## Query 分佈 (加權)

| Query | 權重 | Latency threshold (p95) |
|-------|-----|------------------------|
| `match` | 4 | 500ms |
| `match` (fuzzy) | 2 | 500ms |
| `multi_match` | 2 | 800ms |
| `match_phrase_prefix` | 2 | 500ms |
| `range` | 2 | 300ms |
| `bool` | 1 | 800ms |
| `term` | 1 | 200ms |

## 輸出指標

- `http_req_duration` — 整體 latency (內建)
- `http_req_failed` — 失敗率, 門檻 < 1%
- `es_query_latency{type=...}` — 各 query type 的 latency
- `es_zero_hits{type=...}` — 回傳 0 筆的次數 (檢查測試資料是否合理)
