variable "flow" {
  type    = string
  default = "20-10"
}

variable "cloud_id" {
  type    = string
  default = "b1gd79b06d2cqh2lqig4"
}
variable "folder_id" {
  type    = string
  default = "b1gqjitlluulbdb85vi4"
}

variable "image_id" {
  type    = string
  default = "fd8fe32ig226dls6f9tj"
}

variable "test" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }
}
