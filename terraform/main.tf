module "vpc" {
  source = "./modules/vpc"

  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
}
module "security_group" {
  source = "./modules/security-group"

  vpc_id = module.vpc.vpc_id
  my_ip  = var.my_ip
}
module "ec2" {
  source = "./modules/ec2"

  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.security_group.security_group_id
  key_name          = module.keypair.key_name
}
module "keypair" {
  source = "./modules/keypair"

  public_key = var.public_key
}