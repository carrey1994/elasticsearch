import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import encoding from 'k6/encoding';
import { randomItem, randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

// =========================================
// 環境變數
// =========================================
// BASE_URL    Elasticsearch base URL (default: http://localhost:9200)
// INDEX       目標 index (default: products)
// VUS         並發數 (default: 10)
// DURATION    壓測持續時間 (default: 30s)
// AUTH        Basic auth, 格式 "user:pass" (optional)
const BASE_URL = __ENV.BASE_URL || 'http://localhost:9200';
const INDEX = __ENV.INDEX || 'products';
const VUS = parseInt(__ENV.VUS || '10');
const DURATION = __ENV.DURATION || '30s';
const AUTH = __ENV.AUTH || '';

const SEARCH_URL = `${BASE_URL}/${INDEX}/_search`;

// =========================================
// k6 options
// =========================================
export const options = {
  scenarios: {
    mixed_search: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
      gracefulStop: '10s',
    },
  },
  thresholds: {
    // 整體成功率 > 99%
    http_req_failed: ['rate<0.01'],
    // 95% 請求 < 500ms, 99% < 1s
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    // 每個 query type 的 latency
    'es_query_latency{type:match}': ['p(95)<500'],
    'es_query_latency{type:term}': ['p(95)<200'],
    'es_query_latency{type:range}': ['p(95)<300'],
    'es_query_latency{type:bool}': ['p(95)<800'],
    'es_query_latency{type:multi_match}': ['p(95)<800'],
    'es_query_latency{type:match_phrase_prefix}': ['p(95)<500'],
  },
};

// =========================================
// 自訂 metrics
// =========================================
const queryLatency = new Trend('es_query_latency', true);
const zeroHits = new Counter('es_zero_hits');

// =========================================
// 測試資料 (對應 elastic-query-scripts.sh)
// =========================================
const KEYWORDS = ['宜得利', '毛巾', 'MUJI', '保鮮盒', '防滑地墊', '浴巾', 'NITORI'];
const PREFIXES = ['宜得', 'MUJ', '無印', 'NIT'];
const BRANDS = ['宜得利 NITORI 防滑地墊 中號 G2', 'MUJI 毛巾 浴巾', '宜得利 NITORI 保鮮盒'];

// =========================================
// 各種 query 產生器
// =========================================
function matchQuery() {
  return {
    type: 'match',
    body: {
      size: 10,
      query: { match: { name: { query: randomItem(KEYWORDS) } } },
      sort: [{ _score: 'desc' }],
    },
  };
}

function termQuery() {
  return {
    type: 'term',
    body: {
      size: 10,
      query: { term: { 'name.keyword': randomItem(BRANDS) } },
    },
  };
}

function fuzzyMatchQuery() {
  return {
    type: 'match',
    body: {
      size: 10,
      query: {
        match: {
          name: { query: randomItem(KEYWORDS), fuzziness: 'AUTO' },
        },
      },
    },
  };
}

function matchPhrasePrefixQuery() {
  return {
    type: 'match_phrase_prefix',
    body: {
      size: 10,
      query: { match_phrase_prefix: { name: randomItem(PREFIXES) } },
    },
  };
}

function multiMatchQuery() {
  return {
    type: 'multi_match',
    body: {
      size: 10,
      query: {
        multi_match: {
          query: randomItem(KEYWORDS),
          fields: ['name^2', 'description'],
          type: 'best_fields',
        },
      },
    },
  };
}

function rangeQuery() {
  const lo = randomIntBetween(50, 500);
  return {
    type: 'range',
    body: {
      size: 10,
      query: { range: { price: { gte: lo, lte: lo + 500 } } },
      sort: [{ price: 'asc' }],
    },
  };
}

function boolQuery() {
  return {
    type: 'bool',
    body: {
      size: 10,
      query: {
        bool: {
          must: [{ match: { name: randomItem(KEYWORDS) } }],
          filter: [{ range: { price: { gte: 100, lte: 2000 } } }],
          should: [
            { match_phrase_prefix: { name: randomItem(PREFIXES) } },
          ],
          minimum_should_match: 0,
        },
      },
    },
  };
}

// 加權分佈, 模擬真實流量 (match 最多, range/bool 次之, term 最少)
const QUERY_POOL = [
  matchQuery, matchQuery, matchQuery, matchQuery,
  fuzzyMatchQuery, fuzzyMatchQuery,
  multiMatchQuery, multiMatchQuery,
  matchPhrasePrefixQuery, matchPhrasePrefixQuery,
  rangeQuery, rangeQuery,
  boolQuery,
  termQuery,
];

// =========================================
// HTTP helpers
// =========================================
function headers() {
  const h = { 'Content-Type': 'application/json' };
  if (AUTH) h['Authorization'] = 'Basic ' + encoding.b64encode(AUTH);
  return h;
}

function runQuery(q) {
  const res = http.post(SEARCH_URL, JSON.stringify(q.body), {
    headers: headers(),
    tags: { type: q.type },
  });

  queryLatency.add(res.timings.duration, { type: q.type });

  const ok = check(res, {
    [`${q.type} status 200`]: (r) => r.status === 200,
    [`${q.type} has hits`]: (r) => {
      try {
        return r.json('hits') !== undefined;
      } catch (_) {
        return false;
      }
    },
  });

  if (ok) {
    const total = res.json('hits.total.value');
    if (total === 0) zeroHits.add(1, { type: q.type });
  }
}

// =========================================
// Setup: 確認 cluster 可達 + index 存在
// =========================================
export function setup() {
  const ping = http.get(`${BASE_URL}/_cluster/health`, { headers: headers() });
  if (ping.status !== 200) {
    throw new Error(`Cluster unreachable: ${ping.status} ${ping.body}`);
  }
  const idx = http.get(`${BASE_URL}/${INDEX}`, { headers: headers() });
  if (idx.status !== 200) {
    throw new Error(`Index "${INDEX}" not found: ${idx.status}`);
  }
  console.log(`[setup] target=${SEARCH_URL} vus=${VUS} duration=${DURATION}`);
}

// =========================================
// VU 主循環
// =========================================
export default function () {
  group('search', () => {
    const q = randomItem(QUERY_POOL)();
    runQuery(q);
  });
}
