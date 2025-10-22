resource "aws_launch_template" "todo_app_node_launch_template" {
  name = "todo_app_node_launch_template"

  key_name = "new-key"
  user_data = base64encode(<<-EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -ex

# Bootstrap EKS (REQUIRED - replace cluster_name with your actual cluster name)
/etc/eks/bootstrap.sh ${aws_eks_cluster.todo_cluster.name}

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -ex

# Your custom commands run AFTER EKS bootstrap
echo "Running custom setup"
yum install -y htop vim
# Add more commands here

# Install AWS CLI
yum install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Download config from S3
mkdir -p /app-config
aws s3 cp s3://${aws_s3_bucket.todo_front_nginx_config_s3.bucket}/config.conf /app-config/

# Any other setup
echo "Setup complete"

--==MYBOUNDARY==--
EOF
  )
}
