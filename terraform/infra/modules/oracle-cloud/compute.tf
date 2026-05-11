data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

data "oci_core_vcns" "vcn" {
  compartment_id = var.compartment_id
}

data "oci_core_subnets" "subnet" {
  compartment_id = var.compartment_id
  vcn_id         = data.oci_core_vcns.vcn.virtual_networks[0].id
}

resource "oci_core_instance" "instance" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name # AD-3
  display_name        = "oracle-vm"

  shape = "VM.Standard.E2.1.Micro"

  source_details {
    source_type             = "image"
    source_id               = var.image_id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = data.oci_core_subnets.subnet.subnets[0].id
    assign_public_ip = true
  }

  launch_options {
    network_type            = "PARAVIRTUALIZED"
    remote_data_volume_type = "PARAVIRTUALIZED"
    boot_volume_type        = "PARAVIRTUALIZED"
    firmware                = "UEFI_64"
  }

  metadata = {
    ssh_authorized_keys = join("\n", values(var.ssh_keys))
  }
}

# One day I'll be able to snatch one of these
# resource "oci_core_instance" "instance_arm" {
#   compartment_id      = var.compartment_id
#   availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name # AD-3
#   display_name        = "oracle-vm-arm"

#   shape = "VM.Standard.A1.Flex"

#   shape_config {
#     ocpus         = 4
#     memory_in_gbs = 24
#   }

#   source_details {
#     source_type             = "image"
#     source_id               = var.arm_image_id
#     boot_volume_size_in_gbs = 140
#   }

#   create_vnic_details {
#     subnet_id        = data.oci_core_subnets.subnet.subnets[0].id
#     assign_public_ip = true
#   }

#   launch_options {
#     network_type            = "PARAVIRTUALIZED"
#     remote_data_volume_type = "PARAVIRTUALIZED"
#     boot_volume_type        = "PARAVIRTUALIZED"
#     firmware                = "UEFI_64"
#   }

#   metadata = {
#     ssh_authorized_keys = join("\n", values(var.ssh_keys))
#   }
# }
