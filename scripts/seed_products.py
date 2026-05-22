#!/usr/bin/env python3
"""
Generate demo products via POST /api/products.

Prerequisites:
  - docker compose up (postgres + elasticsearch)
  - ./gradlew bootRun

After changing ES analyzer/mapping, recreate the index then re-seed:
  curl -X DELETE http://localhost:9200/products
  restart bootRun, then run this script again

Usage:
  python seed_products.py
  python seed_products.py --count 50
  python seed_products.py --base-url http://localhost:8080 --count 20
  python seed_products.py --dry-run
  python seed_products.py --verify-search
"""

import argparse
import random
import sys
import time

import requests
from faker import Faker

# ── Faker setup ───────────────────────────────────────────────────────────────
fake = Faker("zh_TW")

# ── Catalog ───────────────────────────────────────────────────────────────────
CATALOG = [
    {
        "prefix": "無線藍牙耳機",
        "desc_tpl": "主動降噪 {kw}，續航 30 小時，支援快充與多裝置切換。",
        "price_range": (1290, 4990),
        "keywords": ["降噪", "藍牙", "耳機"],
    },
    {
        "prefix": "機械式鍵盤",
        "desc_tpl": "青軸手感，RGB 背光，適合 {kw} 與日常文書輸入。",
        "price_range": (1890, 6990),
        "keywords": ["電競", "鍵盤", "機械軸"],
    },
    {
        "prefix": "27 吋 4K 螢幕",
        "desc_tpl": "IPS 面板，99% sRGB，適合 {kw} 與影像剪輯。",
        "price_range": (5990, 18990),
        "keywords": ["螢幕", "4K", "顯示器"],
    },
    {
        "prefix": "輕量羽絨外套",
        "desc_tpl": "防潑水面料，保暖透氣，適合 {kw} 與通勤穿搭。",
        "price_range": (1590, 4590),
        "keywords": ["外套", "羽絨", "冬季"],
    },
    {
        "prefix": "有機咖啡豆",
        "desc_tpl": "中深焙，帶有 {kw} 香氣，250g 真空包裝。",
        "price_range": (320, 890),
        "keywords": ["咖啡", "有機", "手沖"],
    },
    {
        "prefix": "人體工學辦公椅",
        "desc_tpl": "可調腰靠與頭枕，長時間 {kw} 仍保持舒適。",
        "price_range": (3990, 12990),
        "keywords": ["辦公椅", "人體工學", "久坐"],
    },
    {
        "prefix": "行動電源",
        "desc_tpl": "20000mAh，支援 PD 快充，外出 {kw} 必備。",
        "price_range": (690, 2490),
        "keywords": ["行動電源", "快充", "PD"],
    },
    {
        "prefix": "不鏽鋼保溫瓶",
        "desc_tpl": "雙層真空，保冷 24 小時，適合 {kw} 與運動。",
        "price_range": (450, 1290),
        "keywords": ["保溫瓶", "不鏽鋼", "戶外"],
    },
]

ADJECTIVES = ["Pro", "Lite", "Max", "Air", "Ultra", "Classic", "Plus"]
COLORS     = ["黑", "白", "銀", "藍", "綠", "紅"]
BRANDS     = ["Nova", "Zen", "Apex", "Pulse", "Core", "Luma", "Stride"]

# ── Product builder ───────────────────────────────────────────────────────────

def build_product(index: int) -> dict:
    item     = random.choice(CATALOG)
    kw       = random.choice(item["keywords"])
    brand    = random.choice(BRANDS)
    adj      = random.choice(ADJECTIVES)
    color    = random.choice(COLORS)

    name        = f"{brand} {item['prefix']} {adj} {color} #{index:04d}"
    description = item["desc_tpl"].replace("{kw}", kw)

    # 40 % chance to append extra keyword hint (mirrors original bash logic)
    if random.random() < 0.4:
        extra        = random.choice(item["keywords"])
        description += f" 關鍵字：{kw}, {extra}。"

    lo, hi = item["price_range"]
    price  = round(random.uniform(lo, hi), 2)

    return {"name": name, "description": description, "price": price}

# ── HTTP helpers ──────────────────────────────────────────────────────────────

def wait_for_app(base_url: str, timeout: int, retries: int = 30) -> bool:
    url = f"{base_url.rstrip('/')}/api/products?q=test"
    for attempt in range(1, retries + 1):
        try:
            r = requests.get(url, timeout=2)
            if r.ok:
                return True
        except requests.exceptions.RequestException:
            pass
        print(f"  waiting for app... ({attempt}/{retries})")
        time.sleep(1)
    return False


def post_product(base_url: str, payload: dict, timeout: int) -> dict | None:
    url = f"{base_url.rstrip('/')}/api/products"
    try:
        r = requests.post(url, json=payload, timeout=timeout)
        r.raise_for_status()
        return r.json()
    except requests.exceptions.RequestException as exc:
        print(f"  POST failed: {exc}", file=sys.stderr)
        return None


def search_products(base_url: str, keyword: str, timeout: int) -> list | None:
    url = f"{base_url.rstrip('/')}/api/products"
    try:
        r = requests.get(url, params={"q": keyword}, timeout=timeout)
        r.raise_for_status()
        return r.json()
    except requests.exceptions.RequestException as exc:
        print(f"  search failed: {exc}", file=sys.stderr)
        return None

# ── CLI ───────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Seed demo products into the API.")
    p.add_argument("--base-url",      default="http://localhost:8080", metavar="URL")
    p.add_argument("--count",         default=30, type=int,            metavar="N")
    p.add_argument("--timeout",       default=10, type=int,            metavar="SEC")
    p.add_argument("--seed",          default=None, type=int,          metavar="N",
                   help="random seed for reproducible output")
    p.add_argument("--dry-run",       action="store_true",
                   help="print JSON payloads without POSTing")
    p.add_argument("--verify-search", action="store_true",
                   help="run sample search queries after seeding")
    return p.parse_args()

# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()

    if args.count < 1:
        print("--count must be a positive integer", file=sys.stderr)
        sys.exit(1)

    if args.seed is not None:
        random.seed(args.seed)
        Faker.seed(args.seed)

    if not args.dry_run:
        print(f"Checking API at {args.base_url} ...")
        if not wait_for_app(args.base_url, args.timeout):
            print(
                f"Cannot reach {args.base_url}. Start the app first: ./gradlew bootRun",
                file=sys.stderr,
            )
            sys.exit(1)

    created = failed = 0

    for i in range(1, args.count + 1):
        payload = build_product(i)

        if args.dry_run:
            import json
            print(json.dumps(payload, ensure_ascii=False))
            continue

        resp = post_product(args.base_url, payload, args.timeout)
        if resp:
            print(f"[{i}/{args.count}] created id={resp.get('id')} name={resp.get('name')}")
            created += 1
        else:
            failed += 1

    if args.dry_run:
        print(f"dry-run: would create {args.count} products")
        return

    print(f"\nDone. created={created} failed={failed}")

    if args.verify_search and created > 0:
        print("\nSample search results:")
        for kw in ["咖啡", "鍵盤", "4K", "耳機"]:
            hits = search_products(args.base_url, kw, args.timeout)
            if hits is None:
                continue
            print(f"  q='{kw}' -> {len(hits)} hit(s)")
            for item in hits[:3]:
                print(f"    - id={item.get('id')} {item.get('name')}")

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()