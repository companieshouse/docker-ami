source "amazon-ebs" "builder" {
  ami_name             = "${var.ami_name_prefix}-${var.version}"
  ami_users            = var.ami_account_ids
  communicator         = "ssh"
  instance_type        = var.aws_instance_type
  region               = var.aws_region
  ssh_private_key_file = var.ssh_private_key_file
  ssh_username         = var.ssh_username
  ssh_keypair_name     = "packer-builders-${var.aws_region}"
  iam_instance_profile = "packer-builders-${var.aws_region}"

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
    iops                  = var.root_volume_iops
    throughput            = var.root_volume_throughput
  }

  dynamic "launch_block_device_mappings" {
    for_each = var.swap_volume_size_gb > 0 ? [1] : []

    content {
      device_name           = var.swap_volume_device_node
      volume_size           = var.swap_volume_size_gb
      volume_type           = "gp3"
      delete_on_termination = true
      iops                  = var.swap_volume_iops
      throughput            = var.swap_volume_throughput
    }
  }

  security_group_filter {
    filters = {
      "group-name": "packer-builders-${var.aws_region}"
    }
  }

  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name =  "${var.aws_source_ami_filter_name}-${var.aws_source_ami_filter_version}"
      root-device-type = "ebs"
    }
    owners = ["${var.aws_source_ami_owner_id}"]
    most_recent = true
  }

  subnet_filter {
    filters = {
          "tag:Name": "${var.aws_subnet_filter_name}"
    }
    most_free = true
    random = false
  }

  tags = {
    Name    = "${var.ami_name_prefix}-${var.version}"
  }
}
