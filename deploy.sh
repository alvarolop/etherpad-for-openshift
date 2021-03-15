#!/bin/bash

set -e

PROJECT_NAME=etherpad

# Create OCP project
oc new-project $PROJECT_NAME --display-name "Shared Etherpad"

# Deploy PostgreSQL database
oc new-app --template=postgresql-persistent --param POSTGRESQL_USER=ether --param POSTGRESQL_PASSWORD=ether --param POSTGRESQL_DATABASE=etherpad --param POSTGRESQL_VERSION=10 --param VOLUME_CAPACITY=10Gi --labels=app=etherpad_db

echo -ne "\n\nWaiting for pods ready..."
while [[ $(oc get pods -l deploymentconfig=postgresql -n $PROJECT_NAME -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

# Deploy Etherpad 
oc process -f ./etherpad-template.yaml -p DB_TYPE=postgres -p DB_HOST=postgresql -p DB_PORT=5432 -p DB_DATABASE=etherpad -p DB_USER=ether -p DB_PASS=ether -p ETHERPAD_IMAGE=quay.io/wkulhanek/etherpad:1.8.4 -p ADMIN_PASSWORD=secret | oc apply -f -

echo -ne "\n\nWaiting for pods ready..."
while [[ $(oc get pods -l app=etherpad -n $PROJECT_NAME -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

# Clean project
oc delete pod etherpad-1-deploy postgresql-1-deploy

ETHERPAD_ROUTE=$(oc get routes -l app=etherpad -n $PROJECT_NAME --template='https://{{(index .items 0).spec.host }}/p/openshift')

echo -e "\nEtherpad available in this URL:"
echo -e " * URL: $ETHERPAD_ROUTE"