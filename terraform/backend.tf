terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://543dffa83737c567c5540382a450f51b.r2.cloudflarestorage.com"
    }

    bucket = "terraform-state"
    key    = "dotfiles/terraform.tfstate"
    region = "us-east-1"

    use_path_style = true

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
