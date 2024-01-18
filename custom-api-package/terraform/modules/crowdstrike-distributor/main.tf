data "archive_file" "linux" {
  type        = "zip"
  output_path = "package/linux.zip"
  source_dir  = "package/linux"
}

data "archive_file" "windows" {
  type        = "zip"
  output_path = "package/windows.zip"
  source_dir  = "package/windows"
}

data "template_file" "manifest_json" {
  template = file("package/manifest-json.tpl")
  vars     = {
    prefix         = var.aws_resources_prefix
    linux_sha256   = data.archive_file.linux.output_sha256
    windows_sha256 = data.archive_file.windows.output_sha256
  }
}

resource "aws_s3_object" "linux" {
  bucket = var.s3_bucket_name
  key    = "falcon/${var.aws_resources_prefix}-linux.zip"
  source = "package/linux.zip"

  # 2024.01 - AWS S3 doesn't have a way to specify sha256 etag, must use md5
  etag = filemd5("package/linux.zip")
}

resource "aws_s3_object" "windows" {
  bucket = var.s3_bucket_name
  key    = "falcon/${var.aws_resources_prefix}-windows.zip"
  source = "package/windows.zip"

  # 2024.01 - AWS S3 doesn't have a way to specify sha256 etag, must use md5
  etag = filemd5("package/windows.zip")
}

resource "aws_ssm_document" "distributor_package" {
  depends_on = [
    aws_s3_object.linux,
    aws_s3_object.windows,
  ]
  name          = "${var.aws_resources_prefix}-crowdstrike-falcon-installer"
  document_type = "Package"
  content       = data.template_file.manifest_json.rendered

  #    version_name = "$$LATEST"
  attachments_source {
    key    = "SourceUrl"
    values = ["s3://${var.s3_bucket_name}/falcon"]
  }
}

