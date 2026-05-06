#cloud-config
# creates a non-root admin user with sudo access and SSH key authentication
users:
  - name: ${admin_username}
    groups: sudo         # adds the user to the sudo group
    shell: /bin/bash
    sudo: ALL=(ALL:ALL) ALL  # allows running any command as any user without restrictions
    lock_passwd: false
    passwd: ${admin_password_hash}  # pre-hashed password used for local console access only (SSH password auth is disabled)
    ssh_authorized_keys:
%{ for key in ssh_authorized_keys ~}
      - ${key}
%{ endfor ~}
