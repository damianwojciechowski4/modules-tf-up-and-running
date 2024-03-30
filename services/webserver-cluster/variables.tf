variable "cluster_name" {
description = "The name to use for all the cluster resources"
type = string
}
variable "db_remote_state_bucket" {
description = "The name of the S3 bucket for the database's remote state"
type = string
}
variable "db_remote_state_key" {
description = "The path for the database's remote state in S3"
type = string
}

variable "instance_type" {
    type= string
    default = "t2.micro"
}

variable "max_size"{
    type = number
    default = 2
}
variable "min_size"{
    type = number
    default = 2
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------
variable "server_port" {
description = "The port the server will use for HTTP requests"
type = number
default = 8080
}