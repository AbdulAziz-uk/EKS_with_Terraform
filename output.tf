output "cluster_id" {
  value = aws_eks_cluster.star.id
}

output "node_group_id" {
  value = aws_eks_node_group.star.id
}

output "vpc_id" {
  value = aws_vpc.star_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.star_subnet[*].id
}
