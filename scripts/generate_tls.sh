#!/bin/bash
set -e
CDIR=`pwd`
echo $CDIR
cd $CDIR/configs/ca
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
cd $CDIR/configs/admin
cfssl gencert \
  -ca=../ca/ca.pem \
  -ca-key=../ca/ca-key.pem \
  -config=../ca/ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
cd $CDIR/configs/workers
for i in 0; do
  instance="worker-${i}"
  instance_hostname="ip-10-0-102-2${i}"
  cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance_hostname}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "PL",
      "L": "Poznan",
      "O": "system:nodes",
      "OU": "k8s workshow",
      "ST": "Wielkopolskie"
    }
  ]
}
EOF

  external_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
  internal_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PrivateIpAddress')

  cfssl gencert \
    -ca=../ca/ca.pem \
    -ca-key=../ca/ca-key.pem \
    -config=../ca/ca-config.json \
    -hostname=${instance_hostname},${external_ip},${internal_ip} \
    -profile=kubernetes \
    worker-${i}-csr.json | cfssljson -bare worker-${i}
done
cd $CDIR/configs/controllers
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "PL",
      "L": "Poznan",
      "O": "system:kube-controller-manager",
      "OU": "Netguru",
      "ST": "Wielkopolskie"
    }
  ]
}
EOF

cfssl gencert \
  -ca=../ca/ca.pem \
  -ca-key=../ca/ca-key.pem \
  -config=../ca/ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
cd $CDIR/configs/proxy
ls
cfssl gencert \
  -ca=../ca/ca.pem \
  -ca-key=../ca/ca-key.pem \
  -config=../ca/ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
cd $CDIR/configs/scheduler
cfssl gencert \
  -ca=../ca/ca.pem \
  -ca-key=../ca/ca-key.pem \
  -config=../ca/ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
cd $CDIR/configs/api-server
KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers --region=eu-central-1 \
  --names "k8s-workshops-loadbalancer" \
  --output text --query 'LoadBalancers[].DNSName')
cfssl gencert \
  -ca=../ca/ca.pem \
  -ca-key=../ca/ca-key.pem \
  -config=../ca/ca-config.json \
  -hostname=10.32.0.1,10.0.101.10,10.0.101.11,10.0.101.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
cd $CDIR/configs/service-account
cfssl gencert \
  -ca=../ca/ca.pem \
  -ca-key=../ca/ca-key.pem \
  -config=../ca/ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
cd $CDIR
for instance in worker-0; do
  external_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
  echo $external_ip

  scp -i ~/Downloads/mkajszczak-key.pem configs/ca/ca.pem configs/workers/${instance}-key.pem configs/workers/${instance}.pem ubuntu@${external_ip}:~/
done

for instance in controller-0 controller-1 controller-2; do
  external_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')

  scp -i ~/Downloads/mkajszczak-key.pem configs/ca/ca.pem configs/ca/ca-key.pem configs/api-server/kubernetes-key.pem configs/api-server/kubernetes.pem \
    configs/service-account/service-account-key.pem configs/service-account/service-account.pem ubuntu@${external_ip}:~/
done

for instance in worker-0; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=configs/ca/ca.pem \
    --embed-certs=true \
    --server=https://10.0.101.10:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=configs/workers/${instance}.pem \
    --client-key=configs/workers/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done
#
#
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=configs/ca/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=configs/proxy/kube-proxy.pem \
  --client-key=configs/proxy/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=configs/ca/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=configs/controllers/kube-controller-manager.pem \
  --client-key=configs/controllers/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=configs/ca/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=configs/scheduler/kube-scheduler.pem \
  --client-key=configs/scheduler/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=configs/ca/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=configs/admin/admin.pem \
  --client-key=configs/admin/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

for instance in worker-0; do
  external_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
  echo $external_ip

  scp -i ~/Downloads/mkajszczak-key.pem ${instance}.kubeconfig kube-proxy.kubeconfig ubuntu@${external_ip}:~/
done

for instance in controller-0 controller-1 controller-2; do
  external_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')

  scp -i ~/Downloads/mkajszczak-key.pem admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ubuntu@${external_ip}:~/
done


ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
#
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

for instance in controller-0 controller-1 controller-2; do
  external_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')

  scp -i ~/Downloads/mkajszczak-key.pem encryption-config.yaml ubuntu@${external_ip}:~/
done

for instance in controller-0 controller-1 controller-2; do
  external_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')

  scp -i ~/Downloads/mkajszczak-key.pem etcd-bootstrap.sh  ubuntu@${external_ip}:~/
  ssh -i ~/Downloads/mkajszczak-key.pem ubuntu@${external_ip} <<EOF
    bash etcd-bootstrap.sh ${instance}
EOF

done

for instance in controller-0 controller-1 controller-2; do
  external_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')

  scp -i ~/Downloads/mkajszczak-key.pem bootstrap_control.sh  ubuntu@${external_ip}:~/
  ssh -i ~/Downloads/mkajszczak-key.pem ubuntu@${external_ip} <<EOF
    bash bootstrap_control.sh
EOF

done


for instance in controller-0; do
  external_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')

  scp -i ~/Downloads/mkajszczak-key.pem rbac.sh  ubuntu@${external_ip}:~/
  ssh -i ~/Downloads/mkajszczak-key.pem ubuntu@${external_ip} <<EOF
    bash rbac.sh
EOF

done

for instance in worker-0; do
  external_ip=$(aws ec2 describe-instances --region=eu-central-1 \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
  echo $external_ip

  scp -i ~/Downloads/mkajszczak-key.pem worker.sh  ubuntu@${external_ip}:~/
  ssh -i ~/Downloads/mkajszczak-key.pem ubuntu@${external_ip} <<EOF
    bash worker.sh
EOF

done

