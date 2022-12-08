variable "users" {
  type        = list(any)
  default     = []
  description = "List of account level create users, to create environment/product level users please use corresponding terraform setups"
}

variable "ecrs" {
  type        = list(string)
  default     = []
  description = "List of ecrs"
}

variable "buckets" {
  type        = list(any)
  default     = []
  description = "List of account level buckets, to create environment/product level buckets please use corresponding terraform setups"
}

variable "create_cloudwatch_log_role" {
  type        = bool
  default     = false
  description = "This is an account level configuration which creates IAM role with policy allowing cloudwatch sync/push logs into cloudwatch"
}
