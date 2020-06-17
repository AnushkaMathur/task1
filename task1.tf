provider "aws" {
	region	= "ap-south-1"
	profile	= "anushka"
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"


  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_task1"
  }
}


resource "aws_instance" "web" {
	ami = "ami-0447a12f28fddb066"
	instance_type	= "t2.micro"
	key_name  = "key11"
	security_groups	= [ "allow_tls" ]

	connection {
		type		= "ssh"
		user		= "ec2-user"
		private_key	= file(path of key file)
		host		= aws_instance.web.public_ip
	}
	
	provisioner "remote-exec" {
		inline = [
			"sudo yum install httpd git php -y ",
			"sudo systemctl restart httpd",
			"sudo systemctl enable httpd",
		]
	}


	tags = {
		Name = "task1"
	}
}

resource "aws_ebs_volume" "myebs" {
	availability_zone = aws_instance.web.availability_zone
	size	= 1

	tags = {
		Name	= "myebs"
	}
}

resource "aws_volume_attachment" "ebs_attach" {
	device_name	= "/dev/sdh"
	volume_id	= aws_ebs_volume.myebs.id
	instance_id	= aws_instance.web.id
	force_detach	= true
}



resource "null_resource" "connection" {
	depends_on		= [
		aws_volume_attachment.ebs_attach,
	]
	
	connection {
		type		= "ssh"
		user		= "ec2-user"
		private_key	= file("path of key file")
		host		= aws_instance.web.public_ip
	}
	
	provisioner "remote-exec" {
		inline = [
			"sudo mkfs.ext4 /dev/xvdh",
			"sudo mount /dev/xvdh /var/www/html/",
			"sudo rm -rf /var/www/html/*",
			"sudo git clone https://github.com/AnushkaMathur/sample.git /var/www/html/",
		]
	}
}


resource "aws_s3_bucket" "task1hze3hxyz458415660979" {
  bucket = "task1hze3hxyz458415660979"
  acl    = "public-read"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
versioning {
		enabled		= true
	}

provisioner "local-exec" {
		command	= "git clone https://github.com/AnushkaMathur/sample.git mydata"
	}
	
	provisioner "local-exec" {
        when        = destroy
        command     = "echo Y | rmdir /s mydata"
    }
}
resource "aws_s3_bucket_object" "upload_image" {
	bucket	= aws_s3_bucket.task1hze3hxyz458415660979.bucket
	key	= "img.png"
	source	= "mydata/img.png"
	acl	= "public-read"
}



locals {
	s3_origin_id	= "aws_s3_bucket.task1hze3hxyz458415660979.id"
}

resource "aws_cloudfront_distribution" "s3_cf" {
	origin {
		domain_name	= aws_s3_bucket.task1hze3hxyz458415660979.bucket_regional_domain_name
		origin_id	= local.s3_origin_id
	}
	
	enabled		= true
	is_ipv6_enabled		= true
	comment				= "Some comment"
	default_root_object	= "img.png"
	logging_config {
		include_cookies	= false
		bucket			=  aws_s3_bucket.task1hze3hxyz458415660979.bucket_domain_name
	}

	default_cache_behavior {
		allowed_methods		= ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods		= ["GET", "HEAD"]
		target_origin_id	= local.s3_origin_id
		forwarded_values {
			query_string	= false
			cookies {
				forward = "none"
			}
		}
		
		viewer_protocol_policy	= "allow-all"
		min_ttl					= 0
		default_ttl				= 3600
		max_ttl					= 86400
	}
  
  	ordered_cache_behavior {
		path_pattern		= "/content/*"
		allowed_methods		= ["GET", "HEAD", "OPTIONS"]
		cached_methods		= ["GET", "HEAD"]
		target_origin_id	= local.s3_origin_id
		forwarded_values {
			query_string	= false
			cookies {
				forward = "none"
			}
		}
    
		min_ttl	= 0
		default_ttl	= 3200
		max_ttl		= 82400
		compress	= true
		viewer_protocol_policy	= "redirect-to-https"
	}
	
	price_class	= "PriceClass_200"
	restrictions {
		geo_restriction {
		restriction_type	= "whitelist"
		locations	= ["US", "CA", "GB", "DE","IN"]
		}
	}
	
	tags = {
		Environment	= "prod"
	}
	
	viewer_certificate {
		cloudfront_default_certificate	= true
	}
}

resource "null_resource" "nulldisplay"  {
	depends_on = [
		aws_cloudfront_distribution.s3_cf,
	]
	connection {
		type		= "ssh"
		user		= "ec2-user"
		private_key	= file(path of key file")
		host		= aws_instance.web.public_ip
	}
	
	provisioner "remote-exec" {
		inline = [
			"sudo su << EOF",
			"echo \"<img src='https://${aws_cloudfront_distribution.s3_cf.domain_name}/img.png' alt='image'>\" >> /var/www/html/index.html",
			"EOF",
		]
	}
}



