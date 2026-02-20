resource "aws_cognito_user_pool" "prod" {
  count = var.cognito_manage_prod_existing ? 1 : 0

  name = var.cognito_prod_user_pool_name

  lifecycle {
    prevent_destroy = true
    # Existing prod pool should be imported first, then refined gradually.
    ignore_changes = all
  }
}

resource "aws_cognito_user_pool_client" "prod" {
  count = var.cognito_manage_prod_existing ? 1 : 0

  name         = var.cognito_prod_user_pool_client_name
  user_pool_id = aws_cognito_user_pool.prod[0].id

  lifecycle {
    prevent_destroy = true
    # Existing prod client should be imported first, then refined gradually.
    ignore_changes = all
  }
}

resource "aws_cognito_user_pool" "dev" {
  count = var.cognito_create_dev ? 1 : 0

  name = var.cognito_dev_user_pool_name

  auto_verified_attributes = ["email"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cognito_user_pool_client" "dev" {
  count = var.cognito_create_dev ? 1 : 0

  name            = var.cognito_dev_user_pool_client_name
  user_pool_id    = aws_cognito_user_pool.dev[0].id
  generate_secret = true

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  lifecycle {
    prevent_destroy = true
  }
}
