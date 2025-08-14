#!/usr/bin/env python3
"""
Lokiからログを取得してClickHouseに転送するスクリプト
"""

import json
import requests
import clickhouse_driver
from datetime import datetime, timedelta
import sys
import os

# 環境変数から設定を取得
LOKI_URL = os.environ.get('LOKI_URL', 'http://localhost:3100')
CLICKHOUSE_HOST = os.environ.get('CLICKHOUSE_HOST', 'localhost')
CLICKHOUSE_PORT = int(os.environ.get('CLICKHOUSE_PORT', '9000'))

# ClickHouseクライアント
ch_client = clickhouse_driver.Client(
    host=CLICKHOUSE_HOST,
    port=CLICKHOUSE_PORT,
    database='logs'
)

# 過去5分のログを取得
end_time = datetime.now()
start_time = end_time - timedelta(minutes=5)

# Lokiクエリ
query = '{job=~".+"}'
params = {
    'query': query,
    'start': int(start_time.timestamp() * 1e9),
    'end': int(end_time.timestamp() * 1e9),
    'limit': 10000
}

try:
    # Lokiからログ取得
    response = requests.get(f"{LOKI_URL}/loki/api/v1/query_range", params=params)
    response.raise_for_status()
    
    data = response.json()
    
    if data['status'] != 'success':
        print(f"Loki query failed: {data}")
        sys.exit(1)
    
    # ログをパース
    logs_to_insert = []
    
    for stream in data['data']['result']:
        labels = stream['stream']
        
        for entry in stream['values']:
            timestamp_ns, log_line = entry
            timestamp = datetime.fromtimestamp(int(timestamp_ns) / 1e9)
            
            # ログラインをパース（JSON形式を想定）
            try:
                if log_line.strip().startswith('{'):
                    log_data = json.loads(log_line)
                else:
                    # 構造化されていないログ
                    log_data = {'message': log_line}
            except json.JSONDecodeError:
                log_data = {'message': log_line}
            
            # ClickHouse用のレコード作成
            record = {}
            record['ts'] = timestamp
            record['host'] = labels.get('host', 'unknown')
            record['service'] = labels.get('service', labels.get('job', 'unknown'))
            record['unit'] = labels.get('unit', '')
            record['level'] = labels.get('level', log_data.get('level', 'info'))
            record['path'] = log_data.get('path', '')
            record['status'] = int(log_data.get('status', 0))
            record['latency_ms'] = float(log_data.get('latency_ms', 0))
            record['trace_id'] = log_data.get('trace_id', '')
            record['message'] = log_data.get('message', log_line)
            record['attrs'] = json.dumps(log_data.get('attrs', {}))
            
            logs_to_insert.append(record)
    
    # ClickHouseに挿入
    if logs_to_insert:
        ch_client.execute(
            """
            INSERT INTO logs.app_logs 
            (ts, host, service, unit, level, path, status, 
             latency_ms, trace_id, message, attrs)
            VALUES
            """,
            logs_to_insert
        )
        print(f"Inserted {len(logs_to_insert)} log entries into ClickHouse")
    else:
        print("No logs to insert")
    
except Exception as e:
    print(f"Error importing logs: {e}")
    sys.exit(1)