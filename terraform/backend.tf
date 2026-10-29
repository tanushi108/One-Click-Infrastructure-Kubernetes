terraform {
  backend "s3" {
    bucket       = "tanushi-eks-tfstate-2026"
    key          = "One-Click-Infra/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}