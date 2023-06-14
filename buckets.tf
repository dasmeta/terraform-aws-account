module "buckets" {
  source  = "dasmeta/modules/aws//modules/s3"
  version = "2.3.0"

  for_each = { for bucket in var.buckets : bucket.name => bucket }

  name                    = each.value.name
  acl                     = each.value.acl
  ignore_public_acls      = each.value.ignore_public_acls
  restrict_public_buckets = each.value.restrict_public_buckets
  block_public_acls       = each.value.block_public_acls
  block_public_policy     = each.value.block_public_policy
  versioning              = each.value.versioning
  website                 = each.value.website
  create_index_html       = each.value.create_index_html
  create_iam_user         = each.value.create_iam_user
  bucket_files            = each.value.bucket_files
}
