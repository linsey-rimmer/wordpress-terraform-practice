## ensure this providers.tf file remains in your git ignore

provider "aws" {
  region = "us-east-1"
  access_key = "access_key_here"
  secret_key = "secret_key_here"
  token = "session_token_here_if_using_temp_credentials"
}
