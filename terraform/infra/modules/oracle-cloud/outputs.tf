output "instance" {
  description = "Oracle Cloud compute instance"
  value = {
    (oci_core_instance.instance.display_name) = {
      ip       = oci_core_instance.instance.public_ip
      user     = "ubuntu"
      location = oci_core_instance.instance.region
      id       = oci_core_instance.instance.id
      provider = "oracle"
    }
  }
}
