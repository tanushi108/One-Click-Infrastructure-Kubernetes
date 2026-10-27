terraform {
  backend "s3" {
    bucket       = "tanushi-assignment4-tfstate-2026"
    key          = "assignment-4/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}