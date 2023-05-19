#!/bin/bash
/etc/eks/bootstrap.sh '${cluster_name}' \
--b64-cluster-ca '${cluster_ca_certificate}' \
--apiserver-endpoint '${cluster_endpoint}' \
--use-max-pods=true \
--container-runtime containerd \
--ip-family 'ipv4' \
--kubelet-extra-args '--max-pods=40 --node-labels=${karpenter_key}=${cluster_name},managed-by=karpenter'
# --kubelet-extra-args --node-labels=${karpenter_key}=${cluster_name},managed-by=karpenter
# --kubelet-extra-args '--node-labels=node.k8s.aws/capacity-type=spot'
# --register-with-taints=CriticalAddonsOnly=:NoSchedule'

sudo wget https://github.com/prometheus/node_exporter/releases/download/v${version_nodeexporter}/node_exporter-${version_nodeexporter}.linux-amd64.tar.gz --output-document=/tmp/node_exporter-amd64.tar.gz 
sudo mkdir -p /tmp/node_exporter && sudo tar xvf /tmp/node_exporter-amd64.tar.gz --directory=/tmp/node_exporter --strip-components=1
sudo cp /tmp/node_exporter/node_exporter /usr/local/bin/node_exporter
printf %s "[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
" | sudo tee /etc/systemd/system/${systemd_unit_name}.service
sudo systemctl daemon-reload; sudo systemctl enable ${systemd_unit_name}; sudo systemctl start ${systemd_unit_name}
# sudo yum install -y https://s3.region.amazonaws.com/amazon-ssm-region/latest/linux_amd64/amazon-ssm-agent.rpm
# sudo systemctl daemon-reload; sudo systemctl enable amazon-ssm-agent; sudo systemctl restart amazon-ssm-agent
sudo systemctl enable kubelet; sudo systemctl restart kubelet
# sudo systemctl enable kubelet; sudo systemctl start kubelet; systemctl status kubelet
