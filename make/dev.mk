MINISHIFT_IP?=$(shell minishift ip)
MINISHIFT_HOSTNAME=minishift.local
MINISHIFT_HOSTNAME_REGEX='minishift\.local'
ETC_HOSTS=/etc/hosts
TIMESTAMP:=$(shell date +%s)
IMAGE_NAME_DEV?=${IMAGE_NAME}-$(TIMESTAMP)

# to watch all namespaces, keep namespace empty
APP_NAMESPACE ?= $(LOCAL_TEST_NAMESPACE)
LOCAL_TEST_NAMESPACE ?= "toolchain-host-operator"

.PHONY: login-as-admin
## Log in as system:admin
login-as-admin:
	$(Q)-echo "Logging using system:admin..."
	$(Q)-oc login -u system:admin

.PHONY: create-namespace
## Create the test namespace
create-namespace:
	$(Q)-echo "Creating Namespace"
	$(Q)-oc new-project $(LOCAL_TEST_NAMESPACE)
	$(Q)-echo "Switching to the namespace $(LOCAL_TEST_NAMESPACE)"
	$(Q)-oc project $(LOCAL_TEST_NAMESPACE)

.PHONY: use-namespace
## Log in as system:admin and enter the test namespace
use-namespace: login-as-admin
	$(Q)-echo "Using to the namespace $(LOCAL_TEST_NAMESPACE)"
	$(Q)-oc project $(LOCAL_TEST_NAMESPACE)

.PHONY: clean-namespace
## Delete the test namespace
clean-namespace:
	$(Q)-echo "Deleting Namespace"
	$(Q)-oc delete project $(LOCAL_TEST_NAMESPACE)

.PHONY: reset-namespace
## Delete an create the test namespace and deploy rbac there
reset-namespace: login-as-admin clean-namespace create-namespace deploy-rbac

.PHONY: deploy-rbac
## Setup service account and deploy RBAC
deploy-rbac:
	$(Q)-oc apply -f deploy/service_account.yaml
	$(Q)-oc apply -f deploy/role.yaml
	$(Q)-oc apply -f deploy/role_binding.yaml

.PHONY: deploy-dev
## Deploy Registration service on minishift
deploy-dev: login-as-admin create-namespace deploy-rbac build dev-image
	$(Q)-sed -e 's|REPLACE_IMAGE|${IMAGE_NAME_DEV}|g' ./deploy/deployment_dev.yaml  | oc apply -f -

.PHONY: update-etc-hosts
## Add minishift ip to /etc/hosts if needed
update-etc-hosts:
	echo $(MINISHIFT_IP) $(HMINISHIFT_HOSTNAME) $(ETC_HOSTS)
	if grep -q "$(MINISHIFT_IP) $(MINISHIFT_HOSTNAME)" $(ETC_HOSTS); then \
    	echo "Hosts entry exists"; \
	else \
    	echo "Updating /etc/hosts (Remove old minishift.local if any and add new one)"; \
    	# remove old entries with $(HOSTNAME) if any \
    	sudo sed -i "/$(MINISHIFT_HOSTNAME_REGEX)/d" $(ETC_HOSTS); \
    	# add new entry \
    	echo $(MINISHIFT_IP) $(MINISHIFT_HOSTNAME) | sudo tee --append $(ETC_HOSTS); \
	fi

.PHONY: dev-image
## Build the docker image locally that can be deployed to dev environment
dev-image: build
	$(Q)docker build -f build/Dockerfile -t quay.io/${GO_PACKAGE_ORG_NAME}/${GO_PACKAGE_REPO_NAME}:latest \
	 -t ${IMAGE_NAME_DEV} .
