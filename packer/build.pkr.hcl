build {
  sources = [
    "source.amazon-ebs.builder",
  ]

  provisioner "ansible" {
    host_alias = "${var.ansible_host_alias}"
    playbook_file = "${var.playbook_file_path}"
    extra_arguments  = [
      "-e", "aws_region=${var.aws_region}",
      "-e", "nagios_api_key=${var.nagios_api_key}",
      "-e", "aws_s3_dev_resources_bucket=${var.aws_s3_dev_resources_bucket}",
      "-e", "swap_volume_device_node=${var.swap_volume_device_node}",
      "-e", "swap_volume_enabled=${var.swap_volume_size_gb > 0 ? true : false}"
    ]
  }
}
