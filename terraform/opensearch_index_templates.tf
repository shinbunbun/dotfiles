/*
  OpenSearchインデックステンプレート設定

  logs-*パターンに一致するインデックスのテンプレートを定義。
  シャード/レプリカ設定、フィールドマッピングを管理する。
  ISMポリシーによるインデックスライフサイクル管理も定義。
*/

resource "opensearch_composable_index_template" "logs" {
  name = "logs-template"
  body = jsonencode({
    index_patterns = ["logs-*"]
    template = {
      settings = {
        number_of_shards         = 1
        number_of_replicas       = 0
        "index.refresh_interval" = "5s"
        "index.codec"            = "best_compression"
      }
      mappings = {
        properties = {
          "@timestamp" = { type = "date" }
          level = {
            type   = "keyword"
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

/*
  OpenSearch ISM（Index State Management）ポリシー

  logs-*インデックスのライフサイクルを自動管理する。
  Hot（通常運用）→ Warm（force merge + read-only）→ Close（ヒープ解放）の
  3段階で、シャード数を抑えつつ全期間のログをディスク上に保持する。
  closeされたインデックスは手動で_openすれば検索可能。
*/

resource "opensearch_ism_policy" "logs_lifecycle" {
  policy_id = "logs-lifecycle"
  body = jsonencode({
    policy = {
      description   = "Logs index lifecycle: hot -> warm (force merge) -> close"
      default_state = "hot"
      ism_template = [{
        index_patterns = ["logs-*"]
        priority       = 100
      }]
      states = [
        {
          name    = "hot"
          actions = []
          transitions = [{
            state_name = "warm"
            conditions = {
              min_index_age = "30d"
            }
          }]
        },
        {
          name = "warm"
          actions = [
            {
              force_merge = {
                max_num_segments = 1
              }
              retry = {
                backoff = "exponential"
                count   = 3
                delay   = "1m"
              }
            },
            {
              read_only = {}
              retry = {
                backoff = "exponential"
                count   = 3
                delay   = "1m"
              }
            }
          ]
          transitions = [{
            state_name = "close"
            conditions = {
              min_index_age = "60d"
            }
          }]
        },
        {
          name = "close"
          actions = [{
            close = {}
            retry = {
              backoff = "exponential"
              count   = 3
              delay   = "1m"
            }
          }]
          transitions = []
        }
      ]
    }
  })
}
