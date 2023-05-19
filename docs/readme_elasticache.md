# ElastiCache

The main goal is to create a number of ElastiCache clusters with one node in each of them, create CNAME DNS records in the internal zone, and creates CloudWatch alarms for these clusters.

`Variables.tf`:

1. Specify elacticaches_clusters variables. A number of keys like `redis-001` mean a number of crating clusters. I.e. `redis-001` and `redis-002` will create two clusters.
2. Variables `subnet-0d627a9c07089d0af` might be different for each cluster. `us-east-1a` should be corresponded to subnet.
3. `maintenance_window` - if a cluster has one node, the time frame needs to choose carefully.
4. `notify_topic_arn` - change to what you need.

`03-main.tf`:

1. Variables `redis-001` in `loacals` should has the same name as keys in variable `elacticaches_clusters` (`Variables.tf`)
2. Resource `"aws_elasticache_subnet_group" "redis_subnet_group"` variable `name` needs to change.
3. DNS `resource "aws_route53_zone" "private"` variable `name` needs to change.
4. The resources `"aws_cloudwatch_metric_alarm"` creates several Cloudwatch alarms:
   1. The percentage of CPU utilization for the entire host.
   2. The amount of free memory available on the host.
   3. The number of bytes the host has read from the network.
   4. The number of bytes sent out
   5. SwapUsage
   6. Provides CPU utilization of the Redis engine thread.
   7. Percentage of the memory available for the cluster that is in use.
   8. CacheHitRate
   9. Latency of only the time consumed by Redis to process the operations.
   