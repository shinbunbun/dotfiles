/*
  OpenSearchインデックステンプレート設定

  logs-*パターンに一致するインデックスのテンプレートを定義。
  シャード/レプリカ設定、フィールドマッピングを管理する。
*/

resource "opensearch_composable_index_template" "logs" {
  name = "logs-template"
  body = jsonencode({
    index_patterns = ["logs-*"]
    template = {
      settings = {
        number_of_shards   = 1
        number_of_replicas = 0
        "index.refresh_interval" = "5s"
        "index.codec"            = "best_compression"
      }
      mappings = {
        properties = {
          "@timestamp" = { type = "date" }
          level = {
            type = "keyword"
            fields = { text = { type = "text" } }
          }
          message = {
            type = "text"
            fields = {
              keyword = {
                type         = "keyword"
                ignore_above = 256
              }
            }
          }
          host     = { type = "keyword" }
          service  = { type = "keyword" }
          unit     = { type = "keyword" }
          job      = { type = "keyword" }
          log_type = { type = "keyword" }
          method   = { type = "keyword" }
          status   = { type = "keyword" }
          trace_id = { type = "keyword" }
        }
      }
    }
  })
}
