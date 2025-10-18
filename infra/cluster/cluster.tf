resource "aws_eks_cluster" "todo_cluster" {
  name =                    "todo-app-cluster"
  role_arn =                data.aws_iam_role.cluster_role.arn
  vpc_config {
    subnet_ids = [ 
        var.subnet_1_id,
        var.subnet_2_id
     ]
  }
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  url             = aws_eks_cluster.todo_cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd4e4b5"]
}