//Testing Terraform with Python
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}


resource "random_pet" "lambda_bucket_name" {
  prefix = "learn-terraform-functions"
  length = 1
}


resource "aws_s3_bucket" "lambda_bucket" {
    bucket = random_pet.lambda_bucket_name.id
    //acl = "${var.acl_value}"   
}


data "archive_file" "lambda_current_time" {
  type = "zip"

  source_dir  = "${path.module}/src"
  output_path = "${path.module}/main.zip"
}

resource "aws_s3_object" "lambda_current_time" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "main.zip"
  source = data.archive_file.lambda_current_time.output_path

  etag = filemd5(data.archive_file.lambda_current_time.output_path)
}

//DynamoDB

resource "aws_dynamodb_table" "score_table" {
  name             = "scores"
  hash_key         = "id"
  billing_mode   = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 10
  
  attribute {
    name = "id"
    type = "S"
  }

}

//CREAZIONE DELLA LAMBDA

resource "aws_lambda_function" "get_time" {
  function_name = "GetCurrenttime"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_current_time.key

  runtime = "python3.8"
  handler = "main.lambda_handler"

  source_code_hash = data.archive_file.lambda_current_time.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "get_time" {
  name = "/aws/lambda/${aws_lambda_function.get_time.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda_pys"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_rw" {
  name        = "rw_policy"
  path        = "/"
  description = "Read and Write policy for DynamoDB"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.score_table.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_rw_att" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_rw.arn
}


//CREAZIONE DELL'API GATEWAY

//Definiamo l'API gateway (nome, protocollo)
resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw_py"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

//Si configura l'api gateway che deve usare la lambda
resource "aws_apigatewayv2_integration" "get_time" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get_time.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_time" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /time"
  target    = "integrations/${aws_apigatewayv2_integration.get_time.id}"
}

resource "aws_apigatewayv2_route" "insert_table_row" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /time"
  target    = "integrations/${aws_apigatewayv2_integration.get_time.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_time.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}



/*
//Creazione del metodo

resource "aws_api_gateway_rest_api" "get_scoresAPI" {
  name        = "GetScores"
  description = "Test API gateway con più metodi"
}

resource "aws_api_gateway_resource" "get_scoresRes" {
  rest_api_id = aws_api_gateway_rest_api.get_scoresAPI.id
  parent_id   = aws_api_gateway_rest_api.get_scoresAPI.root_resource_id
  path_part   = "mydemoresource"
}

resource "aws_api_gateway_method" "get_scoresMet" {
  rest_api_id   = aws_api_gateway_rest_api.get_scoresAPI.id
  resource_id   = aws_api_gateway_resource.get_scoresRes.id
  http_method   = "POST"
  authorization = "NONE"
}
*/