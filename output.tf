output "server-data" {
  value = [for vm in aws_instance.server[*] : {
    ip_address = vm.public_ip
    public_dns = vm.public_dns
  }]
  description = "The public IP and DNS of the servers"
}

output "instance-data" {
  value = [for vm in aws_instance.instance[*] : {
    ip_address = vm.public_ip
    public_dns = vm.public_dns
  }]
  description = "The public IP and DNS of the servers"
}

output "alb_dns_name" {
  value = aws_lb.my_alb.dns_name
}