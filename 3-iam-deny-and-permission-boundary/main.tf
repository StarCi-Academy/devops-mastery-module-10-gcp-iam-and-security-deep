# main.tf — GCP permission-boundary equivalent in two layers:
#
#   Layer 1 (HARD CEILING) google_iam_deny_policy
#     An explicit deny that beats every allow, attached to the PROJECT. Even if
#     a developer is later granted roles/owner, the denied permissions stay
#     blocked. This is the closest GCP analogue to an AWS Permissions Boundary,
#     except it is deny-based (subtractive) instead of an allow intersection.
#
#   Layer 2 (SCOPED ALLOW) google_project_iam_member + condition (CEL)
#     A normal allow binding whose IAM Condition narrows WHEN/WHERE the grant
#     applies — here, only when the request targets the lab region. This mirrors
#     an AWS condition key (aws:RequestedRegion) but uses Common Expression
#     Language evaluated by GCP's IAM engine.
#
# KEY GCP vs AWS differences surfaced by this file:
#   - project is the isolation unit (no cross-account ARNs); the deny policy
#     attaches to the URL-encoded project resource name.
#   - IAM is member + role BINDING, never "attach policy to a principal".
#   - deny principals use IAM v2 identifiers (principal:// / principalSet://),
#     NOT the v1 member format (user:/serviceAccount:) used by bindings.

locals {
  prefix = "starci-${var.student}"

  # IAM v2 principalSet that matches every identity in the project's identity
  # pool. The deny rule below denies a dangerous permission for ALL of them,
  # then carves out a single break-glass service account via exception.
  all_principals = "principalSet://goog/public:all"
}

# ---------------------------------------------------------------------------
# Break-glass service account: the ONLY identity exempted from the deny rule.
# In production this would be an audited, MFA-gated, on-call-only identity.
# ---------------------------------------------------------------------------
resource "google_service_account" "break_glass" {
  account_id   = "${local.prefix}-breakglass"
  display_name = "Break-glass SA exempted from the project deny policy"
  project      = var.project_id
}

# ---------------------------------------------------------------------------
# Layer 1 — Deny policy (the hard ceiling).
#
# google_iam_deny_policy arguments (Terraform Registry, hashicorp/google):
#   name    (Required) short id of the deny policy within the attachment point.
#   parent  (Required) URL-encoded full resource name of the attachment point.
#           urlencode() turns the "/" into "%2F" as IAM v2 requires.
#   rules   (Required) one or more rule blocks, each holding one deny_rule.
# ---------------------------------------------------------------------------
resource "google_iam_deny_policy" "project_ceiling" {
  name         = "${local.prefix}-deny-iam-escalation"
  display_name = "Block IAM self-escalation + SA key creation project-wide"

  # The attachment point is the PROJECT — the GCP isolation unit. IAM v2 wants
  # the URL-encoded full resource name, e.g.
  # cloudresourcemanager.googleapis.com%2Fprojects%2Fmy-project.
  parent = urlencode("cloudresourcemanager.googleapis.com/projects/${var.project_id}")

  rules {
    description = "Deny self-granting IAM + service-account key creation for everyone except break-glass."

    deny_rule {
      # WHO is denied. principalSet://goog/public:all = every identity that can
      # ever authenticate against this project.
      denied_principals = [local.all_principals]

      # WHO is carved out. The break-glass SA keeps the permissions even though
      # it is inside the denied set. principal:// is the IAM v2 single-identity
      # form for a service account.
      exception_principals = [
        "principal://iam.googleapis.com/projects/-/serviceAccounts/${google_service_account.break_glass.email}",
      ]

      # WHAT is denied. Format is {service-fqdn}/{resource}.{verb}. These two
      # are the classic privilege-escalation primitives:
      #   setIamPolicy — rewrite the project allow policy (grant yourself owner).
      #   serviceAccountKeys.create — mint a long-lived key to exfiltrate later.
      denied_permissions = [
        "cloudresourcemanager.googleapis.com/projects.setIamPolicy",
        "iam.googleapis.com/serviceAccountKeys.create",
      ]

      # WHEN the deny applies. CEL guard: only deny outside the lab region, so
      # in-region break-fix is allowed but cross-region tampering is blocked.
      # Omit this block to deny unconditionally.
      denial_condition {
        title       = "deny-outside-lab-region"
        description = "Deny the escalation permissions unless the request originates in the lab region."
        expression  = "!resource.matchTag('${var.project_id}/region', '${var.gcp_region}')"
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Layer 2 — Scoped allow binding (the conditional grant).
#
# google_project_iam_member arguments (Terraform Registry, hashicorp/google):
#   project   (Required) target project ID.
#   role      (Required) the role granted to exactly one member.
#   member    (Required) one identity in v1 member format.
#   condition (Optional) IAM Condition (CEL) narrowing the grant. A binding with
#             a condition is a DIFFERENT binding from the unconditioned one — the
#             title is part of the binding key.
#
# condition block: expression (Required), title (Required), description (Optional).
# ---------------------------------------------------------------------------
resource "google_project_iam_member" "developer_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = var.developer_member

  condition {
    title       = "only-lab-region"
    description = "Grant compute.viewer only when the targeted resource is tagged with the lab region."
    # CEL evaluated by GCP IAM. resource.matchTag checks a resource tag binding;
    # the grant simply does not apply to resources missing the lab-region tag.
    expression = "resource.matchTag('${var.project_id}/region', '${var.gcp_region}')"
  }
}
