# Terraform AWS Wordpress Blog 

A repository storing code for a practice terraform script, intending to spin up a wordpress blog on the AWS platform. 

## How to use 

1. Clone repository 
2. Update providers-sample.tf with you AWS account details and update file name to providers.tf (ensure this remains in .gitignore and is not exposed online)
3. Run ```terraform init``` to initialise terraform in your environment 
4. Run ```terraform validate```
5. Run ```terraform plan```
6. Run ```terraform apply```, optionally add the flag ```--auto-approve``` to bypass manual terminal approval of application

If you wish to destroy all resources created with the script, run the ```terraform destroy``` command. 

## Features
* Unique VPC with an internet gateway 
* One public subnet connected to the internet gateway and one private back end subnet <del>connected one way to the internet through a NAT gateway</del> TODO
* Web server security group with SSH, HTTP, HTTPS, and SQL rules
* Database security group with SQL communication rules  
* <del>Backend RDS stored in private subnet</del> TODO
* <del>Public subnet containing x2 EC2 instances for load balancing a wordpress blog</del> TODO
