# Archive for minimal backup function
data "archive_file" "minimal_backup_zip" {
  type        = "zip"
  source_file = "${path.module}/script/minimal-backup.js"
  output_path = "${path.module}/minimal-backup.zip"
}
