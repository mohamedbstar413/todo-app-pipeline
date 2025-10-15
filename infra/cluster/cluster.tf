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