#cloud-config

---
coreos:
  update:
    reboot-strategy: etcd-lock

  units:
    - name: format-ephemeral.service
      command: start
      content: |
        [Unit]
        Description=Formats the ephemeral drive
        After=dev-xvdb.device
        Requires=dev-xvdb.device
        ConditionPathExists=!/home/core/.bootstrapped
        [Service]
        ExecStart=/usr/sbin/wipefs -f /dev/xvdb
        ExecStart=/usr/sbin/mkfs.ext4 -F /dev/xvdb
        RemainAfterExit=yes
        Type=oneshot
    - name: var-lib-docker.mount
      command: start
      content: |
        [Unit]
        Description=Mount ephemeral to /var/lib/docker
        Requires=format-ephemeral.service
        After=format-ephemeral.service
        Before=docker.service
        [Mount]
        What=/dev/xvdb
        Where=/var/lib/docker
        Type=ext4
    - name: bootstrap-ansible.service
      command: start
      content: |
        [Unit]
        After=network-online.target
        Description=Bootstrap Ansible
        Requires=network-online.target
        ConditionPathExists=!/home/core/.bootstrapped
        [Service]
        ExecStart=/home/core/bootstrap-ansible.sh
        RemainAfterExit=yes
        Type=oneshot
        User=core

write-files:
  - path: /etc/kubernetes/ssl/ca.pem
    permissions: "0644"
    content: |
      ${CA}
  - path: /etc/kubernetes/ssl/worker-key.pem
    permissions: "0600"
    content: |
      ${CERTIFICATE_KEY}
  - path: /etc/kubernetes/ssl/worker.pem
    permissions: "0644"
    content: |
      ${CERTIFICATE}
  - path: /etc/kubernetes/ssl/proxy-key.pem
    permission: "0600"
    content: |
      ${PROXY_KEY}
  - path: /etc/kubernetes/ssl/proxy.pem
    permission: "0644"
    content: |
      ${PROXY_CERT}
  - path: /etc/ansible/facts.d/k8s_facts.fact
    permissions: "0755"
    content: |
      #!/bin/bash

      cat <<EOF
      {
        "cluster_name" : "${CLUSTER_NAME}",
        "etcd_elb" : "${ETCD_ELB}",
        "etcd_servers" : ${ETCD_SERVERS},
        "api_elb" : "${API_ELB}"
      }
      EOF
  - path: /home/core/bootstrap-ansible.sh
    permissions: "0755"
    owner: "core"
    content: |
      #!/bin/bash

      set -e
      set -x

      PKG_HOME="/home/core"
      PYPY_HOME="/home/core/pypy"
      PYPY_INSTALL="/home/core/.pypy"
      PYPY_SHA256="73014c3840609a62c0984b9c383652097f0a8c52fb74dd9de70d9df2a9a743ff"
      PYPY_VERSION="5.3.1"
      PYPY_FLAVOR="linux_x86_64-portable"

      # do this first so we don't reformat docker directory
      touch $PKG_HOME/.bootstrapped

      cd /tmp

      FILENAME="pypy-$PYPY_VERSION-$PYPY_FLAVOR.tar.bz2"
      curl --retry 5 -L -o "$FILENAME" "https://bitbucket.org/squeaky/portable-pypy/downloads/$FILENAME"

      if [[ -n "$PYPY_SHA256" ]]; then
        echo "$PYPY_SHA256  $FILENAME" > "$FILENAME.sha256"
        sha256sum -c "$FILENAME.sha256"
      fi

      tar -xjf "$FILENAME"
      rm -f "$FILENAME"

      mkdir -p "$PYPY_INSTALL"
      rm -rf "$PYPY_INSTALL"
      mv -n "pypy-$PYPY_VERSION-$PYPY_FLAVOR" "$PYPY_INSTALL"

      # make sure PATH contains the location where pip, wheel and friends are
      # so that ansible knows where to find them
      # this is needed since ansible 2.1 changed the way ansible_python_interpreter
      # is parsed
      cat <<EOF > "$PYPY_INSTALL/site-packages/sitecustomize.py"
      import os
      import sys
      os.environ["PATH"] += os.pathsep + os.path.sep.join([sys.prefix, "bin"])
      EOF

      #mkdir -p `dirname "$PYPY_HOME"`
      rm -rf "$PYPY_HOME"

      "$PYPY_INSTALL/bin/pypy" "$PYPY_INSTALL/bin/virtualenv-pypy" --system-site-packages "$PYPY_HOME"

      mkdir -p "$PKG_HOME/bin"

      ln -sf "$PYPY_HOME/bin/python" "$PKG_HOME/bin/python"
      ln -sf "$PYPY_HOME/bin/pip" "$PKG_HOME/bin/pip"
      ln -sf "$PYPY_HOME/bin/wheel" "$PKG_HOME/bin/wheel"

      PYPY_SSL_PATH=`$PYPY_INSTALL/bin/pypy -c 'from __future__ import print_function; import ssl; print(ssl.get_default_verify_paths().openssl_capath)'`

      sudo mkdir -p `dirname $PYPY_SSL_PATH`
      sudo ln -sf $COREOS_SSL_CERTS $PYPY_SSL_PATH

      # install needed modules
      $PYPY_HOME/bin/pip install docker-py
      $PYPY_HOME/bin/pip install boto
