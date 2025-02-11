resource "rke_cluster" "cluster" {
  cluster_name = "${var.prefix}-cluster"

  dynamic nodes {
    for_each = openstack_compute_floatingip_associate_v2.master-fip-assoc
    content {
      address = nodes.value.floating_ip
      user = "ubuntu"
      role = ["etcd","controlplane"]
    }
  }

  dynamic nodes {
    for_each = openstack_compute_floatingip_associate_v2.worker-fip-assoc
    content {
      address = nodes.value.floating_ip
      user = "ubuntu"
      role = ["worker"]
    }
  }

  ssh_key_path = var.ssh_key

  # Disable port check validation between nodes
  disable_port_check = false

  addons_include = [
    "https://raw.githubusercontent.com/kubernetes/dashboard/v${var.k8s_dashboard_version}/aio/deploy/recommended.yaml",
    "https://gist.githubusercontent.com/superseb/499f2caa2637c404af41cfb7e5f4a938/raw/930841ac00653fdff8beca61dab9a20bb8983782/k8s-dashboard-user.yml",
  ]

  # Initialize Helm (Install Tiller)
  addons = file("./files/tiller.yml")

  depends_on = [null_resource.wait-for-docker]
}

provider "kubernetes" {
  host     = rke_cluster.cluster.api_server_url
  username = rke_cluster.cluster.kube_admin_user

  client_certificate     = rke_cluster.cluster.client_cert
  client_key             = rke_cluster.cluster.client_key
  cluster_ca_certificate = rke_cluster.cluster.ca_crt
  # load_config_file = false
}

resource "kubernetes_namespace" "rancher-sdo" {
  metadata {
    name = "terraform-rancher-sdo-namespace"
  }
}
resource "null_resource" "wait-for-docker" {
  provisioner "local-exec" {
    command = "sleep 180"
  }
  depends_on = [openstack_compute_floatingip_associate_v2.worker-fip-assoc, openstack_compute_floatingip_associate_v2.master-fip-assoc]
}
