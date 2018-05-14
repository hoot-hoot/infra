#/bin/sh

kubectl get pods --show-all=true | grep Evicted | awk '{print $1}' | xargs kubectl delete pod
kubectl get pods --show-all=true --all-namespaces | grep Evicted | awk '{print $2}' | xargs kubectl --namespace="kube-system" delete pod
