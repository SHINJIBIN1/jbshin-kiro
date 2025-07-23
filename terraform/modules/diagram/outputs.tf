output "diagram_path" {
  description = "Path to the generated diagram file"
  value       = local.diagram_path
}

output "mermaid_diagram" {
  description = "Mermaid diagram code for the infrastructure"
  value       = local.mermaid_diagram
}

output "diagram_updated" {
  description = "Indicates if the diagram was successfully updated"
  value       = local.diagram_updated
}