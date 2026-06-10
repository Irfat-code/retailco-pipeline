"""
dlt pipeline: moves data from Lake DB (raw schema) → Warehouse DB (raw schema)
Uses incremental loading - only moves new/updated rows
"""
import os
import dlt
from dlt.sources.sql_database import sql_database
from dlt.sources.incremental import Incremental
from dotenv import load_dotenv

load_dotenv()

INCREMENTAL_ENTITIES = [
    "customers",
    "products",
    "orders",
    "order_items",
    "payments",
    "inventory_movements",
]

FULL_ENTITIES = [
    "stores",
    "employees",
]


def run_dlt_pipeline(**context):
    pipeline = dlt.pipeline(
        pipeline_name="retailco_lake_to_warehouse",
        destination=dlt.destinations.postgres(
            f"postgresql://{os.environ['WH_USER']}:{os.environ['WH_PASSWORD']}"
            f"@{os.environ['WH_HOST']}:{os.environ['WH_PORT']}/{os.environ['WH_DB']}"
        ),
        dataset_name="raw",
    )

    source = sql_database(
        credentials=(
            f"postgresql://{os.environ['LAKE_USER']}:{os.environ['LAKE_PASSWORD']}"
            f"@{os.environ['LAKE_HOST']}:{os.environ['LAKE_PORT']}/{os.environ['LAKE_DB']}"
        ),
        schema="raw",
        table_names=INCREMENTAL_ENTITIES + FULL_ENTITIES,
    )

    # Incremental loading for entities that have updated_at
    for name in INCREMENTAL_ENTITIES:
        if name in source.resources:
            source.resources[name].apply_hints(
                write_disposition="merge",
                primary_key=["id"],
                incremental=Incremental("updated_at"),
            )

    # Full load for small reference tables
    for name in FULL_ENTITIES:
        if name in source.resources:
            source.resources[name].apply_hints(
                write_disposition="merge",
                primary_key=["id"],
            )

    load_info = pipeline.run(source)

    if load_info.has_failed_jobs:
        raise Exception(f"dlt pipeline had failed jobs: {load_info}")

    print(load_info)


if __name__ == "__main__":
    run_dlt_pipeline()