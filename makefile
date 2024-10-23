vpc-basic-init:
	cd vpc-basic && terraform init -backend-config=../backend.conf

vpc-basic-plan:
	cd vpc-basic && terraform plan

vpc-basic-apply:
	cd vpc-basic && terraform apply

vpc-basic-destroy:
	cd vpc-basic && terraform destroy

