"""
dlt pipeline: moves data from Lake DB (raw schema) → Warehouse DB (raw schema)
write_disposition='merge' makes it idempotent — running twice won't duplicate rows
"""
import os
import dlt
from dlt.sources.sql_database import sql_database
from dotenv import load_dotenv

load_dotenv()

ENTITIES = [
    "customers",
    "products",
    "stores",
    "employees",
    "orders",
    "order_items",
    "payments",
    "inventory_movements",
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
        table_names=ENTITIES,
    )

    # merge = idempotent and incremental, never replaces everything
    for resource in source.resources.values():
        resource.apply_hints(
            write_disposition="merge",
            primary_key=["id"]
        )

    load_info = pipeline.run(source)

    if load_info.has_failed_jobs:
        raise Exception(f"dlt pipeline had failed jobs: {load_info}")

    print(load_info)


# Allows running directly for testing
if __name__ == "__main__":
    run_dlt_pipeline()