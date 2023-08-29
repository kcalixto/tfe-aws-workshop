thanks [hopkinsth](https://github.com/hopkinsth) for providing these amazing classes about AWS with Terraform!

# Notes
`
docker build -t 447988592397.dkr.ecr.sa-east-1.amazonaws.com/internal-wasp-dev:1.0.0 -t 447988592397.dkr.ecr.sa-east-1.amazonaws.com/internal-wasp-dev:latest .
`

`
aws ecr get-login-password | docker login -u AWS --password-stdin 447988592397.dkr.ecr.sa-east-1.amazonaws.com
`

`
docker push 447988592397.dkr.ecr.sa-east-1.amazonaws.com/internal-wasp-dev:1.0.0 
`
`
docker push 447988592397.dkr.ecr.sa-east-1.amazonaws.com/internal-wasp-dev:latest 
`

you need to deploy first the vpc:
terraform apply -target=aws_vpc.my_vpc

to use in variable "vpc_id"
and then terraform apply