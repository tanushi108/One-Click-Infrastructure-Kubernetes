terraform {
  backend "s3" {
    bucket       = "one-click-eks-tfstate-478815938749"
    key          = "One-Click-Infra/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}
