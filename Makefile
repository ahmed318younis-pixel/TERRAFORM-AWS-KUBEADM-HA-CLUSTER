.PHONY: init fmt validate plan apply destroy output

init:
	terraform init

fmt:
	terraform fmt -recursive

validate:
	terraform validate

plan:
	terraform plan -out=cluster.tfplan

apply:
	terraform apply cluster.tfplan

destroy:
	terraform destroy

output:
	terraform output
