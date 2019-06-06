#!/bin/bash

NAMESPACE="${NAMESPACE:-federation-test}"
LOCATION="${LOCATION:-local}"
VERSION="${VERSION:-0.0.10}"

function setup-infrastructure () {

  ./scripts/create-cluster.sh
  
  ./scripts/install-kubefed.sh -n ${NAMESPACE} -d ${LOCATION} &

  retries=50
  until [[ $retries == 0 || $name == "federation-v2" ]]; do
    name=$(kubectl get federationconfig -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ $name != "federation-v2" ]]; then
        echo "Waiting for federationconfig to appear"
        sleep 1
        retries=$((retries - 1))
    fi
  done

  if [ $retries == 0 ]; then
    echo "Failed to retrieve FederationConfig resource"
    exit 1
  fi

  # ./scripts/download-binaries.sh
  
}

function enable-resources () {

echo "Performing join operation using kubefedctl"
kubefedctl join cluster1 --federation-namespace=${NAMESPACE} --host-cluster-context=cluster1 --host-cluster-name=cluster1 --cluster-context=cluster1 --add-to-registry

echo "Enable FederatedTypeconfigs"
kubefedctl enable namespaces --federation-namespace=${NAMESPACE}

kubefedctl enable configmaps --federation-namespace=${NAMESPACE}

echo "Creating test-configmap resource"

cat <<EOF | kubectl --namespace=federation-test apply -f -
apiVersion: types.federation.k8s.io/v1alpha1
kind: FederatedConfigMap
metadata:
  name: test-configmap
  namespace: ${NAMESPACE}
spec:
  template:
    data:
      key: value
  placement:
    clusterNames:
    - cluster1
EOF

# check for test-configmap name
retries=50
until [[ $retries == 0 || $name == "test-configmap" ]]; do
  name=$(kubectl get configmap -n ${NAMESPACE} -o jsonpath='{.items[1].metadata.name}' 2>/dev/null)
  if [[ $name != "test-configmap" ]]; then
      echo "Waiting for test-configmap to appear"
      sleep 1
      retries=$((retries - 1))
  fi
done

 if [ $retries == 0 ]; then
    echo "Failed to retrieve test-configmap resource"
    exit 1
 fi

 echo "Configmap resource is federated successfully"

}


echo "==========Setting up the infrastructure for kubefed operator============="
setup-infrastructure

echo "==========Enabling resources=============="
enable-resources

echo "==========Teardown the infrastructure======"
./scripts/teardown.sh

echo "Smoke testing is completed successfully"
