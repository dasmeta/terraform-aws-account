# TODO: have some solution for list(any) types, as it is not descriptive and no validation, need more research for solution
variable "users" {
  type        = list(any)
  default     = []
  description = "List of users"
}

variable "buckets" {
  type        = list(any)
  default     = []
  description = "List of buckets"
}

variable "ecrs" {
  type        = list(string)
  default     = []
  description = "List of ECR repositories"
}
