vpc-basic-init:
	cd vpc-basic && terraform init -backend-config=../backend.conf

vpc-basic-plan:
	cd vpc-basic && terraform plan

vpc-basic-apply:
	cd vpc-basic && terraform apply

vpc-basic-destroy:
	cd vpc-basic && terraform destroy


vpc-peering-init:
	cd vpc-peering && terraform init -backend-config=../backend.conf

vpc-peering-plan:
	cd vpc-peering && terraform plan

vpc-peering-apply:
	cd vpc-peering && terraform apply

vpc-peering-destroy:
	cd vpc-peering && terraform destroy


alb-ecs-fargate-next-init:
	(cd alb-ecs-fargate-next/next-app && npm install && npm run build) && \
	(cd alb-ecs-fargate-next/infra && npm install && npm run build) 

alb-ecs-fargate-next-plan:
	cd alb-ecs-fargate-next/infra && npm run cdk diff

alb-ecs-fargate-next-apply:
	cd alb-ecs-fargate-next/infra && npm run cdk deploy

alb-ecs-fargate-next-destroy:
	cd alb-ecs-fargate-next/infra && npm run cdk destroy

sqs-message-reprocessing-init:
	cd sqs-message-reprocessing && terraform init -backend-config=../backend.conf

sqs-message-reprocessing-plan:
	cd sqs-message-reprocessing && terraform plan

sqs-message-reprocessing-apply:
	cd sqs-message-reprocessing && terraform apply

sqs-message-reprocessing-destroy:
	cd sqs-message-reprocessing && terraform destroy


