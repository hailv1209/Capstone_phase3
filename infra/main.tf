data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  effective_shipping_image_tag = trimspace(var.shipping_image_tag) != "" ? trimspace(var.shipping_image_tag) : "${var.demo_version}-shipping"
  effective_default_image_repository = var.bootstrap_from_seed_images ? var.seed_image_repository : aws_ecr_repository.techx_corp.repository_url
  effective_default_image_tag        = var.bootstrap_from_seed_images ? var.seed_image_tag : var.default_image_tag

  shipping_hotfix_script = trimspace(<<-EOT
import json
import os
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib import request

SHIPPING_PORT = int(os.environ.get("SHIPPING_PORT", "8080"))
QUOTE_ADDR = os.environ.get("QUOTE_ADDR", "http://quote:8080").rstrip("/")
NANOS_MULTIPLE = 10_000_000

def fallback_quote(item_count: int) -> float:
    return round(4.99 + max(item_count, 1) * 1.25, 2)

def request_quote(item_count: int) -> float:
    payload = json.dumps({"numberOfItems": item_count}).encode("utf-8")
    req = request.Request(
        f"{QUOTE_ADDR}/getquote",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with request.urlopen(req, timeout=5) as resp:
        body = resp.read().decode("utf-8").strip()
        return float(body)

def to_money(value: float) -> dict:
    dollars = int(value)
    cents = int(round((value - dollars) * 100))
    if cents == 100:
        dollars += 1
        cents = 0
    return {
        "currency_code": "USD",
        "units": dollars,
        "nanos": cents * NANOS_MULTIPLE,
    }

class Handler(BaseHTTPRequestHandler):
    def _json_response(self, status_code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self._json_response(400, {"error": "invalid json"})
            return

        if self.path == "/get-quote":
            items = payload.get("items", [])
            item_count = sum(int(item.get("quantity", 0)) for item in items)
            try:
                quote_value = request_quote(item_count)
                quote_source = "quote-service"
            except Exception:
                quote_value = fallback_quote(item_count)
                quote_source = "fallback"

            print(
                json.dumps(
                    {
                        "event": "shipping_quote_generated",
                        "item_count": item_count,
                        "quote_source": quote_source,
                        "quote_value": quote_value,
                    }
                ),
                flush=True,
            )
            self._json_response(200, {"cost_usd": to_money(quote_value)})
            return

        if self.path == "/ship-order":
            tracking_id = str(uuid.uuid4())
            print(
                json.dumps(
                    {
                        "event": "shipping_tracking_created",
                        "tracking_id": tracking_id,
                    }
                ),
                flush=True,
            )
            self._json_response(200, {"tracking_id": tracking_id})
            return

        self._json_response(404, {"error": "not found"})

    def do_GET(self) -> None:
        if self.path in ("/", "/healthz", "/readyz"):
            self._json_response(200, {"status": "ok"})
            return
        self._json_response(404, {"error": "not found"})

    def log_message(self, format: str, *args) -> None:
        print(
            json.dumps(
                {
                    "event": "shipping_http_access",
                    "client": self.address_string(),
                    "message": format % args,
                }
            ),
            flush=True,
        )

if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", SHIPPING_PORT), Handler)
    print(
        json.dumps(
            {
                "event": "shipping_hotfix_started",
                "port": SHIPPING_PORT,
                "quote_addr": QUOTE_ADDR,
            }
        ),
        flush=True,
    )
    server.serve_forever()
EOT
  )

  release_values = {
    default = {
      image = {
        repository = local.effective_default_image_repository
        tag        = local.effective_default_image_tag
        pullPolicy = "IfNotPresent"
      }
    }
    components = merge(
      {
        flagd = {
          command = [
            "/flagd-build",
            "start",
            "--port",
            "8013",
            "--ofrep-port",
            "8016",
            "--sources",
            jsonencode([
              {
                uri        = "https://122.248.223.194.sslip.io/flags.json"
                provider   = "http"
                authHeader = "Bearer ${var.flagd_sync_token}"
              }
            ]),
          ]
        }
        shipping = {
          imageOverride = {
            repository = aws_ecr_repository.techx_corp.repository_url
            tag        = local.effective_shipping_image_tag
            pullPolicy = "Always"
          }
        }
      },
      var.enable_shipping_hotfix ? {
        shipping = {
          imageOverride = {
            repository = "python"
            tag        = "3.12-slim-bookworm"
            pullPolicy = "IfNotPresent"
          }
          command = ["python", "/app/shipping.py"]
          mountedConfigMaps = [
            {
              name      = "shipping-hotfix"
              mountPath = "/app/shipping.py"
              subPath   = "shipping.py"
              data = {
                "shipping.py" = local.shipping_hotfix_script
              }
            }
          ]
          readinessProbe = {
            httpGet = {
              path = "/readyz"
              port = 8080
            }
            initialDelaySeconds = 2
            periodSeconds       = 5
          }
          livenessProbe = {
            httpGet = {
              path = "/healthz"
              port = 8080
            }
            initialDelaySeconds = 5
            periodSeconds       = 10
          }
          resources = {
            limits = {
              memory = "64Mi"
            }
          }
        }
      } : {}
    )
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.20"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  cluster_enabled_log_types                = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    (var.nodegroup_name) = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance_type]

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      disk_size = var.node_disk_size

      labels = {
        workload = "techx"
      }

      tags = {
        Name        = "${var.cluster_name}-${var.nodegroup_name}"
        Environment = lookup(var.tags, "Environment", "phase3")
        Team        = lookup(var.tags, "Team", "TF3")
        Project     = lookup(var.tags, "Project", "techx-corp")
      }
    }
  }

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

resource "aws_ecr_repository" "techx_corp" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = var.ecr_repository_name
  })
}

resource "local_file" "env_override" {
  filename = "${path.module}/../techx-corp-platform/.env.override"
  content = join("\n", [
    "# Generated by Terraform in infra/",
    "IMAGE_NAME=${aws_ecr_repository.techx_corp.repository_url}",
    "IMAGE_VERSION=${var.image_version}",
    "DEMO_VERSION=${var.demo_version}",
    "",
  ])
}

resource "kubernetes_namespace_v1" "techx" {
  metadata {
    name = var.namespace
  }

  depends_on = [module.eks]
}

resource "helm_release" "techx_corp" {
  count = var.deploy_release ? 1 : 0

  name              = var.release_name
  namespace         = kubernetes_namespace_v1.techx.metadata[0].name
  chart             = "${path.module}/../techx-corp-chart"
  dependency_update = false
  wait              = true
  timeout           = 1200

  values = [yamlencode(local.release_values)]

  depends_on = [
    module.eks,
    aws_ecr_repository.techx_corp,
    local_file.env_override,
    kubernetes_namespace_v1.techx,
  ]
}
