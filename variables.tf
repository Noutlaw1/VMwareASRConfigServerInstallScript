#These are passed via environment variables in the terraform apply -var <varname>=$variableName

variable "SUBID"  {
  type = string
}

variable "CLIENTID" {
  type = string
}

variable "CERTPATH" {
  type= string
}

variable "CERTPASS" {
  type = string
}

variable "TENANTID" {
  type = string
}

variable "DEFAULTUSER" {
  type = string
}

variable "DEFAULTPASSWORD" {
  type = string
}

variable "location" {
  type = "string"
  default = "eastus"
}
