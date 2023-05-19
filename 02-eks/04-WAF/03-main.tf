locals {
  cluster_name               = data.terraform_remote_state.vpc.outputs.cluster-name
  random_pet                 = data.terraform_remote_state.vpc.outputs.random_pet
  acl_name                   = "eks-${local.cluster_name}"
  http_headers_name_to_block = "referer"
  http_headers_val_to_block  = ["header01", "header02"]
  ip_to_block                = ["149.5.244.149/32"]
  ip_never_block             = ["178.158.197.92/32"]
  ip_rate_limit_for_string   = "wp-login"
  ip_rate_limit_reqests_num  = 100
  country_codes_block        = ["AQ"]
  tags = {
    name        = "${local.cluster_name}-${local.random_pet}"
    environment = var.env
    managedby   = "Terraform"
  }
}

resource "aws_wafv2_regex_pattern_set" "http_headers" {
  name        = "HTTP_headers"
  description = "HTTP headers regex pattern set"
  scope       = "REGIONAL"
  tags        = local.tags

  dynamic "regular_expression" {
    for_each = local.http_headers_val_to_block
    content {
      regex_string = regular_expression.value
    }
  }
}

resource "aws_wafv2_ip_set" "toblock" {
  name               = "IP_set_to_block"
  description        = "Blocks IP set for block"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = local.ip_to_block
  tags               = merge(local.tags, { type = "block" }, )
}

resource "aws_wafv2_ip_set" "neverblock" {
  name               = "IP_set_allow"
  description        = "Blocks IP set which will never block"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = local.ip_never_block
  tags               = merge(local.tags, { type = "allow" }, )
}

resource "aws_wafv2_web_acl" "eks" {
  name        = local.acl_name
  description = "AWS managed rules set"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        excluded_rule {
          name = "SizeRestrictions_QUERYSTRING"
        }

        excluded_rule {
          name = "NoUserAgent_HEADER"
        }

        # scope_down_statement {
        #   geo_match_statement {
        #     country_codes = ["US", "NL"]
        #   }
        # }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "AWS-Common-rules-metric-name"
      sampled_requests_enabled   = false
    }
  }

  # rule {
  #   name     = "Managed_Rules_WordPress_Rule_Set"
  #   priority = 2

  #   override_action {
  #     count {}
  #   }

  #   statement {
  #     managed_rule_group_statement {
  #       name        = "AWSManagedRulesWordPressRuleSet"
  #       vendor_name = "AWS"

  #     }
  #   }
  #   visibility_config {
  #     cloudwatch_metrics_enabled = false
  #     metric_name                = "Managed-Rules-WordPress-Rule-Set-metric"
  #     sampled_requests_enabled   = false
  #   }
  # }

  rule {
    name     = "Managed_Rules_PHP_Rule_Set"
    priority = 3

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesPHPRuleSet"
        vendor_name = "AWS"

      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "Managed-Rules-PHP-Rule-Set-metric"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "Managed_Rules_SQLi_Rule_Set"
    priority = 4

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"

      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "Managed-Rules-SQLi-Rule-Set-metric"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "Managed_Rules_Linux_Rule_Set"
    priority = 6

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"

      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "Managed-Linux-Rule-Set-metric"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "IP_Rate_Based_Rule"
    priority = 7
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = local.ip_rate_limit_reqests_num
        aggregate_key_type = "IP"
        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "CONTAINS"
                search_string         = local.ip_rate_limit_for_string
                text_transformation {
                  priority = 1
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              not_statement {
                statement {

                  ip_set_reference_statement {
                    arn = aws_wafv2_ip_set.neverblock.arn
                  }
                }
              }
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "IP-Rate-Based-Rule-metric"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "IPs_and_HTTP_Header_Based_Rule"
    priority = 8

    action {
      block {}
    }

    statement {

      or_statement {
        statement {

          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.toblock.arn
          }
        }

        statement {

          regex_pattern_set_reference_statement {
            arn = aws_wafv2_regex_pattern_set.http_headers.arn

            field_to_match {
              single_header {
                name = local.http_headers_name_to_block
              }
            }

            text_transformation {
              priority = 2
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "IPs-and-HTTP-Header-Based-Rule-metric"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "Block_country"
    priority = 9

    action {
      block {}
    }

    statement {

      geo_match_statement {
        country_codes = local.country_codes_block
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "Block-country-name"
      sampled_requests_enabled   = false
    }
  }

  tags = local.tags

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "friendly-metric-name"
    sampled_requests_enabled   = false
  }
}
