/*
  OpenSearch Dashboardsオブジェクト設定

  Dashboardsで使用するインデックスパターンを定義。
*/

resource "opensearch_dashboard_object" "logs_index_pattern" {
  body = jsonencode([
    {
      _id     = "index-pattern:logs-*"
      _source = {
        type = "index-pattern"
        index-pattern = {
          title         = "logs-*"
          timeFieldName = "@timestamp"
        }
      }
    }
  ])
}
