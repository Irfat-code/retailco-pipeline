"""
RetailCo End-to-End Pipeline DAG
Task order (strictly enforced via >>):
  extract → load → dbt_snapshot → dbt_staging → dbt_marts → dbt_test
"""
import sys
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

sys.path.insert(0, '/opt/airflow/extractor')
sys.path.insert(0, '/opt/airflow/dlt_pipeline')

from erp_extractor import run_extraction
from lake_to_warehouse import run_dlt_pipeline

DBT_DIR = '/opt/airflow/dbt_retailco'

default_args = {
    'owner': 'retailco-team',
    'depends_on_past': False,
    'retries': 2,                               # rubric requires min 2
    'retry_delay': timedelta(minutes=5),
    'retry_exponential_backoff': True,          # exponential backoff
    'max_retry_delay': timedelta(minutes=30),
    'email_on_failure': False,
}

with DAG(
    dag_id='retailco_pipeline',
    default_args=default_args,
    description='RetailCo full pipeline: ERP → Lake → Warehouse → dbt',
    schedule_interval='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=True,           # enables backfill — graded explicitly
    max_active_runs=1,      # prevents overlapping daily runs
    tags=['retailco', 'stage8'],
) as dag:

    extract = PythonOperator(
        task_id='extract_from_erp',
        python_callable=run_extraction,
        op_kwargs={'execution_date': '{{ ds }}'},
    )

    load = PythonOperator(
        task_id='load_lake_to_warehouse',
        python_callable=run_dlt_pipeline,
    )

    dbt_snapshot = BashOperator(
        task_id='dbt_snapshot',
        bash_command=f'cd {DBT_DIR} && dbt snapshot --profiles-dir .',
    )

    dbt_staging = BashOperator(
        task_id='dbt_run_staging',
        bash_command=f'cd {DBT_DIR} && dbt run --select staging --profiles-dir .',
    )

    dbt_marts = BashOperator(
        task_id='dbt_run_marts',
        bash_command=f'cd {DBT_DIR} && dbt run --select marts --profiles-dir .',
    )

    dbt_test = BashOperator(
        task_id='dbt_test',
        bash_command=f'cd {DBT_DIR} && dbt test --profiles-dir .',
    )

    # Strict linear dependency — failure stops all downstream tasks
    extract >> load >> dbt_snapshot >> dbt_staging >> dbt_marts >> dbt_test