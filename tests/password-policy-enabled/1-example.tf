module "this" {
  source = "../../"

  password_policy = {
    enabled = true
  }

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }
}
