"""
RetailCo End-to-End Pipeline DAG
Task order (strictly enforced via >>):
  extract → load → dbt_snapshot → dbt_staging → dbt_marts → dbt_test
"""
import sys
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.operators.bash_operator import BashOperator

DBT_DIR = '/opt/airflow/dbt_retailco'

default_args = {
    'owner': 'retailco-team',
    'depends_on_past': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'retry_exponential_backoff': True,
    'max_retry_delay': timedelta(minutes=30),
    'email_on_failure': False,
}


def run_extraction_task(**context):
    sys.path.insert(0, '/opt/airflow/extractor')
    try:
        from erp_extractor import run_extraction
        run_extraction(**context)
    except ImportError:
        pass


def run_dlt_task(**context):
    sys.path.insert(0, '/opt/airflow/dlt_pipeline')
    from lake_to_warehouse import run_dlt_pipeline
    run_dlt_pipeline(**context)


with DAG(
    dag_id='retailco_pipeline',
    default_args=default_args,
    description='RetailCo full pipeline: ERP → Lake → Warehouse → dbt',
    schedule_interval='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=True,
    max_active_runs=1,
    tags=['retailco', 'stage8'],
) as dag:

    extract = PythonOperator(
        task_id='extract_from_erp',
        python_callable=run_extraction_task,
        op_kwargs={'execution_date': '{{ ds }}'},
    )

    load = PythonOperator(
        task_id='load_lake_to_warehouse',
        python_callable=run_dlt_task,
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

    extract >> load >> dbt_snapshot >> dbt_staging >> dbt_marts >> dbt_test