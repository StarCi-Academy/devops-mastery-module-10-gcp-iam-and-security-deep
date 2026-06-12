# variables.tf — typed inputs that parameterise the Org Policy + folder lab.
# No secrets here; credentials come from the Google default chain.

# The project the provider uses for quota + endpoint. Org/folder/policy are
# org-level, but the provider still needs a project. Any other lab project works.
variable "project_id" {
  description = "GCP project id the provider uses for quota and the API endpoint. Org/folder/policy are org-level; this is only the billing/quota project."
  type        = string
}

# Default region for the provider endpoint. Org Policy itself is global, but the
# provider block requires a region for resources that have one.
variable "region" {
  description = "Default GCP region for the provider endpoint (org policy is global, but the provider needs a region)."
  type        = string
  default     = "us-central1"
}

# The organization the folder hangs under. The org policies in this lab are
# attached to the FOLDER (folders/{id}), but the folder itself needs an org or
# parent-folder parent of the form organizations/{org_id} or folders/{id}.
variable "org_id" {
  description = "Numeric GCP organization id (digits only) the lab folder is created under. The folder's parent becomes organizations/<org_id>."
  type        = string

  validation {
    # GCP organization ids are pure digits (e.g. 123456789012). Reject any slug
    # or organizations/ prefix here — we add the prefix ourselves.
    condition     = can(regex("^[0-9]+$", var.org_id))
    error_message = "org_id must be the numeric organization id (digits only), e.g. 123456789012 — without the organizations/ prefix."
  }
}

# Display name of the lab folder. Resource Manager requires it unique amongst
# siblings, 1-30 chars, starting and ending with a letter or digit.
variable "folder_display_name" {
  description = "Display name of the lab folder (1-30 chars, unique amongst siblings). The org policies attach to this folder."
  type        = string
  default     = "academy-org-policy-lab"

  validation {
    condition     = can(regex("^[A-Za-z0-9].{0,28}[A-Za-z0-9]$", var.folder_display_name))
    error_message = "folder_display_name must be 1-30 chars and start/end with a letter or digit (Resource Manager rule)."
  }
}

# The single domain the LIST-constraint allowlist permits as IAM members. Any
# principal from another domain is rejected org-wide by the guardrail. Feeds the
# allowed_values of iam.allowedPolicyMemberDomains.
variable "allowed_member_domain" {
  description = "The Cloud Identity customer id (directoryCustomerId, looks like C0xxxxxxx) the allowedPolicyMemberDomains list constraint permits. Members outside it are denied."
  type        = string
  default     = "C00000000"

  validation {
    # allowedPolicyMemberDomains takes the directory customer id, not the raw
    # domain string — it looks like C0abc1234.
    condition     = can(regex("^C[0-9a-zA-Z]{8}$", var.allowed_member_domain))
    error_message = "allowed_member_domain must be a Cloud Identity directory customer id like C0abc1234 (the value allowedPolicyMemberDomains expects)."
  }
}

# The principal that gets folder-level viewer on the lab folder. Demonstrates
# GCP's member+role BINDING model (no policy-document attach like AWS).
variable "folder_viewer_member" {
  description = "IAM member granted roles/resourcemanager.folderViewer on the lab folder, in member syntax e.g. user:alice@example.com or group:team@example.com."
  type        = string
  default     = "group:gcp-org-viewers@example.com"

  validation {
    condition     = can(regex("^(user|group|serviceAccount|domain):", var.folder_viewer_member))
    error_message = "folder_viewer_member must use member syntax: user:, group:, serviceAccount:, or domain: prefix."
  }
}
