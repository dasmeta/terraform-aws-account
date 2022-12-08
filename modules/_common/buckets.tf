module "buckets" {
  source  = "dasmeta/modules/aws//modules/s3"
  version = "0.36.7"

  for_each = { for bucket in var.buckets : bucket.name => bucket }

  name                    = each.value.name
  acl                     = lookup(each.value, "acl", null)
  ignore_public_acls      = each.value.ignore_public_acls
  restrict_public_buckets = each.value.restrict_public_buckets
  block_public_acls       = each.value.block_public_acls
  block_public_policy     = each.value.block_public_policy
  versioning              = each.value.versioning
  website                 = lookup(each.value, "website", {})
  create_index_html       = lookup(each.value, "create_index_html", false)
  create_iam_user         = lookup(each.value, "create_iam_user", false)
  bucket_files            = lookup(each.value, "bucket_files", null)
}
