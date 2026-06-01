# Elasticsearch Query DSL 完整結構

## 最外層結構

```json
{
  "size": 10,
  "from": 0,
  "track_total_hits": true,
  "query": {},
  "sort": [],
  "search_after": []
}
```

---

## Query 種類總覽

```
query
├── match_all             → 全部
├── match                 → 全文搜尋（走分詞器）
├── match_phrase          → 片語搜尋（順序要一致）
├── match_phrase_prefix   → 前綴搜尋
├── multi_match           → 多欄位全文搜尋
├── term                  → 精確匹配（不分詞）
├── terms                 → 多值精確匹配
├── range                 → 範圍查詢
├── wildcard              → 萬用字元
└── bool                  → 組合查詢
    ├── must              → AND（影響分數）
    ├── filter            → AND（不影響分數，有快取）
    ├── should            → OR
    └── must_not          → NOT
```

---

## 各種 Query 格式

### match_all
```json
{ "query": { "match_all": {} } }
```

### match（走分詞器）
```json
{ "query": { "match": { "name": "毛巾" } } }
```

完整參數：
```json
{
  "query": {
    "match": {
      "name": {
        "query": "毛巾",
        "fuzziness": "AUTO",
        "operator": "AND",
        "boost": 2
      }
    }
  }
}
```

### match_phrase（詞序要一致）
```json
{ "query": { "match_phrase": { "name": "MUJI 毛巾" } } }
```

### match_phrase_prefix（前綴補全）
```json
{ "query": { "match_phrase_prefix": { "name": "MUJ" } } }
```

### multi_match（多欄位）
```json
{
  "query": {
    "multi_match": {
      "query": "毛巾",
      "fields": ["name^2", "description"],
      "type": "best_fields",
      "fuzziness": "AUTO"
    }
  }
}
```

### term（精確匹配，不分詞，用 keyword 欄位）
```json
{ "query": { "term": { "name.keyword": "MUJI 毛巾 浴巾" } } }
```

### terms（多值精確匹配）
```json
{ "query": { "terms": { "name.keyword": ["MUJI 毛巾", "宜得利 毛巾"] } } }
```

### range（範圍）
```json
{
  "query": {
    "range": {
      "price": {
        "gte": 100,
        "lte": 500
      }
    }
  }
}
```

### wildcard（萬用字元，效能較差）
```json
{
  "query": {
    "wildcard": {
      "name.keyword": {
        "value": "*MUJI*",
        "case_insensitive": true
      }
    }
  }
}
```

---

## bool 組合格式

```json
{
  "query": {
    "bool": {
      "must": [
        { "match": { "name": "毛巾" } }
      ],
      "filter": [
        { "range": { "price": { "gte": 100, "lte": 500 } } },
        { "term": { "name.keyword": "MUJI 毛巾" } }
      ],
      "should": [
        { "match": { "name": { "query": "浴巾", "boost": 2 } } },
        { "match_phrase_prefix": { "name": "MUJ" } }
      ],
      "must_not": [
        { "term": { "name.keyword": "無品牌" } }
      ],
      "minimum_should_match": 1
    }
  }
}
```

### must vs filter 差異

| | must | filter |
|--|------|--------|
| 影響相關性分數 | ✅ 是 | ❌ 否 |
| 有快取 | ❌ 否 | ✅ 是 |
| 適合 | 全文搜尋、關鍵字 | 價格、日期、精確條件 |

---

## sort 格式

```json
"sort": [
  { "_score": "desc" },
  { "price": "asc" },
  { "id": { "order": "desc" } },
  { "createdAt": "desc" }
]
```

---

## 分頁

### from + size（適合頁數少）
```json
{
  "from": 10,
  "size": 10,
  "query": { "match": { "name": "毛巾" } }
}
```

### search_after（適合大資料量）

第一頁：
```json
{
  "size": 10,
  "query": {
    "match": { "name": { "query": "MUJI", "fuzziness": "AUTO" } }
  },
  "sort": [
    { "_score": "desc" },
    { "id": "desc" }
  ]
}
```

下一頁（取上一頁最後一筆的 sort 值）：
```json
{
  "size": 10,
  "query": {
    "match": { "name": { "query": "MUJI", "fuzziness": "AUTO" } }
  },
  "sort": [
    { "_score": "desc" },
    { "id": "desc" }
  ],
  "search_after": [5.2331233, 2057248]
}
```

### from + size vs search_after

| | from + size | search_after |
|--|-------------|--------------|
| 原理 | 跳過前 N 筆 | 從上一頁最後一筆繼續 |
| 效能 | ❌ 越後面越慢 | ✅ 固定效能 |
| 最大限制 | 預設 10000 筆 | ✅ 無限制 |
| 可跳頁 | ✅ 可以 | ❌ 只能往下一頁 |
| 適合場景 | 頁數少、需跳頁 | 大資料量、無限捲動 |

---

## 精確總筆數

```json
{
  "size": 0,
  "track_total_hits": true,
  "query": { "match": { "name": "毛巾" } }
}
```

> 預設 `track_total_hits: 10000`，超過 10000 筆只會顯示 `"relation": "gte"`。
> 加上 `"track_total_hits": true` 才會回傳精確總數。

---

## Query 對照表

| Query | 走分詞器 | 適合欄位 | 適合場景 |
|-------|---------|---------|---------|
| `match` | ✅ | text | 搜尋框 |
| `match_phrase` | ✅ | text | 完整片語 |
| `match_phrase_prefix` | ✅ | text | 自動補全 |
| `multi_match` | ✅ | text | 多欄位搜尋 |
| `term` | ❌ | keyword | 精確過濾 |
| `terms` | ❌ | keyword | 多值過濾 |
| `range` | ❌ | number/date | 價格、時間範圍 |
| `wildcard` | ❌ | keyword | 模糊匹配（效能差） |
| `bool` | - | 任意 | 組合以上條件 |

## fuzziness AUTO 規則

| 字串長度 | 容錯距離 |
|---------|---------|
| 1 ~ 2 字元 | 0（完全匹配） |
| 3 ~ 5 字元 | 1 |
| 6+ 字元 | 2 |

> AUTO 實際上是 `AUTO:3,6` 的縮寫。
> ES 最大只支援到距離 `2`。