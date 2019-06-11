#!/bin/bash

NAMESPACE="${NAMESPACE:-federation-test}"
LOCATION="${LOCATION:-local}"
VERSION="${VERSION:-0.0.10}"
IMAGE_NAME="${IMAGE_NAME:-"quay.io/anbhat/kubefed-operator:v0.1.0-rc2"}"
function setup-infrastructure () {

  ./scripts/create-cluster.sh
  
  ./scripts/install-kubefed.sh -n ${NAMESPACE} -d ${LOCATION} -i ${IMAGE_NAME} &

  sleep 120

  # ./scripts/download-binaries.sh
  
}

function enable-resources () {

echo "Performing join operation using kubefedctl"
kubefedctl join cluster1 --kubefed-namespace=${NAMESPACE} --host-cluster-context=cluster1 --host-cluster-name=cluster1 --cluster-context=cluster1

echo "Enable FederatedTypeconfigs"
kubefedctl enable namespaces --kubefed-namespace=${NAMESPACE}

kubefedctl enable configmaps --kubefed-namespace=${NAMESPACE}

kubectl create ns test-ns

cat <<EOF | kubectl --namespace=test-ns apply -f -
apiVersion: types.kubefed.k8s.io/v1beta1
kind: FederatedNamespace
metadata:
  name: test-ns
  namespace: test-ns
spec:
  template:
    data:
      key: value
  placement:
    clusters:
    - name: cluster1
EOF

cat <<EOF | kubectl --namespace=test-ns apply -f -
apiVersion: types.kubefed.k8s.io/v1beta1
kind: FederatedConfigMap
metadata:
  name: test-configmap
  namespace: test-ns
spec:
  template:
    data:
      key: value
  placement:
    clusters:
    - name: cluster1
EOF

sleep 40

# check for test-configmap name
if kubectl get configmap -n test-ns -o jsonpath="{.items[0].metadata.name}" | grep -q "test-configmap" ; then
   echo "Configmap resource is federated successfully"
else
   exit 1
fi

}


echo "==========Setting up the infrastructure for kubefed operator============="
setup-infrastructure

sleep 40

echo "==========Enabling resources=============="
enable-resources

echo "==========Teardown the infrastructure======"
./scripts/teardown.sh

echo "Smoke testing is completed successfully"
