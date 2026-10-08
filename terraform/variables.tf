variable "my_ip" {
  type        = string
  description = "Public IP address allowed to access SSH, Jenkins and Grafana"
  default     = "0.0.0.0/0"
}
# default     = "103.163.182.80/32"
