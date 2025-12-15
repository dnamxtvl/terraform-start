data "archive_file" "log_channel_zip" {
  type        = "zip"
  source_file = "${path.module}/log-channel.mjs"
  output_path = "${path.module}/log-channel.zip"
}

resource "aws_lambda_function" "log_channel" {
  function_name = "quiz-ecs-log-to-chat"
  role          = var.lambda_role_arn
  handler       = "log-channel.handler"
  runtime       = "nodejs22.x"
  filename      = data.archive_file.log_channel_zip.output_path

  source_code_hash = data.archive_file.log_channel_zip.output_base64sha256

  environment {
    variables = {
      GOOGLE_CHAT_GENERAL_WEBHOOK = var.google_chat_general_webhook
      GOOGLE_CHAT_ERROR_WEBHOOK   = var.google_chat_error_webhook
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/quiz-ecs-log-to-chat"
  retention_in_days = 14
}

