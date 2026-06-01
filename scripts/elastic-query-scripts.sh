#!/bin/zsh

BASE_URL="http://localhost:9200/products"

# ==========================================
# 1. 分析器切詞確認
# ==========================================
echo "=== 分析器切詞 ==="
curl -s -X POST "$BASE_URL/_analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "analyzer": "product_index",
    "text": "宜得利 NITORI 保鮮盒"
  }' | jq

# ==========================================
# 2. 全文搜尋 (match - text 欄位走分詞器)
# ==========================================
echo "=== 全文搜尋 ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": {
      "match": {
        "name": {
          "query": "宜得利毛巾"
        }
      }
    },
    "sort": [{ "_score": "desc" }]
  }' | jq

# ==========================================
# 3. 精確匹配 (term - keyword 欄位)
# ==========================================
echo "=== 精確匹配 ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": {
      "term": {
        "name.keyword": "宜得利 NITORI 防滑地墊 中號 G2"
      }
    }
  }' | jq

# ==========================================
# 4. 模糊搜尋 (fuzziness - 容錯錯字)
# ==========================================
echo "=== 模糊搜尋 ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": {
      "match": {
        "name": {
          "query": "宜得力多",
          "fuzziness": "AUTO"
        }
      }
    },
    "sort": [{ "_score": "desc" }]
  }' | jq

# ==========================================
# 5. 前綴搜尋 (match_phrase_prefix - 搜尋框自動補全)
# ==========================================
echo "=== 前綴搜尋 ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": {
      "match_phrase_prefix": {
        "name": "宜得"
      }
    }
  }' | jq

# ==========================================
# 6. 多欄位搜尋 (multi_match - name + description)
# ==========================================
echo "=== 多欄位搜尋 ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": {
      "multi_match": {
        "query": "防滑",
        "fields": ["name^2", "description"],
        "type": "best_fields"
      }
    },
    "sort": [{ "_score": "desc" }]
  }' | jq

# ==========================================
# 7. 精確 + 模糊組合 (bool should - 提高精確匹配權重)
# ==========================================
echo "=== 精確 + 模糊組合 ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": {
      "bool": {
        "should": [
          {
            "match_phrase_prefix": {
              "name": { "query": "MUJI", "boost": 3 }
            }
          },
          {
            "match": {
              "name": { "query": "MUJI", "fuzziness": "AUTO", "boost": 1 }
            }
          }
        ]
      }
    },
    "sort": [{ "_score": "desc" }]
  }' | jq

# ==========================================
# 8. 關鍵字 + 價格過濾 (bool must + filter)
# ==========================================
echo "=== 關鍵字 + 價格過濾 ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": {
      "bool": {
        "must": [
          {
            "match": { "name": "毛巾" }
          }
        ],
        "filter": [
          {
            "range": { "price": { "gte": 100, "lte": 500 } }
          }
        ]
      }
    },
    "sort": [{ "_score": "desc" }]
  }' | jq

# ==========================================
# 9. 分頁查詢 第一頁 (sort 必須加 id 確保順序穩定)
# ==========================================
echo "=== 分頁查詢 第一頁 ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": {
      "match": {
        "name": {
          "query": "MUJI",
          "fuzziness": "AUTO"
        }
      }
    },
    "sort": [
      { "_score": "desc" },
      { "id": "desc" }
    ]
  }' | jq

# ==========================================
# 10. 分頁查詢 下一頁 (search_after - 取上一頁最後一筆 sort 值)
# ==========================================
echo "=== 分頁查詢 下一頁 (search_after) ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": {
      "match": {
        "name": {
          "query": "MUJI",
          "fuzziness": "AUTO"
        }
      }
    },
    "sort": [
      { "_score": "desc" },
      { "id": "desc" }
    ],
    "search_after": [5.2331233, 2057248]
  }' | jq

# ==========================================
# 11. 價格排序 + 分頁 (search_after)
# ==========================================
echo "=== 價格排序 第一頁 ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": { "match_all": {} },
    "sort": [
      { "price": { "order": "asc" } },
      { "id": "desc" }
    ]
  }' | jq

echo "=== 價格排序 下一頁 (search_after) ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 10,
    "query": { "match_all": {} },
    "sort": [
      { "price": { "order": "asc" } },
      { "id": "desc" }
    ],
    "search_after": [209.0, 2063594]
  }' | jq

# ==========================================
# 12. 精確總筆數
# ==========================================
echo "=== 精確總筆數 ==="
curl -s -X GET "$BASE_URL/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 0,
    "track_total_hits": true,
    "query": {
      "match": { "name": "毛巾" }
    }
  }' | jq '.hits.total'