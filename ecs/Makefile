_:
	echo "target not specified: vpc or app"

vpc:
	terraform apply -target=aws_vpc.my_vpc -target=aws_subnet.public_subnet_1 -target=aws_subnet.public_subnet_2 -target=aws_internet_gateway.my_igw -target=aws_route_table.public_route_table -target=aws_route_table_association.public_subnet_1_association -target=aws_route_table_association.public_subnet_2_association -target=aws_subnet.private_subnet_1 -target=aws_vpc_endpoint.ecr_endpoint

app:
	terraform apply

destroy:
	terraform destroy

check-vars:
	@if [ -z "$(APP_NAME)" ]; then echo "APP_NAME is not set"; exit 1; fi
	@if [ -z "$(RELEASE)" ]; then echo "RELEASE is not set"; exit 1; fi

build-image: check-vars
	docker build -t 447988592397.dkr.ecr.sa-east-1.amazonaws.com/$(APP_NAME):$(RELEASE) -t 447988592397.dkr.ecr.sa-east-1.amazonaws.com/$(APP_NAME):latest .

deploy-image: check-vars
	docker push 447988592397.dkr.ecr.sa-east-1.amazonaws.com/$(APP_NAME):$(RELEASE)
	docker push 447988592397.dkr.ecr.sa-east-1.amazonaws.com/$(APP_NAME):latest

destroy-image: check-vars
	aws ecr batch-delete-image --repository-name $(APP_NAME) --image-ids imageTag=$(RELEASE)
	aws ecr batch-delete-image --repository-name $(APP_NAME) --image-ids imageTag=latest
