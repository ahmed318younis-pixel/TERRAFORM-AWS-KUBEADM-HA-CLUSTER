data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "base" {
  name_prefix        = "${var.project_name}-base-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role" "bootstrap_writer" {
  name_prefix        = "${var.project_name}-writer-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role" "bootstrap_reader" {
  name_prefix        = "${var.project_name}-reader-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "base_ssm" {
  role       = aws_iam_role.base.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "writer_ssm" {
  role       = aws_iam_role.bootstrap_writer.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "reader_ssm" {
  role       = aws_iam_role.bootstrap_reader.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "bootstrap_writer" {
  statement {
    sid    = "WriteBootstrapParameters"
    effect = "Allow"

    actions = [
      "ssm:DeleteParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:PutParameter"
    ]

    resources = [local.ssm_parameter_arn]
  }
}

data "aws_iam_policy_document" "bootstrap_reader" {
  statement {
    sid    = "ReadBootstrapParameters"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]

    resources = [local.ssm_parameter_arn]
  }
}

resource "aws_iam_role_policy" "bootstrap_writer" {
  name_prefix = "bootstrap-writer-"
  role        = aws_iam_role.bootstrap_writer.id
  policy      = data.aws_iam_policy_document.bootstrap_writer.json
}

resource "aws_iam_role_policy" "bootstrap_reader" {
  name_prefix = "bootstrap-reader-"
  role        = aws_iam_role.bootstrap_reader.id
  policy      = data.aws_iam_policy_document.bootstrap_reader.json
}

resource "aws_iam_instance_profile" "base" {
  name_prefix = "${var.project_name}-base-"
  role        = aws_iam_role.base.name
}

resource "aws_iam_instance_profile" "bootstrap_writer" {
  name_prefix = "${var.project_name}-writer-"
  role        = aws_iam_role.bootstrap_writer.name
}

resource "aws_iam_instance_profile" "bootstrap_reader" {
  name_prefix = "${var.project_name}-reader-"
  role        = aws_iam_role.bootstrap_reader.name
}
