#!/usr/bin/env python3
"""
ログ異常検知スクリプト

ClickHouseのログデータに対して異常検知を実行し、
異常スコアが高いイベントを記録します。

実行周期: 5分ごと
検知手法: Isolation Forest
"""

import json
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple

import clickhouse_driver
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler


class AnomalyDetector:
    """ClickHouseログの異常検知クラス"""
    
    def __init__(self, 
                 host: str = 'localhost',
                 port: int = 9000,
                 database: str = 'logs'):
        """
        Args:
            host: ClickHouseホスト
            port: ClickHouseネイティブポート
            database: 対象データベース
        """
        self.client = clickhouse_driver.Client(
            host=host,
            port=port,
            database=database
        )
        self.scaler = StandardScaler()
        
    def fetch_recent_metrics(self, 
                            window_minutes: int = 30) -> Tuple[np.ndarray, List[Dict]]:
        """
        直近のメトリクスを取得
        
        Args:
            window_minutes: 取得する時間窓（分）
            
        Returns:
            特徴量配列とメタデータのタプル
        """
        query = f"""
        SELECT
            minute,
            host,
            service,
            unit,
            cnt as request_count,
            err as error_count,
            s5xx as server_error_count,
            avg_latency,
            p95_latency,
            p99_latency,
            max_latency,
            IF(cnt > 0, err / cnt, 0) as error_rate,
            IF(cnt > 0, s5xx / cnt, 0) as server_error_rate
        FROM logs.app_logs_1min
        WHERE minute >= now() - INTERVAL {window_minutes} MINUTE
        ORDER BY minute DESC
        """
        
        result = self.client.execute(query)
        
        if not result:
            return np.array([]), []
        
        # メタデータとして保持
        metadata = []
        features = []
        
        for row in result:
            metadata.append({
                'minute': row[0],
                'host': row[1],
                'service': row[2],
                'unit': row[3]
            })
            
            # 特徴量: カウント系、レイテンシ系、エラー率
            features.append([
                row[4],   # request_count
                row[5],   # error_count
                row[6],   # server_error_count
                row[7],   # avg_latency
                row[8],   # p95_latency
                row[9],   # p99_latency
                row[10],  # max_latency
                row[11],  # error_rate
                row[12]   # server_error_rate
            ])
        
        return np.array(features), metadata
    
    def detect_anomalies(self, 
                         features: np.ndarray,
                         contamination: float = 0.05) -> np.ndarray:
        """
        Isolation Forestで異常検知
        
        Args:
            features: 特徴量配列
            contamination: 異常とみなす割合
            
        Returns:
            異常スコア配列（-1から1、低いほど異常）
        """
        if len(features) < 10:
            # データが少なすぎる場合はスキップ
            return np.array([])
        
        # 欠損値を0で埋める
        features = np.nan_to_num(features, nan=0.0)
        
        # 標準化
        features_scaled = self.scaler.fit_transform(features)
        
        # Isolation Forest
        iso_forest = IsolationForest(
            contamination=contamination,
            random_state=42,
            n_estimators=100
        )
        
        # 予測（-1: 異常, 1: 正常）
        predictions = iso_forest.fit_predict(features_scaled)
        
        # 異常スコア（低いほど異常）
        scores = iso_forest.score_samples(features_scaled)
        
        return scores
    
    def save_anomalies(self, 
                       scores: np.ndarray, 
                       metadata: List[Dict],
                       threshold: float = -0.5):
        """
        異常スコアが閾値を下回るものをDBに保存
        
        Args:
            scores: 異常スコア配列
            metadata: メタデータリスト
            threshold: 異常判定閾値
        """
        anomalies = []
        detected_at = datetime.now()
        
        for score, meta in zip(scores, metadata):
            if score < threshold:
                anomalies.append({
                    'detected_at': detected_at,
                    'window_start': meta['minute'],
                    'window_end': meta['minute'] + timedelta(minutes=1),
                    'host': meta['host'],
                    'service': meta['service'],
                    'anomaly_type': 'statistical',
                    'score': float(score),
                    'details': json.dumps({
                        'unit': meta['unit'],
                        'method': 'isolation_forest',
                        'threshold': threshold
                    })
                })
        
        if anomalies:
            # ClickHouseに挿入
            insert_query = """
            INSERT INTO logs.anomalies 
            (detected_at, window_start, window_end, host, service, 
             anomaly_type, score, details)
            VALUES
            """
            
            self.client.execute(insert_query, anomalies)
            print(f"Saved {len(anomalies)} anomalies to database")
    
    def run(self):
        """メイン実行処理"""
        try:
            print(f"Starting anomaly detection at {datetime.now()}")
            
            # 過去30分のデータを取得
            features, metadata = self.fetch_recent_metrics(window_minutes=30)
            
            if len(features) == 0:
                print("No data to analyze")
                return
            
            print(f"Analyzing {len(features)} data points")
            
            # 異常検知実行
            scores = self.detect_anomalies(features)
            
            # 結果を保存
            self.save_anomalies(scores, metadata)
            
            # 統計情報を出力
            if len(scores) > 0:
                print(f"Score statistics:")
                print(f"  Min: {scores.min():.3f}")
                print(f"  Max: {scores.max():.3f}")
                print(f"  Mean: {scores.mean():.3f}")
                print(f"  Std: {scores.std():.3f}")
            
            print("Anomaly detection completed successfully")
            
        except Exception as e:
            print(f"Error during anomaly detection: {e}", file=sys.stderr)
            sys.exit(1)


def main():
    """エントリーポイント"""
    detector = AnomalyDetector()
    detector.run()


if __name__ == "__main__":
    main()