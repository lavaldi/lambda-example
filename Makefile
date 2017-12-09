.DEFAULT_GOAL:= help

# General
OWNER = lavaldi
FUNCTION = example

# Deploy
ENV = dev
INFRA_BUCKET = infraestructura.indie
DEPLOY_REGION = us-east-1

# Result variables
LAMBDA_FUNCTION_NAME = $(OWNER)-$(ENV)-$(FUNCTION)
LAMBDA_FUNCTION_S3_KEY = build/lambda/$(OWNER)/$(ENV)/$(FUNCTION)/$(LAMBDA_FUNCTION_NAME).zip

lambda: ## Empaqueta la funcion lambda con sus dependencias en un archivo zip con el nombre de la funcion
	@echo "Building..."
	@rm -rf build
	@if [ ! -d build ] ; then mkdir build; fi
	@cp app/index.js build/index.js
	@cd build && zip -rq $(LAMBDA_FUNCTION_NAME).zip .
	@mv build/$(LAMBDA_FUNCTION_NAME).zip ./
upload-function: ## Sube la funcion lambda a s3 para desplegar posteriormente
	@make clean
	@make lambda
	aws s3 cp ./$(LAMBDA_FUNCTION_NAME).zip s3://$(INFRA_BUCKET)/$(LAMBDA_FUNCTION_S3_KEY)
	@make clean
update-function: ## Actualiza el codigo de la funcion lambda. Considere la variable ENV como entorno de despliegue y INFRA_BUCKET el bucket donde se encuentra la fuente de la funcion lambda
	@make upload-function
	aws lambda update-function-code \
	--function-name $(LAMBDA_FUNCTION_NAME) \
	--s3-bucket $(INFRA_BUCKET) \
	--s3-key $(LAMBDA_FUNCTION_S3_KEY) \
	--region $(DEPLOY_REGION)
update-stack: ## Despliega el stack de la funcion lambda en cloudformation tomando en cuenta el entorno y la region de despliegue. Considere la variable ENV como entorno de despliegue y INFRA_BUCKET el bucket donde se encuentra la fuente de la funcion lambda
	@make upload-function
	aws cloudformation deploy \
	--template-file ./cloudformation/sam_template.yml \
	--stack-name $(LAMBDA_FUNCTION_NAME) \
	--parameter-overrides \
		Env=$(ENV) \
		SourceFunctionBucket=$(INFRA_BUCKET) \
		SourceFunctionKey=$(LAMBDA_FUNCTION_S3_KEY) \
		Owner=$(OWNER) \
		FunctionName=$(FUNCTION) \
	--capabilities CAPABILITY_NAMED_IAM \
	--region $(DEPLOY_REGION)
clean: ## Elimina el zip de la funcion lambda generada
	@echo "Clean up package files"
	@if [ -f $(LAMBDA_FUNCTION_NAME).zip ]; then rm $(LAMBDA_FUNCTION_NAME).zip; fi
test-function: ## Actualiza el codigo de la funcion lambda. Considere la variable ENV como entorno de ejecucion
	@aws lambda invoke \
	--invocation-type RequestResponse \
	--function-name ${LAMBDA_FUNCTION_NAME} \
	--region $(DEPLOY_REGION) \
	--log-type Tail \
	--payload file://test.json \
	outputfile.txt | jq '.LogResult' -r | base64 --decode
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'
