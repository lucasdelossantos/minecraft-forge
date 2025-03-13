variable "mods" {
  description = "List of mods to install on the server"
  type = list(object({
    name        = string
    url         = string
    version     = string
    description = string
  }))
  default = [
    # Example mods (uncomment and modify as needed)
    # {
    #   name        = "jei"
    #   url         = "https://github.com/mezz/JustEnoughItems/releases/download/1.20.1-15.2.0.27/jei-1.20.1-15.2.0.27.jar"
    #   version     = "15.2.0.27"
    #   description = "Just Enough Items - Item and recipe viewer"
    # },
    # {
    #   name        = "applied-energistics-2"
    #   url         = "https://github.com/AppliedEnergistics/Applied-Energistics-2/releases/download/rv8-stable-8/appliedenergistics2-rv8-stable-8.jar"
    #   version     = "rv8-stable-8"
    #   description = "Applied Energistics 2 - Storage and automation mod"
    # }
  ]
} 