variable "bastion_key_name" {
  description = "SSH key pair name to attach to bastion host (optional). Leave empty to omit."
  type        = string
  default     = ""
}
variable "google_chat_general_webhook" {
  description = "Google Chat webhook URL for general logs"
  type        = string
  sensitive   = true
}

variable "google_chat_error_webhook" {
  description = "Google Chat webhook URL for error logs"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "baston_ami" {
  description = "AMI ID for the bastion host"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the project"
  type        = string
}

#firebase credentials
variable "firebase_api_key" {
  description = "Firebase API key"
  type        = string
}

variable "firebase_app_id" {
  description = "Firebase app ID"
  type        = string
}

variable "firebase_auth_domain" {
  description = "Firebase auth domain"
  type        = string
}

variable "firebase_measurement_id" {
  description = "Firebase measurement ID"
  type        = string
}

variable "firebase_messaging_sender_id" {
  description = "Firebase messaging sender ID"
  type        = string
}

variable "firebase_project_id" {
  description = "Firebase project ID"
  type        = string
}

variable "firebase_storage_bucket" {
  description = "Firebase storage bucket"
  type        = string
}
variable "firebase_vapid_key" {
  description = "Firebase VAPID key"
  type        = string
}

#google client id and client secret
variable "google_client_id" {
  description = "Google client ID"
  type        = string
}

#app url
variable "app_url" {
  description = "App URL"
  type        = string
}


#reverb key
variable "reverb_key" {
  description = "Reverb key"
  type        = string
}

#backend url
variable "backend_url" {
  description = "Backend URL"
  type        = string
}

#backend host
variable "backend_host" {
  description = "Backend host"
  type        = string
}


#repository url
variable "repository_url" {
  description = "Repository URL"
  type        = string
}

# front end domain name
variable "fe_domain" {
  description = "Front end domain name"
  type        = string
}

variable "desired_count" {
  description = "Desired count for the ECS service"
  type        = number
}
