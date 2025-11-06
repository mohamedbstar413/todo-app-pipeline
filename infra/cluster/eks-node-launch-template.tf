resource "aws_launch_template" "todo_app_node_launch_template" {
  name = "todo_app_node_launch_template"

  key_name = "new-key"

  user_data = base64encode(<<-EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==BOUNDARY=="

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
/etc/eks/bootstrap.sh todo-app-cluster
mkdir -p /app-config
cat <<'CONF' > /app-config/nginx.conf
include /etc/nginx/modules-enabled/*.conf;
events { worker_connections 1024; }
http {
  server {
    listen 8080;
    location / { proxy_pass http://127.0.0.1:80; }
    location /api/ {
      proxy_pass http://back-service.back-ns.svc.cluster.local:8080;
      proxy_redirect off;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
  }
}
CONF
chmod 644 /app-config/nginx.conf

--==BOUNDARY==--
EOF
)
}
