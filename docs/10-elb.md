# Network Elastic Load Balancer

This will create an *one* `LB` with **several** `listeners` and `target groups`. Each of target goups will use number of `EC2` instances which should be created previously `07-EC2`. And adding a `CNAME` record for this `LB` in `R53`.

Order of steps:
1. 02-Route53
2. 07-EC2 
3. 08-ACM_certificate 
4. 10-ELB 

## Variables

### aws_lb_target_group

**HTTP** - for create a target group on 80 port
**HTTPS** - frot create a target group on 443 port

### http_tcp_listeners
**HTTP** and **HTTPS** 

If you need an additional listener add by example variables `new_name` and create new resources `resource "aws_lb_target_group_attachment" "new_name"` where variable `target_group_arn = lookup(aws_lb_target_group.main["new_name"], "arn")` should be like this.

Im main.tf specify locals variable `domain_name` `vpc_id` `subnets` for VPC.