# generates the SSM document itself
resource "aws_ssm_document" "crowdstrike_falcon" {
  name            = "${var.aws_resources_prefix}-crowdstrike-falcon-install"
  document_type   = "Automation"
  document_format = "JSON"

  permissions = {
    type        = "Share"
    account_ids = join(",", var.share_with_account_ids)
  }

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Automation Document for installing Crowdstike's Falcon Sensor"
    assumeRole    = "{{AutomationAssumeRole}}"

    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        description = "(Required) The ARN of the role that allows Automation to perform the actions on your behalf. If no role is specified, Systems Manager Automation uses your IAM permissions to run this runbook."
        default     = ""
      }
      WindowsInstallParams = {
        type        = "String"
        description = "(Optional) Enter CrowdStrike's install time params for Windows nodes. For more info refer to the Falcon console documentation."
        default     = ""
      }
      LinuxInstallParams = {
        type        = "String"
        description = "(Optional) Enter CrowdStrike's install time params for Linux nodes. For more info refer to the Falcon console documentation."
        default     = ""
      }
      WindowsUninstallParams = {
        type        = "String"
        default     = ""
        description = "(Optional) Enter CrowdStrike's uninstall time params for Windows nodes. For more info refer to the Falcon console documentation."
      }
      LinuxUninstallParams = {
        type        = "String"
        default     = ""
        description = "(Optional) Enter CrowdStrike's uninstall time params for Linux nodes. For more info refer to the Falcon console documentation."
      }
      Action = {
        type          = "String"
        allowedValues = ["Install", "Uninstall"]
        description   = ""
        default       = "Install"
      }
      PackageName = {
        type        = "String"
        description = "(Required) The name of the distributor package to run."
        default     = aws_ssm_document.distributor_package.name
      }
      PackageVersion = {
        type        = "String"
        description = "(Required) The version of the distributor package to run. Default to n-1, which is the latest."
        default     = ""
      }
      SecretName = {
        type        = "String"
        description = "Secrets Manager Secret Name or ARN, that contains the Crowdstike Cloud API data"
        default     = ""
      }
      FalconCloud = {
        type        = "String"
        description = "SSM Parameter Store name that contains the Falcon Cloud URL for CrowdStrike APIs."
        default     = "/CrowdStrike/Falcon/Cloud"
      }
      FalconClientId = {
        type        = "String"
        description = "SSM Parameter Store name that contains the Falcon Client Id for CrowdStrike APIs."
        default     = "/CrowdStrike/Falcon/ClientId"
      }
      FalconClientSecret = {
        type        = "String"
        description = "SSM Parameter Store name that contains the Falcon Client Secret for CrowdStrike APIs."
        default     = "/CrowdStrike/Falcon/ClientSecret"
      }
      InstanceIds = {
        type = "StringList"
      }
      Targets = {
        type    = "MapList"
        default = []
      }
    }

    mainSteps = [
      # get_authentication_token
      {
        action = "aws:executeScript"
        name   = "GetAuthenticationToken"
        inputs = {
          Runtime      = "python3.8"
          Handler      = "script_handler"
          Script       = file("${path.module}/scripts/get_authentication_token.py")
          InputPayload = {
            SecretName         = "{{SecretName}}"
            FalconCloud        = "{{FalconCloud}}"
            FalconClientId     = "{{FalconClientId}}"
            FalconClientSecret = "{{FalconClientSecret}}"
            Region             = "{{global:REGION}}"
          }
        }
        outputs = [
          {
            Name     = "AuthToken"
            Selector = "$.Payload.AuthToken"
            Type     = "String"
          },
          {
            Name     = "FalconCloud"
            Selector = "$.Payload.ApiGatewayHost"
            Type     = "String"
          }
        ]
      },
      # get_customer_identifier
      {
        action = "aws:executeScript"
        name   = "GetCustomerIdentifier"
        inputs = {
          Runtime      = "python3.8"
          Handler      = "script_handler"
          Script       = file("${path.module}/scripts/get_customer_identifier.py")
          InputPayload = {
            AuthToken   = "{{GetAuthenticationToken.AuthToken}}"
            FalconCloud = "{{GetAuthenticationToken.FalconCloud}}"
          }
        }
        outputs = [
          {
            Name     = "CCID"
            Selector = "$.Payload.CCID"
            Type     = "String"
          }
        ]
      },
      # get_installation_token
      {
        action = "aws:executeScript"
        name   = "GetInstallationToken"
        inputs = {
          Runtime      = "python3.8"
          Handler      = "script_handler"
          Script       = file("${path.module}/scripts/get_installation_token.py")
          InputPayload = {
            AuthToken   = "{{GetAuthenticationToken.AuthToken}}"
            FalconCloud = "{{GetAuthenticationToken.FalconCloud}}"
          }
        }
        outputs = [
          {
            Name     = "InstallationToken"
            Selector = "$.Payload.InstallationToken"
            Type     = "String"
          }
        ]
      },
      # execute_distributor_package
      {
        action = "aws:runCommand"
        name   = "ExecuteDistributorPackage"
        inputs = {
          Targets      = "{{ Targets }}"
          InstanceIds  = "{{ InstanceIds }}"
          DocumentName = "AWS-ConfigureAWSPackage"
          Parameters   = {
            name                = "{{PackageName}}"
            action              = "{{Action}}"
            version             = "{{PackageVersion}}"
            additionalArguments = {
              SSM_INSTALLTOKEN          = "{{GetInstallationToken.InstallationToken}}"
              SSM_CID                   = "{{GetCustomerIdentifier.CCID}}"
              SSM_WIN_INSTALLPARAMS     = "{{WindowsInstallParams}}"
              SSM_LINUX_INSTALLPARAMS   = "{{LinuxInstallParams}}"
              SSM_WIN_UNINSTALLPARAMS   = "{{WindowsUninstallParams}}"
              SSM_LINUX_UNINSTALLPARAMS = "{{LinuxUninstallParams}}"
              SSM_AUTH_TOKEN            = "{{GetAuthenticationToken.AuthToken}}"
              SSM_HOST                  = "{{GetAuthenticationToken.FalconCloud}}"
            }
          }
        }
      }
    ]
  })
}