resource "aws_launch_template" "todo_app_node_launch_template" {
  name = "todo_app_node_launch_template"

  key_name = "new-key"
  user_data = base64encode(<<-EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="MIMEBOUNDARY"

--MIMEBOUNDARY
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -ex

# Initialize EKS node (AL2023 AMI uses nodeadm)
cat <<CONFIG >/etc/nodeadm.yaml
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${aws_eks_cluster.todo_cluster.name}
CONFIG

sudo nodeadm join --config /etc/nodeadm.yaml

echo "Running custom setup"

# Wait for network connection
until ping -c1 8.8.8.8 &>/dev/null ; do
  echo "Network not ready yet... retrying in 3s"
  sleep 3
done

yum install -y htop vim unzip -y

# Install AWS CLI if not installed
if ! command -v aws &>/dev/null; then
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -o awscliv2.zip
  ./aws/install || true
fi

# Download nginx config from S3
mkdir -p /app-config
aws s3 cp s3://${aws_s3_bucket.todo_front_nginx_config_s3.bucket}/nginx.conf /app-config/ || echo "S3 copy failed"

echo "Setup complete"

--MIMEBOUNDARY--
EOF
  )

}
