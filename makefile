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



