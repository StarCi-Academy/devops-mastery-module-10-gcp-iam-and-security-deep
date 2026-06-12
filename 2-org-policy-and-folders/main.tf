# main.tf — GCP Organization Policy + Resource Manager folder hierarchy.
# Builds: a lab FOLDER under the organization, a LIST-constraint org policy
# that forbids VM external IPs (compute.vmExternalIpAccess, denied via deny_all),
# a LIST-constraint org policy that restricts IAM member domains
# (iam.allowedPolicyMemberDomains), and a folder-level IAM BINDING granting a viewer.
#
# WHY a folder: org policies INHERIT downward through the Resource Manager
# hierarchy Organization -> Folder -> Project. Attaching the guardrail to the
# folder means every project created under it is governed automatically, and a
# folder policy may make the parent's policy STRICTER but never looser.
#
# GCP vs AWS, the load-bearing differences this lesson teaches:
#   - A GCP PROJECT is an isolated unit (its own resources, billing, IAM); an
#     AWS account is the rough equivalent but GCP adds folders between org and
#     project for finer guardrail scoping.
#   - GCP IAM is a member + role BINDING: you ADD a (member, role) pair to a
#     resource's policy; you never "attach" a standalone policy document to a
#     principal the way AWS attaches an SCP/IAM policy.
#   - Org Policy CONSTRAINTS are config guardrails (can this resource shape
#     exist at all), distinct from IAM (who may call which API).

# Read the organization so we can build the folder's parent string without
# hardcoding organizations/<id> in multiple places. organization is the numeric
# id; the data source exports name = "organizations/<id>".
data "google_organization" "org" {
  organization = var.org_id
}

# A folder directly under the organization. parent MUST be of the form
# organizations/{org_id} OR folders/{folder_id} — here the org. display_name
# must be unique amongst siblings and 1-30 chars. A folder must be EMPTY (no
# child projects/folders) before terraform destroy can delete it.
resource "google_folder" "lab" {
  display_name = var.folder_display_name
  parent       = data.google_organization.org.name
}

# LIST constraint: compute.vmExternalIpAccess. NOTE: despite the "on/off" feel
# of "no public VMs", GCP models this as a LIST constraint (its allow/deny list
# is VM instance resource names), NOT a boolean — so it takes a `values` /
# `deny_all` rule, never `enforce`. Using `enforce = "TRUE"` here makes the API
# reject the policy with 400 "Policy and Constraint must be of the same type".
# To forbid external IPs on EVERY VM under the folder we set `deny_all = "TRUE"`,
# which denies the whole list (all instances) — the classic "no public VMs"
# guardrail. deny_all is a STRING ("TRUE"/"FALSE"), not a bool.
resource "google_org_policy_policy" "restrict_external_ip" {
  name   = "${google_folder.lab.name}/policies/compute.vmExternalIpAccess"
  parent = google_folder.lab.name

  spec {
    rules {
      deny_all = "TRUE"
    }
  }
}

# LIST constraint: iam.allowedPolicyMemberDomains. List constraints carry an
# allowlist/denylist of values instead of a single on/off. Here allowed_values
# pins IAM membership to ONE Cloud Identity customer: any attempt to grant a
# role to a principal outside this domain is rejected under the folder.
# inherit_from_parent applies to LIST constraints only — false means this rule
# REPLACES (does not merge with) any inherited allowlist, giving a hard ceiling.
resource "google_org_policy_policy" "restrict_member_domains" {
  name   = "${google_folder.lab.name}/policies/iam.allowedPolicyMemberDomains"
  parent = google_folder.lab.name

  spec {
    inherit_from_parent = false

    rules {
      values {
        allowed_values = [var.allowed_member_domain]
      }
    }
  }
}

# Folder-level IAM BINDING. This is the GCP model: add ONE (member, role) pair
# to the folder's IAM policy. roles/resourcemanager.folderViewer lets the member
# see the folder + its projects without edit rights. Unlike AWS, there is no
# policy document to attach — the binding IS the grant, and it is additive
# (other bindings on the folder are untouched). This authorizes WHO can act;
# the org policies above govern WHAT resource shapes may exist.
resource "google_folder_iam_member" "viewer" {
  folder = google_folder.lab.name
  role   = "roles/resourcemanager.folderViewer"
  member = var.folder_viewer_member
}
