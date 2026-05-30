"""
RetailCo ERP Extractor
Handles: cursor pagination, incremental loading (updated_after),
         rate limiting (429+Retry-After), transient errors (500/timeout),
         idempotent upsert, watermark per entity
"""
import os, time, logging
from datetime import datetime
from typing import Optional, List, Dict, Any
import requests, psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

API_BASE = "https://hngstage8da-55c7f5f769c8.herokuapp.com"
API_KEY  = os.environ["ERP_API_KEY"]

ENTITY_PKS = {
    "customers": "id",
    "products": "id",
    "stores": "id",
    "employees": "id",
    "orders": "id",
    "order_items": "id",
    "payments": "id",
    "inventory_movements": "id",
}

INCREMENTAL_ENTITIES = {
    "customers", "products", "orders",
    "order_items", "payments", "inventory_movements"
}


def get_connection():
    return psycopg2.connect(
        host=os.environ["LAKE_HOST"],
        port=os.environ["LAKE_PORT"],
        dbname=os.environ["LAKE_DB"],
        user=os.environ["LAKE_USER"],
        password=os.environ["LAKE_PASSWORD"]
    )


def get_watermark(conn, entity: str) -> Optional[datetime]:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT last_updated_at FROM raw.watermarks WHERE entity_name = %s",
            (entity,)
        )
        row = cur.fetchone()
        return row[0] if row else None


def set_watermark(conn, entity: str, timestamp: datetime):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO raw.watermarks (entity_name, last_updated_at, last_run_at)
            VALUES (%s, %s, NOW())
            ON CONFLICT (entity_name)
            DO UPDATE SET last_updated_at = EXCLUDED.last_updated_at,
                          last_run_at = NOW()
            """,
            (entity, timestamp)
        )
    conn.commit()


def fetch_with_retry(url: str, params: dict, max_retries: int = 5) -> dict:
    headers = {'X-API-Key': API_KEY}
    base_delay = 1

    for attempt in range(max_retries):
        try:
            resp = requests.get(url, headers=headers, params=params, timeout=30)

            if resp.status_code == 429:
                retry_after = int(resp.headers.get("Retry-After", base_delay * (2 ** attempt)))
                logger.warning(f"Rate limited. Sleeping {retry_after}s")
                time.sleep(retry_after)
                continue

            if resp.status_code in (500, 502, 503, 504):
                delay = base_delay * (2 ** attempt)
                logger.warning(f"Server error {resp.status_code}. Backoff {delay}s (attempt {attempt+1}/{max_retries})")
                time.sleep(delay)
                continue

            resp.raise_for_status()
            return resp.json()

        except requests.exceptions.Timeout:
            delay = base_delay * (2 ** attempt)
            logger.warning(f"Timeout. Backoff {delay}s")
            time.sleep(delay)

    raise Exception(f"Failed after {max_retries} attempts: {url}")


def extract_entity(conn, entity: str) -> List[Dict[str, Any]]:
    watermark = get_watermark(conn, entity) if entity in INCREMENTAL_ENTITIES else None
    params = {'limit': 100}

    if watermark:
        params['updated_after'] = watermark.isoformat()
        logger.info(f"Incremental extract: {entity} since {watermark}")
    else:
        logger.info(f"Full extract: {entity} (first run)")

    all_rows, cursor, page = [], None, 0

    while True:
        if cursor:
            params['cursor'] = cursor
        data = fetch_with_retry(f'{API_BASE}/{entity}', params)
        rows = data.get('data', [])
        all_rows.extend(rows)
        page += 1
        logger.info(f"{entity}: page {page}, {len(rows)} rows (total: {len(all_rows)})")

        if not data.get('has_more', False):
            break
        cursor = data.get('next_cursor')
        if not cursor:
            logger.warning(f"{entity}: has_more=true but no cursor. Stopping.")
            break

    logger.info(f"{entity}: extracted {len(all_rows)} total rows")
    return all_rows


def create_table_if_not_exists(conn, entity: str, columns: list):
    """Creates the table dynamically based on the first row's columns."""
    col_defs = []
    for col in columns:
        if col == 'id':
            col_defs.append(f'"{col}" TEXT PRIMARY KEY')
        else:
            col_defs.append(f'"{col}" TEXT')
    col_sql = ',\n    '.join(col_defs)
    sql = f"""
        CREATE TABLE IF NOT EXISTS raw.{entity} (
            {col_sql}
        )
    """
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()
    logger.info(f"{entity}: table ready")


def upsert_rows(conn, entity: str, rows: List[Dict[str, Any]]):
    """Idempotent upsert — running twice produces identical rows, no duplicates."""
    if not rows:
        return
    pk = ENTITY_PKS.get(entity, 'id')
    columns = list(rows[0].keys())

    # Create table if it doesn't exist yet
    create_table_if_not_exists(conn, entity, columns)

    update_cols = [c for c in columns if c != pk]
    set_clause = ', '.join([f'"{c}" = EXCLUDED."{c}"' for c in update_cols])
    col_list = ', '.join([f'"{c}"' for c in columns])

    insert_sql = f"""
        INSERT INTO raw.{entity} ({col_list})
        VALUES %s
        ON CONFLICT ("{pk}")
        DO UPDATE SET {set_clause}
    """
    values = [[row.get(col) for col in columns] for row in rows]
    with conn.cursor() as cur:
        execute_values(cur, insert_sql, values, page_size=500)
    conn.commit()
    logger.info(f"{entity}: upserted {len(rows)} rows")


def find_max_updated_at(rows):
    timestamps = []
    for row in rows:
        if row.get('updated_at'):
            try:
                ts = datetime.fromisoformat(row['updated_at'].replace('Z', '+00:00'))
                timestamps.append(ts)
            except (ValueError, AttributeError):
                pass
    return max(timestamps) if timestamps else None


def run_extraction(**context):
    conn = get_connection()
    try:
        for entity in ENTITY_PKS:
            rows = extract_entity(conn, entity)
            if rows:
                upsert_rows(conn, entity, rows)
                max_ts = find_max_updated_at(rows)
                if max_ts and entity in INCREMENTAL_ENTITIES:
                    set_watermark(conn, entity, max_ts)
            else:
                logger.info(f"{entity}: 0 new rows since watermark")
    finally:
        conn.close()


if __name__ == "__main__":
    run_extraction()